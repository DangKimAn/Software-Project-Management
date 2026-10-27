import { ApiError } from "../../common/api-error";
import { createAuditLog } from "../auth/auth.repository";
import { AuthenticatedUser, normalizeEmail, normalizePhone } from "../auth/auth.service";
import {
    countActiveUsersWithRole,
    findUserByEmail,
    findUserById,
    findUserByPhone,
    findUserByUsername,
    findUserProfileByUserId,
    getUserRoles,
    listUsersForAdmin,
    replaceUserRoles,
    saveUserProfileUpdates,
    saveUserUpdates,
    withTransaction,
} from "./users.repository";
import { UserRole, UserStatus } from "../../models/user";
import Booking from "../../models/booking";

type RequestContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

type UpdateOwnProfileInput = Partial<{
    username: string | null;
    fullName: string;
    firstName: string;
    lastName: string;
    phone: string | null;
    dateOfBirth: string | null;
    dob: string | null;
    bio: string | null;
    avatarUrl: string | null;
    avatarKey: string | null;
    location: string | null;
    job: string | null;
    dreamDestination: string | null;
    school: string | null;
    languages: string[] | null;
}>;

type AdminUpdateUserInput = UpdateOwnProfileInput &
    Partial<{
        email: string;
        status: UserStatus;
        role: UserRole;
        roles: UserRole[];
    }>;

const primaryRolePriority: UserRole[] = ["admin", "moderator", "host", "guest"];

const selfManagedForbiddenFields = ["email", "role", "roles", "status"] as const;

const disablingStatuses: UserStatus[] = ["inactive", "blocked", "suspended", "deleted", "locked"];

const selectPrimaryRole = (roles: UserRole[]) =>
    primaryRolePriority.find((role) => roles.includes(role)) ?? "guest";

const normalizeDate = (value?: string | null) => {
    if (value === undefined) {
        return undefined;
    }

    if (value === null || value === "") {
        return null;
    }

    return new Date(value);
};

const maskEmail = (email: string) => {
    const [localPart, domain] = email.split("@");
    const visible = localPart.slice(0, 2);
    return `${visible}${"*".repeat(Math.max(2, localPart.length - visible.length))}@${domain}`;
};

const maskPhone = (phone?: string | null) => {
    if (!phone) {
        return "";
    }

    const normalized = normalizePhone(phone);
    return `******${normalized.slice(-4)}`;
};

const buildFullName = (input: UpdateOwnProfileInput, currentFullName: string) => {
    if (input.fullName !== undefined) {
        return input.fullName.trim();
    }

    if (input.firstName === undefined && input.lastName === undefined) {
        return undefined;
    }

    const parts = currentFullName.trim().split(/\s+/).filter(Boolean);
    const currentFirstName = parts.length > 1 ? parts.slice(0, -1).join(" ") : parts[0] ?? "";
    const currentLastName = parts.length > 1 ? parts[parts.length - 1] : "";
    const firstName = input.firstName?.trim() ?? currentFirstName;
    const lastName = input.lastName?.trim() ?? currentLastName;

    return `${firstName} ${lastName}`.trim();
};

const normalizeNullableText = (value?: string | null) => {
    if (value === undefined) {
        return undefined;
    }

    if (value === null) {
        return null;
    }

    const normalized = value.trim();
    return normalized ? normalized : null;
};

const normalizeLanguages = (value?: string[] | null) => {
    if (value === undefined) {
        return undefined;
    }

    if (value === null) {
        return null;
    }

    return [...new Set(value.map((item) => item.trim()).filter(Boolean))];
};

const parseStoredLanguages = (value: unknown) => {
    if (Array.isArray(value)) {
        return value.map((item) => String(item).trim()).filter(Boolean);
    }

    if (typeof value === "string" && value.trim()) {
        try {
            const parsed = JSON.parse(value);
            return Array.isArray(parsed) ? parsed.map((item) => String(item).trim()).filter(Boolean) : [];
        } catch {
            return [];
        }
    }

    return [];
};

type SerializeUserOptions = {
    maskContact?: boolean;
};

