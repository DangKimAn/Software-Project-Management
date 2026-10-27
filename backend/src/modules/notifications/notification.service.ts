import { Op, QueryTypes, UniqueConstraintError, type Transaction } from "sequelize";

import { ApiError } from "../../common/api-error";
import sequelize from "../../config/database";
import { logger } from "../../config/logger";
import Booking, { type BookingDocument } from "../../models/booking";
import HostPayoutBatch from "../../models/host-payout-batch";
import Listing, { type ListingDocument } from "../../models/listing";
import NotificationLog from "../../models/notification-log";
import Payment, { type PaymentDocument } from "../../models/payment";
import Refund from "../../models/refund";
import Review from "../../models/review";
import User, { type UserDocument } from "../../models/user";
import { sendMail } from "../../services/mail.service";
import { emitNotificationNew } from "../../socket/socket";
import type { AuthenticatedUser } from "../auth/auth.service";

export const notificationEventTypes = [
    "USER_REGISTERED",
    "HOST_APPLICATION_SUBMITTED",
    "LISTING_SUBMITTED",
    "LISTING_APPROVED",
    "LISTING_REJECTED",
    "BOOKING_CREATED",
    "PAYMENT_PENDING",
    "PAYMENT_SUCCESS",
    "PAYMENT_EXPIRED",
    "BOOKING_CONFIRMED",
    "BOOKING_CANCELLED",
    "REFUND_CREATED",
    "PAYOUT_CREATED",
    "REVIEW_CREATED",
] as const;

export type NotificationEventType = (typeof notificationEventTypes)[number];

type EmailContent = {
    to: string;
    subject: string;
    text: string;
    html?: string;
};

type NotificationRecipient = {
    userId: number;
    title: string;
    body: string;
    actionUrl?: string | null;
    payload?: Record<string, unknown> | null;
    email?: EmailContent | null;
};

type NotifyInput = {
    eventType: NotificationEventType;
    targetType: string;
    targetId: string | number;
    recipients: NotificationRecipient[];
    transaction?: Transaction;
};

export type ListNotificationsQuery = {
    page?: number;
    limit?: number;
    unreadOnly?: boolean;
};

const maxPageLimit = 50;

const toNumber = (value: unknown) => Number(value ?? 0);

const formatMoney = (value: unknown, currency = "VND") =>
    new Intl.NumberFormat("vi-VN", {
        style: "currency",
        currency,
        maximumFractionDigits: 0,
    }).format(toNumber(value));

const formatDate = (value: Date | string | null | undefined) =>
    value ? new Intl.DateTimeFormat("vi-VN").format(new Date(value)) : "";

const escapeHtml = (value: unknown) =>
    String(value ?? "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");

const buildEmailHtml = (title: string, lines: Array<string | null | undefined>) => `
    <div style="font-family:Arial,sans-serif;line-height:1.6;color:#111827">
      <h2>${escapeHtml(title)}</h2>
      ${lines.filter(Boolean).map((line) => `<p>${escapeHtml(line)}</p>`).join("")}
      <p>Minh Thành Villa</p>
    </div>
`;

const listingAddress = (listing: ListingDocument | null) =>
    [
        listing?.addressLine,
        listing?.ward,
        listing?.district,
        listing?.city,
    ]
        .filter(Boolean)
        .join(", ");

const runAfterCommit = (transaction: Transaction | undefined, callback: () => Promise<void>) => {
    if (transaction) {
        transaction.afterCommit(() => {
            void callback();
        });
        return;
    }

    void callback();
};

const serializeNotification = (notification: NotificationLog) => ({
    id: Number(notification.notificationLogId),
    notificationLogId: Number(notification.notificationLogId),
    eventType: notification.eventType,
    targetType: notification.targetType,
    targetId: notification.targetId,
    title: notification.title ?? null,
    body: notification.body ?? null,
    actionUrl: notification.actionUrl ?? null,
    payload: notification.payload ?? null,
    isRead: Boolean(notification.readAt),
    readAt: notification.readAt ?? null,
    createdAt: notification.createdAt,
    updatedAt: notification.updatedAt,
});

