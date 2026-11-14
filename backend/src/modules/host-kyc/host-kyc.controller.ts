// CONFLICT-RESOLVED: Hợp nhất tầng Controller của 3 module KYC (`host-applications`, `host-onboarding`, `verifications`)
// về một tệp điều phối duy nhất, gọi trực tiếp các mô-đun dịch vụ cụ thể để bảo toàn khả năng monkey-patch trong kiểm thử.
import type { RequestHandler } from "express";

import { ApiError } from "../../common/api-error";
import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    assertValidRequest,
    getValidatedBody,
    getValidatedParams,
    getValidatedQuery,
} from "../../common/validation";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import * as hostApplicationService from "./host-application.service";
import * as hostVerificationService from "./host-verification.service";

const adminStatusValues = new Set(["pending", "approved", "rejected", "all"]);

const getFieldFile = (
    files: Express.Request["files"],
    fieldName: string,
): Express.Multer.File | undefined => {
    if (!files || Array.isArray(files)) {
        return undefined;
    }

    return files[fieldName]?.[0];
};

const parsePositiveIntParam = (value: unknown, path: string) => {
    const parsed = Number(value);

    if (!Number.isInteger(parsed) || parsed < 1) {
        throw new ApiError(422, "Validation error", [
            {
                path,
                msg: `${path} must be a positive integer`,
            },
        ]);
    }

    return parsed;
};

const parseOptionalPositiveIntQuery = (value: unknown, path: string) => {
    if (value === undefined || value === null || value === "") {
        return undefined;
    }

    return parsePositiveIntParam(value, path);
};

/**
 * Giải thuật xác thực tải luồng ảnh CCCD/KYC cho Admin an toàn:
 * 1. Từ chối ngay lập tức (`401`) mọi request truyền `streamToken` trên URL query string để ngăn lộ token qua log/Referer.
 * 2. Bắt buộc xác thực phiên đăng nhập chuẩn (`Authorization: Bearer` hoặc cookie phiên) và kiểm tra quyền `admin` đang hoạt động.
 * 3. Nếu client gửi kèm header `X-Document-Stream-Token`, đối chiếu chữ ký HMAC, phạm vi tài liệu và đúng `adminUserId` đang đăng nhập.
 */
export const authenticateAdminHostDocumentStream: RequestHandler = (req, res, next) => {
    const queryStreamToken =
        typeof req.query.streamToken === "string" ? req.query.streamToken.trim() : "";

    if (queryStreamToken || req.query.streamToken !== undefined) {
        next(new ApiError(401, "Document stream token is not permitted in URL query parameters"));
        return;
    }

    authenticate(req, res, (authErr?: unknown) => {
        if (authErr) {
            next(authErr);
            return;
        }
        requireActiveUser(req, res, (activeErr?: unknown) => {
            if (activeErr) {
                next(activeErr);
                return;
            }
            requireRole("admin")(req, res, (roleErr?: unknown) => {
                if (roleErr) {
                    next(roleErr);
                    return;
                }

                try {
                    const headerToken = req.get("x-document-stream-token")?.trim() ?? "";
                    if (headerToken) {
                        const applicationId = parsePositiveIntParam(
                            req.params.applicationId,
                            "applicationId",
                        );
                        const documentId = parsePositiveIntParam(
                            req.params.documentId,
                            "documentId",
                        );
                        const verified = hostApplicationService.verifyHostDocStreamToken(
                            headerToken,
                            {
                                applicationId,
                                documentId,
                            },
                        );
                        if (String(verified.adminUserId) !== String(req.user!.id)) {
                            throw new ApiError(403, "Document stream token does not match current admin");
                        }
                    }
                    next();
                } catch (err) {
                    next(err);
                }
            });
        });
    });
};

export const submitHostApplicationController: RequestHandler = asyncHandler(async (req, res) => {
    const result = await hostApplicationService.submitHostApplication(req.user!, {
        contactName: typeof req.body.contactName === "string" ? req.body.contactName : null,
        contactEmail: typeof req.body.contactEmail === "string" ? req.body.contactEmail : null,
        phone: typeof req.body.phone === "string" ? req.body.phone : null,
        contactPhone: typeof req.body.contactPhone === "string" ? req.body.contactPhone : null,
        profileType: typeof req.body.profileType === "string" ? req.body.profileType : null,
        entityType: typeof req.body.entityType === "string" ? req.body.entityType : null,
        businessAddress: typeof req.body.businessAddress === "string" ? req.body.businessAddress : null,
        note: typeof req.body.note === "string" ? req.body.note : null,
        notes: typeof req.body.notes === "string" ? req.body.notes : null,
        documentType: typeof req.body.documentType === "string" ? req.body.documentType : null,
        files: {
            identityFront: getFieldFile(req.files, "identityFront"),
            identityBack: getFieldFile(req.files, "identityBack"),
            identitySingle: getFieldFile(req.files, "identitySingle"),
            businessLicense: getFieldFile(req.files, "businessLicense"),
        },
    });

    return sendSuccess(res, {
        statusCode: 201,
        message: "Da gui ho so chu nha. Vui long cho admin xet duyet.",
        data: {
            id: result.id,
            applicationId: result.applicationId,
            status: result.status,
            hostApplicationStatus: result.hostApplicationStatus,
        },
    });
});

export const getMyHostApplicationController: RequestHandler = asyncHandler(async (req, res) => {
    const result = await hostApplicationService.getMyHostApplication(req.user!);

    return sendSuccess(res, {
        data: result,
    });
});

