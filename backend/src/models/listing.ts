import {
    CreationOptional,
    DataTypes,
    FindOptions,
    InferAttributes,
    InferCreationAttributes,
    Model,
} from "sequelize";

import sequelize from "../config/database";
import {
    MySqlQuery,
    buildDocumentQuery,
    countDocumentsByFilter,
    findOneByFilter,
    isFindOptions,
    parseJsonValue,
    SimpleFilter,
    stringifyJsonValue,
} from "./mysql-helpers";

export const listingStatusValues = [
    "draft",
    "pending_approval",
    "active",
    "approved",
    "published",
    "inactive",
    "rejected",
    "suspended",
] as const;
export type ListingStatus = (typeof listingStatusValues)[number];

export const propertyTypeValues = ["apartment", "villa", "hotel", "homestay"] as const;
export type PropertyType = (typeof propertyTypeValues)[number];

export const roomTypeValues = ["entire_place", "private_room", "shared_room"] as const;
export type RoomType = (typeof roomTypeValues)[number];

export const cancellationPolicyValues = ["flexible", "moderate", "strict"] as const;
export type CancellationPolicy = (typeof cancellationPolicyValues)[number];

export type ListingImageRecord = {
    imageId: number;
    id?: number;
    listingImageId?: number;
    url: string;
    imageUrl?: string | null;
    image_url?: string | null;
    secureUrl?: string | null;
    publicUrl?: string | null;
    objectKey?: string | null;
    key?: string | null;
    originalFilename?: string | null;

    caption?: string | null;
    sortOrder: number;
    sort_order?: number;
    isCover?: boolean;
    is_cover?: boolean;
    displayTitle?: string | null;
    altText?: string | null;
    aiImageType?: string | null;
    aiSceneTags?: string[] | string | null;
    aiAmenityTags?: string[] | string | null;
    aiDescription?: string | null;
    aiConfidence?: number | string | null;
    aiQualityWarnings?: string[] | string | null;
    aiAnalysisStatus?: "pending" | "analyzed" | "failed";
    aiErrorMessage?: string | null;
    aiAnalyzedAt?: Date | null;
};

export type ListingAvailabilityDayRecord = {
    date: string;
    isAvailable: boolean;
    isBlockedByHost: boolean;
    priceOverride?: number | null;
    minNightsOverride?: number | null;
    notes?: string | null;
};

export type ListingRecord = {
    id: number;
    listingId: number;
    hostId: number;
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
    propertyType: PropertyType;
    roomType: RoomType;
    maxGuests: number;
    includedGuests: number | null;
    bedrooms: number;
    beds: number;
    bathrooms: number;
    basePrice: number;
    weekendPrice: number | null;
    cleaningFee: number | null;
    surchargeAmount: number | null;
    serviceFeePct: number | null;
    extraGuestFee: number | null;
    currency: string;
    minNights: number;
    maxNights: number | null;
    checkInFrom: string;
    checkOutBefore: string;
    cancellationPolicy: CancellationPolicy;
    instantBookEnabled: boolean;
    status: ListingStatus;
    rejectionReason: string | null;
    approvedBy: number | null;
    approvedAt: Date | null;
    amenityIds: number[];
    images: ListingImageRecord[];
    smokingAllowed: boolean;
    petsAllowed: boolean;
    partyAllowed: boolean;
    quietHours: string | null;
    availabilityCalendar: ListingAvailabilityDayRecord[];
    searchText: string | null;
    searchEmbeddingJson: number[] | null;
    searchEmbeddingUpdatedAt: Date | null;
    deletedAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
    aiImageTags: string[] | null;
    aiImageSummary: string | null;
};

class ListingModel extends Model<InferAttributes<ListingModel>, InferCreationAttributes<ListingModel>> {
    declare id: CreationOptional<number>;
    declare listingId: number;
    declare hostId: number;
    declare title: string;
    declare description: string;
    declare addressLine: string;
    declare ward: string;
    declare district: string;
    declare city: string;
    declare stateRegion: string | null;
    declare country: string;
    declare postalCode: string | null;
    declare latitude: number;
    declare longitude: number;
    declare propertyType: PropertyType;
    declare roomType: RoomType;
    declare maxGuests: number;
    declare includedGuests: CreationOptional<number | null>;
    declare bedrooms: number;
    declare beds: number;