const serializeLookupError = (error: unknown) => {
    if (error instanceof Error) {
        return {
            name: error.name,
            message: error.message,
            stack: error.stack,
        };
    }

    return {
        message: String(error),
    };
};

const safeNotificationLookup = async <T>(
    label: string,
    metadata: Record<string, unknown>,
    lookup: () => Promise<T | null | undefined>,
): Promise<T | null> => {
    try {
        return (await lookup()) ?? null;
    } catch (error) {
        logger.warn("Notification context lookup failed", {
            label,
            ...metadata,
            error: serializeLookupError(error),
        });
        return null;
    }
};

const emitCreatedNotification = (userId: number, notification: NotificationLog) => {
    emitNotificationNew(userId, {
        id: Number(notification.notificationLogId),
        notificationLogId: Number(notification.notificationLogId),
        eventType: notification.eventType,
        targetType: notification.targetType,
        targetId: notification.targetId,
        title: notification.title ?? null,
        body: notification.body ?? null,
        actionUrl: notification.actionUrl ?? null,
        payload: notification.payload ?? null,
        readAt: notification.readAt ?? null,
        createdAt: notification.createdAt,
    });
};

const dispatchEmail = async (notification: NotificationLog, email: EmailContent) => {
    try {
        const result = await sendMail(email);

        await notification.update({
            status: "sent",
            sentAt: new Date(),
            providerMessageId:
                typeof result === "object" && result && "messageId" in result
                    ? String(result.messageId)
                    : null,
            errorMessage: null,
        });
    } catch (error) {
        await notification.update({
            status: "failed",
            errorMessage: error instanceof Error ? error.message : String(error),
        });

        logger.error("Failed to send notification email", error, {
            notificationLogId: notification.notificationLogId,
            eventType: notification.eventType,
            recipient: notification.recipient,
        });
    }
};

const createInAppNotificationOnce = async (
    input: Omit<NotifyInput, "recipients">,
    recipient: NotificationRecipient,
) => {
    try {
        const notification = await NotificationLog.create(
            {
                eventType: input.eventType,
                targetType: input.targetType,
                targetId: String(input.targetId),
                recipient: `user:${recipient.userId}`,
                recipientUserId: recipient.userId,
                title: recipient.title,
                body: recipient.body,
                actionUrl: recipient.actionUrl ?? null,
                payload: recipient.payload ?? null,
                status: "sent",
                provider: "in_app",
                providerMessageId: null,
                errorMessage: null,
                sentAt: new Date(),
                readAt: null,
            },
            { transaction: input.transaction },
        );

        runAfterCommit(input.transaction, async () => {
            emitCreatedNotification(recipient.userId, notification);
        });
    } catch (error) {
        if (error instanceof UniqueConstraintError) {
            return;
        }

        logger.error("Failed to create in-app notification", error, {
            eventType: input.eventType,
            targetType: input.targetType,
            targetId: input.targetId,
            recipientUserId: recipient.userId,
        });
    }
};

const createEmailNotificationOnce = async (
    input: Omit<NotifyInput, "recipients">,
    recipient: NotificationRecipient,
) => {
    if (!recipient.email?.to) {
        return;
    }

    try {
        const notification = await NotificationLog.create(
            {
                eventType: input.eventType,
                targetType: input.targetType,
                targetId: String(input.targetId),
                recipient: recipient.email.to,
                recipientUserId: null,
                title: recipient.email.subject,
                body: recipient.email.text,
                actionUrl: recipient.actionUrl ?? null,
                payload: recipient.payload ?? null,
                status: "pending",
                provider: "smtp",
                providerMessageId: null,
                errorMessage: null,
                sentAt: null,
                readAt: null,
            },
            { transaction: input.transaction },
        );

        runAfterCommit(input.transaction, () => dispatchEmail(notification, recipient.email!));
    } catch (error) {
        if (error instanceof UniqueConstraintError) {
            logger.info("Notification email already processed", {
                eventType: input.eventType,
                targetType: input.targetType,
                targetId: input.targetId,
                recipient: recipient.email.to,
            });
            return;
        }

        logger.error("Failed to create notification email log", error, {
            eventType: input.eventType,
            targetType: input.targetType,
            targetId: input.targetId,
            recipient: recipient.email.to,
        });
    }
};

