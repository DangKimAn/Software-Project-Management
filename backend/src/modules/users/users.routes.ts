import express from "express";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import { requireActiveUser } from "../../middlewares/require-active-user.middleware";
import { validate } from "../../middlewares/validate";
import {
    getMe,
    getUserById,
    listUsers,
    updateMe,
    updateMyAvatar,
    updateUserById,
    updateUserStatus,
} from "./users.controller";
import {
    adminUpdateUserBodySchema,
    listUsersQuerySchema,
    updateAvatarBodySchema,
    updateMeBodySchema,
    updateUserStatusBodySchema,
    userIdParamsSchema,
} from "./users.validator";

const router = express.Router();

router.use(authenticate, requireActiveUser);

router.get("/me", getMe);
router.patch("/me/avatar", validate({ body: updateAvatarBodySchema }), updateMyAvatar);
router.patch("/me", validate({ body: updateMeBodySchema }), updateMe);

router.get("/:userId", requireRole("admin"), validate({ params: userIdParamsSchema }), getUserById);
router.get("/", requireRole("admin"), validate({ query: listUsersQuerySchema }), listUsers);
router.patch(
    "/:userId",
    requireRole("admin"),
    validate({ params: userIdParamsSchema, body: adminUpdateUserBodySchema }),
    updateUserById,
);
router.patch(
    "/:userId/status",
    requireRole("admin"),
    validate({ params: userIdParamsSchema, body: updateUserStatusBodySchema }),
    updateUserStatus,
);

export default router;
