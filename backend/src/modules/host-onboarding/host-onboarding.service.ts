import { type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import HostApplication, {
    HostApplicationDocument,
    HostEntityType,
} from "../../models/host-application";
import User from "../../models/user";
import type { AuthenticatedUser } from "../auth/auth.service";
import { getExistingColumns } from "../../services/schema-introspection-service";
import { notifyHostApplicationSubmitted } from "../notifications/notification.service";

export type RegisterHostInput = {
    contactName?: string | null;
    contactEmail?: string | null;
    contactPhone?: string | null;
    businessAddress: string;
    entityType: HostEntityType;
    notes?: string | null;
};

const nullableTrim = (value?: string | null) => {
    const trimmed = value?.trim();
    return trimmed ? trimmed : null;
};

const serializeHostApplication = (application: HostApplicationDocument, created: boolean) => ({
    applicationId: application.applicationId,
    status: application.status,
    hostApplicationStatus: application.status,
    contactName: application.contactName,
    contactEmail: application.contactEmail,
    contactPhone: application.contactPhone,
    businessAddress: application.businessAddress,
    entityType: application.entityType,
    notes: application.notes,
    created,
});

export const getLatestHostApplication = async (
    userId: number,
    transaction?: Transaction,
) =>
    HostApplication.findOne({
        where: {
            userId,
        },
        order: [["createdAt", "DESC"], ["applicationId", "DESC"]],
        transaction,
    });

const updateUserHostApplicationStatus = async (
    userId: number,
    status: "pending" | "approved" | "rejected",
    transaction?: Transaction,
) => {
    const userColumns = await getExistingColumns("users", ["host_application_status"], transaction);

    if (!userColumns.has("host_application_status")) {
        return;
    }

    await sequelize.query(
        `
        UPDATE users
        SET host_application_status = ?
        WHERE user_id = ?
        `,
        {
            replacements: [status, userId],
            transaction,
        },
    );
};

export const registerHostApplication = async (
    user: AuthenticatedUser,
    input: RegisterHostInput,
) => {
    const userId = Number(user.id);
    const existingUser = await User.findById(userId);

    if (!existingUser) {
        throw new ApiError(404, "User not found");
    }

    return sequelize.transaction(async (transaction) => {
        const latestApplication = await getLatestHostApplication(userId, transaction);
        const contactEmail = nullableTrim(input.contactEmail) ?? existingUser.email;
        const contactPhone = (nullableTrim(input.contactPhone) ?? existingUser.phone)?.trim();

        if (!contactEmail) {
            throw new ApiError(422, "contactEmail is required");
        }
        if (!contactPhone) {
            throw new ApiError(422, "contactPhone is required");
        }

        const applicationPayload = {
            contactName: nullableTrim(input.contactName),
            contactEmail,
            contactPhone,
            businessAddress: input.businessAddress.trim(),
            entityType: input.entityType,
            notes: nullableTrim(input.notes),
        };

        if (latestApplication?.status === "approved") {
            await updateUserHostApplicationStatus(userId, "approved", transaction);
            return serializeHostApplication(latestApplication, false);
        }

        if (user.roles.includes("host")) {
            const application =
                latestApplication ??
                (await HostApplication.create(
                    {
                        userId,
                        ...applicationPayload,
                        status: "approved",
                        reviewedByUserId: null,
                        reviewedAt: null,
                        rejectionReason: null,
                    },
                    {
                        transaction,
                    },
                ));

            if (application.status !== "approved") {
                application.set({
                    ...applicationPayload,
                    status: "approved",
                    rejectionReason: null,
                });
                await application.save({ transaction });
            }

            await updateUserHostApplicationStatus(userId, "approved", transaction);
            if (applicationPayload.contactName && applicationPayload.contactName.trim().length > 0) {
                const userColumns = await getExistingColumns("users", ["full_name"], transaction);
                if (userColumns.has("full_name")) {
                    await sequelize.query("UPDATE users SET full_name = ? WHERE user_id = ?", {
                        replacements: [applicationPayload.contactName.trim(), userId],
                        transaction,
                    });
                }
            }
            return serializeHostApplication(application, latestApplication === null);
        }

        if (latestApplication?.status === "pending") {
            latestApplication.set(applicationPayload);
            await latestApplication.save({ transaction });
            await updateUserHostApplicationStatus(userId, "pending", transaction);
            return serializeHostApplication(latestApplication, false);
        }

        const application = await HostApplication.create(
            {
                userId,
                ...applicationPayload,
                status: "pending",
                reviewedByUserId: null,
                reviewedAt: null,
                rejectionReason: null,
            },
            {
                transaction,
            },
        );

        await updateUserHostApplicationStatus(userId, "pending", transaction);

        await notifyHostApplicationSubmitted(
            Number(application.applicationId),
            userId,
            transaction,
        );

        return serializeHostApplication(application, true);
    });
};

export const markLatestHostApplicationApproved = async (
    userId: number,
    adminId: number,
    transaction?: Transaction,
) => {
    const application = await getLatestHostApplication(userId, transaction);

    if (!application) {
        return;
    }

    application.status = "approved";
    application.reviewedByUserId = adminId;
    application.reviewedAt = new Date();
    application.rejectionReason = null;
    await application.save({ transaction });
    await updateUserHostApplicationStatus(userId, "approved", transaction);

    if (application.contactName && application.contactName.trim().length > 0) {
        const userColumns = await getExistingColumns("users", ["full_name"], transaction);
        if (userColumns.has("full_name")) {
            await sequelize.query("UPDATE users SET full_name = ? WHERE user_id = ?", {
                replacements: [application.contactName.trim(), userId],
                transaction,
            });
        }
    }
};
export const getCurrentHostApplication = async (user: AuthenticatedUser) => {
    const userId = Number(user.id);
    const application = await getLatestHostApplication(userId);
    const existingUser = await User.findById(userId);

    if (!existingUser) {
        throw new ApiError(404, "User not found");
    }

    const isCurrentHost = user.roles.includes("host");
    let status = application?.status ?? existingUser.hostApplicationStatus ?? null;
    let rejectionReason = application?.rejectionReason ?? null;

    if (status === "approved" && !isCurrentHost) {
        status = "rejected";
        rejectionReason = rejectionReason || "Quyền Host đã được quản trị viên điều chỉnh về Guest.";
    }

    return {
        status,
        hostApplicationStatus: status,
        application: application
            ? {
                applicationId: application.applicationId,
                status,
                hostApplicationStatus: status,
                contactName: application.contactName,
                contactEmail: application.contactEmail,
                contactPhone: application.contactPhone,
                businessAddress: application.businessAddress,
                entityType: application.entityType,
                notes: application.notes,
                rejectionReason,
                reviewedAt: application.reviewedAt,
                createdAt: application.createdAt,
                updatedAt: application.updatedAt,
            }
            : null,
    };
};