export const notify = async (input: NotifyInput) => {
    const uniqueRecipients = new Map<number, NotificationRecipient>();

    for (const recipient of input.recipients) {
        if (!Number.isFinite(recipient.userId) || recipient.userId < 1) {
            continue;
        }

        uniqueRecipients.set(recipient.userId, recipient);
    }

    for (const recipient of uniqueRecipients.values()) {
        await createInAppNotificationOnce(input, recipient);
        await createEmailNotificationOnce(input, recipient);
    }
};

const getActiveUser = async (userId: number, transaction?: Transaction) => {
    if (!Number.isFinite(userId) || userId < 1) {
        return null;
    }

    return safeNotificationLookup<UserDocument>("user", { userId }, () =>
        User.findByPk(userId, {
            transaction,
        }) as Promise<UserDocument | null>,
    );
};

const getAdminRecipientIds = async (transaction?: Transaction) => {
    let rows: Array<{ userId: number }> = [];

    try {
        rows = await sequelize.query<{ userId: number }>(
            `
            SELECT DISTINCT u.user_id AS userId
            FROM users u
            INNER JOIN user_role ur ON ur.user_id = u.user_id
            INNER JOIN roles r ON r.role_id = ur.role_id
            WHERE r.code IN ('admin', 'moderator')
              AND u.status = 'active'
            `,
            {
                type: QueryTypes.SELECT,
                transaction,
            },
        );
    } catch (error) {
        logger.warn("Notification admin recipient lookup failed", {
            error: serializeLookupError(error),
        });
        return [];
    }

    return rows.map((row) => Number(row.userId)).filter((userId) => Number.isFinite(userId));
};

const getListingForNotification = async (listingId: number, transaction?: Transaction) => {
    if (!Number.isFinite(listingId) || listingId < 1) {
        return null;
    }

    return safeNotificationLookup<ListingDocument>("listing", { listingId }, () =>
        Listing.findOne({
            where: {
                listingId,
            },
            transaction,
        }) as Promise<ListingDocument | null>,
    );
};

const getBookingContext = async (bookingId: number, transaction?: Transaction) => {
    const booking = await safeNotificationLookup<BookingDocument>("booking", { bookingId }, () =>
        Booking.findOne({
            where: {
                bookingId,
            },
            transaction,
        }) as Promise<BookingDocument | null>,
    );

    if (!booking) {
        return null;
    }

    const [listing, guest, host, payment] = await Promise.all([
        getListingForNotification(Number(booking.listingId), transaction),
        getActiveUser(Number(booking.guestUserId), transaction),
        getActiveUser(Number(booking.hostUserId), transaction),
        safeNotificationLookup<PaymentDocument>("payment", { bookingId: booking.bookingId }, () =>
            Payment.findOne({
                where: {
                    bookingId: booking.bookingId,
                },
                order: [["createdAt", "DESC"]],
                transaction,
            }) as Promise<PaymentDocument | null>,
        ),
    ]);

    return {
        booking,
        listing,
        guest,
        host,
        payment,
    };
};

const buildBookingPayload = (
    booking: BookingDocument,
    listing: ListingDocument | null,
    extra: Record<string, unknown> = {},
) => ({
    bookingId: booking.bookingId,
    listingId: booking.listingId,
    listingTitle: listing?.title ?? null,
    checkInDate: booking.checkInDate,
    checkOutDate: booking.checkOutDate,
    status: booking.status,
    ...extra,
});

