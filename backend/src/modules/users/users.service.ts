import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import RefreshSession from "../../models/refresh-session";
import { deactivateAllUserDeviceTokens } from "../../services/fcm-push.service";
import { disconnectUserSockets } from "../../socket/socket";
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
    syncUserHostDemotion,
    syncUserHostPromotion,
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

const primaryRolePriority: UserRole[] = ["admin", "host", "guest"];

const selfManagedForbiddenFields = ["email", "role", "roles", "status"] as const;

const disablingStatuses: UserStatus[] = ["inactive", "blocked", "suspended", "deleted", "locked"];

/**
 * Giải thuật phân giải vai trò chính đại diện từ tập vai trò của người dùng theo thứ bậc ưu tiên đặc quyền giảm dần `admin -> host -> guest` (mặc định `"guest"`).
 */
const selectPrimaryRole = (roles: UserRole[]) =>
    primaryRolePriority.find((role) => roles.includes(role)) ?? "guest";

/**
 * Giải thuật chuẩn hóa giá trị ngày sinh đầu vào sang đối tượng `Date`, giữ nguyên `undefined` khi không cập nhật và quy đổi chuỗi rỗng về `null`.
 */
const normalizeDate = (value?: string | null) => {
    if (value === undefined) {
        return undefined;
    }

    if (value === null || value === "") {
        return null;
    }

    return new Date(value);
};

/**
 * Giải thuật che mặt nạ dữ liệu định danh cá nhân (PII Masking) cho địa chỉ email:
 * Tách phần tên hộp thư (`localPart`) và tên miền (`domain`), chỉ hiển thị 2 ký tự đầu của `localPart` và thay thế phần còn lại bằng tối thiểu 2 dấu sao `*`.
 */
const maskEmail = (email: string) => {
    const [localPart, domain] = email.split("@");
    const visible = localPart.slice(0, 2);
    return `${visible}${"*".repeat(Math.max(2, localPart.length - visible.length))}@${domain}`;
};

/**
 * Giải thuật che mặt nạ dữ liệu PII cho số điện thoại:
 * Chuẩn hóa số điện thoại qua `normalizePhone` và chỉ hiển thị 4 chữ số cuối dưới định dạng `******XXXX`.
 */
const maskPhone = (phone?: string | null) => {
    if (!phone) {
        return "";
    }

    const normalized = normalizePhone(phone);
    return `******${normalized.slice(-4)}`;
};

/**
 * Giải thuật tái tổng hợp họ tên đầy đủ (`fullName`):
 * Ưu tiên trường `fullName` trực tiếp, hoặc phân rã họ/tên hiện hữu để ghép lại chính xác khi client chỉ gửi cập nhật riêng lẻ `firstName` hoặc `lastName`.
 */
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

/**
 * Giải thuật chuẩn hóa chuỗi văn bản tùy chọn: cắt khoảng trắng hai đầu và chuyển chuỗi rỗng về `null`.
 */
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

/**
 * Giải thuật chuẩn hóa và khử trùng lặp danh sách ngôn ngữ giao tiếp của người dùng bằng cấu trúc `Set`.
 */
const normalizeLanguages = (value?: string[] | null) => {
    if (value === undefined) {
        return undefined;
    }

    if (value === null) {
        return null;
    }

    return [...new Set(value.map((item) => item.trim()).filter(Boolean))];
};

/**
 * Giải thuật giải mã an toàn trường danh sách ngôn ngữ lưu trữ trong CSDL (hỗ trợ cả mảng trực tiếp lẫn chuỗi JSON tuần tự hóa).
 */
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

/**
 * Giải thuật tổng hợp và tuần tự hóa hồ sơ người dùng kèm cơ chế bảo vệ dữ liệu cá nhân (PII Masking):
 * - Hợp nhất thông tin bảng `users`, tập vai trò từ `getUserRoles` và hồ sơ mở rộng `UserProfile`.
 * - Khi bật `options.maskContact = true` (dành cho luồng tra cứu Admin), tự động thay thế `email` và `phone` gốc bằng chuỗi đã che mặt nạ `maskEmail`/`maskPhone`.
 */
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

/**
 * Giải thuật trích xuất các thuộc tính cập nhật thuộc bảng hồ sơ mở rộng công khai (`user_profiles`).
 */
