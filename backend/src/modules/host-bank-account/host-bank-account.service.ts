import { createHash } from "node:crypto";

import { Op, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import { getEnv } from "../../config/env";
import { getVietnamBankByCode } from "../../constants/vietnamBanks";
import PayoutAccount, { type PayoutAccountDocument } from "../../models/payout-account";
import type { AuthenticatedUser } from "../auth/auth.service";

export type SaveHostBankAccountInput = {
    bankCode?: unknown;
    bankName?: unknown;
    bankShortName?: unknown;
    bankBin?: unknown;
    accountNumber?: unknown;
    accountHolderName?: unknown;
    branchName?: unknown;
};

const getCurrentUserId = (user: AuthenticatedUser) => Number(user.id);

const normalizeOptionalString = (value: unknown, maxLength: number, message: string) => {
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

const normalizeRequiredString = (value: unknown, message: string, maxLength = 255) => {
    if (typeof value !== "string") {
        throw new ApiError(400, message);
    }

    const normalized = value.trim();

    if (!normalized || normalized.length > maxLength) {
        throw new ApiError(400, message);
    }

    return normalized;
};

const normalizeAccountNumber = (value: unknown) => {
    const accountNumber = normalizeRequiredString(value, "Số tài khoản là bắt buộc", 30);

    if (!/^\d{6,30}$/.test(accountNumber)) {
        throw new ApiError(400, "Số tài khoản không hợp lệ");
    }

    return accountNumber;
};

const hashAccountNumber = (value: string) =>
    createHash("sha256")
        .update(getEnv().tokenHashSecret)
        .update(":payout-account:")
        .update(value)
        .digest("hex");

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

export const serializeHostBankAccount = (account: PayoutAccountDocument) => ({
    id: account.payoutAccountId,
    payoutAccountId: account.payoutAccountId,
    bankCode: account.bankCode,
    bankName: account.bankName,
    bankShortName: account.bankShortName,
    bankBin: account.bankBin,
    accountNumber: account.accountNumber,
    accountHolderName: account.accountName,
    branchName: account.branchName,
    isDefault: account.isDefault,
    createdAt: account.createdAt,
    updatedAt: account.updatedAt,
});

export const getHostBankAccount = async (user: AuthenticatedUser) => {
    const account = await findHostDefaultBankAccount(getCurrentUserId(user));
    return account ? serializeHostBankAccount(account) : null;
};

export const saveHostBankAccount = async (
    user: AuthenticatedUser,
    input: SaveHostBankAccountInput,
) => {
    const bankCode = normalizeRequiredString(input.bankCode, "Vui lòng chọn ngân hàng", 32);
    const bankName = normalizeRequiredString(input.bankName, "Tên ngân hàng là bắt buộc", 255);
    const selectedBank = getVietnamBankByCode(bankCode);

    if (!selectedBank) {
        throw new ApiError(400, "Ngân hàng không hợp lệ");
    }

    const accountNumber = normalizeAccountNumber(input.accountNumber);
    const accountHolderName = normalizeRequiredString(
        input.accountHolderName,
        "Chủ tài khoản là bắt buộc",
        255,
    ).toUpperCase();
    const branchName = normalizeOptionalString(input.branchName, 255, "Chi nhánh không hợp lệ");
    const fallbackBankShortName = normalizeOptionalString(
        input.bankShortName,
        100,
        "Tên viết tắt ngân hàng không hợp lệ",
    );
    const fallbackBankBin = normalizeOptionalString(input.bankBin, 16, "BIN ngân hàng không hợp lệ");

    if (fallbackBankBin && !/^\d{4,16}$/.test(fallbackBankBin)) {
        throw new ApiError(400, "BIN ngân hàng không hợp lệ");
    }

    const userId = getCurrentUserId(user);

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
                    accountNumber,
                    accountNumberEncrypted: null,
                    accountNumberHash: hashAccountNumber(accountNumber),
                    accountNumberLast4: accountNumber.slice(-4),
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
        account.accountNumber = accountNumber;
        account.accountNumberHash = hashAccountNumber(accountNumber);
        account.accountNumberLast4 = accountNumber.slice(-4);
        account.isDefault = true;

        await account.save({ transaction });
        return serializeHostBankAccount(account);
    });
};
