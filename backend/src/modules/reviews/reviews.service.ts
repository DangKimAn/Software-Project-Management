import { UniqueConstraintError } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import type { AuthenticatedUser } from "../auth/auth.service";
import Booking from "../../models/booking";
import { getNextSequence } from "../../models/counter";
import Listing from "../../models/listing";
import Review, { ReviewDocument } from "../../models/review";
import { sanitizeAndModerateText, sanitizeUserText } from "../../common/text-moderation";
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

/**
 * Giải thuật kiểm tra an toàn thuộc tính sở hữu trực tiếp trên đối tượng để phân biệt trường không gửi (`undefined`) với trường xóa trắng (`null`).
 */
const hasOwn = <T extends object>(value: T, key: keyof T) =>
    Object.prototype.hasOwnProperty.call(value, key);

/**
 * Giải thuật làm sạch chống XSS và kiểm duyệt nội dung bình luận đánh giá qua bộ lọc an toàn tín nhiệm (`sanitizeAndModerateText`),
 * cho phép chuỗi rỗng khi khách chỉ chấm điểm sao mà không viết nhận xét.
 */
const normalizeComment = (value?: string | null) =>
    sanitizeAndModerateText(value ?? "", {
        field: "comment",
        allowEmpty: true,
    });

/**
 * Giải thuật làm sạch và kiểm duyệt nội dung phản hồi của Chủ nhà, bắt buộc khác rỗng và tuân thủ chính sách nội dung an toàn.
 */
const normalizeReply = (value: string) =>
    sanitizeAndModerateText(value, {
        field: "reply",
    });

/**
 * Giải thuật trích xuất và làm sạch tên hiển thị công khai trên một dòng của người đánh giá, mặc định `"Guest"` nếu thiếu định danh.
 */
const getPublicReviewerName = (user: AuthenticatedUser) =>
    sanitizeUserText(user.name || user.username || "Guest", "singleLine") || "Guest";

/**
 * Giải thuật kiểm tra quyền sở hữu đánh giá: chỉ cho phép chính tác giả đánh giá (`reviewerUserId === user.id`) sửa hoặc xóa bản ghi (ném lỗi 403 nếu vi phạm).
 */
const assertReviewOwner = (review: ReviewDocument, user: AuthenticatedUser) => {
    if (String(review.reviewerUserId) !== user.id) {
        throw new ApiError(403, "Forbidden");
    }
};

/**
 * Giải thuật kiểm tra bất biến khả biến của đánh giá: chặn cập nhật/xóa lại với lỗi xung đột 409 nếu đánh giá đã bị xóa mềm (`deletedAt`) hoặc đã bị ẩn (`!isVisible`).
 */
const assertReviewEditable = (review: ReviewDocument) => {
    if (review.deletedAt || !review.isVisible) {
        throw new ApiError(409, "Review has been deleted");
    }
};

/**
 * Giải thuật khởi tạo đánh giá sau lưu trú trong giao dịch CSDL:
 * - Xác thực chính chủ khách đặt phòng (`booking.guestUserId === user.id`) và kiểm tra điều kiện tiên quyết đã hoàn tất lưu trú:
 *   trạng thái đơn bắt buộc là `"completed"`, `"checked_out"` hoặc đã ghi nhận mốc trả phòng thực tế `checkedOutAt` (ném lỗi 409 nếu chưa hoàn tất).
 * - Đảm bảo bất biến tối đa 1 đánh giá / 1 đơn đặt phòng bằng cả truy vấn kiểm tra trước lẫn bắt ngoại lệ `UniqueConstraintError` chống race condition.
 * - Lưu bản ghi ở trạng thái hiển thị (`isVisible = true`, `deletedAt = null`) làm dữ liệu nguồn để tính lại điểm trung bình cộng `ratingAvg` và tổng số lượt đánh giá `reviewCount`, đồng thời gửi thông báo cho Chủ nhà.
 */
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

        try {
            await review.save({ transaction });
        } catch (error) {
            if (error instanceof UniqueConstraintError) {
                throw new ApiError(409, "Booking has already been reviewed");
            }
            throw error;
        }
        await notifyReviewCreated(review.reviewId, transaction);

        return {
            reviewId: review.reviewId,
        };
    });

/**
 * Giải thuật cập nhật điểm số (`rating`) hoặc nhận xét (`comment`) của đánh giá:
 * Yêu cầu tối thiểu một trường thay đổi, xác thực quyền sở hữu và trạng thái chưa xóa mềm, kiểm duyệt lại văn bản nhận xét và lưu cập nhật để làm mới `ratingAvg` của chỗ nghỉ.
 */
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

/**
 * Giải thuật xóa mềm đánh giá của khách hàng:
 * Xác thực quyền sở hữu, hạ cờ `isVisible = false` và đánh dấu `deletedAt` để loại trừ tức thời bản ghi khỏi phép tính trung bình cộng `ratingAvg` và bộ đếm `reviewCount`.
 */
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

/**
 * Giải thuật ghi nhận phản hồi một lần của Chủ nhà (hoặc Admin) trên đánh giá của khách:
 * Đảm bảo đánh giá đang hiển thị, chưa có phản hồi trước đó (lỗi 409 nếu phản hồi lặp), xác thực quyền sở hữu chỗ nghỉ (`listing.hostId === user.id` hoặc `admin`) và kiểm duyệt văn bản phản hồi.
 */
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
