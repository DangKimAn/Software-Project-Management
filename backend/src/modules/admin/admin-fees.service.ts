import { Op, QueryTypes, Transaction } from "sequelize";

import sequelize from "../../config/database";
import { ApiError } from "../../common/api-error";
import PlatformFeeSetting, { type PlatformFeeStatus } from "../../models/platform-fee-setting";
import { notifyAllHostsPlatformFeeScheduled } from "../notifications/notification.service";

export type FeeSettingResponse = {
    id: number;
    feePct: number;
    status: PlatformFeeStatus;
    effectiveAt: string;
    createdByAdminId: number;
    cancelledByAdminId: number | null;
    reason: string | null;
    createdAt: string;
};

let cachedActiveFeePct = 10;
let cacheExpiresAt = Date.now() + 60 * 1000;

export const invalidatePlatformFeeCache = () => {
    cacheExpiresAt = 0;
};

/**
 * Ensures any scheduled fee that has reached its effective date
 * is automatically transitioned to 'active', while previous 'active' becomes 'superseded'.
 */
export const syncEffectivePlatformFee = async (
    transaction?: Transaction,
    forceSync = false,
): Promise<number> => {
    const now = new Date();

    if (!forceSync && cacheExpiresAt > now.getTime()) {
        return cachedActiveFeePct;
    }

    // Check if any scheduled record has reached its effective time
    const readyToActivate = await PlatformFeeSetting.findAll({
        where: {
            status: "scheduled",
            effectiveAt: { [Op.lte]: now },
        },
        order: [["effectiveAt", "ASC"]],
        transaction,
    });

    if (readyToActivate.length > 0) {
        for (const item of readyToActivate) {
            // Supersede previous active records
            await PlatformFeeSetting.update(
                { status: "superseded" },
                {
                    where: {
                        status: "active",
                    },
                    transaction,
                },
            );

            item.status = "active";
            await item.save({ transaction });
        }
    }

    // Return the current active fee percentage
    const activeSetting = await PlatformFeeSetting.findOne({
        where: { status: "active" },
        order: [["effectiveAt", "DESC"]],
        transaction,
    });

    cachedActiveFeePct = activeSetting ? Number(activeSetting.feePct) : 10;
    cacheExpiresAt = now.getTime() + 60 * 1000;
    return cachedActiveFeePct;
};

export const getCurrentPlatformFeeStatus = async () => {
    // 1. Sync any ready-to-activate records
    const activeFeePct = await syncEffectivePlatformFee(undefined, true);

    const activeSetting = await PlatformFeeSetting.findOne({
        where: { status: "active" },
        order: [["effectiveAt", "DESC"]],
    });

    const pendingScheduled = await PlatformFeeSetting.findOne({
        where: {
            status: "scheduled",
            effectiveAt: { [Op.gt]: new Date() },
        },
        order: [["effectiveAt", "ASC"]],
    });

    const historyRows = await PlatformFeeSetting.findAll({
        order: [["id", "DESC"]],
        limit: 20,
    });

    // Calculate total platform revenue to date
    const [revResult] = await sequelize.query<{ totalPlatformRevenue: string | number }>(
        `
        SELECT COALESCE(SUM(b.service_fee_amount), 0) AS totalPlatformRevenue
        FROM bookings b
        WHERE b.status NOT IN ('cancelled', 'rejected')
        `,
        { type: QueryTypes.SELECT },
    );

    const totalPlatformRevenue = Number(revResult?.totalPlatformRevenue ?? 0);

    let scheduledFee: (FeeSettingResponse & { countdownSeconds: number }) | null = null;
    if (pendingScheduled) {
        const diffMs = pendingScheduled.effectiveAt.getTime() - Date.now();
        const countdownSeconds = Math.max(0, Math.floor(diffMs / 1000));
        scheduledFee = {
            id: pendingScheduled.id,
            feePct: Number(pendingScheduled.feePct),
            status: pendingScheduled.status,
            effectiveAt: pendingScheduled.effectiveAt.toISOString(),
            createdByAdminId: pendingScheduled.createdByAdminId,
            cancelledByAdminId: pendingScheduled.cancelledByAdminId,
            reason: pendingScheduled.reason,
            createdAt: pendingScheduled.createdAt.toISOString(),
            countdownSeconds,
        };
    }

    return {
        activeFee: {
            id: activeSetting?.id ?? 0,
            feePct: activeFeePct,
            status: "active" as const,
            effectiveAt: activeSetting?.effectiveAt.toISOString() ?? new Date().toISOString(),
        },
        scheduledFee,
        totalPlatformRevenue,
        history: historyRows.map((h) => ({
            id: h.id,
            feePct: Number(h.feePct),
            status: h.status,
            effectiveAt: h.effectiveAt.toISOString(),
            createdByAdminId: h.createdByAdminId,
            cancelledByAdminId: h.cancelledByAdminId,
            reason: h.reason,
            createdAt: h.createdAt.toISOString(),
        })),
    };
};

