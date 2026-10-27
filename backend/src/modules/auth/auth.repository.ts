import { QueryTypes, type Transaction } from "sequelize";

import sequelize from "../../config/database";
import { logger } from "../../config/logger";
import AuthOtpToken from "../../models/auth-otp-token";
import RefreshSession from "../../models/refresh-session";
import SocialAccount from "../../models/social-account";
import User from "../../models/user";

export { AuthOtpToken, RefreshSession, SocialAccount, User };

type AuditLogInput = {
    actorId?: string | number | null;
    action: string;
    targetType: string;
    targetId?: string | number | null;
    metadata?: Record<string, unknown>;
    ipAddress?: string | null;
    userAgent?: string | null;
    transaction?: Transaction;
};

export const createAuditLog = async (input: AuditLogInput) => {
    try {
        await sequelize.query(
            `
            INSERT INTO audit_logs (
                actor_id,
                action,
                target_type,
                target_id,
                metadata_json,
                ip_address,
                user_agent,
                created_at
            )
            VALUES (
                :actorId,
                :action,
                :targetType,
                :targetId,
                :metadataJson,
                :ipAddress,
                :userAgent,
                NOW()
            )
            `,
            {
                replacements: {
                    actorId: input.actorId == null ? null : Number(input.actorId),
                    action: input.action,
                    targetType: input.targetType,
                    targetId: input.targetId == null ? null : Number(input.targetId),
                    metadataJson: input.metadata ? JSON.stringify(input.metadata) : null,
                    ipAddress: input.ipAddress ?? null,
                    userAgent: input.userAgent ?? null,
                },
                transaction: input.transaction,
            },
        );
    } catch (error) {
        logger.warn("Unable to write audit log", {
            action: input.action,
            targetType: input.targetType,
            error: error instanceof Error ? error.message : error,
        });
    }
};

export const countRecentAuditLogsByIdentifierHash = async (
    action: string,
    identifierHash: string,
    since: Date,
) => {
    try {
        const rows = await sequelize.query<{ count: number }>(
            `
            SELECT COUNT(*) AS count
            FROM audit_logs
            WHERE action = :action
              AND created_at >= :since
              AND JSON_UNQUOTE(JSON_EXTRACT(metadata_json, '$.identifierHash')) = :identifierHash
            `,
            {
                replacements: {
                    action,
                    identifierHash,
                    since,
                },
                type: QueryTypes.SELECT,
            },
        );

        return Number(rows[0]?.count ?? 0);
    } catch {
        return 0;
    }
};
