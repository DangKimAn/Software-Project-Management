import cors from "cors";
import cookieParser from "cookie-parser";
import "dotenv/config";
import express from "express";
import path from "path";

import { getCorsOptions } from "./config/cors";
import sequelize from "./config/database";
import { getEnv } from "./config/env";
import { logger } from "./config/logger";
import { errorHandler } from "./middlewares/error-handler.middleware";
import { notFound } from "./middlewares/notFound";
import { getGlobalRateLimiter } from "./middlewares/rate-limit.middleware";
import { requestId } from "./middlewares/requestId";
import { requestLogger } from "./middlewares/requestLogger";
import { sanitizeInput } from "./middlewares/sanitizeInput";
import { securityHeaders } from "./middlewares/securityHeaders";
import adminRoutes from "./modules/admin/admin.routes";
import amenitiesRoutes from "./modules/amenities/amenities.routes";
import authRoutes from "./modules/auth/auth.routes";
import banksRoutes from "./modules/banks/banks.routes";
import blogsRoutes from "./modules/blogs/blogs.routes";
import bookingsRoutes, { hostBookingsRoutes } from "./modules/bookings/bookings.routes";
import conversationsRoutes from "./modules/conversations/conversations.routes";
import couponsRoutes from "./modules/coupons/coupons.routes";
import hostApplicationRoutes from "./modules/host-applications/host-application.routes";
import hostBankAccountRoutes from "./modules/host-bank-account/host-bank-account.routes";
import hostListingsRoutes from "./modules/host-listings/host-listings.routes";
import notificationsRoutes from "./modules/notifications/notifications.routes";
import paymentsRoutes from "./modules/payments/payments.routes";
import hostPayoutsRoutes from "./modules/payouts/host-payouts.routes";
import publicListingsRoutes from "./modules/listings/listings.routes";
import reportsRoutes, { hostReportsRouter } from "./modules/reports/reports.routes";
import reviewsRoutes from "./modules/reviews/reviews.routes";
import userRoutes from "./modules/users/users.routes";
import wishlistRoutes from "./modules/wishlist/wishlist.routes";
import hostVerificationsRoutes from "./modules/verifications/host-verifications.routes";
import hostOnboardingRoutes from "./modules/host-onboarding/host-onboarding.routes";
import { sendSuccess } from "./common/http";
import semanticSearchRoutes, { aiListingSearchRouter } from "./modules/semantic-search/semantic-search.routes";
import uploadsRoutes from "./modules/uploads/uploads.routes";
import listingImageVisionRoutes, {
    adminImageVisionRoutes,
    hostImageVisionRoutes,
    hostListingImageVisionRoutes,
} from "./modules/ai/listing-image-vision.routes";
import { checkQdrantHealth, getQdrantCollectionName } from "./modules/semantic-search/qdrant-vector.service";

export const createApp = () => {
    const env = getEnv();
    const app = express();

    app.disable("x-powered-by");
    app.set("trust proxy", env.trustProxy);
    app.use(requestId);
    app.use(requestLogger);
    app.use(securityHeaders());
    app.use(cors(getCorsOptions()));
    app.use(getGlobalRateLimiter());
    app.use(express.json({ limit: env.requestBodyLimit }));
    app.use(express.urlencoded({ extended: true, limit: env.requestBodyLimit, parameterLimit: 100 }));
    app.use(cookieParser(env.cookieSecret));
    app.use(sanitizeInput);

    app.use(
        "/uploads",
        express.static(path.resolve(process.cwd(), "uploads"), {
            dotfiles: "deny",
            index: false,
            maxAge: env.nodeEnv === "production" ? "7d" : 0,
        }),
    );

    app.get("/api/test", (_req, res) => {
        sendSuccess(res, {
            message: "Booking backend ready",
        });
    });

    app.get("/api/health", async (req, res, next) => {
        try {
            await sequelize.authenticate();
            const qdrantStatus = await checkQdrantHealth();

            return sendSuccess(res, {
                message: "OK",
                data: {
                    status: "ok",
                    requestId: req.requestId,
                    uptime: process.uptime(),
                    time: new Date().toISOString(),
                    database: {
                        dialect: "mysql",
                        status: "up",
                    },
                    qdrant: {
                        status: qdrantStatus,
                        collection: getQdrantCollectionName(),
                    },
                },
            });
        } catch (error) {
            logger.error("Health check failed", error, { requestId: req.requestId });
            return next(error);
        }
    });

    app.get("/api/health/db", async (_req, res, next) => {
        try {
            await sequelize.authenticate();
            return sendSuccess(res, {
                message: "Database connection healthy",
                data: {
                    dialect: "mysql",
                    status: "up",
                },
            });
        } catch (error) {
            return next(error);
        }
    });

    app.use("/api/auth", authRoutes);
    app.use("/api/banks", banksRoutes);
    app.use("/api/blogs", blogsRoutes);
    app.use("/api/users", userRoutes);
    app.use("/api/wishlist", wishlistRoutes);
    app.use("/api/bookings", bookingsRoutes);
    app.use("/api/host/bookings", hostBookingsRoutes);
    app.use("/api/conversations", conversationsRoutes);
    app.use("/api/notifications", notificationsRoutes);
    app.use("/api/host/applications", hostApplicationRoutes);
    app.use("/api/host/listings", hostListingsRoutes);
    app.use("/api/host/listings", hostListingImageVisionRoutes);
    app.use("/api/host/images", hostImageVisionRoutes);
    app.use("/api/host/verifications", hostVerificationsRoutes);
    app.use("/api/host", hostBankAccountRoutes);
    app.use("/api/host", hostOnboardingRoutes);
    app.use("/api/host", hostPayoutsRoutes);
    app.use("/api/ai/listings/search", aiListingSearchRouter);
    app.use("/api/ai/listings", listingImageVisionRoutes);
    app.use("/api/admin/images", adminImageVisionRoutes);
    app.use("/api/admin", adminRoutes);
    app.use("/api/payments", paymentsRoutes);
    app.use("/api/coupons", couponsRoutes);
    app.use("/api/reviews", reviewsRoutes);
    app.use("/api/uploads", uploadsRoutes);
    app.use("/api/listings", publicListingsRoutes);
    app.use("/api/search", semanticSearchRoutes);
    app.use("/api/reports", reportsRoutes);
    app.use("/api/host/reports", hostReportsRouter);
    app.use("/api/amenities", amenitiesRoutes);

    app.use(notFound);
    app.use(errorHandler);

    return app;
};

const app = createApp();

export default app;
