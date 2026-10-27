require("dotenv/config");

const fs = require("node:fs");
const path = require("node:path");
const mysql = require("mysql2/promise");

const databaseName = process.env.MYSQL_DATABASE || process.env.MYSQLDATABASE || "booking_room";

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

const quoteId = (value) => `\`${String(value).replace(/`/g, "``")}\``;

const createConnection = () =>
    mysql.createConnection({
        host: process.env.MYSQLHOST || process.env.MYSQL_HOST || "127.0.0.1",
        port: Number(process.env.MYSQLPORT || process.env.MYSQL_PORT || 3306),
        user: dbUser,
        password: process.env.MYSQLPASSWORD || process.env.MYSQL_PASSWORD || "",
        database: databaseName,
        ssl,
        multipleStatements: false,
        decimalNumbers: true,
        charset: "utf8mb4",
    });

const tableExists = async (connection, tableName) => {
    const [rows] = await connection.execute(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name = ?
        `,
        [tableName],
    );

    return Number(rows[0].count) > 0;
};

const columnExists = async (connection, tableName, columnName) => {
    const [rows] = await connection.execute(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND column_name = ?
        `,
        [tableName, columnName],
    );

    return Number(rows[0].count) > 0;
};

const indexExists = async (connection, tableName, indexName) => {
    const [rows] = await connection.execute(
        `
        SELECT COUNT(*) AS count
        FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = ?
          AND index_name = ?
        `,
        [tableName, indexName],
    );

    return Number(rows[0].count) > 0;
};

const ensureColumn = async (connection, tableName, columnName, definition) => {
    if (!(await tableExists(connection, tableName))) {
        console.info(`Skipped ${tableName}.${columnName}: table missing`);
        return;
    }

    if (await columnExists(connection, tableName, columnName)) {
        return;
    }

    await connection.query(`ALTER TABLE ${quoteId(tableName)} ADD COLUMN ${definition}`);
    console.info(`Added column ${tableName}.${columnName}`);
};

const modifyColumnIfExists = async (connection, tableName, columnName, definition) => {
    if (!(await tableExists(connection, tableName)) || !(await columnExists(connection, tableName, columnName))) {
        return;
    }

    await connection.query(`ALTER TABLE ${quoteId(tableName)} MODIFY COLUMN ${definition}`);
    console.info(`Modified column ${tableName}.${columnName}`);
};

const ensureIndex = async (connection, tableName, indexName, definition) => {
    if (!(await tableExists(connection, tableName)) || (await indexExists(connection, tableName, indexName))) {
        return;
    }

    await connection.query(`CREATE ${definition}`);
    console.info(`Added index ${tableName}.${indexName}`);
};

const supportsJsonColumn = async (connection) => {
    const tempTable = `tmp_json_probe_${Date.now()}`;

    try {
        await connection.query(`CREATE TEMPORARY TABLE ${quoteId(tempTable)} (payload JSON NULL)`);
        await connection.query(`DROP TEMPORARY TABLE ${quoteId(tempTable)}`);
        return true;
    } catch {
        return false;
    }
};

