require("dotenv/config");

const fs = require("fs");
const path = require("path");
const vm = require("vm");
const mysql = require("mysql2/promise");

const dbUser = process.env.MYSQLUSER || process.env.MYSQL_USER || "booking_app";

if (
    dbUser.toLowerCase() === "root" &&
    process.env.ALLOW_DATABASE_ROOT_USER !== "true"
) {
    throw new Error("Refusing to run migration with MySQL root user.");
}

const ssl =
    process.env.MYSQL_SSL === "true"
        ? {
              rejectUnauthorized: true,
              ...(process.env.MYSQL_SSL_CA && fs.existsSync(path.resolve(process.cwd(), process.env.MYSQL_SSL_CA))
                  ? { ca: fs.readFileSync(path.resolve(process.cwd(), process.env.MYSQL_SSL_CA), "utf8") }
                  : {}),
          }
        : undefined;

const config = {
    host: process.env.MYSQLHOST || process.env.MYSQL_HOST || "localhost",
    port: Number(process.env.MYSQLPORT || process.env.MYSQL_PORT || 3306),
    user: dbUser,
    password: process.env.MYSQLPASSWORD || process.env.MYSQL_PASSWORD || "",
    database: process.env.MYSQLDATABASE || process.env.MYSQL_DATABASE || "booking_room",
    ssl,
};

async function tableExists(connection, tableName) {
    const [rows] = await connection.query(
        `
        SELECT COUNT(*) AS count
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
        `,
        [tableName],
    );

    return Number(rows[0].count) > 0;
}

async function indexExists(connection, tableName, indexName) {
    const [rows] = await connection.query(
        `
        SELECT COUNT(*) AS count
        FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND INDEX_NAME = ?
        `,
        [tableName, indexName],
    );

    return Number(rows[0].count) > 0;
}

async function addIndexIfMissing(connection, tableName, indexName, ddl) {
    if (!(await indexExists(connection, tableName, indexName))) {
        await connection.query(ddl);
    }
}

