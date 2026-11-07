import crypto from "node:crypto";
import { getEnv } from "../../config/env";
import { logger } from "../../config/logger";
import { ApiError } from "../../common/api-error";

export type DisbursementParams = {
    targetType: "host_payout" | "guest_refund";
    targetId: number;
    bankCode: string;
    accountNumber: string;
    accountName: string;
    amount: number;
    currency?: string;
    description: string;
};

export type DisbursementResult = {
    success: boolean;
    provider: "mock" | "payos";
    transferReference: string;
    transferredAt: Date;
    message: string;
};

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const executeMockDisbursement = async (params: DisbursementParams): Promise<DisbursementResult> => {
    // Giả lập trễ mạng liên ngân hàng Napas 24/7 trong 1.5 giây
    await delay(1500);

    const timestamp = Date.now();
    const randomSuffix = Math.floor(1000 + Math.random() * 9000);
    const transferReference = `FT_NAPAS_${timestamp}_${randomSuffix}`;

    const formattedAmount = `${Number(params.amount).toLocaleString("vi-VN")} ${params.currency || "VND"}`;

    logger.info(`[MOCK NAPAS 24/7] ==================================================`);
    logger.info(`[MOCK NAPAS 24/7] GIAO DỊCH CHUYỂN KHOẢN TỰ ĐỘNG THÀNH CÔNG`);
    logger.info(`[MOCK NAPAS 24/7] Loại GD      : ${params.targetType.toUpperCase()} (ID: #${params.targetId})`);
    logger.info(`[MOCK NAPAS 24/7] Người nhận   : ${params.accountName.toUpperCase()}`);
    logger.info(`[MOCK NAPAS 24/7] Ngân hàng/STK: ${params.bankCode.toUpperCase()} - ${params.accountNumber}`);
    logger.info(`[MOCK NAPAS 24/7] Số tiền      : ${formattedAmount}`);
    logger.info(`[MOCK NAPAS 24/7] Nội dung     : ${params.description}`);
    logger.info(`[MOCK NAPAS 24/7] Mã FT Napas  : ${transferReference}`);
    logger.info(`[MOCK NAPAS 24/7] ==================================================`);

    return {
        success: true,
        provider: "mock",
        transferReference,
        transferredAt: new Date(),
        message: `Chuyển khoản thành công tới ${params.accountName} (${params.accountNumber})`,
    };
};

const executePayosDisbursement = async (params: DisbursementParams): Promise<DisbursementResult> => {
    const env = getEnv();

    if (!env.payosClientId || !env.payosApiKey || !env.payosChecksumKey) {
        logger.warn("[PayOS Payout] Thiếu cấu hình PayOS Keys. Tự động fallback sang Mock Engine.");
        return executeMockDisbursement(params);
    }

    try {
        const payload = {
            orderCode: Date.now(),
            amount: Math.round(params.amount),
            description: params.description.slice(0, 50),
            accountNumber: params.accountNumber,
            accountName: params.accountName,
            bankCode: params.bankCode,
        };

        const signatureData = `amount=${payload.amount}&cancelUrl=&description=${payload.description}&orderCode=${payload.orderCode}&returnUrl=`;
        const signature = crypto
            .createHmac("sha256", env.payosChecksumKey)
            .update(signatureData)
            .digest("hex");

        const response = await fetch("https://api-merchant.payos.vn/v2/disbursements", {
            method: "POST",
            headers: {
                "x-client-id": env.payosClientId,
                "x-api-key": env.payosApiKey,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ ...payload, signature }),
        });

        const resJson: any = await response.json();
        if (!response.ok) {
            throw new Error(resJson?.message || `HTTP error ${response.status}`);
        }

        const data = resJson?.data ?? resJson;
        const transferReference = data?.reference ?? data?.transactionId ?? `FT_PAYOS_${Date.now()}`;

        return {
            success: true,
            provider: "payos",
            transferReference,
            transferredAt: new Date(),
            message: "Chuyển tiền thành công qua PayOS",
        };
    } catch (error: any) {
        logger.error("[PayOS Payout] Lỗi khi gọi API PayOS:", error?.response?.data || error.message);
        throw new ApiError(502, `Lỗi cổng chi hộ PayOS: ${error?.response?.data?.message || error.message}`);
    }
};

export const executeDisbursement = async (params: DisbursementParams): Promise<DisbursementResult> => {
    const env = getEnv();

    if (env.disbursementMode === "payos") {
        return executePayosDisbursement(params);
    }

    return executeMockDisbursement(params);
};
