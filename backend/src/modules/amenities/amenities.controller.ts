import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    assertValidRequest,
    getValidatedBody,
    getValidatedParams,
} from "../../common/validation";
import {
    AmenityInput,
    createAmenity,
    deleteAmenity,
    listAdminAmenities,
    listPublicAmenities,
    updateAmenity,
} from "./amenities.service";

export const getPublicAmenities: RequestHandler = asyncHandler(async (_req, res) => {
    const result = await listPublicAmenities();

    return sendSuccess(res, {
        data: result,
    });
});

export const getAdminAmenities: RequestHandler = asyncHandler(async (_req, res) => {
    const result = await listAdminAmenities();

    return sendSuccess(res, {
        data: result,
    });
});

export const createAdminAmenity: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<AmenityInput>(req);
    const result = await createAmenity(req.user!, payload);

    return sendSuccess(res, {
        statusCode: 201,
        message: "Amenity created",
        data: result,
    });
});

export const updateAdminAmenity: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ amenityId: number }>(req);
    const payload = getValidatedBody<Partial<AmenityInput>>(req);
    const result = await updateAmenity(req.user!, params.amenityId, payload);

    return sendSuccess(res, {
        message: "Amenity updated",
        data: result,
    });
});

export const deleteAdminAmenity: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ amenityId: number }>(req);
    await deleteAmenity(req.user!, params.amenityId);

    return sendSuccess(res, {
        message: "Amenity deleted",
    });
});
