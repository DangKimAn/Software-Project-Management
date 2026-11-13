import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";

import { cert, getApps, initializeApp, type ServiceAccount } from "firebase-admin/app";
import {
    getMessaging,
    type BatchResponse,
    type FidMulticastMessage,
    type MulticastMessage,
} from "firebase-admin/messaging";

import { Op, UniqueConstraintError } from "sequelize";

import { ApiError } from "../common/api-error";
import { getEnv } from "../config/env";
import { logger } from "../config/logger";
import User from "../models/user";
import UserDeviceToken, { type DevicePlatform } from "../models/user-device-token";

export const ANDROID_NOTIFICATION_CHANNEL_ID = "minh_thanh_villa_high_importance";

export type RegisterDeviceTokenInput = {
    userId: number;
    token: string;
    platform?: string | null;
    appFlavor?: string | null;
    deviceLabel?: string | null;
};

export type PushNotificationPayload = {
    title: string;
    body: string;
    actionUrl?: string | null;
    eventType?: string | null;
    targetType?: string | null;
    targetId?: string | number | null;
    notificationLogId?: number | null;
    data?: Record<string, unknown> | null;
};

export type FcmMulticastPayload = MulticastMessage | FidMulticastMessage;
export type FcmMulticastSender = (message: FcmMulticastPayload) => Promise<BatchResponse>;

const FIREBASE_APP_NAME = "minh-thanh-villa-fcm";
const DEFAULT_SERVICE_ACCOUNT_REL_PATH = "./secrets/firebase-service-account.json";
const FIREBASE_FID_PATTERN = /^[c-f][A-Za-z0-9_-]{21}$/;
const PERMANENT_INVALID_TOKEN_CODES = new Set<string>([
    "messaging/registration-token-not-registered",
    "messaging/installation-id-not-registered",
    "messaging/invalid-registration-token",
    "messaging/invalid-argument",
    "messaging/mismatched-credential",
]);

let cachedSender: FcmMulticastSender | null | undefined;
let customSenderForTesting: FcmMulticastSender | null = null;
let loggedMissingConfig = false;

export const setFcmMulticastSenderForTesting = (sender: FcmMulticastSender | null) => {
    customSenderForTesting = sender;
};

export const resetFcmServiceCacheForTesting = () => {
    cachedSender = undefined;
    customSenderForTesting = null;
    loggedMissingConfig = false;
};

export const hashDeviceToken = (rawToken: string): string =>
    createHash("sha256").update(rawToken.trim(), "utf8").digest("hex");

const normalizePlatform = (raw: string | null | undefined): DevicePlatform => {
    const lower = (raw ?? "").trim().toLowerCase();
    if (lower === "ios") return "ios";
    if (lower === "web") return "web";
    return "android";
};

const validateFcmToken = (rawToken: unknown): string => {
    if (typeof rawToken !== "string") {
        throw new ApiError(400, "FCM device token is required");
    }
    const trimmed = rawToken.trim();
    if (trimmed.length < 20 || trimmed.length > 512) {
        throw new ApiError(400, "FCM device token length is invalid");
    }
    if (/[\r\n\s]/.test(trimmed)) {
        throw new ApiError(400, "FCM device token format is invalid");
    }
    return trimmed;
};

type RawServiceAccount = {
    project_id?: string;
    projectId?: string;
    client_email?: string;
    clientEmail?: string;
    private_key?: string;
    privateKey?: string;
};

const parseServiceAccountJson = (rawContent: string): ServiceAccount | null => {
    const trimmed = rawContent.trim();
    if (!trimmed) return null;

    let decodedText = trimmed;
    if (!trimmed.startsWith("{")) {
        try {
            decodedText = Buffer.from(trimmed, "base64").toString("utf8");
        } catch {
            return null;
        }
    }

    const parsed = JSON.parse(decodedText) as RawServiceAccount;
    const projectId = parsed.project_id ?? parsed.projectId;
    const clientEmail = parsed.client_email ?? parsed.clientEmail;
    const rawPrivateKey = parsed.private_key ?? parsed.privateKey;
    const privateKey = typeof rawPrivateKey === "string" ? rawPrivateKey.replace(/\\n/g, "\n") : undefined;

    if (!projectId || !clientEmail || !privateKey) {
        return null;
    }

    return {
        projectId,
        clientEmail,
        privateKey,
    };
};