const bookingSummaryLines = (
    booking: BookingDocument,
    listing: ListingDocument | null,
    payment?: PaymentDocument | null,
) => [
    `Mã booking: ${booking.bookingId}`,
    `Chỗ nghỉ: ${listing?.title ?? ""}`,
    `Địa chỉ: ${listingAddress(listing)}`,
    `Nhận phòng: ${formatDate(booking.checkInDate)}`,
    `Trả phòng: ${formatDate(booking.checkOutDate)}`,
    `Số khách: ${booking.guestCount}`,
    `Tổng tiền: ${formatMoney(payment?.amount ?? booking.totalAmount, payment?.currency ?? booking.currency)}`,
];

const notifyBookingParticipants = async (params: {
    eventType: NotificationEventType;
    bookingId: number;
    guestTitle: string;
    guestBody: string;
    hostTitle: string;
    hostBody: string;
    guestEmail?: EmailContent | null;
    transaction?: Transaction;
    payload?: Record<string, unknown>;
}) => {
    const context = await getBookingContext(params.bookingId, params.transaction);

    if (!context) {
        return;
    }

    const payload = buildBookingPayload(context.booking, context.listing, params.payload);
    await notify({
        eventType: params.eventType,
        targetType: "booking",
        targetId: context.booking.bookingId,
        transaction: params.transaction,
        recipients: [
            {
                userId: Number(context.booking.guestUserId),
                title: params.guestTitle,
                body: params.guestBody,
                actionUrl: "/account/trips",
                payload,
                email: params.guestEmail ?? null,
            },
            {
                userId: Number(context.booking.hostUserId),
                title: params.hostTitle,
                body: params.hostBody,
                actionUrl: "/chu-nha/dat-phong",
                payload,
            },
        ],
    });
};

export const notifyUserRegistered = async (userId: number, transaction?: Transaction) => {
    const user = await getActiveUser(userId, transaction);

    if (!user) {
        return;
    }

    await notify({
        eventType: "USER_REGISTERED",
        targetType: "user",
        targetId: user.userId,
        transaction,
        recipients: [
            {
                userId: user.userId,
                title: "Chào mừng đến Minh Thành Villa",
                body: "Tài khoản của bạn đã được tạo thành công.",
                actionUrl: "/account/profile",
                payload: {
                    userId: user.userId,
                },
            },
        ],
    });
};

export const notifyHostApplicationSubmitted = async (
    applicationId: number,
    userId: number,
    transaction?: Transaction,
) => {
    const user = await getActiveUser(userId, transaction);
    const adminIds = await getAdminRecipientIds(transaction);

    if (adminIds.length === 0) {
        logger.warn("No admin recipients found for host application notification", {
            applicationId,
            userId,
        });
        return;
    }

    const userName = user?.fullName ?? `User #${userId}`;
    const userEmail = user?.email ?? "";
    const userPhone = user?.phone ?? "";

    await notify({
        eventType: "HOST_APPLICATION_SUBMITTED",
        targetType: "host_application",
        targetId: applicationId,
        transaction,
        recipients: adminIds.map((adminUserId) => ({
            userId: adminUserId,
            title: "Có hồ sơ host mới chờ duyệt",
            body: `${userName} (${userEmail || userPhone}) đã gửi hồ sơ đăng ký trở thành host.`,
            actionUrl: "/admin/ho-so-host",
            payload: {
                applicationId,
                userId,
                userName,
                userEmail,
            },
        })),
    });
};

export const notifyListingSubmitted = async (listingId: number, transaction?: Transaction) => {
    const listing = await getListingForNotification(listingId, transaction);

    if (!listing) {
        return;
    }

    const adminIds = await getAdminRecipientIds(transaction);
    const payload = {
        listingId: listing.listingId,
        title: listing.title,
        status: listing.status,
        hostId: listing.hostId,
    };

    await notify({
        eventType: "LISTING_SUBMITTED",
        targetType: "listing",
        targetId: listing.listingId,
        transaction,
        recipients: [
            {
                userId: Number(listing.hostId),
                title: "Tin đăng đã gửi kiểm duyệt",
                body: `${listing.title} đang chờ đội ngũ kiểm duyệt.`,
                actionUrl: "/chu-nha/cho-nghi",
                payload,
            },
            ...adminIds.map((userId) => ({
                userId,
                title: "Có listing mới chờ duyệt",
                body: `${listing.title} cần được kiểm duyệt.`,
                actionUrl: "/admin/kiem-duyet",
                payload,
            })),
        ],
    });
};

