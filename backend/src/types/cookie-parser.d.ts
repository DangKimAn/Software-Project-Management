/**
 * Khai báo kiểu TypeScript cho middleware cookie-parser trên Express.
 */
declare module "cookie-parser" {
    import type { RequestHandler } from "express";

    function cookieParser(secret?: string | string[], options?: Record<string, unknown>): RequestHandler;

    export = cookieParser;
}
