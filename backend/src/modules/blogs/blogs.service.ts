import { Op, type Transaction, type WhereOptions } from "sequelize";

import { ApiError } from "../../common/api-error";
import { sanitizeNullableSingleLineText, sanitizeSingleLineText, sanitizeText } from "../../common/sanitization";
import sequelize from "../../config/database";
import Blog, { type BlogDocument, type BlogStatus } from "../../models/blog";
import BlogCategory from "../../models/blog-category";
import { writeAuditLog } from "../../services/audit-log.service";
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

/**
 * Giải thuật kiểm tra quyền Quản trị viên (RBAC Guard):
 * Bắt buộc tài khoản thực thi có vai trò `admin` trước khi thao tác quản lý bài viết; ném lỗi 403 nếu không đủ đặc quyền.
 */
const assertAdmin = (user: AuthenticatedUser) => {
    if (!user.roles.includes("admin")) {
        throw new ApiError(403, "Forbidden");
    }
};

/**
 * Giải thuật chuẩn hóa tiêu đề tiếng Việt sang chuỗi đường dẫn tĩnh URL-safe dạng `kebab-case`:
 * - Làm sạch chuỗi một dòng chống mã độc, phân rã Unicode NFD và loại bỏ toàn bộ dấu thanh thuộc lớp `\p{Diacritic}`.
 * - Hạ chữ thường, thay thế mọi cụm ký tự phi chữ-số ASCII (`[^a-z0-9]+`) bằng dấu gạch ngang đơn `-`, cắt bỏ gạch ngang ở hai đầu và giới hạn tối đa 255 ký tự.
 * - Cơ chế dự phòng (fallback): nếu kết quả rỗng sau chuẩn hóa, tự động sinh slug duy nhất theo dấu thời gian `blog-${Date.now()}`. Độ phức tạp: O(n).
 */
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

/**
 * Giải thuật làm sạch tên chuyên mục bài viết và kiểm tra bất biến không rỗng sau khi loại bỏ ký tự điều khiển/thẻ HTML (ném lỗi 422 nếu rỗng).
 */
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

/**
 * Giải thuật chuẩn hóa mảng đoạn văn nội dung bài viết:
 * Làm sạch chống XSS từng đoạn qua `sanitizeText`, lọc bỏ đoạn rỗng và đảm bảo bài viết chứa ít nhất một đoạn văn hợp lệ.
 */
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

/**
 * Giải thuật phân tích và xác thực mốc thời gian xuất bản `publishedAt`:
 * Phân biệt 3 trạng thái: `undefined` (không cập nhật), `null`/chuỗi rỗng (gỡ mốc xuất bản) và đối tượng `Date` hợp lệ (ném lỗi 422 nếu ngày không hợp lệ).
 */
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

/**
 * Giải thuật định dạng mốc thời gian xuất bản sang chuỗi ngày chuẩn ISO `YYYY-MM-DD` (hoặc `null` nếu chưa xuất bản).
 */
const formatPublishedAt = (date?: Date | null) => {
    if (!date) {
        return null;
    }

    return new Date(date).toISOString().slice(0, 10);
};

/**
 * Giải thuật tuần tự hóa bản ghi `BlogDocument` sang đối tượng DTO chuẩn cho client, đảm bảo tính an toàn kiểu cho mảng `content` và các trường tùy chọn.
 */
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

/**
 * Giải thuật chuẩn hóa và kẹp biên tham số phân trang bài viết (`page >= 1`, `1 <= limit <= 50`, mặc định 12).
 */
const parsePagination = (query: ListBlogsQuery) => ({
    page: Math.max(1, query.page ?? 1),
    limit: Math.min(maxPageLimit, Math.max(1, query.limit ?? 12)),
});

/**
 * Giải thuật dựng điều kiện lọc truy vấn SQL cho bài viết:
 * - Lọc khớp chuyên mục đã làm sạch (nếu chỉ định).
 * - Thoát ký tự đại diện SQL LIKE (`\`, `%`, `_`) chống wildcard injection trước khi tìm kiếm chuỗi con đa trường (`title`, `excerpt`, `categoryName`, `location`).
 */