async function ensureBlogCategoriesTable(connection) {
    await connection.query(`
        CREATE TABLE IF NOT EXISTS blog_categories (
            category_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            name VARCHAR(255) NOT NULL,
            slug VARCHAR(255) NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (category_id),
            UNIQUE KEY uniq_blog_categories_name (name),
            UNIQUE KEY uniq_blog_categories_slug (slug)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
}

async function ensureBlogsTable(connection) {
    await connection.query(`
        CREATE TABLE IF NOT EXISTS blogs (
            blog_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            slug VARCHAR(255) NOT NULL,
            title VARCHAR(255) NOT NULL,
            category_id BIGINT UNSIGNED NULL,
            category_name VARCHAR(255) NOT NULL,
            read_time VARCHAR(64) NULL,
            location VARCHAR(255) NULL,
            excerpt TEXT NOT NULL,
            cover_image VARCHAR(1024) NULL,
            content_json JSON NOT NULL,
            status ENUM('draft', 'published') NOT NULL DEFAULT 'published',
            published_at DATETIME NULL,
            created_by_user_id BIGINT UNSIGNED NULL,
            updated_by_user_id BIGINT UNSIGNED NULL,
            deleted_at DATETIME NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (blog_id),
            UNIQUE KEY uniq_blogs_slug (slug),
            INDEX idx_blogs_status_published_deleted (status, published_at, deleted_at),
            INDEX idx_blogs_category_id (category_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
}

async function ensureWishlistsTable(connection) {
    await connection.query(`
        CREATE TABLE IF NOT EXISTS wishlists (
            wishlist_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            listing_id INT UNSIGNED NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (wishlist_id),
            UNIQUE KEY uniq_wishlists_user_listing (user_id, listing_id),
            INDEX idx_wishlists_user_created (user_id, created_at),
            INDEX idx_wishlists_listing (listing_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
}

function slugify(value) {
    const slug = String(value || "")
        .normalize("NFD")
        .replace(/\p{Diacritic}/gu, "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "")
        .slice(0, 255);

    return slug || `blog-${Date.now()}`;
}

function toPublicAssetPath(importPath) {
    return importPath
        .replace(/\\/g, "/")
        .replace(/^\.\.\/assets\//, "/src/assets/");
}

function loadFrontendBlogPosts() {
    const blogPostsPath = path.resolve(__dirname, "..", "..", "..", "frontend", "src", "data", "blogPosts.ts");

    if (!fs.existsSync(blogPostsPath)) {
        return [];
    }

    const rawSource = fs.readFileSync(blogPostsPath, "utf8");
    let source = rawSource.replace(
        /import\s+([A-Za-z_$][\w$]*)\s+from\s+"([^"]+)";/g,
        (_match, variableName, importPath) =>
            `const ${variableName} = ${JSON.stringify(toPublicAssetPath(importPath))};`,
    );

    source = source
        .replace(/export type BlogPost = \{[\s\S]*?\};\s*/m, "")
        .replace(/export const blogPosts:\s*BlogPost\[\]\s*=/, "const blogPosts =")
        .replace(/export const /g, "const ")
        .replace(/\((\w+):\s*string\)/g, "($1)")
        .replace(/const featuredBlogPost[\s\S]*$/m, "");

    const sandbox = {
        module: { exports: {} },
        exports: {},
    };

    vm.runInNewContext(`${source}\nmodule.exports = { blogPosts };`, sandbox, {
        timeout: 1000,
        filename: blogPostsPath,
    });

    return Array.isArray(sandbox.module.exports.blogPosts)
        ? sandbox.module.exports.blogPosts
        : [];
}

async function getOrCreateCategoryId(connection, categoryName) {
    const name = String(categoryName || "Cẩm nang").trim() || "Cẩm nang";
    const slug = slugify(name);

    await connection.query(
        `
        INSERT IGNORE INTO blog_categories (name, slug, created_at, updated_at)
        VALUES (?, ?, NOW(), NOW())
        `,
        [name, slug],
    );

    const [rows] = await connection.query(
        `
        SELECT category_id AS categoryId
        FROM blog_categories
        WHERE name = ? OR slug = ?
        ORDER BY category_id ASC
        LIMIT 1
        `,
        [name, slug],
    );

    return Number(rows[0]?.categoryId || 0) || null;
}

function toPublishedDate(value) {
    if (!value) {
        return null;
    }

    const dateText = String(value).slice(0, 10);
    return /^\d{4}-\d{2}-\d{2}$/.test(dateText) ? `${dateText} 00:00:00` : null;
}

async function seedBlogsFromFrontend(connection) {
    const posts = loadFrontendBlogPosts();

    for (const post of posts) {
        if (!post?.slug || !post?.title) {
            continue;
        }

        const categoryId = await getOrCreateCategoryId(connection, post.category);

        await connection.query(
            `
            INSERT INTO blogs (
                slug,
                title,
                category_id,
                category_name,
                read_time,
                location,
                excerpt,
                cover_image,
                content_json,
                status,
                published_at,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'published', ?, NOW(), NOW())
            ON DUPLICATE KEY UPDATE blog_id = blog_id
            `,
            [
                String(post.slug),
                String(post.title),
                categoryId,
                String(post.category || "Cẩm nang"),
                post.readTime ? String(post.readTime) : null,
                post.location ? String(post.location) : null,
                String(post.excerpt || ""),
                post.coverImage ? String(post.coverImage) : null,
                JSON.stringify(Array.isArray(post.content) ? post.content : []),
                toPublishedDate(post.publishedAt),
            ],
        );
    }
}

async function main() {
    const connection = await mysql.createConnection(config);

    try {
        await connection.beginTransaction();

        await ensureBlogCategoriesTable(connection);
        await ensureBlogsTable(connection);
        await ensureWishlistsTable(connection);

        await addIndexIfMissing(
            connection,
            "blogs",
            "idx_blogs_status_published_deleted",
            "CREATE INDEX idx_blogs_status_published_deleted ON blogs (status, published_at, deleted_at)",
        );
        await addIndexIfMissing(
            connection,
            "wishlists",
            "uniq_wishlists_user_listing",
            "CREATE UNIQUE INDEX uniq_wishlists_user_listing ON wishlists (user_id, listing_id)",
        );

        await seedBlogsFromFrontend(connection);
        await connection.commit();
        console.log("20260603_blogs_wishlist_schema migrated");
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        await connection.end();
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