export const cancelHostApplicationController: RequestHandler = asyncHandler(async (req, res) => {
    const result = await hostApplicationService.cancelHostApplication(req.user!);

    return sendSuccess(res, {
        statusCode: 200,
        message: result.message,
        data: result,
    });
});

export const getCurrentHostOnboardingController: RequestHandler = asyncHandler(async (req, res) => {
    const result = await hostApplicationService.getCurrentHostApplication(req.user!);

    return sendSuccess(res, {
        data: result,
    });
});

export const registerHostOnboardingController: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<hostApplicationService.RegisterHostInput>(req);
    const result = await hostApplicationService.registerHostApplication(req.user!, payload);

    return sendSuccess(res, {
        statusCode: result.created ? 201 : 200,
        message: result.created ? "Host application submitted" : "Host application updated",
        data: result,
    });
});

export const listAdminHostApplicationsController: RequestHandler = asyncHandler(async (req, res) => {
    const rawStatus = typeof req.query.status === "string" ? req.query.status : undefined;

    if (rawStatus && !adminStatusValues.has(rawStatus)) {
        throw new ApiError(422, "Validation error", [
            {
                path: "status",
                msg: "status must be pending, approved, rejected, or all",
            },
        ]);
    }

    const result = await hostApplicationService.listAdminHostApplications(req.user!, {
        status: rawStatus as "pending" | "approved" | "rejected" | "all" | undefined,
        page: parseOptionalPositiveIntQuery(req.query.page, "page"),
        limit: parseOptionalPositiveIntQuery(req.query.limit, "limit"),
    });

    return sendSuccess(res, {
        data: result,
    });
});

export const getAdminHostApplicationDetailController: RequestHandler = asyncHandler(async (req, res) => {
    const applicationId = parsePositiveIntParam(req.params.applicationId, "applicationId");
    const result = await hostApplicationService.getAdminHostApplicationDetail(req.user!, applicationId);

    return sendSuccess(res, {
        data: result,
    });
});

export const streamAdminHostDocumentController: RequestHandler = asyncHandler(async (req, res) => {
    const applicationId = parsePositiveIntParam(req.params.applicationId, "applicationId");
    const documentId = parsePositiveIntParam(req.params.documentId, "documentId");

    const { document, stream } = await hostApplicationService.getAdminHostDocumentStream(
        req.user!,
        applicationId,
        documentId,
    );

    res.setHeader("Content-Type", document.mimeType || "application/octet-stream");
    if (document.fileSize) {
        res.setHeader("Content-Length", String(document.fileSize));
    }
    res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, private");
    res.setHeader("Pragma", "no-cache");
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader("X-Frame-Options", "DENY");
    res.setHeader("Referrer-Policy", "no-referrer");
    res.setHeader("Cross-Origin-Resource-Policy", "same-origin");
    res.setHeader(
        "Content-Security-Policy",
        "default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'; frame-ancestors 'none'; sandbox",
    );

    const readable = stream as import("stream").Readable;
    readable.pipe(res);
});

export const approveHostApplicationController: RequestHandler = asyncHandler(async (req, res) => {
    const applicationId = parsePositiveIntParam(req.params.applicationId, "applicationId");
    await hostApplicationService.approveHostApplication(req.user!, applicationId, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    return sendSuccess(res, {
        message: "Da duyet ho so chu nha.",
    });
});

export const rejectHostApplicationController: RequestHandler = asyncHandler(async (req, res) => {
    const applicationId = parsePositiveIntParam(req.params.applicationId, "applicationId");
    await hostApplicationService.rejectHostApplication(
        req.user!,
        applicationId,
        {
            reason: typeof req.body.reason === "string" ? req.body.reason : null,
        },
        {
            ipAddress: req.ip,
            userAgent: req.get("user-agent") ?? null,
        },
    );

    return sendSuccess(res, {
        message: "Da tu choi ho so chu nha.",
    });
});

export const submitVerificationController: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<hostVerificationService.CreateVerificationInput>(req);
    const result = await hostVerificationService.submitHostVerification(req.user!, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Verification submitted",
        data: result,
    });
});

export const getMyVerificationsController: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<hostVerificationService.MyVerificationQuery>(req);
    const result = await hostVerificationService.getMyHostVerifications(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const listAdminVerificationsController: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<hostVerificationService.AdminVerificationQuery>(req);
    const result = await hostVerificationService.getAdminVerifications(req.user!, queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const approveVerificationController: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ verificationId: number }>(req);
    const payload = getValidatedBody<hostVerificationService.ApproveVerificationInput>(req);
    const result = await hostVerificationService.approveHostVerification(
        params.verificationId,
        req.user!,
        payload,
        {
            ipAddress: req.ip,
            userAgent: req.get("user-agent") ?? null,
        },
    );

    return sendSuccess(res, {
        message: "Verification approved",
        data: result,
    });
});

export const rejectVerificationController: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ verificationId: number }>(req);
    const payload = getValidatedBody<hostVerificationService.RejectVerificationInput>(req);
    const result = await hostVerificationService.rejectHostVerification(
        params.verificationId,
        req.user!,
        payload,
        {
            ipAddress: req.ip,
            userAgent: req.get("user-agent") ?? null,
        },
    );

    return sendSuccess(res, {
        message: "Verification rejected",
        data: result,
    });
});
