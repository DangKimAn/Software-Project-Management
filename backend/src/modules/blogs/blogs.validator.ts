/**
 * Lược đồ kiểm chứng dữ liệu đầu vào bằng Zod cho phân hệ bài viết (`blogs`):
 * - Kiểm tra tham số phân trang, bộ lọc trạng thái, định dạng `slug`/`blogId`, danh sách trắng URL ảnh bìa an toàn và nội dung tạo/cập nhật bài viết.
 */

import { z } from "zod";

import { isSafeExternalHttpUrl } from "../../common/url-security";
import { blogStatusValues } from "../../models/blog";

const nullableTrimmedString = (max: number) =>
    z
        .string()
        .trim()
        .max(max)
        .nullable()
        .optional();

const isAllowedBlogCoverImage = (value: string) => {
    const trimmed = value.trim();
    if (!trimmed) {
        return true;
    }
    if (/^(assets\/|\/uploads\/)/i.test(trimmed) && !trimmed.includes("..")) {
        return true;
    }
    return isSafeExternalHttpUrl(trimmed, { allowLocalhostInDev: true });
};

const coverImageSchema = z
    .string()
    .trim()
    .max(1024)
    .refine(isAllowedBlogCoverImage, {
        message: "coverImage must be a valid public http(s) URL or relative asset path",
    })
    .nullable()
    .optional();

const contentSchema = z.array(z.string().trim().min(1).max(5000)).min(1).max(50);

/**
 * Schema kiểm chứng tham số phân trang và từ khóa tìm kiếm danh sách bài viết công khai.
 */
export const blogListQuerySchema = z.object({
    q: z.string().trim().min(1).max(255).optional(),
    category: z.string().trim().min(1).max(255).optional(),
    page: z.coerce.number().int().positive().optional(),
    limit: z.coerce.number().int().positive().max(50).optional(),
});

/**
 * Schema mở rộng bộ lọc trạng thái xuất bản khi truy vấn danh sách bài viết ở trang quản trị.
 */
export const adminBlogListQuerySchema = blogListQuerySchema.extend({
    status: z.enum(blogStatusValues).optional(),
});

/**
 * Schema kiểm chứng định dạng chuỗi `slug` trên đường dẫn chi tiết bài viết.
 */
export const blogSlugParamSchema = z.object({
    slug: z.string().trim().min(1).max(255),
});

/**
 * Schema kiểm chứng tham số định danh số nguyên dương `blogId`.
 */
export const blogIdParamSchema = z.object({
    blogId: z.coerce.number().int().positive(),
});

const slugInputSchema = z.preprocess(
    (value) => (typeof value === "string" && value.trim() === "" ? undefined : value),
    z
        .string()
        .trim()
        .min(1)
        .max(255)
        .regex(
            /^[a-z0-9]+(?:-[a-z0-9]+)*$/,
            "slug chỉ được chứa chữ thường không dấu (a-z), chữ số (0-9) và dấu gạch ngang đơn (-)",
        )
        .optional(),
);

const tagsSchema = z
    .array(z.string().trim().min(1).max(64))
    .max(20)
    .optional();

/**
 * Schema kiểm chứng dữ liệu tạo mới bài viết gồm tiêu đề, tóm tắt, nội dung, thẻ từ khóa, ảnh bìa hợp lệ và trạng thái.
 */
export const createBlogBodySchema = z.object({
    slug: slugInputSchema,
    title: z.string().trim().min(1).max(255),
    category: z.string().trim().min(1).max(255),
    readTime: nullableTrimmedString(64),
    location: nullableTrimmedString(255),
    excerpt: z.string().trim().min(1).max(2000),
    coverImage: coverImageSchema,
    content: contentSchema,
    tags: tagsSchema,
    status: z.enum(blogStatusValues).optional(),
    publishedAt: nullableTrimmedString(64),
});

/**
 * Schema kiểm chứng dữ liệu cập nhật từng phần bài viết, bắt buộc có ít nhất một trường thay đổi.
 */
export const updateBlogBodySchema = createBlogBodySchema.partial().refine(
    (value) => Object.keys(value).length > 0,
    "At least one field is required",
);