const buildPublicProfileUpdates = (input: UpdateOwnProfileInput) => ({
    ...(input.location !== undefined ? { location: normalizeNullableText(input.location) } : {}),
    ...(input.job !== undefined ? { job: normalizeNullableText(input.job) } : {}),
    ...(input.dreamDestination !== undefined
        ? { dreamDestination: normalizeNullableText(input.dreamDestination) }
        : {}),
    ...(input.school !== undefined ? { school: normalizeNullableText(input.school) } : {}),
    ...(input.languages !== undefined ? { languages: normalizeLanguages(input.languages) } : {}),
});

/**
 * Giải thuật truy xuất hồ sơ cá nhân đầy đủ (không che PII) cho chính chủ tài khoản đang xác thực.
 */
export const getCurrentUserProfile = (actor: AuthenticatedUser) => serializeUser(actor.id);

/**
 * Giải thuật truy xuất hồ sơ người dùng cho Quản trị viên với chế độ bắt buộc che mặt nạ thông tin liên hệ PII (`maskContact: true`).
 */
export const getUserProfileForAdmin = async (userId: string) => serializeUser(userId, { maskContact: true });

/**
 * Giải thuật trích xuất và chuẩn hóa các trường cập nhật thuộc bảng `users` cốt lõi.
 */
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

/**
 * Giải thuật chống tự leo thang đặc quyền (Privilege Escalation Guard):
 * Ném lỗi 403 ngay lập tức nếu người dùng gửi kèm bất kỳ trường quản trị nhạy cảm nào (`email`, `role`, `roles`, `status`) trong yêu cầu tự sửa hồ sơ cá nhân.
 */
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

/**
 * Giải thuật kiểm tra quyền Quản trị viên (`admin`) đối với các nghiệp vụ quản lý người dùng cấp hệ thống.
 */
const assertAdminActor = (actor: AuthenticatedUser) => {
    if (!actor.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }
};

/**
 * Giải thuật kiểm tra tính duy nhất song song (`Promise.all`) cho bộ ba định danh `username`, `email` và `phone` đã chuẩn hóa:
 * Loại trừ chính `targetUserId` đang được cập nhật và ném lỗi xung đột 409 tổng hợp đầy đủ các trường bị trùng lặp.
 */
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

/**
 * Giải thuật bảo vệ bất biến an toàn hệ thống "Quản trị viên hoạt động cuối cùng" (Last Active Admin Protection):
 * - Nếu tài khoản mục tiêu hiện đang là `admin` ở trạng thái `active`, đánh giá xem thay đổi `nextRoles` (bỏ vai trò `admin`) hoặc `nextStatus` (chuyển sang trạng thái khóa/vô hiệu hóa thuộc `disablingStatuses`) có làm mất quyền Admin hoạt động hay không.
 * - Khi phát hiện nguy cơ giảm số lượng Admin hoạt động, truy vấn `countActiveUsersWithRole("admin")` và chặn thao tác với lỗi 409 nếu toàn hệ thống chỉ còn duy nhất `<= 1` Admin đang `active`.
 */
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

/**
 * Giải thuật kiểm tra ràng buộc nghĩa vụ lưu trú trước khi hạ quyền Chủ nhà (`host`) về Khách (`guest`):
 * Đếm số đơn đặt phòng thuộc Host đang ở trạng thái đã thanh toán, đã xác nhận hoặc khách đang lưu trú (`paid`, `confirmed`, `checked_in`); ném lỗi xung đột 409 nếu vẫn còn đơn hiệu lực.
 */
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

/**
 * Giải thuật thu hồi cưỡng bức toàn bộ phiên đăng nhập và kết nối thời gian thực khi tài khoản bị hạ quyền hoặc vô hiệu hóa:
 * Đánh dấu `revokedAt` cho mọi `RefreshSession` còn hiệu lực, hủy kích hoạt toàn bộ thiết bị nhận FCM Push và ngắt kết nối tất cả phiên Socket.IO của `userId`.
 */
const revokeUserSessionsAndRealtime = async (userId: number) => {
    if (getEnv().nodeEnv !== "test" || Object.prototype.hasOwnProperty.call(RefreshSession, "update")) {
        try {
            await RefreshSession.update(
                { revokedAt: new Date() },
                { where: { userId, revokedAt: null } },
            );
        } catch {
            // Ignore in isolated mock test contexts
        }
    }

    await deactivateAllUserDeviceTokens(userId);
    disconnectUserSockets(userId);
};

