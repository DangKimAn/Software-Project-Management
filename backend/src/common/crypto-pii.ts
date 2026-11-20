/**
 * Tiện ích mật mã bảo vệ dữ liệu định danh tài chính nhạy cảm (PII Cryptography):
 * - Mã hóa/giải mã xác thực AES-256-GCM với khóa dẫn xuất HKDF-SHA256 và AAD gắn ngữ cảnh người sở hữu.
 * - Băm một chiều có khóa HMAC-SHA256 phục vụ đối chiếu trùng lặp và hàm che mặt nạ hiển thị an toàn.
 */
// CONFLICT-RESOLVED: Bổ sung ràng buộc ngữ cảnh chủ sở hữu (`ownerUserId`) vào AAD của AES-256-GCM để chặn đánh tráo bản mã chéo người dùng, đồng thời giữ tương thích ngược khi không truyền `ownerUserId`.
import { createCipheriv, createDecipheriv, createHmac, hkdfSync, randomBytes } from "node:crypto";

import { getEnv } from "../config/env";

const ENCRYPTION_VERSION_PREFIX = "v1:";
const AES_ALGORITHM = "aes-256-gcm";
const GCM_NONCE_BYTES = 12;
const GCM_AUTH_TAG_BYTES = 16;
const HKDF_SALT = Buffer.from("hotel-booking-pii-at-rest-salt-v1", "utf8");
const HKDF_INFO = Buffer.from("hotel-booking:payout-account:aes-256-gcm:v1", "utf8");

const buildBankAccountAad = (ownerUserId?: number | string | null): Buffer => {
    const normalizedOwner =
        ownerUserId !== undefined && ownerUserId !== null && String(ownerUserId).trim() !== ""
            ? `:user:${String(ownerUserId).trim()}`
            : "";
    return Buffer.from(`payout_account.account_number${normalizedOwner}`, "utf8");
};

/**
 * Giải thuật dẫn xuất khóa đối xứng AES-256 (HKDF-SHA256):
 * 1. Lấy khóa gốc ưu tiên từ biến môi trường độc lập PII_ENCRYPTION_KEY (nếu cấu hình >= 16 ký tự),
 *    hoặc fallback sang khóa bí mật phía máy chủ tokenHashSecret.
 * 2. Dẫn xuất khóa 256-bit (32 byte) tách biệt miền (domain-separated) bằng HKDF-SHA256 với salt và info cố định,
 *    đảm bảo khóa mã hóa AES không bao giờ dùng chung trực tiếp byte thô với HMAC token.
 */
const derivePiiAes256Key = (): Buffer => {
    const rawCustomKey = process.env.PII_ENCRYPTION_KEY?.trim();
    const masterSecret =
        rawCustomKey && rawCustomKey.length >= 16 ? rawCustomKey : getEnv().tokenHashSecret;

    return Buffer.from(hkdfSync("sha256", masterSecret, HKDF_SALT, HKDF_INFO, 32));
};

/**
 * Giải thuật mã hóa xác thực số tài khoản ngân hàng (AES-256-GCM - NIST FIPS 197):
 * 1. Chuẩn hóa chuỗi đầu vào và từ chối chuỗi rỗng.
 * 2. Sinh vector khởi tạo (IV / Nonce) ngẫu nhiên mật mã 96-bit (12 byte) qua CSPRNG cho mỗi lần mã hóa
 *    để tuyệt đối không tái sử dụng nonce trên cùng một khóa.
 * 3. Mã hóa bản rõ bằng AES-256-GCM kèm dữ liệu xác thực bổ sung (AAD) gắn ngữ cảnh trường dữ liệu và định danh người dùng.
 * 4. Đóng gói theo định dạng có phiên bản: "v1:<iv_b64url>.<tag_b64url>.<ciphertext_b64url>".
 */
export const encryptBankAccountNumber = (
    plainAccountNumber: string,
    ownerUserId?: number | string | null,
): string => {
    const normalized = String(plainAccountNumber ?? "").trim();
    if (!normalized) {
        throw new Error("Plain bank account number must not be empty");
    }

    const key = derivePiiAes256Key();
    const iv = randomBytes(GCM_NONCE_BYTES);

    try {
        const cipher = createCipheriv(AES_ALGORITHM, key, iv, {
            authTagLength: GCM_AUTH_TAG_BYTES,
        });
        cipher.setAAD(buildBankAccountAad(ownerUserId));

        const ciphertext = Buffer.concat([cipher.update(normalized, "utf8"), cipher.final()]);
        const authTag = cipher.getAuthTag();

        return `${ENCRYPTION_VERSION_PREFIX}${iv.toString("base64url")}.${authTag.toString("base64url")}.${ciphertext.toString("base64url")}`;
    } finally {
        key.fill(0);
    }
};