const resolveServiceAccount = (): ServiceAccount | null => {
    const env = getEnv();

    if (env.firebaseServiceAccountJson?.trim()) {
        try {
            return parseServiceAccountJson(env.firebaseServiceAccountJson);
        } catch (error) {
            logger.error("Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON", error);
            return null;
        }
    }

    const configuredPath = env.firebaseServiceAccountPath?.trim();
    const candidateRelPath =
        configuredPath || (env.nodeEnv !== "test" ? DEFAULT_SERVICE_ACCOUNT_REL_PATH : "");

    if (!candidateRelPath) {
        return null;
    }

    const resolvedPath = path.isAbsolute(candidateRelPath)
        ? candidateRelPath
        : path.resolve(process.cwd(), candidateRelPath);

    if (!fs.existsSync(resolvedPath)) {
        if (configuredPath) {
            logger.warn("Configured FIREBASE_SERVICE_ACCOUNT_PATH does not exist", {
                configuredPath,
            });
        }
        return null;
    }

    try {
        const raw = fs.readFileSync(resolvedPath, "utf8");
        return parseServiceAccountJson(raw);
    } catch (error) {
        logger.error("Failed to load Firebase service account file", error);
        return null;
    }
};

const getOrCreateMulticastSender = (): FcmMulticastSender | null => {
    if (customSenderForTesting) {
        return customSenderForTesting;
    }
    if (getEnv().nodeEnv === "test") {
        return null;
    }
    if (cachedSender !== undefined) {
        return cachedSender;
    }

    const serviceAccount = resolveServiceAccount();
    if (!serviceAccount) {
        if (!loggedMissingConfig && getEnv().nodeEnv !== "test") {
            loggedMissingConfig = true;
            logger.info("FCM push notifications skipped: Firebase service account is not configured");
        }
        cachedSender = null;
        return null;
    }

    try {
        const existingApp = getApps().find((item) => item.name === FIREBASE_APP_NAME);
        const app =
            existingApp ??
            initializeApp(
                {
                    credential: cert(serviceAccount),
                },
                FIREBASE_APP_NAME,
            );
        const messaging = getMessaging(app);
        cachedSender = (message: FcmMulticastPayload) =>
            "tokens" in message
                ? messaging.sendEachForMulticast(message)
                : messaging.sendEachForMulticast(message);
        logger.info("Firebase Cloud Messaging initialized", {
            projectId: serviceAccount.projectId,
        });
        return cachedSender;
    } catch (error) {
        logger.error("Failed to initialize Firebase Admin SDK for FCM", error);
        cachedSender = null;
        return null;
    }
};

const MAX_ACTIVE_DEVICE_TOKENS_PER_USER = 20;
const FCM_MULTICAST_BATCH_SIZE = 500;
const SENSITIVE_PUSH_DATA_KEYS = new Set([
    "email",
    "useremail",
    "guestemail",
    "hostemail",
    "contactemail",
    "phone",
    "userphone",
    "guestphone",
    "hostphone",
    "contactphone",
    "token",
    "accesstoken",
    "refreshtoken",
    "otp",
    "password",
    "idnumber",
    "cccd",
    "accountnumber",
    "bankaccountnumber",
]);

const sanitizePushDataRecord = (input: Record<string, unknown>): Record<string, unknown> => {
    const cleaned: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(input)) {
        const normalizedKey = key.replace(/[_-]/g, "").toLowerCase();
        if (SENSITIVE_PUSH_DATA_KEYS.has(normalizedKey)) {
            continue;
        }
        if (value && typeof value === "object" && !Array.isArray(value)) {
            cleaned[key] = sanitizePushDataRecord(value as Record<string, unknown>);
        } else {
            cleaned[key] = value;
        }
    }
    return cleaned;
};

const pruneExcessUserDeviceTokens = async (userId: number) => {
    if (getEnv().nodeEnv === "test" && !Object.prototype.hasOwnProperty.call(UserDeviceToken, "findAll")) {
        return;
    }

    try {
        const activeTokens = await UserDeviceToken.findAll({
            where: {
                userId,
                isActive: true,
            },
            order: [["lastSeenAt", "DESC"]],
        });

        if (activeTokens.length <= MAX_ACTIVE_DEVICE_TOKENS_PER_USER) {
            return;
        }

        const staleHashes = activeTokens
            .slice(MAX_ACTIVE_DEVICE_TOKENS_PER_USER)
            .map((item) => item.tokenHash)
            .filter(Boolean);

        if (staleHashes.length > 0) {
            await UserDeviceToken.update(
                { isActive: false },
                {
                    where: {
                        userId,
                        tokenHash: { [Op.in]: staleHashes },
                    },
                },
            );
        }
    } catch {
        // Non-blocking cap cleanup
    }
};

