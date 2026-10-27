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