export const notifyListingApproved = async (listingId: number, transaction?: Transaction) => {
    const listing = await getListingForNotification(listingId, transaction);

    if (!listing) {
        return;
    }

    const host = await getActiveUser(Number(listing.hostId), transaction);
    const title = "Listing đã được duyệt";
    const body = `${listing.title} đã được duyệt và hiển thị trên hệ thống.`;
    const lines = [
        `Xin chào ${host?.fullName ?? ""},`,
        body,
        `Mã listing: ${listing.listingId}`,
        `Địa chỉ: ${listingAddress(listing)}`,
    ];

    await notify({
        eventType: "LISTING_APPROVED",
        targetType: "listing",
        targetId: listing.listingId,
        transaction,
        recipients: [
            {
                userId: Number(listing.hostId),
                title,
                body,
                actionUrl: "/chu-nha/cho-nghi",
                payload: {
                    listingId: listing.listingId,
                    status: listing.status,
                },
                email: host?.email
                    ? {
                          to: host.email,
                          subject: "Listing đã được duyệt - Minh Thành Villa",
                          text: lines.filter(Boolean).join("\n"),
                          html: buildEmailHtml(title, lines),
                      }
                    : null,
            },
        ],
    });
};

export const notifyListingRejected = async (listingId: number, transaction?: Transaction) => {
    const listing = await getListingForNotification(listingId, transaction);

    if (!listing) {
        return;
    }

    const host = await getActiveUser(Number(listing.hostId), transaction);
    const title = "Listing bị từ chối";
    const reason = listing.rejectionReason ? `Lý do: ${listing.rejectionReason}` : "Vui lòng kiểm tra lại nội dung listing.";
    const body = `${listing.title} chưa được duyệt. ${reason}`;
    const lines = [
        `Xin chào ${host?.fullName ?? ""},`,
        `${listing.title} chưa được duyệt.`,
        reason,
        `Mã listing: ${listing.listingId}`,
    ];

    await notify({
        eventType: "LISTING_REJECTED",
        targetType: "listing",
        targetId: listing.listingId,
        transaction,
        recipients: [
            {
                userId: Number(listing.hostId),
                title,
                body,
                actionUrl: "/chu-nha/cho-nghi",
                payload: {
                    listingId: listing.listingId,
                    status: listing.status,
                    rejectionReason: listing.rejectionReason ?? null,
                },
                email: host?.email
                    ? {
                          to: host.email,
                          subject: "Listing cần chỉnh sửa - Minh Thành Villa",
                          text: lines.filter(Boolean).join("\n"),
                          html: buildEmailHtml(title, lines),
                      }
                    : null,
            },
        ],
    });
};

export const notifyBookingCreated = async (bookingId: number, transaction?: Transaction) => {
    await notifyBookingParticipants({
        eventType: "BOOKING_CREATED",
        bookingId,
        guestTitle: "Booking đã được tạo",
        guestBody: "Vui lòng hoàn tất thanh toán để giữ chỗ.",
        hostTitle: "Có booking mới",
        hostBody: `Booking #${bookingId} đang chờ khách thanh toán.`,
        transaction,
    });
};