export const schedulePlatformFeeChange = async (params: {
    feePct: number;
    reason?: string | null;
    adminUserId: number;
}) => {
    const { feePct, reason, adminUserId } = params;

    if (!Number.isFinite(feePct) || feePct < 0 || feePct > 100) {
        throw new ApiError(400, "Tỷ lệ phí nền tảng phải là số từ 0% đến 100%");
    }

    // Sync active fee
    const currentActiveFeePct = await syncEffectivePlatformFee(undefined, true);

    if (Math.abs(currentActiveFeePct - feePct) < 0.001) {
        throw new ApiError(400, `Mức phí nền tảng hiện tại đã là ${feePct}%. Vui lòng chọn mức phí khác.`);
    }

    // Check if an upcoming scheduled change already exists
    const existingScheduled = await PlatformFeeSetting.findOne({
        where: {
            status: "scheduled",
            effectiveAt: { [Op.gt]: new Date() },
        },
    });

    if (existingScheduled) {
        throw new ApiError(
            409,
            `Đang có một lịch điều chỉnh phí (${existingScheduled.feePct}%) chờ hiệu lực. Vui lòng hủy lịch cũ trước khi tạo lịch mới.`,
        );
    }

    // Grace period: Exactly 7 days from now
    const now = new Date();
    const effectiveAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    const newSetting = await PlatformFeeSetting.create({
        feePct,
        status: "scheduled",
        effectiveAt,
        createdByAdminId: adminUserId,
        cancelledByAdminId: null,
        reason: reason?.trim() || null,
        notificationSentAt: now,
    });
    invalidatePlatformFeeCache();

    // Notify all active hosts via In-App, FCM Push, and Email
    try {
        await notifyAllHostsPlatformFeeScheduled(
            newSetting.id,
            currentActiveFeePct,
            feePct,
            effectiveAt,
            reason,
        );
    } catch (err) {
        // Notification failure shouldn't abort transaction but log it
        console.error("Failed to notify hosts of fee schedule:", err);
    }

    return {
        id: newSetting.id,
        feePct: Number(newSetting.feePct),
        status: newSetting.status,
        effectiveAt: newSetting.effectiveAt.toISOString(),
        createdByAdminId: newSetting.createdByAdminId,
        reason: newSetting.reason,
        createdAt: newSetting.createdAt.toISOString(),
    };
};

export const cancelScheduledPlatformFee = async (adminUserId: number) => {
    const pendingScheduled = await PlatformFeeSetting.findOne({
        where: {
            status: "scheduled",
            effectiveAt: { [Op.gt]: new Date() },
        },
    });

    if (!pendingScheduled) {
        throw new ApiError(404, "Không có lịch điều chỉnh phí nào đang chờ kích hoạt để hủy.");
    }

    pendingScheduled.status = "cancelled";
    pendingScheduled.cancelledByAdminId = adminUserId;
    await pendingScheduled.save();
    invalidatePlatformFeeCache();

    return {
        success: true,
        message: `Đã hủy lịch điều chỉnh phí ${pendingScheduled.feePct}% thành công.`,
    };
};
