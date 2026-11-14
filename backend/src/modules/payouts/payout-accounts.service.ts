/**
 * Dịch vụ quản lý tài khoản ngân hàng thụ hưởng chi trả của Chủ nhà (`payout-accounts.service`),
 * tích hợp mã hóa AES-256-GCM tại chỗ, băm tra cứu HMAC-SHA256 và che mặt nạ dữ liệu định danh tài chính (PII).
 */
// CONFLICT-RESOLVED: Hợp nhất quản lý tài khoản ngân hàng từ `modules/host-bank-account/` và `modules/payouts/payouts.service.ts`
// về một dịch vụ đơn trách nhiệm `payout-accounts.service.ts`, dùng chung bảng `payout_accounts` và chính sách bảo mật PII.
import { Op, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import {
    encryptBankAccountNumber,
    hashBankAccountNumber,
    maskBankAccountNumber,
} from "../../common/crypto-pii";
import sequelize from "../../config/database";
import HostPayoutBatch from "../../models/host-payout-batch";
import PayoutAccount, { type PayoutAccountDocument } from "../../models/payout-account";
import type { AuthenticatedUser } from "../auth/auth.service";
import { getVietnamBankByCode } from "./vietnam-banks.data";

export type CreatePayoutAccountInput = {
    bankName: string;
    bankCode?: string | null;
    accountName: string;
    accountNumber: string;
    isDefault?: boolean;
};

export type UpdatePayoutAccountInput = Partial<CreatePayoutAccountInput>;

export type SaveHostBankAccountInput = {
    bankCode?: unknown;
    bankName?: unknown;
    bankShortName?: unknown;
    bankBin?: unknown;
    accountNumber?: unknown;
    accountHolderName?: unknown;
    branchName?: unknown;
};

const hasOwn = <T extends object>(value: T, key: keyof T) =>
    Object.prototype.hasOwnProperty.call(value, key);

const getCurrentUserId = (user: AuthenticatedUser) => Number(user.id);

const normalizeOptional = (value?: string | null) => (value?.trim() ? value.trim() : null);

const normalizeOptionalInputString = (value: unknown, maxLength: number, message: string) => {
    if (value === undefined || value === null) {
        return null;
    }

    if (typeof value !== "string") {
        throw new ApiError(400, message);
    }

    const normalized = value.trim();
    if (!normalized) {
        return null;
    }

    if (normalized.length > maxLength) {
        throw new ApiError(400, message);
    }

    return normalized;
};

const normalizeRequiredInputString = (value: unknown, message: string, maxLength = 255) => {
    if (typeof value !== "string") {
        throw new ApiError(400, message);
    }

    const normalized = value.trim();
    if (!normalized || normalized.length > maxLength) {
        throw new ApiError(400, message);
    }

    return normalized;
};

const normalizeHostAccountNumber = (value: unknown) => {
    const accountNumber = normalizeRequiredInputString(value, "Số tài khoản là bắt buộc", 30);

    if (!/^\d{6,30}$/.test(accountNumber)) {
        throw new ApiError(400, "Số tài khoản không hợp lệ");
    }

    return accountNumber;
};

/**
 * Giải thuật kiểm định định dạng thông tin tài khoản ngân hàng nhận chi trả bằng biểu thức chính quy Unicode:
 * kiểm tra tên ngân hàng (`bankName`), mã ngân hàng (`bankCode`), tên chủ tài khoản (`accountName`) và chuỗi chữ số tài khoản (`4..32` chữ số).
 */
const assertValidBankInfo = (input: {
    bankName?: string;
    bankCode?: string | null;
    accountName?: string;
    accountNumber?: string;
}) => {
    if (input.bankName !== undefined && !/^[\p{L}0-9 .,'&()-]{2,150}$/u.test(input.bankName.trim())) {
        throw new ApiError(422, "Validation error", [
            {
                path: "bankName",
                msg: "bankName format is invalid",
            },
        ]);
    }

    if (input.bankCode !== undefined && input.bankCode !== null && input.bankCode.trim() !== "") {
        if (!/^[A-Z0-9_-]{2,32}$/i.test(input.bankCode.trim())) {
            throw new ApiError(422, "Validation error", [
                {
                    path: "bankCode",
                    msg: "bankCode format is invalid",
                },
            ]);
        }
    }

    if (input.accountName !== undefined && !/^[\p{L} .,'-]{2,255}$/u.test(input.accountName.trim())) {
        throw new ApiError(422, "Validation error", [
            {
                path: "accountName",
                msg: "accountName format is invalid",
            },
        ]);
    }

    if (input.accountNumber !== undefined && !/^\d{4,32}$/.test(input.accountNumber.trim())) {
        throw new ApiError(422, "Validation error", [
            {
                path: "accountNumber",
                msg: "accountNumber must contain 4 to 32 digits",
            },
        ]);
    }
};

/**
 * Giải thuật che mặt nạ hiển thị số tài khoản bảo vệ dữ liệu định danh tài chính (PII Masking):
 * Giữ nguyên nếu dữ liệu lưu trữ đã che dấu `*`, áp dụng `maskBankAccountNumber` nếu còn chuỗi thô tương thích ngược,
 * hoặc ghép `****` với 4 chữ số cuối (`accountNumberLast4`) để không bao giờ làm lộ số tài khoản gốc.
 */
const resolveMaskedAccountNumber = (account: PayoutAccountDocument): string => {
    const raw = String(account.accountNumber ?? "").trim();
    if (raw.includes("*")) {
        return raw;
    }
    if (raw) {
        return maskBankAccountNumber(raw);
    }
    if (account.accountNumberLast4) {
        return `****${account.accountNumberLast4}`;
    }
    return "****";
};

const serializePayoutAccount = (account: PayoutAccountDocument) => ({
    payoutAccountId: account.payoutAccountId,
    bankName: account.bankName,
    bankCode: account.bankCode ?? null,
    accountName: account.accountName,
    accountNumberMasked: resolveMaskedAccountNumber(account),
    isDefault: account.isDefault,
    createdAt: account.createdAt,
    updatedAt: account.updatedAt,
});

/**
 * Giải thuật tuần tự hóa tài khoản ngân hàng mặc định của Chủ nhà chống lộ PII:
 * Tuyệt đối không trả số tài khoản gốc qua API; cả `accountNumber` lẫn `accountNumberMasked` chỉ trả chuỗi mặt nạ.
 */
export const serializeHostBankAccount = (account: PayoutAccountDocument) => {
    const masked = resolveMaskedAccountNumber(account);
    return {
        id: account.payoutAccountId,
        payoutAccountId: account.payoutAccountId,
        bankCode: account.bankCode,
        bankName: account.bankName,
        bankShortName: account.bankShortName,
        bankBin: account.bankBin,
        accountNumber: masked,
        accountNumberMasked: masked,
        accountNumberLast4: account.accountNumberLast4 ?? masked.slice(-4),
        accountHolderName: account.accountName,
        branchName: account.branchName,
        isDefault: account.isDefault,
        createdAt: account.createdAt,
        updatedAt: account.updatedAt,
    };
};

const getPayoutAccountForActor = async (
    payoutAccountId: number,
    actor: AuthenticatedUser,
    transaction?: Transaction,
) => {
    const account = await PayoutAccount.findOne({
        where: {
            payoutAccountId,
            deletedAt: null,
        },
        transaction,
    });

    if (!account) {
        throw new ApiError(404, "Payout account not found");
    }

    if (!actor.roles.includes("admin") && account.userId !== getCurrentUserId(actor)) {
        throw new ApiError(403, "Forbidden");
    }

    return account;
};

/**
 * Giải thuật chống đăng ký trùng lặp tài khoản nhận tiền cho cùng một người dùng:
 * so khớp tên/mã ngân hàng kết hợp mã băm một chiều HMAC-SHA256 (`accountNumberHash`) của số tài khoản.
 */
const assertNoDuplicatePayoutAccount = async (
    userId: number,
    bankName: string,
    bankCode: string | null,
    accountNumberOrHash: { rawAccountNumber?: string; existingHash?: string | null },
    excludePayoutAccountId?: number,
) => {
    const targetHash = accountNumberOrHash.rawAccountNumber
        ? hashBankAccountNumber(accountNumberOrHash.rawAccountNumber)
        : (accountNumberOrHash.existingHash ?? null);
    const rows = await PayoutAccount.find({
        userId,
        bankName,
        deletedAt: null,
    });
    const duplicate = rows.find((row) => {
        if (row.payoutAccountId === excludePayoutAccountId) {
            return false;
        }
        const sameBankCode = bankCode === null || row.bankCode === null || row.bankCode === bankCode;
        if (!sameBankCode) {
            return false;
        }
        if (targetHash && row.accountNumberHash === targetHash) {
            return true;
        }
        if (accountNumberOrHash.rawAccountNumber && row.accountNumber === accountNumberOrHash.rawAccountNumber) {
            return true;
        }
        return false;
    });

    if (duplicate) {
        throw new ApiError(409, "Payout account already exists");
    }
};

const findHostDefaultBankAccount = async (userId: number, transaction?: Transaction) => {
    const defaultAccount = await PayoutAccount.findOne({
        where: {
            userId,
            isDefault: true,
            deletedAt: null,
        },
        order: [["updatedAt", "DESC"]],
        transaction,
    });

    if (defaultAccount) {
        return defaultAccount;
    }

    return PayoutAccount.findOne({
        where: {
            userId,
            deletedAt: null,
        },
        order: [
            ["isDefault", "DESC"],
            ["updatedAt", "DESC"],
        ],
        transaction,
    });
};

export const getHostPayoutAccounts = async (user: AuthenticatedUser) => {
    const accounts = await PayoutAccount.find({
        userId: getCurrentUserId(user),
        deletedAt: null,
    }).sort({ isDefault: -1, createdAt: -1 });

    return {
        items: accounts.map(serializePayoutAccount),
    };
};

/**
 * Giải thuật tạo mới tài khoản ngân hàng nhận chi trả với bảo mật PII (AES-256-GCM + HMAC-SHA256 + Masking).
 */
export const createPayoutAccount = async (
    user: AuthenticatedUser,
    input: CreatePayoutAccountInput,
) => {
    const userId = getCurrentUserId(user);
    const bankName = input.bankName.trim();
    const bankCode = normalizeOptional(input.bankCode);
    const accountNumber = input.accountNumber.trim();

    assertValidBankInfo(input);
    await assertNoDuplicatePayoutAccount(userId, bankName, bankCode, {
        rawAccountNumber: accountNumber,
    });

    const maskedAccountNumber = maskBankAccountNumber(accountNumber);
    const encryptedAccountNumber = encryptBankAccountNumber(accountNumber, userId);
    const hashedAccountNumber = hashBankAccountNumber(accountNumber);

    const account = await sequelize.transaction(async (transaction) => {
        if (input.isDefault === true) {
            await PayoutAccount.update(
                { isDefault: false },
                {
                    where: {
                        userId,
                        deletedAt: null,
                    },
                    transaction,
                },
            );
        }

        return PayoutAccount.create(
            {
                userId,
                bankName,
                bankCode,
                accountName: input.accountName.trim(),
                accountNumber: maskedAccountNumber,
                accountNumberEncrypted: encryptedAccountNumber,
                accountNumberHash: hashedAccountNumber,
                accountNumberLast4: accountNumber.slice(-4),
                isDefault: input.isDefault ?? false,
                deletedAt: null,
            },
            { transaction },
        );
    });

    return serializePayoutAccount(account);
};

export const updatePayoutAccount = async (
    user: AuthenticatedUser,
    payoutAccountId: number,
    input: UpdatePayoutAccountInput,
) => {
    if (
        !hasOwn(input, "bankName") &&
        !hasOwn(input, "bankCode") &&
        !hasOwn(input, "accountName") &&
        !hasOwn(input, "accountNumber") &&
        !hasOwn(input, "isDefault")
    ) {
        throw new ApiError(422, "Validation error", [
            {
                path: "body",
                msg: "At least one payout account field must be provided",
            },
        ]);
    }

    return sequelize.transaction(async (transaction) => {
        const account = await getPayoutAccountForActor(payoutAccountId, user, transaction);
        const nextBankName = input.bankName?.trim() ?? account.bankName;
        const nextBankCode = hasOwn(input, "bankCode") ? normalizeOptional(input.bankCode) : account.bankCode;
        const rawUpdatedAccountNumber =
            input.accountNumber !== undefined ? input.accountNumber.trim() : undefined;

        assertValidBankInfo(input);
        await assertNoDuplicatePayoutAccount(
            account.userId,
            nextBankName,
            nextBankCode,
            rawUpdatedAccountNumber !== undefined
                ? { rawAccountNumber: rawUpdatedAccountNumber }
                : { existingHash: account.accountNumberHash },
            account.payoutAccountId,
        );

        if (input.isDefault === true) {
            await PayoutAccount.update(
                { isDefault: false },
                {
                    where: {
                        userId: account.userId,
                        deletedAt: null,
                    },
                    transaction,
                },
            );
        }

        account.bankName = nextBankName;
        account.bankCode = nextBankCode;
        if (rawUpdatedAccountNumber !== undefined) {
            account.accountNumber = maskBankAccountNumber(rawUpdatedAccountNumber);
            account.accountNumberEncrypted = encryptBankAccountNumber(rawUpdatedAccountNumber, account.userId);
            account.accountNumberHash = hashBankAccountNumber(rawUpdatedAccountNumber);
            account.accountNumberLast4 = rawUpdatedAccountNumber.slice(-4);
        }

        if (input.accountName !== undefined) {
            account.accountName = input.accountName.trim();
        }

        if (input.isDefault !== undefined) {
            account.isDefault = input.isDefault;
        }

        await account.save({ transaction });
        return serializePayoutAccount(account);
    });
};

export const deletePayoutAccount = async (user: AuthenticatedUser, payoutAccountId: number) =>
    sequelize.transaction(async (transaction) => {
        const account = await getPayoutAccountForActor(payoutAccountId, user, transaction);

        if (account.isDefault) {
            const activePayoutCount = await HostPayoutBatch.countDocuments({
                payoutAccountId: account.payoutAccountId,
                status: { $in: ["pending", "approved", "processing"] },
            });

            if (activePayoutCount > 0) {
                throw new ApiError(409, "Cannot delete default account used by active payouts");
            }
        }

        account.deletedAt = new Date();
        account.isDefault = false;
        await account.save({ transaction });
    });

export const getHostBankAccount = async (user: AuthenticatedUser) => {
    const account = await findHostDefaultBankAccount(getCurrentUserId(user));
    return account ? serializeHostBankAccount(account) : null;
};

/**
 * Giải thuật lưu hoặc cập nhật tài khoản ngân hàng mặc định của Chủ nhà (`/api/host/bank-account`)
 * có đối chiếu mã VietQR và mã hóa AES-256-GCM tại chỗ.
 */
export const saveHostBankAccount = async (
    user: AuthenticatedUser,
    input: SaveHostBankAccountInput,
) => {
    const bankCode = normalizeRequiredInputString(input.bankCode, "Vui lòng chọn ngân hàng", 32);
    const bankName = normalizeRequiredInputString(input.bankName, "Tên ngân hàng là bắt buộc", 255);
    const selectedBank = getVietnamBankByCode(bankCode);

    if (!selectedBank) {
        throw new ApiError(400, "Ngân hàng không hợp lệ");
    }

    const userId = getCurrentUserId(user);
    const accountNumber = normalizeHostAccountNumber(input.accountNumber);
    const maskedAccountNumber = maskBankAccountNumber(accountNumber);
    const encryptedAccountNumber = encryptBankAccountNumber(accountNumber, userId);
    const hashedAccountNumber = hashBankAccountNumber(accountNumber);
    const last4 = accountNumber.slice(-4);

    const accountHolderName = normalizeRequiredInputString(
        input.accountHolderName,
        "Chủ tài khoản là bắt buộc",
        255,
    ).toUpperCase();
    const branchName = normalizeOptionalInputString(input.branchName, 255, "Chi nhánh không hợp lệ");
    const fallbackBankShortName = normalizeOptionalInputString(
        input.bankShortName,
        100,
        "Tên viết tắt ngân hàng không hợp lệ",
    );
    const fallbackBankBin = normalizeOptionalInputString(input.bankBin, 16, "BIN ngân hàng không hợp lệ");

    if (fallbackBankBin && !/^\d{4,16}$/.test(fallbackBankBin)) {
        throw new ApiError(400, "BIN ngân hàng không hợp lệ");
    }

    return sequelize.transaction(async (transaction) => {
        const account = await findHostDefaultBankAccount(userId, transaction);
        const canonicalBankName = selectedBank.name || bankName;
        const canonicalBankShortName = selectedBank.shortName || fallbackBankShortName;
        const canonicalBankBin = selectedBank.bin ?? fallbackBankBin;

        await PayoutAccount.update(
            { isDefault: false },
            {
                where: {
                    userId,
                    deletedAt: null,
                    ...(account
                        ? {
                              payoutAccountId: {
                                  [Op.ne]: account.payoutAccountId,
                              },
                          }
                        : {}),
                },
                transaction,
            },
        );

        if (!account) {
            const created = await PayoutAccount.create(
                {
                    userId,
                    bankName: canonicalBankName,
                    bankCode: selectedBank.code,
                    bankShortName: canonicalBankShortName,
                    bankBin: canonicalBankBin,
                    accountName: accountHolderName,
                    branchName,
                    accountNumber: maskedAccountNumber,
                    accountNumberEncrypted: encryptedAccountNumber,
                    accountNumberHash: hashedAccountNumber,
                    accountNumberLast4: last4,
                    isDefault: true,
                    deletedAt: null,
                },
                { transaction },
            );

            return serializeHostBankAccount(created);
        }

        account.bankName = canonicalBankName;
        account.bankCode = selectedBank.code;
        account.bankShortName = canonicalBankShortName;
        account.bankBin = canonicalBankBin;
        account.accountName = accountHolderName;
        account.branchName = branchName;
        account.accountNumber = maskedAccountNumber;
        account.accountNumberEncrypted = encryptedAccountNumber;
        account.accountNumberHash = hashedAccountNumber;
        account.accountNumberLast4 = last4;
        account.isDefault = true;

        await account.save({ transaction });
        return serializeHostBankAccount(account);
    });
};