    declare bathrooms: number;
    declare basePrice: number;
    declare weekendPrice: number | null;
    declare cleaningFee: number | null;
    declare surchargeAmount: CreationOptional<number | null>;
    declare serviceFeePct: number | null;
    declare extraGuestFee: CreationOptional<number | null>;
    declare currency: string;
    declare minNights: number;
    declare maxNights: number | null;
    declare checkInFrom: string;
    declare checkOutBefore: string;
    declare cancellationPolicy: CancellationPolicy;
    declare instantBookEnabled: boolean;
    declare status: ListingStatus;
    declare rejectionReason: string | null;
    declare approvedBy: number | null;
    declare approvedAt: Date | null;
    declare amenityIds: number[];
    declare images: ListingImageRecord[];
    declare smokingAllowed: boolean;
    declare petsAllowed: boolean;
    declare partyAllowed: boolean;
    declare quietHours: string | null;
    declare availabilityCalendar: ListingAvailabilityDayRecord[];
    declare searchText: string | null;
    declare aiImageTags: string[] | null;
    declare aiImageSummary: string | null;
    declare searchEmbeddingJson: number[] | null;
    declare searchEmbeddingUpdatedAt: Date | null;
    declare deletedAt: Date | null;
    declare createdAt: CreationOptional<Date>;
    declare updatedAt: CreationOptional<Date>;

}