export const notifyPaymentPending = async (paymentId: number, transaction?: Transaction) => {
    const payment = await safeNotificationLookup<PaymentDocument>("payment", { paymentId }, () =>
        Payment.findOne({
            where: {
                paymentId,
            },
            transaction,
        }) as Promise<PaymentDocument | null>,
    );

    if (!payment) {
        return;
    }

    await notify({
        eventType: "PAYMENT_PENDING",
        targetType: "payment",
        targetId: payment.paymentId,
        transaction,
        recipients: [
            {
                userId: Number(payment.userId),
                title: "Thanh toán đang chờ xử lý",
                body: `Thanh toán #${payment.paymentId} cho booking #${payment.bookingId} đang chờ hoàn tất.`,
                actionUrl: `/thanh-toan/${payment.bookingId}`,
                payload: {
                    paymentId: payment.paymentId,
                    bookingId: payment.bookingId,
                    amount: toNumber(payment.amount),
                    currency: payment.currency,
                    status: payment.status,
                },
            },
        ],
    });
};

export const notifyPaymentSuccess = async (paymentId: number, transaction?: Transaction) => {
    const payment = await safeNotificationLookup<PaymentDocument>("payment", { paymentId }, () =>
        Payment.findOne({
            where: {
                paymentId,
            },
            transaction,
        }) as Promise<PaymentDocument | null>,
    );

    if (!payment || payment.status !== "paid") {
        return;
    }

    const context = await getBookingContext(payment.bookingId, transaction);

    if (!context) {
        return;
    }

    const title = "Thanh toán thành công";
    const guestBody = `Booking #${context.booking.bookingId} đã thanh toán thành công. Host sẽ xác nhận đặt phòng.`;
    const hostBody = `Booking #${context.booking.bookingId} đã thanh toán và đang chờ xác nhận.`;
    const lines = [
        `Xin chào ${context.guest?.fullName ?? ""},`,
        guestBody,
        ...bookingSummaryLines(context.booking, context.listing, payment),
        `Phương thức: ${payment.method}`,
        `Mã giao dịch: ${payment.providerTransactionNo ?? payment.providerTxnRef ?? payment.paymentId}`,
    ];

    await notify({
        eventType: "PAYMENT_SUCCESS",
        targetType: "payment",
        targetId: payment.paymentId,
        transaction,
        recipients: [
            {
                userId: Number(context.booking.guestUserId),
                title,
                body: guestBody,
                actionUrl: "/account/trips",
                payload: buildBookingPayload(context.booking, context.listing, {
                    paymentId: payment.paymentId,
                    paymentStatus: payment.status,
                }),
                email: context.guest?.email
                    ? {
                          to: context.guest.email,
                          subject: "Thanh toán thành công - Minh Thành Villa",
                          text: lines.filter(Boolean).join("\n"),
                          html: buildEmailHtml(title, lines),
                      }
                    : null,
            },
            {
                userId: Number(context.booking.hostUserId),
                title: "Booking đã thanh toán",
                body: hostBody,
                actionUrl: "/chu-nha/dat-phong",
                payload: buildBookingPayload(context.booking, context.listing, {
                    paymentId: payment.paymentId,
                    paymentStatus: payment.status,
                }),
            },
        ],
    });
};

export const notifyPaymentExpired = async (bookingId: number, transaction?: Transaction) => {
    const context = await getBookingContext(bookingId, transaction);

    if (!context) {
        return;
    }

    const title = "Phiên thanh toán đã hết hạn";
    const guestBody = `Booking #${context.booking.bookingId} đã hết hạn thanh toán.`;
    const lines = [
        `Xin chào ${context.guest?.fullName ?? ""},`,
        guestBody,
        `Chỗ nghỉ: ${context.listing?.title ?? ""}`,
        `Mã booking: ${context.booking.bookingId}`,
    ];

    await notifyBookingParticipants({
        eventType: "PAYMENT_EXPIRED",
        bookingId,
        guestTitle: title,
        guestBody,
        hostTitle: "Booking đã hết hạn thanh toán",
        hostBody: `Booking #${context.booking.bookingId} không được thanh toán đúng hạn.`,
        transaction,
        payload: {
            paymentStatus: context.payment?.status ?? null,
        },
        guestEmail: context.guest?.email
            ? {
                  to: context.guest.email,
                  subject: "Phiên thanh toán đã hết hạn - Minh Thành Villa",
                  text: lines.filter(Boolean).join("\n"),
                  html: buildEmailHtml(title, lines),
              }
            : null,
    });
};

