import type { RequestHandler } from "express";

import { ApiError } from "../../common/api-error";
import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import User from "../../models/user";
import {
    assertUserCanAuthenticate,
    toAuthenticatedUser,
} from "../auth/auth.service";
import {
    approveHostApplication,
    cancelHostApplication,
    getAdminHostApplicationDetail,
    getAdminHostDocumentStream,
    getMyHostApplication,
    listAdminHostApplications,
    rejectHostApplication,
    submitHostApplication,
    verifyHostDocStreamToken,
} from "./host-application.service";

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

export const authenticateAdminHostDocumentStream: RequestHandler = (req, res, next) => {
    const rawStreamToken = typeof req.query.streamToken === "string" ? req.query.streamToken.trim() : "";

    if (rawStreamToken) {
        void (async () => {
            const applicationId = parsePositiveIntParam(req.params.applicationId, "applicationId");
            const documentId = parsePositiveIntParam(req.params.documentId, "documentId");
            const verified = verifyHostDocStreamToken(rawStreamToken, {
                applicationId,
                documentId,
            });
            const user = await User.findById(verified.adminUserId);
            if (!user) {
                throw new ApiError(401, "Unauthorized");
            }
            assertUserCanAuthenticate(user);
            const authUser = await toAuthenticatedUser(user);
            if (authUser.status !== "active" || !authUser.roles.includes("admin")) {
                throw new ApiError(403, "Forbidden");
            }
            req.user = authUser;
            next();
        })().catch(next);
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
            requireRole("admin")(req, res, next);
        });
    });
};

export const submitHostApplicationController: RequestHandler = asyncHandler(async (req, res) => {
    const result = await submitHostApplication(req.user!, {
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
    const result = await getMyHostApplication(req.user!);

    return sendSuccess(res, {
        data: result,
    });
});

export const cancelHostApplicationController: RequestHandler = asyncHandler(async (req, res) => {
    const result = await cancelHostApplication(req.user!);

    return sendSuccess(res, {
        statusCode: 200,
        message: result.message,
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

    const result = await listAdminHostApplications(req.user!, {
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
    const result = await getAdminHostApplicationDetail(req.user!, applicationId);

    return sendSuccess(res, {
        data: result,
    });
});

export const streamAdminHostDocumentController: RequestHandler = asyncHandler(async (req, res) => {
    const applicationId = parsePositiveIntParam(req.params.applicationId, "applicationId");
    const documentId = parsePositiveIntParam(req.params.documentId, "documentId");

    const { document, stream } = await getAdminHostDocumentStream(
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
    res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
    res.setHeader(
        "Content-Security-Policy",
        "default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'; sandbox",
    );

    const readable = stream as import("stream").Readable;
    readable.pipe(res);
});

export const approveHostApplicationController: RequestHandler = asyncHandler(async (req, res) => {
    const applicationId = parsePositiveIntParam(req.params.applicationId, "applicationId");
    await approveHostApplication(req.user!, applicationId, {
        ipAddress: req.ip,
        userAgent: req.get("user-agent") ?? null,
    });

    return sendSuccess(res, {
        message: "Da duyet ho so chu nha.",
    });
});

export const rejectHostApplicationController: RequestHandler = asyncHandler(async (req, res) => {
    const applicationId = parsePositiveIntParam(req.params.applicationId, "applicationId");
    await rejectHostApplication(
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
