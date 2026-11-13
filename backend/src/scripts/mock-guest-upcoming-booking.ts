import "dotenv/config";
import sequelize from "../config/database";
import {
    Booking,
    BookingDateLock,
    BookingGuest,
    BookingStatusHistory,
    Counter,
    Listing,
    NotificationLog,
    Payment,
    User,
} from "../models";
import { getNextSequence } from "../models/counter";
import { getMyBookings } from "../modules/bookings/bookings.service";

async function mockUpcomingBooking() {
    console.info("🚀 Starting mock upcoming booking for guest@gmail.com...");

    const guestUser = await User.findOne({ where: { email: "guest@gmail.com" } });
    if (!guestUser) {
        throw new Error("Guest user guest@gmail.com not found!");
    }
    console.info(`Found guest: ${guestUser.fullName} (ID: ${guestUser.userId})`);

    const listing = await Listing.findOne({ where: { listingId: 101 } });
    if (!listing) {
        throw new Error("Listing 101 not found!");
    }
    console.info(`Found listing: ${listing.title} (Host ID: ${listing.hostId})`);

    // Dates for upcoming trip: Nov 1, 2026 - Nov 3, 2026 (2 nights)
    const checkInDate = "2026-11-01";
    const checkOutDate = "2026-11-03";
    const guestCount = 4;
    const totalNights = 2;
    const weekdayNights = 1;
    const weekendNights = 1;

    // Pricing calculation
    const basePrice = Number(listing.basePrice); // 3,500,000
    const weekendPrice = Number(listing.weekendPrice ?? 4500000); // 4,500,000
    const cleaningFee = Number(listing.cleaningFee); // 300,000

    // Nov 1 (Sunday) = weekendPrice, Nov 2 (Monday) = basePrice
    const nightlyPrices = [
        { date: "2026-11-01", amount: weekendPrice, source: "weekendPrice" as const, isWeekend: true },
        { date: "2026-11-02", amount: basePrice, source: "basePrice" as const, isWeekend: false },
    ];
    const subtotalAmount = nightlyPrices.reduce((acc, curr) => acc + curr.amount, 0); // 8,000,000
    const totalAmount = subtotalAmount + cleaningFee; // 8,300,000

    const priceBreakdown = {
        totalNights,
        weekdayNights,
        weekendNights,
        nightlyPrice: basePrice,
        weekendPrice,
        nightlyPrices,
        subtotalAmount,
        subtotal: subtotalAmount,
        cleaningFeeAmount: cleaningFee,
        cleaningFee,
        surchargeAmount: 0,
        serviceFeeAmount: 0,
        serviceFee: 0,
        extraGuestFeeAmount: 0,
        extraGuestFee: 0,
        discountAmount: 0,
        discount: 0,
        totalAmount,
        couponId: null,
        couponCode: null,
        extraGuest: {
            includedGuests: listing.maxGuests,
            extraGuests: 0,
            feePerGuestPerNight: 0,
        },
    };

    // Clean up existing locks or duplicate booking for these dates if previously ran
    const existingSameDatesBooking = await Booking.findOne({
        where: {
            guestUserId: guestUser.userId,
            listingId: listing.listingId,
            checkInDate,
            checkOutDate,
        },
    });

    let bookingId: number;

    if (existingSameDatesBooking) {
        bookingId = existingSameDatesBooking.bookingId;
        console.info(`Found existing booking #${bookingId} for the same dates, updating to confirmed...`);
        await existingSameDatesBooking.update({
            status: "confirmed",
            paidAt: new Date("2026-10-28T10:30:00.000Z"),
            lockedUntil: null,
            subtotalAmount,
            cleaningFeeAmount: cleaningFee,
            totalAmount,
            priceBreakdown,
            bookingNote: "Đoàn gia đình 4 người (2 người lớn, 2 trẻ em). Cần chuẩn bị bếp nướng BBQ ngoài trời vào tối 01/11.",
        });
    } else {
        bookingId = await getNextSequence("booking", 17);
        console.info(`Creating new booking #${bookingId}...`);

        await Booking.create({
            bookingId,
            listingId: listing.listingId,
            guestUserId: guestUser.userId,
            hostUserId: Number(listing.hostId),
            checkInDate,
            checkOutDate,
            guestCount,
            nights: totalNights,
            totalNights,
            status: "confirmed",
            version: 1,
            lockedUntil: null,
            currency: "VND",
            couponId: null,
            subtotalAmount,
            cleaningFeeAmount: cleaningFee,
            serviceFeeAmount: 0,
            discountAmount: 0,
            totalAmount,
            priceBreakdown,
            bookingNote: "Đoàn gia đình 4 người (2 người lớn, 2 trẻ em). Cần chuẩn bị bếp nướng BBQ ngoài trời vào tối 01/11.",
            paidAt: new Date("2026-10-28T10:30:00.000Z"),
            createdAt: new Date("2026-10-28T10:15:00.000Z"),
            updatedAt: new Date("2026-10-28T10:30:00.000Z"),
        });
    }

    // Payment record
    const existingPayment = await Payment.findOne({ where: { bookingId } });
    if (!existingPayment) {
        const paymentId = await getNextSequence("payment", 895);
        await Payment.create({
            paymentId,
            bookingId,
            userId: guestUser.userId,
            amount: totalAmount,
            currency: "VND",
            method: "vnpay",
            status: "paid",
            provider: "vnpay",
            providerTxnRef: `VNPAY_${bookingId}_1730111400`,
            providerTransactionNo: `1460${bookingId}88`,
            providerResponseCode: "00",
            providerPayload: {
                vnp_ResponseCode: "00",
                vnp_TransactionStatus: "00",
                vnp_CardType: "ATM",
                vnp_BankCode: "NCB",
                vnp_Amount: `${totalAmount * 100}`,
                vnp_OrderInfo: `Thanh toan don dat phong #${bookingId} tai The Palm Villa`,
            },
            paidAt: new Date("2026-10-28T10:30:00.000Z"),
            failedAt: null,
            refundedAt: null,
            expiresAt: null,
            expiredAt: null,
            createdAt: new Date("2026-10-28T10:15:00.000Z"),
            updatedAt: new Date("2026-10-28T10:30:00.000Z"),
        });
        console.info(`Created payment record #${paymentId}`);
    }

    // Date locks
    for (const date of ["2026-11-01", "2026-11-02"]) {
        const [lock, created] = await BookingDateLock.findOrCreate({
            where: {
                listingId: listing.listingId,
                reservedDate: date,
            },
            defaults: {
                bookingId,
                listingId: listing.listingId,
                reservedDate: date,
                status: "held",
                releasedAt: null,
            },
        });
        if (!created && lock.bookingId !== bookingId) {
            await lock.update({ bookingId, status: "held", releasedAt: null });
        }
    }
    console.info("Updated booking date locks for 2026-11-01 and 2026-11-02");

    // Status history
    await BookingStatusHistory.findOrCreate({
        where: { bookingId, newStatus: "pending_payment" },
        defaults: {
            bookingId,
            oldStatus: null,
            newStatus: "pending_payment",
            changedByUserId: guestUser.userId,
            reason: "Khách hàng tạo đơn đặt phòng",
            metadataJson: { priceBreakdown },
        },
    });

    await BookingStatusHistory.findOrCreate({
        where: { bookingId, newStatus: "paid" },
        defaults: {
            bookingId,
            oldStatus: "pending_payment",
            newStatus: "paid",
            changedByUserId: null,
            reason: "Cổng VNPAY xác nhận thanh toán thành công",
            metadataJson: { method: "vnpay", amount: totalAmount },
        },
    });

    await BookingStatusHistory.findOrCreate({
        where: { bookingId, newStatus: "confirmed" },
        defaults: {
            bookingId,
            oldStatus: "paid",
            newStatus: "confirmed",
            changedByUserId: Number(listing.hostId),
            reason: "Chủ biệt thự đã xác nhận lịch lưu trú",
            metadataJson: { instantBook: true },
        },
    });
    console.info("Recorded booking status histories");

    // Booking guests
    const guests = [
        { fullName: "Lê Hoàng Long", email: "guest@gmail.com", phone: "0901000004", age: 31, documentType: "CCCD" },
        { fullName: "Trần Thị Mai", phone: "0901000005", age: 29, documentType: "CCCD" },
        { fullName: "Lê Hoàng Nam", age: 10, documentType: null },
        { fullName: "Lê Ngọc An", age: 6, documentType: null },
    ];
    for (const g of guests) {
        await BookingGuest.findOrCreate({
            where: { bookingId, fullName: g.fullName },
            defaults: {
                bookingId,
                fullName: g.fullName,
                email: g.email ?? null,
                phone: g.phone ?? null,
                age: g.age ?? null,
                documentType: g.documentType ?? null,
            },
        });
    }
    console.info("Registered 4 guests for the booking");

    // Notification Log
    await NotificationLog.findOrCreate({
        where: {
            targetType: "booking",
            targetId: String(bookingId),
            eventType: "BOOKING_CONFIRMED",
        },
        defaults: {
            eventType: "BOOKING_CONFIRMED",
            targetType: "booking",
            targetId: String(bookingId),
            recipient: guestUser.email,
            recipientUserId: guestUser.userId,
            title: "Đặt phòng đã được xác nhận!",
            body: `Chủ biệt thự The Palm Villa đã xác nhận kỳ nghỉ #${bookingId} của bạn tại ${listing.title} từ ngày 01/11/2026 đến 03/11/2026.`,
            actionUrl: `/trips/${bookingId}`,
            payload: { bookingId, listingId: listing.listingId },
            status: "sent",
            provider: "in_app",
            providerMessageId: null,
            errorMessage: null,
            sentAt: new Date(),
            readAt: null,
        },
    });
    console.info("Created confirmation notification");

    // Verify through service
    console.info("\n🔍 Verifying via getMyBookings service...");
    const myBookingsResult = await getMyBookings(
        {
            id: String(guestUser.userId),
            email: guestUser.email,
            roles: ["guest"],
        } as any,
        {}
    );

    const mockedTrip = myBookingsResult.items.find((b: any) => b.bookingId === bookingId);
    console.info("--------------------------------------------------");
    console.info("🎉 Mocked booking verified successfully:");
    console.info(`- Booking ID: #${mockedTrip?.bookingId}`);
    console.info(`- Villa: ${mockedTrip?.listingTitle}`);
    console.info(`- Check-in: ${mockedTrip?.checkInDate} (14:00)`);
    console.info(`- Check-out: ${mockedTrip?.checkOutDate} (12:00)`);
    console.info(`- Nights: ${mockedTrip?.totalNights}`);
    console.info(`- Guests: ${mockedTrip?.guestCount} khách`);
    console.info(`- Status: ${mockedTrip?.status} (Display: ${mockedTrip?.displayStatus?.label})`);
    console.info(`- Total: ${mockedTrip?.totalAmount?.toLocaleString("vi-VN")} VND (Đã thanh toán)`);
    console.info("--------------------------------------------------");

    await sequelize.close();
    process.exit(0);
}

mockUpcomingBooking().catch(async (error) => {
    console.error("❌ Failed to mock booking:", error);
    await sequelize.close();
    process.exit(1);
});
