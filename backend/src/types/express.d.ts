import { AuthenticatedUser } from "../modules/auth/auth.service";

/**
 * Mở rộng giao diện Express.Request với thông tin người dùng xác thực, requestId, cookie và dữ liệu đã kiểm chứng.
 */
declare global {
    namespace Express {
        interface Request {
            user?: AuthenticatedUser;
            requestId?: string;
            cookies?: Record<string, string>;
            signedCookies?: Record<string, string | false>;
            validatedData?: {
                body?: unknown;
                query?: unknown;
                params?: unknown;
            };
        }
    }
}

export {};