export const serializeUser = async (
    userIdOrUser: string | number | { _id: string | number },
    options: SerializeUserOptions = {},
) => {
    const user =
        typeof userIdOrUser === "object" ? await findUserById(userIdOrUser._id) : await findUserById(userIdOrUser);

    if (!user) {
        throw new ApiError(404, "User not found");
    }

    const roles = await getUserRoles(user._id);
    const profile = await findUserProfileByUserId(user._id);
    const email = options.maskContact ? maskEmail(user.email) : user.email;
    const phone = options.maskContact ? maskPhone(user.phone) : (user.phone ?? "");

    return {
        id: String(user._id),
        userId: String(user._id),
        email,
        emailMasked: maskEmail(user.email),
        phone,
        phoneMasked: maskPhone(user.phone),
        name: user.fullName,
        fullName: user.fullName,
        firstName: user.firstName,
        lastName: user.lastName,
        username: user.username ?? null,
        dateOfBirth: user.dateOfBirth,
        dob: user.dateOfBirth,
        bio: user.bio,
        avatarUrl: user.avatarUrl ?? null,
        avatarKey: user.avatarKey ?? null,
        location: profile?.location ?? null,
        job: profile?.job ?? null,
        dreamDestination: profile?.dreamDestination ?? null,
        school: profile?.school ?? null,
        languages: parseStoredLanguages(profile?.languages),
        status: user.status,
        roles,
        role: selectPrimaryRole(roles),
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
    };
};

const buildPublicProfileUpdates = (input: UpdateOwnProfileInput) => ({
    ...(input.location !== undefined ? { location: normalizeNullableText(input.location) } : {}),
    ...(input.job !== undefined ? { job: normalizeNullableText(input.job) } : {}),
    ...(input.dreamDestination !== undefined
        ? { dreamDestination: normalizeNullableText(input.dreamDestination) }
        : {}),
    ...(input.school !== undefined ? { school: normalizeNullableText(input.school) } : {}),
    ...(input.languages !== undefined ? { languages: normalizeLanguages(input.languages) } : {}),
});

export const getCurrentUserProfile = (actor: AuthenticatedUser) => serializeUser(actor.id);

export const getUserProfileForAdmin = async (userId: string) => serializeUser(userId, { maskContact: true });

const buildProfileUpdates = (input: UpdateOwnProfileInput, currentFullName: string) => {
    const dateInput = input.dateOfBirth ?? input.dob;
    const dateOfBirth = normalizeDate(dateInput);
    const fullName = buildFullName(input, currentFullName);

    return {
        ...(input.username !== undefined ? { username: input.username } : {}),
        ...(fullName !== undefined ? { fullName } : {}),
        ...(input.phone !== undefined ? { phone: input.phone ? normalizePhone(input.phone) : null } : {}),
        ...(dateOfBirth !== undefined ? { dateOfBirth } : {}),
        ...(input.bio !== undefined ? { bio: input.bio } : {}),
        ...(input.avatarUrl !== undefined ? { avatarUrl: input.avatarUrl?.trim() ? input.avatarUrl.trim() : null } : {}),
        ...(input.avatarKey !== undefined ? { avatarKey: input.avatarKey?.trim() ? input.avatarKey.trim() : null } : {}),
    };
};

const assertNoSelfManagedAdminFields = (input: Record<string, unknown>) => {
    const forbiddenField = selfManagedForbiddenFields.find((field) =>
        Object.prototype.hasOwnProperty.call(input, field),
    );

    if (forbiddenField) {
        throw new ApiError(403, "Users cannot update role, status, or account authority fields on their own profile", [
            {
                path: forbiddenField,
                msg: "This field is admin-only",
            },
        ]);
    }
};

const assertAdminActor = (actor: AuthenticatedUser) => {
    if (!actor.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }
};

