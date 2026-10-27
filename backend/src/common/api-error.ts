export type AppErrorDetail = {
    path?: string;
    msg: string;
};

export type ApiErrorDetail = AppErrorDetail;

export class AppError extends Error {
    statusCode: number;
    errors?: AppErrorDetail[];
    expose: boolean;

    constructor(statusCode: number, message: string, errors?: AppErrorDetail[], expose = statusCode < 500) {
        super(message);
        this.name = "AppError";
        this.statusCode = statusCode;
        this.errors = errors;
        this.expose = expose;
    }
}

export class ApiError extends AppError {
    constructor(statusCode: number, message: string, errors?: ApiErrorDetail[]) {
        super(statusCode, message, errors);
        this.name = "ApiError";
    }
}
