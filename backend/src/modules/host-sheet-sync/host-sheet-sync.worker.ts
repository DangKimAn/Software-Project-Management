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

/**
 * Giải thuật nhận việc nguyên tử theo cơ chế thuê bao có thời hạn (Atomic Optimistic Lease Claim)
 * chống chạy chồng chéo giữa nhiều worker và tự động thu hồi tác vụ treo quá hạn (Timeout Recovery):
 * 1. Truy vấn ứng viên sẵn sàng thực thi theo thứ tự ưu tiên `(priority ASC, availableAt ASC, jobId ASC)`
 *    thỏa một trong hai trạng thái: đang `pending` và đã đến hạn `availableAt <= now`, hoặc đang `processing`
 *    nhưng đã quá hạn khóa thuê bao `lockedUntil < now` (worker trước bị sự cố/timeout quá `120s`).
 * 2. Thực hiện cập nhật nguyên tử có điều kiện kiểm tra lại trạng thái ngay trong mệnh đề `WHERE` (Compare-And-Swap):
 *    gán `status = "processing"`, `lockedBy = workerId`, cấp thời hạn thuê `lockedUntil = now + JOB_CLAIM_LEASE_MS`
 *    và tăng `attempts` thêm `1`.
 * 3. Nếu `claimedCount === 0` (đã bị worker khác giành trước), trả về `null` an toàn mà không xử lý trùng.
 */
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

/**
 * Giải thuật thực thi công việc đồng bộ đã nhận kèm gộp hàng đợi (Job Coalescing) và thử lại giãn cách lũy thừa:
 * 1. Nếu tích hợp của chủ nhà không tồn tại hoặc đã `disconnected`, hủy công việc (`cancelled`) và giải phóng khóa.
 * 2. Kích hoạt `runHostSheetSyncCycle` theo chế độ `initialize` hoặc `bidirectional`. Nếu bảng tính đang bị khóa
 *    bởi luồng đồng bộ khác (`skippedBecauseLocked`), hoàn trả công việc về `pending`, hoàn lại lượt đếm `attempts`
 *    và hẹn thực thi lại sau `5 giây` mà không tính là lỗi.
 * 3. Khi hoàn tất thành công: đánh dấu `succeeded`, đồng thời hợp nhất (coalesce) đánh dấu hoàn thành luôn các
 *    công việc `pending` cùng chủ nhà được tạo trước thời điểm vừa đồng bộ để tránh gọi thừa Google Sheets API.
 * 4. Khi gặp lỗi: nếu là lỗi phân quyền không thể tự hồi phục (`403 / Editor`) hoặc đã chạm trần `maxAttempts`,
 *    chuyển sang `failed`; ngược lại tính độ trễ lũy thừa `backoffSeconds = min(300, 2^attempts * 10)` giây
 *    và đưa lại về trạng thái `pending` chờ thử lại.
 */
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

        const forceConfirm =
            job.jobType === "manual_sync" || mode === "initialize";

        const result = await runHostSheetSyncCycle(job.hostUserId, {
            mode,
            trigger: job.jobType,
            forceConfirm,
        });

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

/**
 * Giải thuật thực thi một nhịp của vòng lặp worker nền với chốt chống tái nhập cục bộ (`workerTickInFlight`):
 * - Ngăn chặn các chu kỳ định thời `setInterval` chạy chồng lên nhau trong cùng một tiến trình khi tác vụ I/O kéo dài.
 * - Xử lý tuần tự tối đa `maxJobsPerTick` công việc mỗi nhịp (thoát sớm ngay khi hàng đợi hết việc sẵn sàng)
 *   và luôn đảm bảo mở lại khóa `workerTickInFlight = false` trong khối `finally`.
 */
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

/**
 * Giải thuật lập lịch quét đồng bộ định kỳ cho các kết nối Google Sheets đến hạn (`nextPollAt <= now` hoặc `null`):
 * - Truy vấn theo lô tối đa `batchLimit` tích hợp đang bật `autoSyncEnabled` và ở trạng thái cho phép đồng bộ.
 * - Dời mốc `nextPollAt = now + googleSheetsSyncIntervalSeconds` trước khi gọi `enqueueHostSheetSyncJob`
 *   để ngăn nhiều tiến trình máy chủ xếp hàng trùng lặp các tác vụ quét định kỳ.
 */
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

/**
 * Khởi động cặp bộ định thời nền của worker đồng bộ Google Sheets (tiêu thụ hàng đợi mỗi `4s` và lập lịch
 * quét định kỳ mỗi `25s`), tự động bỏ qua trong môi trường `test`, khi tắt cấu hình hoặc khi worker đã chạy.
 */
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

/**
 * Giải thuật thu hồi tài nguyên bộ định thời nền (`clearInterval`) khi tắt tiến trình máy chủ (Graceful Shutdown),
 * giải phóng hoàn toàn `workerIntervalHandle` và `pollSchedulerHandle` để không chặn vòng lặp sự kiện Node.js.
 */
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