const imageTagTaxonomies = [
    ["bedroom", "phòng ngủ", "room", ["bedroom", "phong ngu", "phòng ngủ", "giường ngủ"]],
    ["double_bed", "giường đôi", "object", ["double bed", "giuong doi", "giường đôi", "queen bed", "king bed"]],
    ["pool", "hồ bơi", "amenity", ["pool", "swimming pool", "ho boi", "hồ bơi", "bể bơi"]],
    ["garden", "sân vườn", "amenity", ["garden", "san vuon", "sân vườn", "vườn", "cây xanh"]],
    ["bbq", "BBQ", "amenity", ["bbq", "barbecue", "bếp nướng", "khu nướng", "lò nướng ngoài trời"]],
    ["kitchen", "bếp", "room", ["kitchen", "bep", "bếp", "nhà bếp", "khu bếp"]],
    ["living_room", "phòng khách", "room", ["living room", "phong khach", "phòng khách", "sảnh khách"]],
    ["toilet", "toilet", "room", ["toilet", "bathroom", "phòng tắm", "phòng vệ sinh", "nhà vệ sinh", "wc"]],
    ["bathtub", "bồn tắm", "object", ["bathtub", "bon tam", "bồn tắm", "tub"]],
    ["balcony", "ban công", "amenity", ["balcony", "ban cong", "ban công", "terrace"]],
    ["sea_view", "view biển", "view", ["sea view", "ocean view", "view bien", "view biển", "nhìn ra biển"]],
    ["karaoke", "karaoke", "amenity", ["karaoke", "phòng karaoke", "loa karaoke", "micro karaoke"]],
    ["billiards", "bàn bida", "amenity", ["billiards", "pool table", "ban bida", "bàn bida", "bida"]],
    ["front_view", "mặt tiền", "exterior", ["front view", "facade", "mat tien", "mặt tiền", "ngoại thất", "exterior"]],
    ["garage", "gara", "amenity", ["garage", "gara", "nhà xe", "chỗ đậu xe", "parking garage"]],
    ["air_conditioner", "máy lạnh", "amenity", ["air conditioner", "air conditioning", "may lanh", "máy lạnh", "điều hòa"]],
    ["sofa", "sofa", "object", ["sofa", "ghế sofa", "couch"]],
    ["dining_table", "bàn ăn", "object", ["dining table", "ban an", "bàn ăn", "khu ăn uống"]],
    ["modern", "hiện đại", "style", ["modern", "hien dai", "hiện đại", "contemporary"]],
    ["luxury", "sang trọng", "style", ["luxury", "sang trong", "sang trọng", "cao cấp"]],
    ["family_friendly", "phù hợp gia đình", "quality", ["family friendly", "phu hop gia dinh", "phù hợp gia đình", "gia đình"]],
    ["large_group_friendly", "phù hợp nhóm đông người", "quality", ["large group", "nhom dong nguoi", "nhóm đông người", "phù hợp nhóm đông người"]],
];

const ensureImageAnalysisTables = async (connection, jsonColumnType) => {
    await connection.query(`
        CREATE TABLE IF NOT EXISTS \`image_analysis_results\` (
            \`id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`image_id\` BIGINT UNSIGNED NOT NULL,
            \`provider\` VARCHAR(64) NULL,
            \`model\` VARCHAR(120) NULL,
            \`status\` ENUM('pending','analyzed','failed') NOT NULL DEFAULT 'pending',
            \`caption\` TEXT NULL,
            \`room_type\` VARCHAR(64) NULL,
            \`detected_objects\` ${jsonColumnType} NULL,
            \`amenities\` ${jsonColumnType} NULL,
            \`style_tags\` ${jsonColumnType} NULL,
            \`quality_tags\` ${jsonColumnType} NULL,
            \`raw_response\` ${jsonColumnType} NULL,
            \`confidence\` DECIMAL(5,4) NULL,
            \`error_message\` TEXT NULL,
            \`analyzed_at\` DATETIME NULL,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`id\`),
            INDEX \`idx_image_analysis_image_status\` (\`image_id\`, \`status\`),
            INDEX \`idx_image_analysis_image_analyzed\` (\`image_id\`, \`analyzed_at\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);

    await connection.query(`
        CREATE TABLE IF NOT EXISTS \`image_tags\` (
            \`id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`image_id\` BIGINT UNSIGNED NOT NULL,
            \`listing_id\` INT UNSIGNED NOT NULL,
            \`tag\` VARCHAR(80) NOT NULL,
            \`tag_group\` VARCHAR(50) NOT NULL,
            \`confidence\` DECIMAL(5,4) NULL,
            \`source\` ENUM('ai','host','admin') NOT NULL DEFAULT 'ai',
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (\`id\`),
            UNIQUE KEY \`uq_image_tags_image_tag\` (\`image_id\`, \`tag\`),
            INDEX \`idx_image_tags_image\` (\`image_id\`),
            INDEX \`idx_image_tags_listing_tag\` (\`listing_id\`, \`tag\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);

    await connection.query(`
        CREATE TABLE IF NOT EXISTS \`tag_taxonomies\` (
            \`id\` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            \`code\` VARCHAR(80) NOT NULL,
            \`label_vi\` VARCHAR(120) NOT NULL,
            \`group\` VARCHAR(50) NOT NULL,
            \`aliases\` ${jsonColumnType} NULL,
            \`is_searchable\` TINYINT(1) NOT NULL DEFAULT 1,
            \`created_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            \`updated_at\` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (\`id\`),
            UNIQUE KEY \`uq_tag_taxonomies_code\` (\`code\`),
            INDEX \`idx_tag_taxonomies_group\` (\`group\`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);

    await ensureIndex(
        connection,
        "image_analysis_results",
        "idx_image_analysis_image_status",
        "INDEX `idx_image_analysis_image_status` ON `image_analysis_results` (`image_id`, `status`)",
    );
    await ensureIndex(
        connection,
        "image_tags",
        "idx_image_tags_listing_tag",
        "INDEX `idx_image_tags_listing_tag` ON `image_tags` (`listing_id`, `tag`)",
    );

    await ensureColumn(
        connection,
        "image_analysis_results",
        "created_at",
        "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP",
    );
    await ensureColumn(
        connection,
        "image_analysis_results",
        "updated_at",
        "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`",
    );
    await modifyColumnIfExists(
        connection,
        "image_analysis_results",
        "created_at",
        "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP",
    );
    await modifyColumnIfExists(
        connection,
        "image_analysis_results",
        "updated_at",
        "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
    );

    await ensureColumn(
        connection,
        "image_tags",
        "created_at",
        "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP",
    );
    await modifyColumnIfExists(
        connection,
        "image_tags",
        "created_at",
        "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP",
    );

    for (const [code, labelVi, group, aliases] of imageTagTaxonomies) {
        await connection.execute(
            `
            INSERT INTO \`tag_taxonomies\` (\`code\`, \`label_vi\`, \`group\`, \`aliases\`, \`is_searchable\`, \`created_at\`, \`updated_at\`)
            VALUES (?, ?, ?, ?, 1, NOW(), NOW())
            ON DUPLICATE KEY UPDATE
                \`label_vi\` = VALUES(\`label_vi\`),
                \`group\` = VALUES(\`group\`),
                \`aliases\` = VALUES(\`aliases\`),
                \`is_searchable\` = VALUES(\`is_searchable\`),
                \`updated_at\` = NOW()
            `,
            [code, labelVi, group, JSON.stringify(aliases)],
        );
    }
};

