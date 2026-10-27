import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import type { AuthenticatedUser } from "../auth/auth.service";
import Booking from "../../models/booking";
import { getNextSequence } from "../../models/counter";
import Listing from "../../models/listing";
import Review, { ReviewDocument } from "../../models/review";
import { sanitizeAndModerateText, sanitizeUserText } from "../../services/trust-safety-service";
import { notifyReviewCreated } from "../notifications/notification.service";

export type CreateReviewInput = {
    bookingId: number;
    rating: number;
    comment?: string | null;
};

export type UpdateReviewInput = {
    rating?: number;
    comment?: string | null;
};

export type CreateReviewReplyInput = {
    reply: string;
};

const hasOwn = <T extends object>(value: T, key: keyof T) =>
    Object.prototype.hasOwnProperty.call(value, key);

const normalizeComment = (value?: string | null) =>
    sanitizeAndModerateText(value ?? "", {
        field: "comment",
        allowEmpty: true,
    });

const normalizeReply = (value: string) =>
    sanitizeAndModerateText(value, {
        field: "reply",
    });

const getPublicReviewerName = (user: AuthenticatedUser) =>
    sanitizeUserText(user.name || user.username || "Guest", "singleLine") || "Guest";

const assertReviewOwner = (review: ReviewDocument, user: AuthenticatedUser) => {
    if (String(review.reviewerUserId) !== user.id) {
        throw new ApiError(403, "Forbidden");
    }
};

const assertReviewEditable = (review: ReviewDocument) => {
    if (review.deletedAt || !review.isVisible) {
        throw new ApiError(409, "Review has been deleted");
    }
};

export const createReview = async (user: AuthenticatedUser, input: CreateReviewInput) =>
    sequelize.transaction(async (transaction) => {
        const booking = await Booking.findOne({
            where: {
                bookingId: input.bookingId,
            },
            transaction,
        });

        if (!booking) {
            throw new ApiError(404, "Booking not found");
        }

        if (String(booking.guestUserId) !== user.id) {
            throw new ApiError(403, "Forbidden");
        }

        const bookingStatus = String(booking.status);

        if (bookingStatus !== "completed" && bookingStatus !== "checked_out" && !booking.checkedOutAt) {
            throw new ApiError(409, "Booking must be completed before review");
        }

        const existingReview = await Review.findOne({
            where: {
                bookingId: booking.bookingId,
            },
            transaction,
        });

        if (existingReview) {
            throw new ApiError(409, "Booking has already been reviewed");
        }

        const listing = await Listing.findOne({
            where: {
                listingId: booking.listingId,
                deletedAt: null,
            },
            transaction,
        });

        if (!listing) {
            throw new ApiError(404, "Listing not found");
        }

        const review = new Review({
            reviewId: await getNextSequence("review", 1),
            bookingId: booking.bookingId,
            listingId: booking.listingId,
            reviewerUserId: Number(user.id),
            reviewerName: getPublicReviewerName(user),
            rating: input.rating,
            comment: normalizeComment(input.comment),
            hostReply: null,
            isVisible: true,
            deletedAt: null,
        });

        await review.save({ transaction });
        await notifyReviewCreated(review.reviewId, transaction);

        return {
            reviewId: review.reviewId,
        };
    });

export const updateReview = async (
    user: AuthenticatedUser,
    reviewId: number,
    input: UpdateReviewInput,
) => {
    if (!hasOwn(input, "rating") && !hasOwn(input, "comment")) {
        throw new ApiError(422, "Validation error", [
            {
                path: "body",
                msg: "At least one review field must be provided",
            },
        ]);
    }

    const review = await Review.findOne({ reviewId });

    if (!review) {
        throw new ApiError(404, "Review not found");
    }

    assertReviewOwner(review, user);
    assertReviewEditable(review);

    if (input.rating !== undefined) {
        review.rating = input.rating;
    }

    if (hasOwn(input, "comment")) {
        review.comment = normalizeComment(input.comment);
    }

    await review.save();

    return {
        reviewId: review.reviewId,
    };
};

export const deleteReview = async (user: AuthenticatedUser, reviewId: number) => {
    const review = await Review.findOne({ reviewId });

    if (!review) {
        throw new ApiError(404, "Review not found");
    }

    assertReviewOwner(review, user);
    assertReviewEditable(review);

    review.isVisible = false;
    review.deletedAt = new Date();
    await review.save();
};

export const createReviewReply = async (
    user: AuthenticatedUser,
    reviewId: number,
    input: CreateReviewReplyInput,
) => {
    const review = await Review.findOne({ reviewId });

    if (!review || review.deletedAt || !review.isVisible) {
        throw new ApiError(404, "Review not found");
    }

    if (review.hostReply?.trim()) {
        throw new ApiError(409, "Review already has a reply");
    }

    const listing = await Listing.findOne({
        listingId: review.listingId,
        deletedAt: null,
    });

    if (!listing) {
        throw new ApiError(404, "Listing not found");
    }

    if (!user.roles.includes("admin") && String(listing.hostId) !== user.id) {
        throw new ApiError(403, "Forbidden");
    }

    review.hostReply = normalizeReply(input.reply);
    await review.save();

    return {
        reviewId: review.reviewId,
    };
};
