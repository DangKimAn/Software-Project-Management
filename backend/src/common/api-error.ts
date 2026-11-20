export type AppErrorDetail = {
    path?: string;
    msg: string;
};

export type ApiErrorDetail = AppErrorDetail;

/**
 * Lớp ngoại lệ chuẩn tầng ứng dụng kèm mã HTTP và cờ `expose` kiểm soát việc hiển thị thông điệp lỗi ra client.
 */
export class AppError extends Error {
    statusCode: number;
    errors?: AppErrorDetail[];
    details?: unknown;
    code?: string;
    expose: boolean;

    constructor(
        statusCode: number,
        message: string,
        errors?: AppErrorDetail[],
        expose = statusCode < 500,
        options?: { details?: unknown; code?: string },
    ) {
        super(message);
        this.name = "AppError";
        this.statusCode = statusCode;
        this.errors = errors;
        this.details = options?.details;
        this.code = options?.code;
        this.expose = expose;
    }
}

/**
 * Lớp ngoại lệ hợp đồng HTTP API dùng thống nhất trên các controller và service nghiệp vụ.
 */
export class ApiError extends AppError {
    constructor(
        statusCode: number,
        message: string,
        errors?: ApiErrorDetail[],
        options?: { details?: unknown; code?: string },
    ) {
        super(statusCode, message, errors, statusCode < 500, options);
        this.name = "ApiError";
    }
}
