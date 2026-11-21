/**
 * Định tuyến HTTP công khai của phân hệ tiện ích (`/api/amenities`), phục vụ tra cứu danh sách tiện ích đang hoạt động.
 */

import express from "express";

import { getPublicAmenities } from "./amenities.controller";

const router = express.Router();

router.get("/", getPublicAmenities);

export default router;
