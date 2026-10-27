import express from "express";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import { validate } from "../../middlewares/validate";
import {
    createAdminBlogRequest,
    deleteAdminBlogRequest,
    getAdminBlogs,
    getPublicBlog,
    getPublicBlogs,
    updateAdminBlogRequest,
} from "./blogs.controller";
import {
    adminBlogListQuerySchema,
    blogIdParamSchema,
    blogListQuerySchema,
    blogSlugParamSchema,
    createBlogBodySchema,
    updateBlogBodySchema,
} from "./blogs.validator";

const router = express.Router();

router.get("/", validate({ query: blogListQuerySchema }), getPublicBlogs);
router.get("/:slug", validate({ params: blogSlugParamSchema }), getPublicBlog);

export const adminBlogsRoutes = express.Router();

adminBlogsRoutes.use(authenticate, requireRole("admin"));
adminBlogsRoutes.get("/", validate({ query: adminBlogListQuerySchema }), getAdminBlogs);
adminBlogsRoutes.post("/", validate({ body: createBlogBodySchema }), createAdminBlogRequest);
adminBlogsRoutes.patch(
    "/:blogId",
    validate({ params: blogIdParamSchema, body: updateBlogBodySchema }),
    updateAdminBlogRequest,
);
adminBlogsRoutes.delete("/:blogId", validate({ params: blogIdParamSchema }), deleteAdminBlogRequest);

export default router;