const buildSearchWhere = (query: ListBlogsQuery): WhereOptions => {
    const filters: Record<string | symbol, unknown> = {};

    if (query.category) {
        filters.categoryName = sanitizeSingleLineText(query.category);
    }

    if (query.q?.trim()) {
        const escapedQuery = sanitizeSingleLineText(query.q).replace(/[\\%_]/g, "\\$&");
        const keyword = `%${escapedQuery}%`;
        filters[Op.or] = [
            { title: { [Op.like]: keyword } },
            { excerpt: { [Op.like]: keyword } },
            { categoryName: { [Op.like]: keyword } },
            { location: { [Op.like]: keyword } },
        ];
    }

    return filters as WhereOptions;
};

/**
 * Giải thuật tìm kiếm hoặc khởi tạo mới chuyên mục bài viết (`BlogCategory`) trong giao dịch CSDL kèm sinh `slug` chuẩn hóa từ tên chuyên mục.
 */
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

/**
 * Giải thuật kiểm tra tính duy nhất của `slug` bài viết chống trùng lặp đường dẫn tĩnh:
 * Truy vấn đối chiếu bản ghi mang cùng `slug` (loại trừ `currentBlogId` khi đang cập nhật bài viết hiện hữu) và ném lỗi xung đột 409 nếu đã tồn tại.
 */
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

/**
 * Giải thuật ghi nhận nhật ký kiểm toán (`audit_logs`) cho các thao tác tạo, sửa và xóa mềm bài viết của Quản trị viên.
 */
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

/**
 * Giải thuật pipeline truy vấn và phân trang danh sách bài viết công khai:
 * Áp dụng bộ lọc tìm kiếm `buildSearchWhere`, giới hạn nghiêm ngặt các bài đã xuất bản (`status = "published"`) và chưa xóa mềm (`deletedAt IS NULL`),
 * sắp xếp theo thời điểm xuất bản mới nhất (`publishedAt DESC, blogId DESC`).
 */
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

/**
 * Giải thuật truy xuất chi tiết bài viết công khai theo đường dẫn tĩnh `slug`:
 * Làm sạch `slug` đầu vào và chỉ trả về bài viết có `status = "published"`, `deletedAt IS NULL` (ném lỗi 404 nếu bài đang nháp hoặc đã xóa).
 */
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

/**
 * Giải thuật truy vấn và phân trang danh sách bài viết cho trang Quản trị:
 * Xác thực quyền Admin, hỗ trợ tìm kiếm đa trường và lọc theo mọi trạng thái (`draft`/`published`) trên các bản ghi chưa xóa mềm, sắp xếp theo `updatedAt DESC`.
 */
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

/**
 * Giải thuật tạo mới bài viết quản trị trong giao dịch CSDL:
 * - Xác thực quyền Admin, sinh `slug` chuẩn hóa từ `input.slug` hoặc `title` và kiểm tra chống trùng lặp qua `assertUniqueSlug`.
 * - Tự động gán `publishedAt = new Date()` nếu xuất bản ngay mà chưa truyền ngày, đồng bộ chuyên mục `ensureCategory`, lưu bài viết và ghi audit log.
 */
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

/**
 * Giải thuật cập nhật bài viết quản trị trong giao dịch CSDL:
 * Kiểm tra chống trùng lặp khi thay đổi `slug`, đồng bộ lại chuyên mục nếu đổi tên, tự động gán mốc `publishedAt` lần đầu khi chuyển sang `published`,
 * làm sạch chống XSS toàn bộ trường văn bản và ghi audit log các trường biến đổi.
 */
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

/**
 * Giải thuật xóa mềm bài viết quản trị trong giao dịch CSDL:
 * Hạ trạng thái về `draft`, đánh dấu `deletedAt` để ẩn khỏi truy vấn công khai lẫn quản trị mà vẫn bảo toàn dữ liệu đối soát kiểm toán.
 */
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
