import express from "express";

import { getPublicAmenities } from "./amenities.controller";

const router = express.Router();

router.get("/", getPublicAmenities);

export default router;
