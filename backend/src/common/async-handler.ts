import { NextFunction, Request, RequestHandler, Response } from "express";

type AsyncRequestHandler = (req: Request, res: Response, next: NextFunction) => Promise<unknown>;

/**
 * Giải thuật bọc hàm điều khiển bất đồng bộ (Async Middleware Wrapper):
 * - Bắt mọi Promise bị từ chối (`rejected`) và chuyển tiếp sang `next(error)` để `errorHandler` tập trung xử lý thay vì gây treo tiến trình.
 */
export const asyncHandler = (handler: AsyncRequestHandler): RequestHandler => {
    return (req, res, next) => {
        void Promise.resolve(handler(req, res, next)).catch(next);
    };
};
