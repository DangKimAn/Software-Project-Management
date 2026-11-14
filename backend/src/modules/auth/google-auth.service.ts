import { OAuth2Client } from "google-auth-library";

import { ApiError } from "../../common/api-error";
import { getEnv } from "../../config/env";
import SocialAccount from "../../models/social-account";
import User from "../../models/user";
import type { UserDocument } from "../../models/user";
import {
    assertUserCanAuthenticate,
    createSocialUser,
    issueAuthSession,
    normalizeEmail,
    toAuthResponseUser,
} from "./auth.service";

const googleIssuers = new Set(["accounts.google.com", "https://accounts.google.com"]);

export type VerifiedGoogleProfile = {
    sub: string;
    email: string;
    emailVerified: boolean;
    name: string;
    picture?: string | null;
};

type GoogleIdTokenVerifier = (idToken: string) => Promise<VerifiedGoogleProfile>;

type GoogleAuthContext = {
    ipAddress?: string | null;
    userAgent?: string | null;
};

/**
 * Giải thuật xác thực mật mã học Google ID Token (chuẩn OpenID Connect JWT):
 * - Dùng `OAuth2Client.verifyIdToken` kiểm tra chữ ký số RSA đối chiếu chứng chỉ JWK công khai của Google
 *   cùng hạn hiệu lực thời gian (`exp`, `iat`).
 * - Ràng buộc chặt đối tượng thụ hưởng `aud === googleClientId` (chống tấn công dùng lại ID Token
 *   cấp cho ứng dụng khác - confused deputy attack).
 * - Kiểm tra nguồn phát hành `iss` thuộc danh sách trắng của Google (`accounts.google.com` hoặc
 *   `https://accounts.google.com`) và bắt buộc `email_verified === true` để ngăn chặn chiếm đoạt
 *   tài khoản thông qua địa chỉ email chưa được xác minh chủ sở hữu.
 */
const defaultGoogleIdTokenVerifier: GoogleIdTokenVerifier = async (idToken) => {
    const clientId = getEnv().googleClientId;

    if (!clientId) {
        throw new ApiError(500, "Missing Google client id configuration");
    }

    const client = new OAuth2Client(clientId);

    try {
        const ticket = await client.verifyIdToken({
            idToken,
            audience: clientId,
        });
        const payload = ticket.getPayload();

        if (
            !payload ||
            typeof payload.sub !== "string" ||
            typeof payload.email !== "string" ||
            payload.email_verified !== true
        ) {
            throw new ApiError(401, "Invalid Google token");
        }

        if (payload.iss && !googleIssuers.has(payload.iss)) {
            throw new ApiError(401, "Invalid Google token");
        }

        return {
            sub: payload.sub,
            email: payload.email,
            emailVerified: true,
            name: payload.name?.trim() || payload.email,
            picture: payload.picture ?? null,
        };
    } catch (error) {
        if (error instanceof ApiError) {
            throw error;
        }

        throw new ApiError(401, "Invalid Google token");
    }
};

let googleIdTokenVerifier: GoogleIdTokenVerifier = defaultGoogleIdTokenVerifier;

/**
 * Thay thế hàm xác thực Google ID Token phục vụ kiểm thử tự động cô lập,
 * tự động khôi phục bộ xác thực OIDC mặc định khi không truyền đối số.
 */
export const setGoogleIdTokenVerifierForTests = (verifier?: GoogleIdTokenVerifier) => {
    googleIdTokenVerifier = verifier ?? defaultGoogleIdTokenVerifier;
};

/**
 * Giải thuật xác thực Google ID Token có chuẩn hóa ngoại lệ:
 * - Ủy quyền kiểm tra chữ ký số và claims cho `googleIdTokenVerifier` hiện hành,
 *   ánh xạ mọi ngoại lệ thư viện bên dưới về `ApiError(401)` đồng nhất để tránh rò rỉ chi tiết nội bộ.
 */
export const verifyGoogleIdToken = async (idToken: string) => {
    try {
        return await googleIdTokenVerifier(idToken);
    } catch (error) {
        if (error instanceof ApiError) {
            throw error;
        }

        throw new ApiError(401, "Invalid Google token");
    }
};

