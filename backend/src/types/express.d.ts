import { AuthenticatedUser } from "../modules/auth/auth.service";

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