export const deactivateAllUserDeviceTokens = async (userId: number): Promise<number> => {
    if (!Number.isInteger(userId) || userId < 1) {
        return 0;
    }

    if (getEnv().nodeEnv === "test" && !Object.prototype.hasOwnProperty.call(UserDeviceToken, "update")) {
        return 0;
    }

    try {
        const [updatedCount] = await UserDeviceToken.update(
            { isActive: false },
            {
                where: {
                    userId,
                    isActive: true,
                },
            },
        );
        return updatedCount;
    } catch (error) {
        logger.warn("Failed to deactivate user FCM device tokens", {
            userId,
            error: error instanceof Error ? error.message : String(error),
        });
        return 0;
    }
};

export const registerUserDeviceToken = async (input: RegisterDeviceTokenInput) => {
    if (!Number.isInteger(input.userId) || input.userId < 1) {
        throw new ApiError(401, "Unauthorized");
    }

    const fcmToken = validateFcmToken(input.token);
    const tokenHash = hashDeviceToken(fcmToken);
    const platform = normalizePlatform(input.platform);
    const appFlavor = input.appFlavor ? String(input.appFlavor).trim().slice(0, 32) : null;
    const deviceLabel = input.deviceLabel ? String(input.deviceLabel).trim().slice(0, 255) : null;
    const now = new Date();

    const existing = await UserDeviceToken.findOne({
        where: { tokenHash },
    });

    if (existing) {
        await existing.update({
            userId: input.userId,
            fcmToken,
            platform,
            appFlavor,
            deviceLabel,
            isActive: true,
            lastSeenAt: now,
        });
        await pruneExcessUserDeviceTokens(input.userId);

        return {
            deviceTokenId: Number(existing.deviceTokenId),
            platform: existing.platform,
            isActive: true,
        };
    }

    try {
        const created = await UserDeviceToken.create({
            userId: input.userId,
            fcmToken,
            tokenHash,
            platform,
            appFlavor,
            deviceLabel,
            isActive: true,
            lastSeenAt: now,
        });
        await pruneExcessUserDeviceTokens(input.userId);

        return {
            deviceTokenId: Number(created.deviceTokenId),
            platform: created.platform,
            isActive: true,
        };
    } catch (error) {
        if (error instanceof UniqueConstraintError) {
            const raced = await UserDeviceToken.findOne({
                where: { tokenHash },
            });
            if (raced) {
                await raced.update({
                    userId: input.userId,
                    fcmToken,
                    platform,
                    appFlavor,
                    deviceLabel,
                    isActive: true,
                    lastSeenAt: now,
                });
                await pruneExcessUserDeviceTokens(input.userId);

                return {
                    deviceTokenId: Number(raced.deviceTokenId),
                    platform: raced.platform,
                    isActive: true,
                };
            }
        }
        throw error;
    }
};

export const unregisterUserDeviceToken = async (params: {
    userId: number;
    token: unknown;
}) => {
    if (!Number.isInteger(params.userId) || params.userId < 1) {
        throw new ApiError(401, "Unauthorized");
    }

    const fcmToken = validateFcmToken(params.token);
    const tokenHash = hashDeviceToken(fcmToken);

    const [updatedCount] = await UserDeviceToken.update(
        {
            isActive: false,
        },
        {
            where: {
                userId: params.userId,
                tokenHash,
                isActive: true,
            },
        },
    );

    return {
        unregistered: updatedCount > 0,
    };
};

const buildStringDataMap = (payload: PushNotificationPayload): Record<string, string> => {
    const out: Record<string, string> = {};

    if (payload.actionUrl) out.actionUrl = String(payload.actionUrl);
    if (payload.eventType) out.eventType = String(payload.eventType);
    if (payload.targetType) out.targetType = String(payload.targetType);
    if (payload.targetId !== undefined && payload.targetId !== null) {
        out.targetId = String(payload.targetId);
    }
    if (payload.notificationLogId !== undefined && payload.notificationLogId !== null) {
        out.notificationLogId = String(payload.notificationLogId);
    }

    if (payload.data && typeof payload.data === "object") {
        const safeData = sanitizePushDataRecord(payload.data);
        for (const [key, value] of Object.entries(safeData)) {
            if (value === undefined || value === null || key in out) continue;
            if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
                out[key] = String(value);
            } else {
                try {
                    out[key] = JSON.stringify(value);
                } catch {
                    // Ignore non-serializable field
                }
            }
        }
        try {
            out.payloadJson = JSON.stringify(safeData);
        } catch {
            // Ignore non-serializable nested payload
        }
    }

    return out;
};

