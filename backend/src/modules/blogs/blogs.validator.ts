import { z } from "zod";

import { blogStatusValues } from "../../models/blog";

const nullableTrimmedString = (max: number) =>
    z
        .string()
        .trim()
        .max(max)
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
    coverImage: nullableTrimmedString(1024),
    content: contentSchema,
    status: z.enum(blogStatusValues).optional(),
    publishedAt: nullableTrimmedString(64),
});

export const updateBlogBodySchema = createBlogBodySchema.partial().refine(
    (value) => Object.keys(value).length > 0,
    "At least one field is required",
);
