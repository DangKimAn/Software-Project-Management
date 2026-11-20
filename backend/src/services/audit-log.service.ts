// CONFLICT-RESOLVED: Chuẩn hóa tên tệp dịch vụ kiểm toán hạ tầng từ `audit-log-service.ts` sang `audit-log.service.ts`.
import type { Transaction } from "sequelize";

import { logger } from "../config/logger";
import AuditLog from "../models/audit-log";

export type AuditLogInput = {
    actorId?: number | null;
    action: string;
    targetType: string;
    targetId?: number | null;
    metadata?: Record<string, unknown> | null;
    ipAddress?: string | null;
    userAgent?: string | null;
    transaction?: Transaction;
};

/**
 * Giải thuật ghi nhận nhật ký kiểm toán an toàn không làm gián đoạn luồng chính (Fail-Safe Audit Logging):
 * - Lưu bản ghi sự kiện (`actorId`, `action`, `targetType`, `targetId`, `metadataJson`, `ipAddress`, `userAgent`)
 *   vào bảng `audit_logs`, hỗ trợ tham gia cùng giao dịch DB (`transaction`) khi cần tính nguyên tử.
 * - Bắt và ghi cảnh báo mọi ngoại lệ phát sinh để lỗi phụ trợ ghi audit không làm đổ vỡ thao tác nghiệp vụ.
 */
export const writeAuditLog = async (input: AuditLogInput) => {
    try {
        await AuditLog.create(
            {
                actorId: input.actorId ?? null,
                action: input.action,
                targetType: input.targetType,
                targetId: input.targetId ?? null,
                metadataJson: input.metadata ?? null,
                ipAddress: input.ipAddress ?? null,
                userAgent: input.userAgent ?? null,
            },
            {
                transaction: input.transaction,
            },
        );
    } catch (error) {
        logger.warn("Unable to write audit log", {
            action: input.action,
            targetType: input.targetType,
            targetId: input.targetId,
            error: error instanceof Error ? error.message : error,
        });
    }
};