const assertUniqueUserFields = async (
    targetUserId: string | number,
    input: Partial<{
        username: string | null;
        email: string;
        phone: string | null;
    }>,
) => {
    const targetId = String(targetUserId);
    const checks: Array<Promise<{ field: "username" | "email" | "phone"; conflict: boolean }>> = [];

    if (input.username) {
        checks.push(
            findUserByUsername(input.username).then((user) => ({
                field: "username",
                conflict: Boolean(user && String(user._id) !== targetId),
            })),
        );
    }

    if (input.email) {
        checks.push(
            findUserByEmail(normalizeEmail(input.email)).then((user) => ({
                field: "email",
                conflict: Boolean(user && String(user._id) !== targetId),
            })),
        );
    }

    if (input.phone) {
        const normalizedPhone = normalizePhone(input.phone);
        checks.push(
            findUserByPhone(normalizedPhone).then((user) => ({
                field: "phone",
                conflict: Boolean(user && String(user._id) !== targetId),
            })),
        );
    }

    const conflicts = (await Promise.all(checks)).filter((item) => item.conflict);

    if (conflicts.length > 0) {
        throw new ApiError(409, "User field already exists", conflicts.map((item) => ({
            path: item.field,
            msg: `${item.field} already exists`,
        })));
    }
};

const assertDoesNotRemoveLastActiveAdmin = async (
    currentRoles: UserRole[],
    currentStatus: UserStatus,
    nextRoles?: UserRole[],
    nextStatus?: UserStatus,
) => {
    if (!currentRoles.includes("admin") || currentStatus !== "active") {
        return;
    }

    const willStillBeActiveAdmin =
        (nextRoles === undefined || nextRoles.includes("admin")) &&
        (nextStatus === undefined || !disablingStatuses.includes(nextStatus));

    if (willStillBeActiveAdmin) {
        return;
    }

    const activeAdminCount = await countActiveUsersWithRole("admin");

    if (activeAdminCount <= 1) {
        throw new ApiError(409, "Cannot remove, disable, or demote the last active admin");
    }
};

const activeBookingStatuses = ["paid", "confirmed", "checked_in"] as const;

const assertHostCanBeDowngraded = async (
    userId: string | number,
    currentRoles: UserRole[],
    nextRoles?: UserRole[],
) => {
    if (!currentRoles.includes("host")) {
        return;
    }

    if (nextRoles === undefined || nextRoles.includes("host")) {
        return;
    }

    const activeBookingCount = await Booking.countDocuments({
        hostUserId: Number(userId),
        status: { $in: [...activeBookingStatuses] },
    });

    if (activeBookingCount > 0) {
        throw new ApiError(
            409,
            "Host này đang có khách nên không thể đổi role từ host về guest",
        );
    }
};

export const updateCurrentUserProfile = async (actor: AuthenticatedUser, input: UpdateOwnProfileInput) => {
    assertNoSelfManagedAdminFields(input as Record<string, unknown>);

    const user = await findUserById(actor.id);

    if (!user) {
        throw new ApiError(404, "User not found");
    }

    await assertUniqueUserFields(user._id, {
        username: input.username,
        phone: input.phone,
    });

    const updates = buildProfileUpdates(input, user.fullName);
    const publicProfileUpdates = buildPublicProfileUpdates(input);

    if (Object.keys(publicProfileUpdates).length > 0) {
        await withTransaction(async (transaction) => {
            if (Object.keys(updates).length > 0) {
                await saveUserUpdates(user, updates, transaction);
            }

            await saveUserProfileUpdates(user._id, publicProfileUpdates, transaction);
        });
    } else if (Object.keys(updates).length > 0) {
        await saveUserUpdates(user, updates);
    }

    return serializeUser(user);
};

export const updateCurrentUserAvatar = async (
    actor: AuthenticatedUser,
    input: { url: string; key?: string | null },
) => {
    return updateCurrentUserProfile(actor, {
        avatarUrl: input.url,
        avatarKey: input.key ?? null,
    });
};

