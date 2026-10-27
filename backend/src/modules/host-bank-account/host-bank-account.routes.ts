import express from "express";

import { authenticate } from "../../middlewares/authenticate.middleware";
import { requireRole } from "../../middlewares/require-role.middleware";
import { getMyHostBankAccount, saveMyHostBankAccount } from "./host-bank-account.controller";

const router = express.Router();

const requireHostBankAccountAuth = [authenticate, requireRole("host")];

router.get("/bank-account", requireHostBankAccountAuth, getMyHostBankAccount);
router.put("/bank-account", requireHostBankAccountAuth, saveMyHostBankAccount);
router.post("/bank-account", requireHostBankAccountAuth, saveMyHostBankAccount);

export default router;
