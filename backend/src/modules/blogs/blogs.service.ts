import { Op, type Transaction, type WhereOptions } from "sequelize";

import { ApiError } from "../../common/api-error";
import { sanitizeNullableSingleLineText, sanitizeSingleLineText, sanitizeText } from "../../common/sanitization";
import sequelize from "../../config/database";
import Blog, { type BlogDocument, type BlogStatus } from "../../models/blog";
import BlogCategory from "../../models/blog-category";
import { writeAuditLog } from "../../services/audit-log-service";
import type { AuthenticatedUser } from "../auth/auth.service";

export type ListBlogsQuery = {
    q?: string;
    category?: string;
    status?: BlogStatus;
    page?: number;
    limit?: number;
};

export type BlogInput = {
    slug?: string;
    title: string;
    category: string;
    readTime?: string | null;
    location?: string | null;
    excerpt: string;
    coverImage?: string | null;
    content: string[];
    status?: BlogStatus;
    publishedAt?: string | null;
};

export type UpdateBlogInput = Partial<BlogInput>;

type AuditContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

const maxPageLimit = 50;

const assertAdmin = (user: AuthenticatedUser) => {
    if (!user.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }
};

const slugify = (value: string) => {
    const slug = sanitizeSingleLineText(value)
        .normalize("NFD")
        .replace(/\p{Diacritic}/gu, "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "")
        .slice(0, 255);

    return slug || `blog-${Date.now()}`;
};

const normalizeCategory = (value: string) => {
    const category = sanitizeSingleLineText(value);

    if (!category) {
        throw new ApiError(422, "Validation error", [
            {
                path: "category",
                msg: "category cannot be empty after sanitization",
            },
        ]);
    }

    return category;
};

const normalizeContent = (content: string[]) => {
    const normalized = content.map(sanitizeText).filter(Boolean);

    if (normalized.length === 0) {
        throw new ApiError(422, "Validation error", [
            {
                path: "content",
                msg: "content must contain at least one paragraph",
            },
        ]);
    }

    return normalized;
};

const toDateOrNull = (value?: string | null) => {
    if (value === undefined) {
        return undefined;
    }

    if (value === null || !value.trim()) {
        return null;
    }

    const date = new Date(value);

    if (Number.isNaN(date.getTime())) {
        throw new ApiError(422, "Validation error", [
            {
                path: "publishedAt",
                msg: "publishedAt must be a valid date",
            },
        ]);
    }

    return date;
};

const formatPublishedAt = (date?: Date | null) => {
    if (!date) {
        return null;
    }

    return new Date(date).toISOString().slice(0, 10);
};

const serializeBlog = (blog: BlogDocument) => ({
    id: String(blog.blogId),
    blogId: Number(blog.blogId),
    slug: blog.slug,
    title: blog.title,
    category: blog.categoryName,
    categoryId: blog.categoryId ?? null,
    readTime: blog.readTime ?? "",
    location: blog.location ?? "",
    excerpt: blog.excerpt,
    coverImage: blog.coverImage ?? "",
    content: Array.isArray(blog.content) ? blog.content : [],
    status: blog.status,
    publishedAt: formatPublishedAt(blog.publishedAt),
    createdAt: blog.createdAt,
    updatedAt: blog.updatedAt,
});

const parsePagination = (query: ListBlogsQuery) => ({
    page: Math.max(1, query.page ?? 1),
    limit: Math.min(maxPageLimit, Math.max(1, query.limit ?? 12)),
});

const buildSearchWhere = (query: ListBlogsQuery): WhereOptions => {
    const filters: Record<string | symbol, unknown> = {};

    if (query.category) {
        filters.categoryName = sanitizeSingleLineText(query.category);
    }

    if (query.q?.trim()) {
        const keyword = `%${sanitizeSingleLineText(query.q)}%`;
        filters[Op.or] = [
            { title: { [Op.like]: keyword } },
            { excerpt: { [Op.like]: keyword } },
            { categoryName: { [Op.like]: keyword } },
            { location: { [Op.like]: keyword } },
        ];
    }

    return filters as WhereOptions;
};

const ensureCategory = async (name: string, transaction?: Transaction) => {
    const normalizedName = normalizeCategory(name);
    const existing = await BlogCategory.findOne({
        where: {
            name: normalizedName,
        },
        transaction,
    });

    if (existing) {
        return existing;
    }

    return BlogCategory.create(
        {
            name: normalizedName,
            slug: slugify(normalizedName),
        },
        { transaction },
    );
};

const assertUniqueSlug = async (slug: string, currentBlogId?: number, transaction?: Transaction) => {
    const duplicate = await Blog.findOne({
        where: {
            slug,
            ...(currentBlogId ? { blogId: { [Op.ne]: currentBlogId } } : {}),
        },
        transaction,
    });

    if (duplicate) {
        throw new ApiError(409, "Blog slug already exists");
    }
};

const writeBlogAudit = async (
    actor: AuthenticatedUser,
    action: string,
    blogId: number,
    metadata: Record<string, unknown>,
    context: AuditContext,
    transaction?: Transaction,
) => {
    await writeAuditLog({
        actorId: Number(actor.id),
        action,
        targetType: "blog",
        targetId: blogId,
        metadata,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        transaction,
    });
};

export const listPublicBlogs = async (query: ListBlogsQuery) => {
    const { page, limit } = parsePagination(query);
    const where: WhereOptions = {
        ...buildSearchWhere(query),
        status: "published",
        deletedAt: {
            [Op.is]: null,
        },
    };
    const { rows, count } = await Blog.findAndCountAll({
        where,
        order: [["publishedAt", "DESC"], ["blogId", "DESC"]],
        offset: (page - 1) * limit,
        limit,
    });

    return {
        items: rows.map(serializeBlog),
        pagination: {
            page,
            limit,
            total: count,
            totalPages: Math.max(1, Math.ceil(count / limit)),
        },
    };
};

export const getPublicBlogBySlug = async (slug: string) => {
    const blog = await Blog.findOne({
        where: {
            slug: sanitizeSingleLineText(slug),
            status: "published",
            deletedAt: {
                [Op.is]: null,
            },
        },
    });

    if (!blog) {
        throw new ApiError(404, "Blog not found");
    }

    return serializeBlog(blog);
};

export const listAdminBlogs = async (admin: AuthenticatedUser, query: ListBlogsQuery) => {
    assertAdmin(admin);

    const { page, limit } = parsePagination(query);
    const where: WhereOptions = {
        ...buildSearchWhere(query),
        deletedAt: {
            [Op.is]: null,
        },
        ...(query.status ? { status: query.status } : {}),
    };
    const { rows, count } = await Blog.findAndCountAll({
        where,
        order: [["updatedAt", "DESC"], ["blogId", "DESC"]],
        offset: (page - 1) * limit,
        limit,
    });

    return {
        items: rows.map(serializeBlog),
        pagination: {
            page,
            limit,
            total: count,
            totalPages: Math.max(1, Math.ceil(count / limit)),
        },
    };
};

export const createAdminBlog = async (
    admin: AuthenticatedUser,
    input: BlogInput,
    context: AuditContext = {},
) => {
    assertAdmin(admin);

    const title = sanitizeSingleLineText(input.title);
    const slug = slugify(input.slug ?? title);
    const content = normalizeContent(input.content);
    const status = input.status ?? "published";
    const parsedPublishedAt = toDateOrNull(input.publishedAt);
    const publishedAt = parsedPublishedAt === undefined
        ? status === "published"
            ? new Date()
            : null
        : parsedPublishedAt;

    await assertUniqueSlug(slug);

    return sequelize.transaction(async (transaction) => {
        const category = await ensureCategory(input.category, transaction);
        const blog = await Blog.create(
            {
                slug,
                title,
                categoryId: category.categoryId,
                categoryName: category.name,
                readTime: sanitizeNullableSingleLineText(input.readTime),
                location: sanitizeNullableSingleLineText(input.location),
                excerpt: sanitizeText(input.excerpt),
                coverImage: sanitizeNullableSingleLineText(input.coverImage),
                content,
                status,
                publishedAt,
                createdByUserId: Number(admin.id),
                updatedByUserId: Number(admin.id),
                deletedAt: null,
            },
            { transaction },
        );

        await writeBlogAudit(admin, "blog.create", blog.blogId, { slug: blog.slug }, context, transaction);

        return serializeBlog(blog);
    });
};

export const updateAdminBlog = async (
    admin: AuthenticatedUser,
    blogId: number,
    input: UpdateBlogInput,
    context: AuditContext = {},
) => {
    assertAdmin(admin);

    const blog = await Blog.findOne({
        where: {
            blogId,
            deletedAt: {
                [Op.is]: null,
            },
        },
    });

    if (!blog) {
        throw new ApiError(404, "Blog not found");
    }

    const nextSlug = input.slug !== undefined ? slugify(input.slug) : undefined;

    if (nextSlug && nextSlug !== blog.slug) {
        await assertUniqueSlug(nextSlug, blog.blogId);
    }

    return sequelize.transaction(async (transaction) => {
        if (input.category !== undefined) {
            const category = await ensureCategory(input.category, transaction);
            blog.categoryId = category.categoryId;
            blog.categoryName = category.name;
        }

        if (nextSlug) blog.slug = nextSlug;
        if (input.title !== undefined) blog.title = sanitizeSingleLineText(input.title);
        if (input.readTime !== undefined) blog.readTime = sanitizeNullableSingleLineText(input.readTime);
        if (input.location !== undefined) blog.location = sanitizeNullableSingleLineText(input.location);
        if (input.excerpt !== undefined) blog.excerpt = sanitizeText(input.excerpt);
        if (input.coverImage !== undefined) blog.coverImage = sanitizeNullableSingleLineText(input.coverImage);
        if (input.content !== undefined) blog.content = normalizeContent(input.content);
        if (input.status !== undefined) blog.status = input.status;

        const nextPublishedAt = toDateOrNull(input.publishedAt);
        if (nextPublishedAt !== undefined) {
            blog.publishedAt = nextPublishedAt;
        } else if (input.status === "published" && !blog.publishedAt) {
            blog.publishedAt = new Date();
        }

        blog.updatedByUserId = Number(admin.id);
        await blog.save({ transaction });
        await writeBlogAudit(
            admin,
            "blog.update",
            blog.blogId,
            { slug: blog.slug, changedFields: Object.keys(input) },
            context,
            transaction,
        );

        return serializeBlog(blog);
    });
};

export const deleteAdminBlog = async (
    admin: AuthenticatedUser,
    blogId: number,
    context: AuditContext = {},
) => {
    assertAdmin(admin);

    const blog = await Blog.findOne({
        where: {
            blogId,
            deletedAt: {
                [Op.is]: null,
            },
        },
    });

    if (!blog) {
        throw new ApiError(404, "Blog not found");
    }

    await sequelize.transaction(async (transaction) => {
        blog.status = "draft";
        blog.deletedAt = new Date();
        blog.updatedByUserId = Number(admin.id);
        await blog.save({ transaction });
        await writeBlogAudit(admin, "blog.delete", blog.blogId, { slug: blog.slug }, context, transaction);
    });
};