export const sendPushToUser = async (
    userId: number,
    payload: PushNotificationPayload,
): Promise<{ sentCount: number; failureCount: number; skipped?: boolean }> => {
    if (!Number.isFinite(userId) || userId < 1) {
        return { sentCount: 0, failureCount: 0, skipped: true };
    }

    const sender = getOrCreateMulticastSender();
    if (!sender) {
        return { sentCount: 0, failureCount: 0, skipped: true };
    }

    const title = (payload.title ?? "").trim();
    const body = (payload.body ?? "").trim();
    if (!title && !body) {
        return { sentCount: 0, failureCount: 0, skipped: true };
    }

    if (!(getEnv().nodeEnv === "test" && !Object.prototype.hasOwnProperty.call(User, "findByPk"))) {
        try {
            const recipientUser = await User.findByPk(userId);
            if (recipientUser && recipientUser.status && recipientUser.status !== "active") {
                await deactivateAllUserDeviceTokens(userId);
                return { sentCount: 0, failureCount: 0, skipped: true };
            }
        } catch {
            // Proceed if user status lookup is unavailable in isolated test context
        }
    }

    let deviceRecords: UserDeviceToken[] = [];
    try {
        deviceRecords = await UserDeviceToken.findAll({
            where: {
                userId,
                isActive: true,
            },
        });
    } catch (error) {
        logger.warn("Failed to look up active FCM device tokens", {
            userId,
            error: error instanceof Error ? error.message : String(error),
        });
        return { sentCount: 0, failureCount: 0 };
    }

    const validRecords = deviceRecords.filter(
        (record) => typeof record.fcmToken === "string" && record.fcmToken.trim().length >= 20,
    );

    if (validRecords.length === 0) {
        return { sentCount: 0, failureCount: 0 };
    }

    const dataMap = buildStringDataMap(payload);
    const fidRecords = validRecords.filter((record) => FIREBASE_FID_PATTERN.test(record.fcmToken.trim()));
    const tokenRecords = validRecords.filter((record) => !FIREBASE_FID_PATTERN.test(record.fcmToken.trim()));
    const orderedRecords = [...tokenRecords, ...fidRecords];
    const baseMulticast = {
        notification: {
            title: title || "The Palm Villa",
            body,
        },
        data: dataMap,
        android: {
            priority: "high" as const,
            notification: {
                icon: "ic_launcher",
                channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
                sound: "default",
                defaultSound: true,
                defaultVibrateTimings: true,
                priority: "high" as const,
                color: "#FF385C",
            },
        },
        apns: {
            headers: {
                "apns-priority": "10",
            },
            payload: {
                aps: {
                    sound: "default",
                    badge: 1,
                },
            },
        },
    };

    try {
        let totalSentCount = 0;
        let totalFailureCount = 0;
        const invalidHashes: string[] = [];

        for (let offset = 0; offset < orderedRecords.length; offset += FCM_MULTICAST_BATCH_SIZE) {
            const chunkRecords = orderedRecords.slice(offset, offset + FCM_MULTICAST_BATCH_SIZE);
            const chunkTokens = chunkRecords
                .filter((record) => !FIREBASE_FID_PATTERN.test(record.fcmToken.trim()))
                .map((record) => record.fcmToken.trim());
            const chunkFids = chunkRecords
                .filter((record) => FIREBASE_FID_PATTERN.test(record.fcmToken.trim()))
                .map((record) => record.fcmToken.trim());

            const multicastPayload: FcmMulticastPayload =
                chunkTokens.length > 0
                    ? {
                          ...baseMulticast,
                          tokens: chunkTokens,
                          ...(chunkFids.length > 0 ? { fids: chunkFids } : {}),
                      }
                    : {
                          ...baseMulticast,
                          fids: chunkFids,
                      };

            const batchResponse = await sender(multicastPayload);
            totalSentCount += batchResponse.successCount;
            totalFailureCount += batchResponse.failureCount;

            batchResponse.responses.forEach((resp, idx) => {
                if (!resp.success && resp.error?.code && PERMANENT_INVALID_TOKEN_CODES.has(resp.error.code)) {
                    const record = chunkRecords[idx];
                    if (record?.tokenHash) {
                        invalidHashes.push(record.tokenHash);
                    }
                }
            });
        }

        if (invalidHashes.length > 0) {
            try {
                await UserDeviceToken.update(
                    { isActive: false },
                    {
                        where: {
                            tokenHash: invalidHashes,
                        },
                    },
                );
            } catch (cleanupError) {
                logger.warn("Failed to deactivate expired FCM device tokens", {
                    userId,
                    count: invalidHashes.length,
                    error: cleanupError instanceof Error ? cleanupError.message : String(cleanupError),
                });
            }
        }

        return {
            sentCount: totalSentCount,
            failureCount: totalFailureCount,
        };
    } catch (error) {
        logger.error("Failed to dispatch FCM push notification", error, {
            userId,
            eventType: payload.eventType ?? null,
        });
        return { sentCount: 0, failureCount: orderedRecords.length };
    }
};
