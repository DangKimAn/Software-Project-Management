import type { RequestHandler } from "express";

import { asyncHandler } from "../../common/async-handler";
import { sendSuccess } from "../../common/http";
import {
    assertValidRequest,
    getValidatedBody,
    getValidatedParams,
    getValidatedQuery,
} from "../../common/validation";
import {
    addListingImages,
    AddListingImagesInput,
    bulkUpdateListingCalendar,
    BulkCalendarUpdateInput,
    createListing,
    CreateListingInput,
    deleteListing,
    deleteListingImage,
    getListingCalendar,
    GetCalendarQuery,
    getListingDetail,
    getMyListings,
    ListMineQuery,
    replaceListingAmenities,
    ReplaceAmenitiesInput,
    setListingImageCover,
    toHostActor,
    updateListing,
    UpdateListingInput,
    updateListingRules,
    UpdateRulesInput,
} from "./host-listings.service";

export const createHostListing: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const payload = getValidatedBody<CreateListingInput>(req);
    const result = await createListing(req.user!.id, payload, {
        isAdmin: req.user!.roles.includes("admin"),
    });

    return sendSuccess(res, {
        statusCode: 201,
        message: "Listing created",
        data: result,
    });
});

export const getMyHostListings: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const queryParams = getValidatedQuery<ListMineQuery>(req);
    const result = await getMyListings(toHostActor(req.user!), queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const getHostListingCalendar: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const queryParams = getValidatedQuery<GetCalendarQuery>(req);
    const result = await getListingCalendar(params.listingId, toHostActor(req.user!), queryParams);

    return sendSuccess(res, {
        data: result,
    });
});

export const bulkUpdateHostListingCalendar: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const payload = getValidatedBody<BulkCalendarUpdateInput>(req);
    const result = await bulkUpdateListingCalendar(params.listingId, toHostActor(req.user!), payload);

    return sendSuccess(res, {
        message: "Calendar updated",
        data: result,
    });
});

export const addHostListingImages: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const payload = getValidatedBody<AddListingImagesInput>(req);
    const result = await addListingImages(params.listingId, toHostActor(req.user!), payload);

    return sendSuccess(res, {
        message: "Images added",
        data: result,
    });
});

export const deleteHostListingImage: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number; imageId: number }>(req);
    await deleteListingImage(params.listingId, params.imageId, toHostActor(req.user!));

    return sendSuccess(res, {
        message: "Image deleted",
    });
});

export const setHostListingImageCover: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number; imageId: number }>(req);
    const result = await setListingImageCover(params.listingId, params.imageId, toHostActor(req.user!));

    return sendSuccess(res, {
        message: "Cover image updated",
        data: result,
    });
});

export const replaceHostListingAmenities: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const payload = getValidatedBody<ReplaceAmenitiesInput>(req);
    const result = await replaceListingAmenities(params.listingId, toHostActor(req.user!), payload);

    return sendSuccess(res, {
        message: "Amenities updated",
        data: result,
    });
});

export const updateHostListingRules: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const payload = getValidatedBody<UpdateRulesInput>(req);
    const result = await updateListingRules(params.listingId, toHostActor(req.user!), payload);

    return sendSuccess(res, {
        message: "Rules updated",
        data: result,
    });
});

export const getHostListingDetail: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const result = await getListingDetail(params.listingId, toHostActor(req.user!));

    return sendSuccess(res, {
        data: result,
    });
});

export const updateHostListing: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    const payload = getValidatedBody<UpdateListingInput>(req);
    const result = await updateListing(params.listingId, toHostActor(req.user!), payload);

    return sendSuccess(res, {
        message: "Listing updated",
        data: result,
    });
});

export const deleteHostListing: RequestHandler = asyncHandler(async (req, res) => {
    assertValidRequest(req);

    const params = getValidatedParams<{ listingId: number }>(req);
    await deleteListing(params.listingId, toHostActor(req.user!));

    return sendSuccess(res, {
        message: "Listing deleted",
    });
});
