import crypto from "node:crypto";
import { Op } from "sequelize";

import { getEnv } from "../../config/env";
import { logger } from "../../config/logger";
import HostSheetIntegration from "../../models/host-sheet-integration";
import HostSheetSyncJob, { HostSheetSyncJobDocument } from "../../models/host-sheet-sync-job";
import { enqueueHostSheetSyncJob, runHostSheetSyncCycle } from "./host-sheet-sync.service";

const WORKER_INSTANCE_ID = `sheet-worker-${process.pid}-${crypto.randomBytes(4).toString("hex")}`;
const JOB_CLAIM_LEASE_MS = 120_000;

let workerIntervalHandle: NodeJS.Timeout | null = null;
let pollSchedulerHandle: NodeJS.Timeout | null = null;
let workerTickInFlight = false;

export const claimNextPendingSheetSyncJob = async (
    workerId = WORKER_INSTANCE_ID,
): Promise<HostSheetSyncJobDocument | null> => {
    const now = new Date();

    const candidate = await HostSheetSyncJob.findOne({
        where: {
            [Op.or]: [
                {
                    status: "pending",
                    availableAt: { [Op.lte]: now },
                },
                {
                    status: "processing",
                    lockedUntil: { [Op.lt]: now },
                },
            ],
        },
        order: [
            ["priority", "ASC"],
            ["availableAt", "ASC"],
            ["jobId", "ASC"],
        ],
    });

    if (!candidate) {
        return null;
    }

    const leaseUntil = new Date(now.getTime() + JOB_CLAIM_LEASE_MS);
    const [claimedCount] = await HostSheetSyncJob.update(
        {
            status: "processing",
            lockedBy: workerId,
            lockedUntil: leaseUntil,
            attempts: Number(candidate.attempts ?? 0) + 1,
        },
        {
            where: {
                jobId: candidate.jobId,
                [Op.or]: [
                    { status: "pending" },
                    {
                        status: "processing",
                        lockedUntil: { [Op.lt]: now },
                    },
                ],
            },
        },
    );

    if (claimedCount === 0) {
        return null;
    }

    return HostSheetSyncJob.findByPk(candidate.jobId);
};

export const processClaimedSheetSyncJob = async (
    job: HostSheetSyncJobDocument,
): Promise<{ status: "succeeded" | "requeued" | "failed" | "cancelled" }> => {
    const integration = await HostSheetIntegration.findOne({
        where: { hostUserId: job.hostUserId },
    });

    if (!integration || integration.status === "disconnected") {
        job.status = "cancelled";
        job.lockedBy = null;
        job.lockedUntil = null;
        job.completedAt = new Date();
        await job.save();
        return { status: "cancelled" };
    }

    try {
        const mode =
            job.jobType === "init_standard_calendar" || job.jobType === "structure_repair"
                ? "initialize"
                : "bidirectional";

        const result = await runHostSheetSyncCycle(job.hostUserId, { mode });

        if (result.skippedBecauseLocked) {
            // Another worker instance is currently syncing this Host; defer without counting as failure
            job.status = "pending";
            job.attempts = Math.max(0, Number(job.attempts ?? 1) - 1);
            job.availableAt = new Date(Date.now() + 5_000);
            job.lockedBy = null;
            job.lockedUntil = null;
            await job.save();
            return { status: "requeued" };
        }

        job.status = "succeeded";
        job.lockedBy = null;
        job.lockedUntil = null;
        job.lastError = null;
        job.completedAt = new Date();
        await job.save();

        // Coalesce any duplicate pending jobs of lower/equal urgency that were covered by this fresh DB sync!
        await HostSheetSyncJob.update(
            {
                status: "succeeded",
                completedAt: new Date(),
            },
            {
                where: {
                    hostUserId: job.hostUserId,
                    status: "pending",
                    jobType: {
                        [Op.in]: ["periodic_poll", "booking_changed", "app_calendar_updated", "listing_updated"],
                    },
                    createdAt: {
                        [Op.lte]: job.updatedAt ?? new Date(),
                    },
                },
            },
        ).catch(() => undefined);

        return { status: "succeeded" };
    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        const attempts = Number(job.attempts ?? 1);
        const maxAttempts = Number(job.maxAttempts ?? 5);

        const isNonRetryablePermissionError =
            integration.status === "permission_error" ||
            /Editor|quyền|403/i.test(errorMessage);

        if (isNonRetryablePermissionError || attempts >= maxAttempts) {
            job.status = "failed";
            job.lastError = errorMessage;
            job.lockedBy = null;
            job.lockedUntil = null;
            job.completedAt = new Date();
            await job.save();
            return { status: "failed" };
        }

        const backoffSeconds = Math.min(300, Math.pow(2, attempts) * 10);
        job.status = "pending";
        job.lastError = errorMessage;
        job.availableAt = new Date(Date.now() + backoffSeconds * 1000);
        job.lockedBy = null;
        job.lockedUntil = null;
        await job.save();
        return { status: "requeued" };
    }
};