export const notifyBookingConfirmed = async (bookingId: number, transaction?: Transaction) => {
    const context = await getBookingContext(bookingId, transaction);

    if (!context) {
        return;
    }

    const title = "Đặt phòng đã được xác nhận";
    const guestBody = `Host đã xác nhận booking #${context.booking.bookingId}.`;
    const lines = [
        `Xin chào ${context.guest?.fullName ?? ""},`,
        guestBody,
        ...bookingSummaryLines(context.booking, context.listing, context.payment),
    ];

    await notifyBookingParticipants({
        eventType: "BOOKING_CONFIRMED",
        bookingId,
        guestTitle: title,
        guestBody,
        hostTitle: "Bạn đã xác nhận booking",
        hostBody: `Booking #${context.booking.bookingId} đã được xác nhận.`,
        transaction,
        guestEmail: context.guest?.email
            ? {
                  to: context.guest.email,
                  subject: "Đặt phòng đã được xác nhận - Minh Thành Villa",
                  text: lines.filter(Boolean).join("\n"),
                  html: buildEmailHtml(title, lines),
              }
            : null,
    });
};

export const notifyBookingCancelled = async (bookingId: number, transaction?: Transaction) => {
    const context = await getBookingContext(bookingId, transaction);

    if (!context) {
        return;
    }

    await notifyBookingParticipants({
        eventType: "BOOKING_CANCELLED",
        bookingId,
        guestTitle: "Booking đã bị hủy",
        guestBody: `Booking #${context.booking.bookingId} đã bị hủy.`,
        hostTitle: "Booking đã bị hủy",
        hostBody: `Booking #${context.booking.bookingId} đã bị hủy.`,
        transaction,
        payload: {
            cancellationReason: context.booking.cancellationReason ?? null,
            cancelledAt: context.booking.cancelledAt ?? null,
        },
    });
};

export const notifyRefundCreated = async (refundId: number, transaction?: Transaction) => {
    const refund = await safeNotificationLookup("refund", { refundId }, () =>
        Refund.findByPk(refundId, {
            transaction,
        }),
    );

    if (!refund) {
        return;
    }

    const context = await getBookingContext(refund.bookingId, transaction);

    if (!context) {
        return;
    }

    const adminIds = (await getAdminRecipientIds(transaction)).filter(
        (userId) => userId !== Number(context.booking.guestUserId),
    );
    const title = "Yêu cầu hoàn tiền đã được tạo";
    const body = `Hoàn tiền ${formatMoney(refund.amount, refund.currency)} cho booking #${refund.bookingId} đang chờ xử lý.`;
    const payload = {
        refundId: refund.refundId,
        paymentId: refund.paymentId,
        bookingId: refund.bookingId,
        status: refund.status,
        amount: toNumber(refund.amount),
        currency: refund.currency,
    };
    const lines = [
        `Xin chào ${context.guest?.fullName ?? ""},`,
        body,
        `Mã refund: ${refund.refundId}`,
        `Lý do: ${refund.reason ?? "Không có"}`,
    ];

    await notify({
        eventType: "REFUND_CREATED",
        targetType: "refund",
        targetId: refund.refundId,
        transaction,
        recipients: [
            {
                userId: Number(context.booking.guestUserId),
                title,
                body,
                actionUrl: "/account/trips",
                payload,
                email: context.guest?.email
                    ? {
                          to: context.guest.email,
                          subject: "Cập nhật hoàn tiền - Minh Thành Villa",
                          text: lines.filter(Boolean).join("\n"),
                          html: buildEmailHtml(title, lines),
                      }
                    : null,
            },
            ...adminIds.map((userId) => ({
                userId,
                title: "Có refund mới cần xử lý",
                body,
                actionUrl: "/admin",
                payload,
            })),
        ],
    });
};

