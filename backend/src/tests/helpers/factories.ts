import { randomUUID } from "node:crypto";

import bcrypt from "bcryptjs";

import Listing, {
    ListingAvailabilityDayRecord,
    ListingImageRecord,
    ListingStatus,
} from "../../models/listing";
import Booking, { BookingStatus } from "../../models/booking";
import Review from "../../models/review";
import SocialAccount from "../../models/social-account";
import User, { UserDocument, UserRole, UserRecord } from "../../models/user";
import { getNextSequence } from "../../models/counter";

let uniqueUserCounter = 0;

type CreateUserInput = {
    email?: string;
    phone?: string;
    name?: string;
    password?: string;
    roles?: UserRole[];
    status?: UserRecord["status"];
};

type CreateListingInput = Partial<{
    listingId: number;
    status: ListingStatus;
    title: string;
    description: string;
    addressLine: string;
    ward: string;
    district: string;
    city: string;
    stateRegion: string | null;
    country: string;
    postalCode: string | null;
    latitude: number;
    longitude: number;
    propertyType: "apartment" | "villa" | "hotel" | "homestay";
    roomType: "entire_place" | "private_room" | "shared_room";
    maxGuests: number;
    includedGuests: number | null;
    bedrooms: number;
    beds: number;
    bathrooms: number;
    basePrice: number;
    weekendPrice: number | null;
    cleaningFee: number | null;
    serviceFeePct: number | null;
    extraGuestFee: number | null;
    currency: string;
    minNights: number;
    maxNights: number | null;
    checkInFrom: string;
    checkOutBefore: string;
    cancellationPolicy: "flexible" | "moderate" | "strict";
    instantBookEnabled: boolean;
    amenityIds: number[];
    images: ListingImageRecord[];
    smokingAllowed: boolean;
    petsAllowed: boolean;
    partyAllowed: boolean;
    quietHours: string | null;
    availabilityCalendar: ListingAvailabilityDayRecord[];
}>;

type CreateReviewInput = Partial<{
    reviewId: number;
    bookingId: number | null;
    reviewerUserId: string | null;
    reviewerName: string;
    rating: number;
    comment: string;
    hostReply: string | null;
    isVisible: boolean;
    deletedAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
}>;

type CreateBookingInput = Partial<{
    bookingId: number;
    listingId: number;
    guestUserId: number;
    hostUserId: number;
    checkInDate: string;
    checkOutDate: string;
    guestCount: number;
    nights: number | null;
    totalNights: number | null;
    status: BookingStatus;
    currency: string;
    couponId: number | null;
    subtotalAmount: number;
    cleaningFeeAmount: number;
    serviceFeeAmount: number;
    discountAmount: number;
    totalAmount: number;
    priceBreakdown: Record<string, unknown> | null;
    paidAt: Date | null;
}>;

export const createUser = async (input: CreateUserInput = {}) => {
    uniqueUserCounter += 1;
    const suffix = String(uniqueUserCounter).padStart(4, "0");
    const password = input.password ?? "secret123";
    const role = input.roles?.[0] ?? "guest";
    const user = new User({
        email: input.email ?? `user${suffix}@example.com`,
        phone: input.phone ?? `090000${suffix}`,
        username: `user${suffix}`,
        firstName: input.name ?? `User`,
        lastName: suffix,
        passwordHash: await bcrypt.hash(password, 10),
        role,
        status: input.status ?? "active",
    });

    await user.save();
    return user as UserDocument;
};

export const createSocialAccount = async (input: {
    userId: string;
    providerUid?: string;
}) => {
    const socialAccount = new SocialAccount({
        userId: input.userId,
        provider: "google",
        providerUid: input.providerUid ?? `google-sub-${randomUUID()}`,
    });

    await socialAccount.save();
    return socialAccount;
};