export const runSheetSyncWorkerTick = async (maxJobsPerTick = 5): Promise<number> => {
    if (workerTickInFlight) {
        return 0;
    }

    workerTickInFlight = true;
    let processed = 0;

    try {
        for (let i = 0; i < maxJobsPerTick; i += 1) {
            const job = await claimNextPendingSheetSyncJob();
            if (!job) {
                break;
            }
            await processClaimedSheetSyncJob(job);
            processed += 1;
        }
    } catch (error) {
        logger.warn("Host sheet sync worker tick encountered an error", {
            errorMessage: error instanceof Error ? error.message : String(error),
        });
    } finally {
        workerTickInFlight = false;
    }

    return processed;
};

export const scheduleDuePeriodicPolls = async (batchLimit = 20): Promise<number> => {
    const now = new Date();
    const env = getEnv();

    const dueIntegrations = await HostSheetIntegration.findAll({
        where: {
            autoSyncEnabled: true,
            status: {
                [Op.in]: ["connected", "quota_limited", "sync_error"],
            },
            [Op.or]: [
                { nextPollAt: null },
                { nextPollAt: { [Op.lte]: now } },
            ],
        },
        order: [["nextPollAt", "ASC"]],
        limit: batchLimit,
    });

    let enqueued = 0;
    for (const integration of dueIntegrations) {
        // Space out nextPollAt immediately so multiple instances don't enqueue duplicate polls
        integration.nextPollAt = new Date(
            now.getTime() + env.googleSheetsSyncIntervalSeconds * 1000,
        );
        await integration.save();

        const created = await enqueueHostSheetSyncJob({
            hostUserId: integration.hostUserId,
            jobType: "periodic_poll",
            priority: 80,
        });
        if (created) {
            enqueued += 1;
        }
    }

    return enqueued;
};

export const startHostSheetSyncWorker = (): void => {
    if (process.env.NODE_ENV === "test") {
        return;
    }
    if (!getEnv().googleSheetsSyncEnabled) {
        return;
    }
    if (workerIntervalHandle) {
        return;
    }

    workerIntervalHandle = setInterval(() => {
        void runSheetSyncWorkerTick(4);
    }, 4_000);

    pollSchedulerHandle = setInterval(() => {
        void scheduleDuePeriodicPolls(20).catch((error: unknown) => {
            logger.warn("Host sheet periodic poll scheduler error", {
                errorMessage: error instanceof Error ? error.message : String(error),
            });
        });
    }, 25_000);

    logger.info("Host Google Sheets bidirectional sync worker started", {
        workerId: WORKER_INSTANCE_ID,
    });
};

export const stopHostSheetSyncWorker = (): void => {
    if (workerIntervalHandle) {
        clearInterval(workerIntervalHandle);
        workerIntervalHandle = null;
    }
    if (pollSchedulerHandle) {
        clearInterval(pollSchedulerHandle);
        pollSchedulerHandle = null;
    }
};
