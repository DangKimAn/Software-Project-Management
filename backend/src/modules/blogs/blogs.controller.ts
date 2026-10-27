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

export const getPublicBlogs: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ListBlogsQuery>(req);
    const result = await listPublicBlogs(query);

    return sendSuccess(res, {
        data: result,
    });
});

export const getPublicBlog: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ slug: string }>(req);
    const result = await getPublicBlogBySlug(params.slug);

    return sendSuccess(res, {
        data: result,
    });
});

export const getAdminBlogs: RequestHandler = asyncHandler(async (req, res) => {
    const query = getValidatedQuery<ListBlogsQuery>(req);
    const result = await listAdminBlogs(req.user!, query);

    return sendSuccess(res, {
        data: result,
    });
});

export const createAdminBlogRequest: RequestHandler = asyncHandler(async (req, res) => {
    const payload = getValidatedBody<BlogInput>(req);
    const result = await createAdminBlog(req.user!, payload, auditContextFromRequest(req));

    return sendSuccess(res, {
        statusCode: 201,
        message: "Blog created",
        data: result,
    });
});

export const updateAdminBlogRequest: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ blogId: number }>(req);
    const payload = getValidatedBody<UpdateBlogInput>(req);
    const result = await updateAdminBlog(req.user!, params.blogId, payload, auditContextFromRequest(req));

    return sendSuccess(res, {
        message: "Blog updated",
        data: result,
    });
});

export const deleteAdminBlogRequest: RequestHandler = asyncHandler(async (req, res) => {
    const params = getValidatedParams<{ blogId: number }>(req);
    await deleteAdminBlog(req.user!, params.blogId, auditContextFromRequest(req));

    return sendSuccess(res, {
        message: "Blog deleted",
    });
});