export const notifyPayoutCreated = async (payoutId: number, transaction?: Transaction) => {
    const payout = await HostPayoutBatch.findByPk(payoutId, {
        transaction,
    });

    if (!payout) {
        return;
    }

    const host = await getActiveUser(Number(payout.hostId), transaction);
    const title = "Payout đã được tạo";
    const body = `Payout #${payout.payoutId} trị giá ${formatMoney(payout.amount, payout.currency)} đang chờ xử lý.`;
    const lines = [
        `Xin chào ${host?.fullName ?? ""},`,
        body,
        `Trạng thái: ${payout.status}`,
    ];

    await notify({
        eventType: "PAYOUT_CREATED",
        targetType: "payout",
        targetId: payout.payoutId,
        transaction,
        recipients: [
            {
                userId: Number(payout.hostId),
                title,
                body,
                actionUrl: "/chu-nha/thanh-toan",
                payload: {
                    payoutId: payout.payoutId,
                    amount: toNumber(payout.amount),
                    currency: payout.currency,
                    status: payout.status,
                },
                email: host?.email
                    ? {
                          to: host.email,
                          subject: "Cập nhật payout - Minh Thành Villa",
                          text: lines.filter(Boolean).join("\n"),
                          html: buildEmailHtml(title, lines),
                      }
                    : null,
            },
        ],
    });
};

export const notifyReviewCreated = async (reviewId: number, transaction?: Transaction) => {
    const review = await Review.findOne({
        where: {
            reviewId,
        },
        transaction,
    });

    if (!review) {
        return;
    }

    const listing = await getListingForNotification(Number(review.listingId), transaction);

    if (!listing) {
        return;
    }

    await notify({
        eventType: "REVIEW_CREATED",
        targetType: "review",
        targetId: review.reviewId,
        transaction,
        recipients: [
            {
                userId: Number(listing.hostId),
                title: "Có đánh giá mới",
                body: `${review.reviewerName} đã đánh giá ${review.rating}/5 cho ${listing.title}.`,
                actionUrl: "/chu-nha/danh-gia",
                payload: {
                    reviewId: review.reviewId,
                    listingId: listing.listingId,
                    rating: review.rating,
                },
            },
        ],
    });
};

export const listMyNotifications = async (user: AuthenticatedUser, query: ListNotificationsQuery) => {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(maxPageLimit, Math.max(1, query.limit ?? 10));
    const where = {
        recipientUserId: Number(user.id),
        provider: "in_app",
        ...(query.unreadOnly ? { readAt: { [Op.is]: null } } : {}),
    };

    const [items, total, unreadCount] = await Promise.all([
        NotificationLog.findAll({
            where,
            order: [["createdAt", "DESC"], ["notificationLogId", "DESC"]],
            offset: (page - 1) * limit,
            limit,
        }),
        NotificationLog.count({ where }),
        NotificationLog.count({
            where: {
                recipientUserId: Number(user.id),
                provider: "in_app",
                readAt: {
                    [Op.is]: null,
                },
            },
        }),
    ]);

    return {
        items: items.map(serializeNotification),
        unreadCount,
        pagination: {
            page,
            limit,
            total,
            totalPages: Math.max(1, Math.ceil(total / limit)),
        },
    };
};

export const markNotificationRead = async (user: AuthenticatedUser, notificationLogId: number) => {
    const notification = await NotificationLog.findOne({
        where: {
            notificationLogId,
            recipientUserId: Number(user.id),
            provider: "in_app",
        },
    });

    if (!notification) {
        throw new ApiError(404, "Notification not found");
    }

    if (!notification.readAt) {
        notification.readAt = new Date();
        await notification.save();
    }

    return serializeNotification(notification);
};

export const markAllNotificationsRead = async (user: AuthenticatedUser) => {
    const readAt = new Date();
    const [updatedCount] = await NotificationLog.update(
        {
            readAt,
        },
        {
            where: {
                recipientUserId: Number(user.id),
                provider: "in_app",
                readAt: {
                    [Op.is]: null,
                },
            },
        },
    );

    return {
        updatedCount,
        readAt,
    };
};