export const updateUserForAdmin = async (
    actor: AuthenticatedUser,
    userId: string,
    input: AdminUpdateUserInput,
    context: RequestContext = {},
) => {
    assertAdminActor(actor);

    const user = await findUserById(userId);

    if (!user) {
        throw new ApiError(404, "User not found");
    }

    const oldRoles = await getUserRoles(user._id);
    const previousStatus = user.status;
    const nextRoles = input.roles ? [...new Set(input.roles)] : input.role ? [input.role] : undefined;

    await assertUniqueUserFields(user._id, {
        username: input.username,
        email: input.email,
        phone: input.phone,
    });
    await assertDoesNotRemoveLastActiveAdmin(oldRoles, previousStatus, nextRoles, input.status);
    await assertHostCanBeDowngraded(user._id, oldRoles, nextRoles);

    const updates = {
        ...buildProfileUpdates(input, user.fullName),
        ...(input.email !== undefined ? { email: normalizeEmail(input.email) } : {}),
        ...(input.status !== undefined ? { status: input.status } : {}),
    };
    const publicProfileUpdates = buildPublicProfileUpdates(input);

    await withTransaction(async (transaction) => {
        if (Object.keys(updates).length > 0) {
            await saveUserUpdates(user, updates, transaction);
        }

        if (Object.keys(publicProfileUpdates).length > 0) {
            await saveUserProfileUpdates(user._id, publicProfileUpdates, transaction);
        }

        if (nextRoles) {
            await replaceUserRoles(user._id, nextRoles, transaction);

            if (oldRoles.join(",") !== nextRoles.join(",")) {
                await createAuditLog({
                    actorId: actor.id,
                    action: "users.role_changed",
                    targetType: "user",
                    targetId: user._id,
                    metadata: {
                        before: oldRoles,
                        after: nextRoles,
                    },
                    ipAddress: context.ipAddress ?? null,
                    userAgent: context.userAgent ?? null,
                    transaction,
                });
            }
        }

        if (input.status !== undefined) {
            await createAuditLog({
                actorId: actor.id,
                action:
                    input.status === "blocked" || input.status === "inactive"
                        ? "users.account_locked"
                        : previousStatus === "blocked" || previousStatus === "inactive"
                            ? "users.account_unlocked"
                            : "users.status_changed",
                targetType: "user",
                targetId: user._id,
                metadata: {
                    before: previousStatus,
                    after: input.status,
                },
                ipAddress: context.ipAddress ?? null,
                userAgent: context.userAgent ?? null,
                transaction,
            });
        }
    });

    return serializeUser(user, { maskContact: true });
};

export const updateUserAvatarForAdmin = async (
    actor: AuthenticatedUser,
    userId: string,
    input: { url: string; key?: string | null },
    context: RequestContext = {},
) => {
    assertAdminActor(actor);

    const user = await findUserById(userId);

    if (!user) {
        throw new ApiError(404, "User not found");
    }

    await withTransaction(async (transaction) => {
        await saveUserUpdates(
            user,
            {
                avatarUrl: input.url.trim(),
                avatarKey: input.key?.trim() ? input.key.trim() : null,
            },
            transaction,
        );
        await createAuditLog({
            actorId: actor.id,
            action: "users.avatar_updated",
            targetType: "user",
            targetId: user._id,
            metadata: {
                avatarKey: input.key ?? null,
            },
            ipAddress: context.ipAddress ?? null,
            userAgent: context.userAgent ?? null,
            transaction,
        });
    });

    return serializeUser(user, { maskContact: true });
};

export const updateUserStatusForAdmin = async (
    actor: AuthenticatedUser,
    userId: string,
    status: UserStatus,
    context: RequestContext = {},
) => {
    assertAdminActor(actor);

    const user = await findUserById(userId);

    if (!user) {
        throw new ApiError(404, "User not found");
    }

    const previousStatus = user.status;
    const roles = await getUserRoles(user._id);

    await assertDoesNotRemoveLastActiveAdmin(roles, previousStatus, undefined, status);

    await withTransaction(async (transaction) => {
        await saveUserUpdates(user, { status }, transaction);
        await createAuditLog({
            actorId: actor.id,
            action:
                status === "blocked" || status === "inactive"
                    ? "users.account_locked"
                    : previousStatus === "blocked" || previousStatus === "inactive"
                        ? "users.account_unlocked"
                        : "users.status_changed",
            targetType: "user",
            targetId: user._id,
            metadata: {
                before: previousStatus,
                after: status,
            },
            ipAddress: context.ipAddress ?? null,
            userAgent: context.userAgent ?? null,
            transaction,
        });
    });

    return serializeUser(user, { maskContact: true });
};
export type AdminListUsersQuery = {
    page: number;
    limit: number;
    search?: string;
    role?: UserRole;
    status?: UserStatus;
};

export const listUserProfilesForAdmin = async (actor: AuthenticatedUser, query: AdminListUsersQuery) => {
    assertAdminActor(actor);

    return listUsersForAdmin({
        page: query.page,
        limit: query.limit,
        search: query.search,
        role: query.role,
        status: query.status,
    });
};