/**
 * Giải thuật giải mã và kiểm tra tính toàn vẹn số tài khoản (AES-256-GCM):
 * 1. Kiểm tra tiền tố phiên bản "v1:" và tách đúng 3 thành phần (IV, Auth Tag, Ciphertext).
 * 2. Kiểm tra kích thước chuẩn của IV (12 byte) và Auth Tag (16 byte).
 * 3. Nạp Auth Tag và AAD (kèm `ownerUserId` nếu có) vào bộ giải mã AES-256-GCM; nếu bản mã, tag hoặc chủ sở hữu sai lệch,
 *    decipher.final() sẽ lập tức ném lỗi xác thực để chặn giả mạo hoặc hoán đổi dữ liệu chéo tài khoản.
 */
export const decryptBankAccountNumber = (
    encryptedPayload: string,
    ownerUserId?: number | string | null,
): string => {
    const trimmed = String(encryptedPayload ?? "").trim();
    if (!trimmed.startsWith(ENCRYPTION_VERSION_PREFIX)) {
        throw new Error("Unsupported encrypted bank account payload format");
    }

    const segments = trimmed.slice(ENCRYPTION_VERSION_PREFIX.length).split(".");
    if (segments.length !== 3) {
        throw new Error("Malformed encrypted bank account payload");
    }

    const [ivB64, tagB64, cipherB64] = segments;
    const iv = Buffer.from(ivB64, "base64url");
    const authTag = Buffer.from(tagB64, "base64url");
    const ciphertext = Buffer.from(cipherB64, "base64url");

    if (iv.length !== GCM_NONCE_BYTES || authTag.length !== GCM_AUTH_TAG_BYTES || ciphertext.length === 0) {
        throw new Error("Invalid nonce, authentication tag, or ciphertext length");
    }

    const key = derivePiiAes256Key();
    try {
        const decipher = createDecipheriv(AES_ALGORITHM, key, iv, {
            authTagLength: GCM_AUTH_TAG_BYTES,
        });
        decipher.setAAD(buildBankAccountAad(ownerUserId));
        decipher.setAuthTag(authTag);

        const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
        return decrypted.toString("utf8");
    } finally {
        key.fill(0);
    }
};

/**
 * Giải thuật băm tra cứu trùng lặp số tài khoản một chiều (HMAC-SHA256):
 * Tạo mã băm tất định có khóa bí mật miền "payout-account" để đối chiếu trùng tài khoản
 * trong cơ sở dữ liệu mà không cần lưu hay truy vấn số tài khoản dạng rõ.
 */
export const hashBankAccountNumber = (plainAccountNumber: string): string =>
    createHmac("sha256", getEnv().tokenHashSecret)
        .update("payout-account:")
        .update(String(plainAccountNumber ?? "").trim())
        .digest("hex");

/**
 * Giải thuật che giấu (masking) số tài khoản ngân hàng khi lưu cột hiển thị và trả về qua API:
 * 1. Tách lấy tối đa 4 chữ số cuối cùng từ chuỗi đầu vào (kể cả khi đầu vào đã được che trước đó).
 * 2. Thay thế toàn bộ phần đầu bằng dấu '*' theo đúng độ dài gốc (tối thiểu 4 dấu '*' nếu chỉ biết last4),
 *    đảm bảo API không bao giờ tiết lộ đầy đủ số tài khoản ngân hàng của Chủ nhà.
 */
export const maskBankAccountNumber = (rawOrMasked: string, fallbackLast4?: string | null): string => {
    const trimmed = String(rawOrMasked ?? "").trim();
    const cleanLast4 = String(fallbackLast4 ?? "").replace(/\D/g, "").slice(-4);

    if (!trimmed) {
        return cleanLast4 ? `****${cleanLast4}` : "****";
    }

    if (/^\*+\d{1,4}$/.test(trimmed)) {
        return trimmed;
    }

    if (trimmed.length <= 4) {
        return "*".repeat(trimmed.length);
    }

    return `${"*".repeat(trimmed.length - 4)}${trimmed.slice(-4)}`;
};