ListingModel.init(
    {
        id: {
            type: DataTypes.INTEGER.UNSIGNED,
            autoIncrement: true,
            primaryKey: true,
        },
        listingId: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            unique: true,
            field: "listing_id",
        },
        hostId: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: false,
            field: "host_id",
        },
        title: {
            type: DataTypes.STRING(255),
            allowNull: false,
        },
        description: {
            type: DataTypes.TEXT,
            allowNull: false,
        },
        addressLine: {
            type: DataTypes.STRING(255),
            allowNull: false,
            field: "address_line",
        },
        ward: {
            type: DataTypes.STRING(255),
            allowNull: false,
        },
        district: {
            type: DataTypes.STRING(255),
            allowNull: false,
        },
        city: {
            type: DataTypes.STRING(255),
            allowNull: false,
        },
        stateRegion: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "state_region",
        },
        country: {
            type: DataTypes.STRING(8),
            allowNull: false,
            defaultValue: "VN",
        },
        postalCode: {
            type: DataTypes.STRING(32),
            allowNull: true,
            field: "postal_code",
        },
        latitude: {
            type: DataTypes.DOUBLE,
            allowNull: false,
        },
        longitude: {
            type: DataTypes.DOUBLE,
            allowNull: false,
        },
        propertyType: {
            type: DataTypes.ENUM(...propertyTypeValues),
            allowNull: false,
            field: "property_type",
        },
        roomType: {
            type: DataTypes.ENUM(...roomTypeValues),
            allowNull: false,
            field: "room_type",
        },
        maxGuests: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "max_guests",
        },
        includedGuests: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            field: "included_guests",
        },
        bedrooms: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
        },
        beds: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
        },
        bathrooms: {
            type: DataTypes.DECIMAL(4, 1),
            allowNull: false,
        },
        basePrice: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: false,
            field: "base_price",
        },
        weekendPrice: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: true,
            field: "weekend_price",
        },
        cleaningFee: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: true,
            field: "cleaning_fee",
        },
        surchargeAmount: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: true,
            defaultValue: 0,
            field: "surcharge_amount",
        },
        serviceFeePct: {
            type: DataTypes.DECIMAL(5, 2),
            allowNull: true,
            field: "service_fee_pct",
        },
        extraGuestFee: {
            type: DataTypes.DECIMAL(15, 2),
            allowNull: true,
            field: "extra_guest_fee",
        },
        currency: {
            type: DataTypes.STRING(8),
            allowNull: false,
            defaultValue: "VND",
        },
        minNights: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: false,
            field: "min_nights",
        },
        maxNights: {
            type: DataTypes.INTEGER.UNSIGNED,
            allowNull: true,
            field: "max_nights",
        },
        checkInFrom: {
            type: DataTypes.STRING(16),
            allowNull: false,
            field: "check_in_from",
        },
        checkOutBefore: {
            type: DataTypes.STRING(16),
            allowNull: false,
            field: "check_out_before",
        },
        cancellationPolicy: {
            type: DataTypes.ENUM(...cancellationPolicyValues),
            allowNull: false,
            field: "cancellation_policy",
        },
        instantBookEnabled: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "instant_book_enabled",
        },
        status: {
            type: DataTypes.ENUM(...listingStatusValues),
            allowNull: false,
            defaultValue: "draft",
        },
        rejectionReason: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "rejection_reason",
        },
        approvedBy: {
            type: DataTypes.BIGINT.UNSIGNED,
            allowNull: true,
            field: "approved_by",
        },
        approvedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "approved_at",
        },
        amenityIds: {
            type: DataTypes.TEXT("long"),
            allowNull: false,
            field: "amenity_ids",
            get() {
                return parseJsonValue<number[]>(this.getDataValue("amenityIds"), []);
            },
            set(value: number[]) {
                this.setDataValue("amenityIds", stringifyJsonValue(value ?? []) as never);
            },
        },
        images: {
            type: DataTypes.TEXT("long"),
            allowNull: false,
            get() {
                return parseJsonValue<ListingImageRecord[]>(this.getDataValue("images"), []);
            },
            set(value: ListingImageRecord[]) {
                this.setDataValue("images", stringifyJsonValue(value ?? []) as never);
            },
        },
        smokingAllowed: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "smoking_allowed",
        },
        petsAllowed: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "pets_allowed",
        },
        partyAllowed: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false,
            field: "party_allowed",
        },
        quietHours: {
            type: DataTypes.STRING(255),
            allowNull: true,
            field: "quiet_hours",
        },
        availabilityCalendar: {
            type: DataTypes.TEXT("long"),
            allowNull: false,
            field: "availability_calendar",
            get() {
                return parseJsonValue<ListingAvailabilityDayRecord[]>(
                    this.getDataValue("availabilityCalendar"),
                    [],
                );
            },
            set(value: ListingAvailabilityDayRecord[]) {
                this.setDataValue("availabilityCalendar", stringifyJsonValue(value ?? []) as never);
            },
        },
        searchText: {
            type: DataTypes.TEXT("long"),
            allowNull: true,
            field: "search_text",
        },
        aiImageTags: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "ai_image_tags",
        },
        aiImageSummary: {
            type: DataTypes.TEXT,
            allowNull: true,
            field: "ai_image_summary",
        },
        searchEmbeddingJson: {
            type: DataTypes.JSON,
            allowNull: true,
            field: "search_embedding_json",
        },
        searchEmbeddingUpdatedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "search_embedding_updated_at",
        },
        deletedAt: {
            type: DataTypes.DATE,
            allowNull: true,
            field: "deleted_at",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
    },
    {
        sequelize,
        tableName: "listings",
        underscored: true,
        timestamps: true,
        indexes: [
            {
                unique: true,
                fields: ["listing_id"],
            },
            {
                fields: ["host_id", "status", "deleted_at"],
            },
        ],
    },
);

export type ListingDocument = ListingModel;
type ListingWithHelpers = typeof ListingModel & {
    find(filter?: SimpleFilter<ListingRecord>): MySqlQuery<ListingModel>;
    findOne(options?: FindOptions | SimpleFilter<ListingRecord>): Promise<ListingModel | null>;
    countDocuments(filter?: SimpleFilter<ListingRecord>): Promise<number>;
};

const defaultListingFindOne = ListingModel.findOne.bind(ListingModel) as (
    options?: FindOptions,
) => Promise<ListingModel | null>;

const Listing = ListingModel as ListingWithHelpers;

Listing.find = (filter = {}) => buildDocumentQuery<ListingModel, ListingRecord>(ListingModel, filter);

Listing.findOne = (options?: FindOptions | SimpleFilter<ListingRecord>) => {
    if (!options || isFindOptions(options)) {
        return defaultListingFindOne(options);
    }

    return findOneByFilter<ListingModel, ListingRecord>({ findOne: defaultListingFindOne }, options);
};

Listing.countDocuments = (filter = {}) =>
    countDocumentsByFilter<ListingModel, ListingRecord>(ListingModel, filter);

export default Listing;