export const createListing = async (hostId: string, input: CreateListingInput = {}) => {
    const listing = new Listing({
        listingId: input.listingId ?? (await getNextSequence("listing", 101)),
        hostId,
        status: input.status ?? "draft",
        title: input.title ?? "Seaside villa",
        description: input.description ?? "A calm stay close to the beach",
        addressLine: input.addressLine ?? "123 Tran Phu",
        ward: input.ward ?? "Ward 1",
        district: input.district ?? "District 1",
        city: input.city ?? "Vung Tau",
        stateRegion: input.stateRegion ?? "Ba Ria - Vung Tau",
        country: input.country ?? "VN",
        postalCode: input.postalCode ?? "790000",
        latitude: input.latitude ?? 10.3456,
        longitude: input.longitude ?? 107.0842,
        propertyType: input.propertyType ?? "villa",
        roomType: input.roomType ?? "entire_place",
        maxGuests: input.maxGuests ?? 6,
        includedGuests: input.includedGuests ?? null,
        bedrooms: input.bedrooms ?? 3,
        beds: input.beds ?? 4,
        bathrooms: input.bathrooms ?? 2,
        basePrice: input.basePrice ?? 1500000,
        weekendPrice: input.weekendPrice ?? 1800000,
        cleaningFee: input.cleaningFee ?? 200000,
        serviceFeePct: input.serviceFeePct ?? 10,
        extraGuestFee: input.extraGuestFee ?? null,
        currency: input.currency ?? "VND",
        minNights: input.minNights ?? 2,
        maxNights: input.maxNights ?? 10,
        checkInFrom: input.checkInFrom ?? "14:00",
        checkOutBefore: input.checkOutBefore ?? "12:00",
        cancellationPolicy: input.cancellationPolicy ?? "moderate",
        instantBookEnabled: input.instantBookEnabled ?? false,
        amenityIds: input.amenityIds ?? [1, 2],
        images: input.images ?? [],
        smokingAllowed: input.smokingAllowed ?? false,
        petsAllowed: input.petsAllowed ?? false,
        partyAllowed: input.partyAllowed ?? false,
        quietHours: input.quietHours ?? null,
        availabilityCalendar: input.availabilityCalendar ?? [],
        deletedAt: null,
    });

    await listing.save();
    return listing;
};

export const createReview = async (listingId: number, input: CreateReviewInput = {}) => {
    const review = new Review({
        reviewId: input.reviewId ?? (await getNextSequence("review", 1)),
        bookingId: input.bookingId ?? null,
        listingId,
        reviewerUserId: input.reviewerUserId ?? null,
        reviewerName: input.reviewerName ?? "Guest Reviewer",
        rating: input.rating ?? 5,
        comment: input.comment ?? "Amazing stay",
        hostReply: input.hostReply ?? null,
        isVisible: input.isVisible ?? true,
        deletedAt: input.deletedAt ?? null,
        createdAt: input.createdAt,
        updatedAt: input.updatedAt,
    });

    await review.save();
    return review;
};

export const createBooking = async (input: CreateBookingInput) => {
    const booking = new Booking({
        bookingId: input.bookingId ?? (await getNextSequence("booking", 1)),
        listingId: input.listingId!,
        guestUserId: input.guestUserId ?? 1,
        hostUserId: input.hostUserId ?? 1,
        checkInDate: input.checkInDate ?? "2026-04-20",
        checkOutDate: input.checkOutDate ?? "2026-04-22",
        guestCount: input.guestCount ?? 2,
        nights: input.nights ?? null,
        totalNights: input.totalNights ?? input.nights ?? null,
        status: input.status ?? "confirmed",
        currency: input.currency ?? "VND",
        couponId: input.couponId ?? null,
        subtotalAmount: input.subtotalAmount ?? 3000000,
        cleaningFeeAmount: input.cleaningFeeAmount ?? 0,
        serviceFeeAmount: input.serviceFeeAmount ?? 0,
        discountAmount: input.discountAmount ?? 0,
        totalAmount: input.totalAmount ?? 3000000,
        priceBreakdown: input.priceBreakdown ?? null,
        paidAt: input.paidAt ?? null,
    });

    await booking.save();
    return booking;
};
