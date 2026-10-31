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

export const blogListQuerySchema = z.object({
    q: z.string().trim().min(1).max(255).optional(),
    category: z.string().trim().min(1).max(255).optional(),
    page: z.coerce.number().int().positive().optional(),
    limit: z.coerce.number().int().positive().max(50).optional(),
});

export const adminBlogListQuerySchema = blogListQuerySchema.extend({
    status: z.enum(blogStatusValues).optional(),
});

export const blogSlugParamSchema = z.object({
    slug: z.string().trim().min(1).max(255),
});

export const blogIdParamSchema = z.object({
    blogId: z.coerce.number().int().positive(),
});

export const createBlogBodySchema = z.object({
    slug: z.string().trim().min(1).max(255).optional(),
    title: z.string().trim().min(1).max(255),
    category: z.string().trim().min(1).max(255),
    readTime: nullableTrimmedString(64),
    location: nullableTrimmedString(255),
    excerpt: z.string().trim().min(1).max(2000),
    coverImage: coverImageSchema,
    content: contentSchema,
    status: z.enum(blogStatusValues).optional(),
    publishedAt: nullableTrimmedString(64),
});

export const updateBlogBodySchema = createBlogBodySchema.partial().refine(
    (value) => Object.keys(value).length > 0,
    "At least one field is required",
);