/**
 * Giải thuật đồng bộ thuộc tính hồ sơ đã xác minh từ Google sang tài khoản nội bộ:
 * - Chỉ nâng cấp cờ `isEmailVerified` khi Google xác nhận `emailVerified === true` và chỉ điền
 *   `avatarUrl` khi hồ sơ nội bộ chưa có ảnh đại diện, tránh ghi đè dữ liệu tùy chỉnh của người dùng
 *   và chỉ thực thi thao tác ghi DB khi có thay đổi thực tế.
 */
const applyVerifiedGoogleProfile = async (user: UserDocument, profile: VerifiedGoogleProfile) => {
    let shouldSave = false;

    if (profile.emailVerified && !user.isEmailVerified) {
        user.isEmailVerified = true;
        shouldSave = true;
    }

    if (!user.avatarUrl && profile.picture) {
        user.avatarUrl = profile.picture;
        shouldSave = true;
    }

    if (shouldSave) {
        await user.save();
    }
};

/**
 * Giải thuật xác thực OAuth Google và liên kết tài khoản xã hội an toàn:
 * 1. Xác thực chữ ký số, `aud`, `iss` và `email_verified` của `idToken` để thu nhận định danh bất biến `sub`.
 * 2. Ưu tiên tra cứu liên kết `SocialAccount` theo khóa `("google", sub)`; nếu bản ghi liên kết mồ côi
 *    (tài khoản `User` đã bị xóa) thì thu dọn bản ghi cũ trước khi xử lý tiếp.
 * 3. Nếu chưa có liên kết theo `sub`, đối chiếu người dùng nội bộ theo `email` chuẩn hóa đã xác minh:
 *    - Nếu tìm thấy tài khoản hiện hữu: kiểm tra quyền đăng nhập, chặn xung đột `409` nếu tài khoản đó
 *      đã liên kết với một `providerUid` Google khác (chống chiếm quyền/ghi đè liên kết trái phép),
 *      hoặc thiết lập liên kết `SocialAccount` mới một cách bất biến (Idempotent).
 *    - Nếu chưa tồn tại tài khoản: khởi tạo nguyên tử người dùng xã hội mới kèm liên kết `SocialAccount`.
 * 4. Khởi tạo phiên đăng nhập mới (`issueAuthSession`) gồm Access Token và Refresh Token lưu băm.
 */
export const authenticateWithGoogleIdToken = async (
    idToken: string,
    context: GoogleAuthContext = {},
) => {
    const profile = await verifyGoogleIdToken(idToken);
    const normalizedEmail = normalizeEmail(profile.email);

    if (!profile.emailVerified || !normalizedEmail) {
        throw new ApiError(401, "Invalid Google token");
    }

    let socialAccount = await SocialAccount.findOne({
        provider: "google",
        providerUid: profile.sub,
    });
    let user = socialAccount ? await User.findById(socialAccount.userId) : null;

    if (socialAccount && !user) {
        await SocialAccount.deleteOne({ id: socialAccount.id });
        socialAccount = null;
    }

    if (user) {
        assertUserCanAuthenticate(user);
        await applyVerifiedGoogleProfile(user, profile);
    }

    if (!user) {
        user = await User.findOne({ email: normalizedEmail });

        if (user) {
            assertUserCanAuthenticate(user);

            const existingGoogleLink = await SocialAccount.findOne({
                provider: "google",
                userId: user._id,
            });

            if (existingGoogleLink && existingGoogleLink.providerUid !== profile.sub) {
                throw new ApiError(409, "Google account is already linked to this user");
            }

            if (!existingGoogleLink) {
                socialAccount = await new SocialAccount({
                    userId: user._id,
                    provider: "google",
                    providerUid: profile.sub,
                }).save();
            } else {
                socialAccount = existingGoogleLink;
            }

            await applyVerifiedGoogleProfile(user, profile);
        } else {
            user = await createSocialUser({
                email: normalizedEmail,
                name: profile.name,
                role: "guest",
                emailVerified: true,
                avatarUrl: profile.picture,
            });

            socialAccount = await new SocialAccount({
                userId: user._id,
                provider: "google",
                providerUid: profile.sub,
            }).save();
        }
    }

    if (!socialAccount) {
        throw new ApiError(500, "Unable to complete Google login");
    }

    if (!user) {
        throw new ApiError(500, "Unable to complete Google login");
    }

    const { accessToken, refreshToken, roles } = await issueAuthSession(user, context);

    return {
        accessToken,
        refreshToken,
        user: await toAuthResponseUser(user, roles),
    };
};
