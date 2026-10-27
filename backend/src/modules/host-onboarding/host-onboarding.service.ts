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

export type RegisterHostInput = {
    contactName?: string | null;
    contactEmail?: string | null;
    contactPhone: string;
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
        const applicationPayload = {
            contactName: nullableTrim(input.contactName),
            contactEmail: nullableTrim(input.contactEmail) ?? existingUser.email,
            contactPhone: input.contactPhone.trim(),
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
};
export const getCurrentHostApplication = async (user: AuthenticatedUser) => {
    const userId = Number(user.id);
    const application = await getLatestHostApplication(userId);
    const existingUser = await User.findById(userId);

    if (!existingUser) {
        throw new ApiError(404, "User not found");
    }

    return {
        status: application?.status ?? existingUser.hostApplicationStatus ?? null,
        hostApplicationStatus: application?.status ?? existingUser.hostApplicationStatus ?? null,
        application: application
            ? {
                applicationId: application.applicationId,
                status: application.status,
                hostApplicationStatus: application.status,
                contactName: application.contactName,
                contactEmail: application.contactEmail,
                contactPhone: application.contactPhone,
                businessAddress: application.businessAddress,
                entityType: application.entityType,
                notes: application.notes,
                rejectionReason: application.rejectionReason,
                reviewedAt: application.reviewedAt,
                createdAt: application.createdAt,
                updatedAt: application.updatedAt,
            }
            : null,
    };
};
