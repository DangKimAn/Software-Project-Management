/**
 * Bộ điều phối HTTP cho phân hệ bài viết cẩm nang du lịch (`blogs`):
 * - Phục vụ tra cứu danh sách/chi tiết bài viết công khai theo `slug` và các thao tác quản trị tạo, cập nhật, xóa bài viết có ghi nhận ngữ cảnh kiểm toán.
 */

import type { Request, RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    getValidatedBody,
    getValidatedParams,
    getValidatedQuery,
} from "../../common/validation";
import {
    createAdminBlog,
    deleteAdminBlog,
    getPublicBlogBySlug,
    listAdminBlogs,
    listPublicBlogs,
    updateAdminBlog,
    type BlogInput,
    type ListBlogsQuery,
    type UpdateBlogInput,
} from "./blogs.service";

const auditContextFromRequest = (req: Request) => ({
    ipAddress: req.ip,
    userAgent: req.get("user-agent") ?? null,
});

/**
 * Truy vấn phân trang danh sách các bài viết blog đã xuất bản công khai.
 */
export const getPublicBlogs: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ListBlogsQuery>(req);
    const result = await listPublicBlogs(query);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Truy vấn chi tiết một bài viết công khai theo đường dẫn tĩnh `slug`.
 */
export const getPublicBlog: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ slug: string }>(req);
    const result = await getPublicBlogBySlug(params.slug);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Truy vấn phân trang danh sách toàn bộ bài viết (bao gồm bản nháp/ẩn) dành cho quản trị viên.
 */
export const getAdminBlogs: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ListBlogsQuery>(req);
    const result = await listAdminBlogs(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

/**
 * Tạo mới bài viết blog từ phía quản trị viên kèm ghi nhận kiểm toán.
 */
export const createAdminBlogRequest: RequestHandler = asyncHandler(async (req, res) => {
    const payload = getValidatedBody<BlogInput>(req);
    const result = await createAdminBlog(req.user!, payload, auditContextFromRequest(req));

    return sendSuccess(res, {
        statusCode: 201,
        message: "Blog created",
        data: result,
    });
});

/**
 * Cập nhật nội dung hoặc trạng thái xuất bản của bài viết theo `blogId`.
 */
export const updateAdminBlogRequest: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ blogId: number }>(req);
    const payload = getValidatedBody<UpdateBlogInput>(req);
    const result = await updateAdminBlog(req.user!, params.blogId, payload, auditContextFromRequest(req));

    return sendSuccess(res, {
        message: "Blog updated",
        data: result,
    });
});

/**
 * Xóa bài viết blog theo `blogId` và ghi nhận nhật ký kiểm toán quản trị.
 */
export const deleteAdminBlogRequest: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ blogId: number }>(req);
    await deleteAdminBlog(req.user!, params.blogId, auditContextFromRequest(req));

    return sendSuccess(res, {
        message: "Blog deleted",
    });
});