const main = async () => {
    const connection = await createConnection();

    try {
        const jsonColumnType = (await supportsJsonColumn(connection)) ? "JSON" : "LONGTEXT";

        await modifyColumnIfExists(connection, "listing_images", "caption", "`caption` TEXT NULL");

        await ensureColumn(connection, "listing_images", "display_title", "`display_title` VARCHAR(120) NULL AFTER `caption`");
        await ensureColumn(connection, "listing_images", "alt_text", "`alt_text` VARCHAR(500) NULL AFTER `display_title`");
        await ensureColumn(connection, "listing_images", "ai_image_type", "`ai_image_type` VARCHAR(50) NULL AFTER `alt_text`");
        await ensureColumn(connection, "listing_images", "ai_scene_tags", `\`ai_scene_tags\` ${jsonColumnType} NULL AFTER \`ai_image_type\``);
        await ensureColumn(connection, "listing_images", "ai_amenity_tags", `\`ai_amenity_tags\` ${jsonColumnType} NULL AFTER \`ai_scene_tags\``);
        await ensureColumn(connection, "listing_images", "ai_description", "`ai_description` TEXT NULL AFTER `ai_amenity_tags`");
        await ensureColumn(connection, "listing_images", "ai_confidence", "`ai_confidence` DECIMAL(5,4) NULL AFTER `ai_description`");
        await ensureColumn(connection, "listing_images", "ai_quality_warnings", `\`ai_quality_warnings\` ${jsonColumnType} NULL AFTER \`ai_confidence\``);

        await ensureColumn(
            connection,
            "listing_images",
            "ai_analysis_status",
            "`ai_analysis_status` ENUM('pending','analyzed','failed') NOT NULL DEFAULT 'pending' AFTER `ai_quality_warnings`",
        );

        await ensureColumn(connection, "listing_images", "ai_error_message", "`ai_error_message` TEXT NULL AFTER `ai_analysis_status`");
        await ensureColumn(connection, "listing_images", "ai_analyzed_at", "`ai_analyzed_at` DATETIME NULL AFTER `ai_error_message`");
        await ensureColumn(connection, "listing_images", "created_at", "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP");
        await ensureColumn(connection, "listing_images", "updated_at", "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER `created_at`");
        await modifyColumnIfExists(connection, "listing_images", "created_at", "`created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP");
        await modifyColumnIfExists(connection, "listing_images", "updated_at", "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP");

        await ensureColumn(connection, "listings", "ai_image_tags", `\`ai_image_tags\` ${jsonColumnType} NULL`);
        await ensureColumn(connection, "listings", "ai_image_summary", "`ai_image_summary` TEXT NULL");
        await ensureImageAnalysisTables(connection, jsonColumnType);

        console.info("AI image labels schema completed");
    } finally {
        await connection.end();
    }
};

main().catch((error) => {
    console.error("AI image labels schema failed");
    console.error(error.message);
    process.exitCode = 1;
});
