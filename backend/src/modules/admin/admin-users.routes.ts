import express from "express";

import { updateAdminUserAvatar } from "../users/users.controller";
import { updateAvatarBodySchema, userIdParamsSchema } from "../users/users.validator";
import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import { validate } from "../../middlewares/validate";

const router = express.Router();

router.use(authenticate, requireRole("admin"));

router.patch(
    "/:userId/avatar",
    validate({ params: userIdParamsSchema, body: updateAvatarBodySchema }),
    updateAdminUserAvatar,
);

export default router;
