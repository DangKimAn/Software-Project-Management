/**
 * Lược đồ kiểm chứng dữ liệu đầu vào bằng Zod cho phân hệ người dùng (`users`):
 * - Ràng buộc nghiêm ngặt trường cập nhật hồ sơ cá nhân (`strict()`), đường dẫn ảnh đại diện hợp lệ, tham số phân trang tìm kiếm và trạng thái tài khoản quản trị.
 */

import { z } from "zod";

import { isSafeExternalHttpUrl } from "../../common/url-security";

const phoneSchema = z
    .string()
    .trim()
    .regex(/^(0|\+84)[0-9]{9}$/, "phone must be a valid Vietnamese phone number");

const nullableString = (max: number) =>
    z.preprocess(
        (value) => (value === "" ? null : value),
        z.string().trim().max(max).nullable().optional(),
    );

const dateSchema = z.preprocess(
    (value) => (value === "" ? null : value),
    z
        .string()
        .refine((value) => !Number.isNaN(Date.parse(value)), "date must be a valid ISO date")
        .refine((value) => new Date(value).getTime() <= Date.now(), "date cannot be in the future")
        .nullable()
        .optional(),
);

const safeAvatarUrlStringSchema = z
    .string()
    .trim()
    .url("avatarUrl must be a valid URL")
    .max(1024)
    .refine((value) => isSafeExternalHttpUrl(value, { allowLocalhostInDev: true }), {
        message: "avatarUrl must use http(s) and point to a public host",
    });

const avatarUrlSchema = z.preprocess(
    (value) => (value === "" ? null : value),
    safeAvatarUrlStringSchema.nullable().optional(),
);

const avatarKeySchema = z.preprocess(
    (value) => (value === "" ? null : value),
    z.string().trim().max(500).nullable().optional(),
);

const publicProfileTextSchema = nullableString(255);
const languagesSchema = z.array(z.string().trim().min(1).max(64)).max(20).nullable().optional();

const userStatusSchema = z.enum(["active", "inactive", "blocked", "suspended", "deleted", "locked"]);
const userRoleSchema = z.enum(["guest", "host", "admin"]);

const userIdParamsSchema = z.object({
    userId: z.string().regex(/^\d+$/, "userId must be numeric"),
});

const baseProfileBodySchema = z.object({
    username: nullableString(255),
    fullName: z.string().trim().min(1).max(255).optional(),
    firstName: z.string().trim().min(1).max(120).optional(),
    lastName: z.string().trim().min(1).max(120).optional(),
    phone: z.preprocess((value) => (value === "" ? null : value), phoneSchema.nullable().optional()),
    dateOfBirth: dateSchema,
    dob: dateSchema,
    bio: nullableString(2000),
    avatarUrl: avatarUrlSchema,
    location: publicProfileTextSchema,
    job: publicProfileTextSchema,
    dreamDestination: publicProfileTextSchema,
    school: publicProfileTextSchema,
    languages: languagesSchema,
});

/**
 * Schema kiểm chứng nghiêm ngặt các trường người dùng được phép tự cập nhật trên hồ sơ cá nhân.
 */
export const updateMeBodySchema = baseProfileBodySchema.strict();

/**
 * Schema kiểm chứng URL ảnh đại diện hợp lệ khi cập nhật avatar.
 */
export const updateAvatarBodySchema = z
    .object({
        url: z
            .string()
            .trim()
            .url("url must be a valid URL")
            .max(1024)
            .refine((value) => isSafeExternalHttpUrl(value, { allowLocalhostInDev: true }), {
                message: "url must use http(s) and point to a public host",
            }),
        key: avatarKeySchema,
    })
    .strict();

/**
 * Schema kiểm chứng dữ liệu cập nhật thông tin người dùng dành cho quản trị viên.
 */
export const adminUpdateUserBodySchema = baseProfileBodySchema
    .extend({
        email: z.string().trim().email("email is invalid").transform((value) => value.toLowerCase()).optional(),
        status: userStatusSchema.optional(),
        role: userRoleSchema.optional(),
        roles: z.array(userRoleSchema).min(1).max(4).optional(),
    })
    .strict()
    .refine((value) => !(value.role && value.roles), {
        message: "Use either role or roles, not both",
        path: ["roles"],
    });

/**
 * Schema kiểm chứng trạng thái tài khoản mục tiêu khi quản trị viên khóa hoặc kích hoạt lại người dùng.
 */
export const updateUserStatusBodySchema = z
    .object({
        status: userStatusSchema,
    })
    .strict();

/**
 * Schema kiểm chứng bộ lọc từ khóa, vai trò, trạng thái và phân trang danh sách người dùng.
 */
export const listUsersQuerySchema = z
    .object({
        page: z.coerce.number().int().min(1).default(1),
        limit: z.coerce.number().int().min(1).max(100).default(20),
        search: z.string().trim().max(255).optional(),
        role: userRoleSchema.optional(),
        status: userStatusSchema.optional(),
    })
    .strict();

export { userIdParamsSchema };