/**
 * Giải thuật tự cập nhật hồ sơ cá nhân của người dùng:
 * Chặn leo thang đặc quyền qua `assertNoSelfManagedAdminFields`, kiểm tra chống trùng `username`/`phone`, tự động đặt lại `isPhoneVerified = false` nếu đổi số điện thoại
 * và ghi cập nhật nguyên tử hai bảng `users` + `user_profiles` trong một giao dịch CSDL.
 */
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

    const updates: Parameters<typeof saveUserUpdates>[1] = buildProfileUpdates(input, user.fullName);
    if (updates.phone !== undefined && updates.phone !== (user.phone ?? null)) {
        updates.isPhoneVerified = false;
    }
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

/**
 * Giải thuật cập nhật đường dẫn và khóa đối tượng ảnh đại diện của người dùng hiện tại thông qua luồng chuẩn hóa `updateCurrentUserProfile`.
 */
export const updateCurrentUserAvatar = async (
    actor: AuthenticatedUser,
    input: { url: string; key?: string | null },
) => {
    return updateCurrentUserProfile(actor, {
        avatarUrl: input.url,
        avatarKey: input.key ?? null,
    });
};

/**
 * Giải thuật cập nhật hồ sơ, trạng thái và phân quyền người dùng dành cho Quản trị viên:
 * - Xác thực quyền Admin, tính duy nhất của định danh, bất biến bảo vệ Admin hoạt động cuối cùng (`assertDoesNotRemoveLastActiveAdmin`) và điều kiện cho phép hạ quyền Host (`assertHostCanBeDowngraded`).
 * - Trong giao dịch CSDL: cập nhật bảng `users`/`user_profiles`, thay thế vai trò, đồng bộ cờ xác minh và hồ sơ Host khi thăng/hạ quyền (`syncUserHostPromotion` / `syncUserHostDemotion`), và ghi nhận audit log.
 * - Thu hồi tức thời toàn bộ phiên đăng nhập và kết nối realtime nếu người dùng bị gỡ bớt vai trò hoặc chuyển sang trạng thái khác `active`, trả về DTO đã che PII.
 */
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

            const hadHostRole = oldRoles.includes("host");
            const willHaveHostRole = nextRoles.includes("host");

            if (hadHostRole && !willHaveHostRole) {
                await syncUserHostDemotion(user._id, actor.id, transaction);
            } else if (!hadHostRole && willHaveHostRole) {
                await syncUserHostPromotion(user._id, transaction);
            }

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

    const roleWasRemoved = nextRoles ? oldRoles.some((role) => !nextRoles.includes(role)) : false;
    const statusWasDisabled = input.status !== undefined && input.status !== "active";
    if (roleWasRemoved || statusWasDisabled) {
        await revokeUserSessionsAndRealtime(Number(user._id));
    }

    return serializeUser(user, { maskContact: true });
};

/**
 * Giải thuật cập nhật ảnh đại diện người dùng bởi Quản trị viên kèm ghi nhật ký kiểm toán trong giao dịch CSDL và trả về hồ sơ đã che mặt nạ PII.
 */
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

/**
 * Giải thuật khóa, mở khóa hoặc đổi trạng thái tài khoản người dùng bởi Quản trị viên:
 * Bảo vệ Admin hoạt động cuối cùng qua `assertDoesNotRemoveLastActiveAdmin`, ghi audit log phân loại hành động khóa/mở khóa/đổi trạng thái,
 * và thu hồi mọi phiên RefreshSession/FCM/Socket.IO ngay khi trạng thái mới khác `active`.
 */
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

    if (status !== "active") {
        await revokeUserSessionsAndRealtime(Number(user._id));
    }

    return serializeUser(user, { maskContact: true });
};
export type AdminListUsersQuery = {
    page: number;
    limit: number;
    search?: string;
    role?: UserRole;
    status?: UserStatus;
};

/**
 * Giải thuật xác thực quyền Quản trị viên và truy vấn danh sách người dùng có lọc theo từ khóa/vai trò/trạng thái kèm phân trang.
 */
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
