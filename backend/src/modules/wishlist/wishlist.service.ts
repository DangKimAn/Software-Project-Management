import { Op } from "sequelize";

import { ApiError } from "../../common/api-error";
import { getCoverImage, serializeListingImage } from "../../common/listing-mappers";
import { getListingImagesMap } from "../../common/listing-relations";
import Listing, { type ListingDocument } from "../../models/listing";
import Wishlist, { type WishlistDocument } from "../../models/wishlist";
import type { AuthenticatedUser } from "../auth/auth.service";

const serializeListingSummary = async (listing: ListingDocument) => {
    const imageMap = await getListingImagesMap([listing]);
    const images = imageMap.get(listing.listingId) ?? [];
    const coverImage = getCoverImage(images);

    return {
        listingId: listing.listingId,
        title: listing.title,
        description: listing.description,
        basePrice: Number(listing.basePrice),
        addressLine: listing.addressLine,
        ward: listing.ward,
        district: listing.district,
        city: listing.city,
        propertyType: listing.propertyType,
        roomType: listing.roomType,
        maxGuests: listing.maxGuests,
        bedrooms: listing.bedrooms,
        beds: listing.beds,
        bathrooms: Number(listing.bathrooms),
        currency: listing.currency,
        imageUrl: coverImage?.url ?? null,
        coverImage: coverImage ? serializeListingImage(coverImage) : null,
        images: images.map(serializeListingImage),
    };
};

const serializeWishlistItem = async (wishlist: WishlistDocument, listing?: ListingDocument | null) => ({
    id: Number(wishlist.wishlistId),
    wishlistId: Number(wishlist.wishlistId),
    userId: Number(wishlist.userId),
    listingId: Number(wishlist.listingId),
    createdAt: wishlist.createdAt,
    listing: listing ? await serializeListingSummary(listing) : null,
});

const getActiveListingOrThrow = async (listingId: number) => {
    const listing = await Listing.findOne({
        where: {
            listingId,
            status: "active",
            deletedAt: {
                [Op.is]: null,
            },
        },
    });

    if (!listing) {
        throw new ApiError(404, "Listing not found");
    }

    return listing;
};

export const listMyWishlist = async (user: AuthenticatedUser) => {
    const userId = Number(user.id);
    const wishlists = await Wishlist.findAll({
        where: {
            userId,
        },
        order: [["createdAt", "DESC"], ["wishlistId", "DESC"]],
    });
    const listingIds = wishlists.map((item) => Number(item.listingId));
    const listings = listingIds.length
        ? await Listing.findAll({
              where: {
                  listingId: {
                      [Op.in]: listingIds,
                  },
                  status: "active",
                  deletedAt: {
                      [Op.is]: null,
                  },
              },
          })
        : [];
    const listingById = new Map(listings.map((listing) => [Number(listing.listingId), listing]));
    const validListingIds = new Set(listings.map((listing) => Number(listing.listingId)));
    const invalidListingIds = listingIds.filter((id) => !validListingIds.has(id));

    const validWishlists = wishlists.filter((wishlist) => validListingIds.has(Number(wishlist.listingId)));

    return {
        listingIds: Array.from(validListingIds),
        invalidListingIds,
        items: await Promise.all(
            validWishlists.map((wishlist) => serializeWishlistItem(wishlist, listingById.get(Number(wishlist.listingId)))),
        ),
    };
};

export const addListingToWishlist = async (user: AuthenticatedUser, listingId: number) => {
    const userId = Number(user.id);
    const listing = await getActiveListingOrThrow(listingId);
    const [wishlist] = await Wishlist.findOrCreate({
        where: {
            userId,
            listingId,
        },
        defaults: {
            userId,
            listingId,
        },
    });

    return serializeWishlistItem(wishlist, listing);
};

export const removeListingFromWishlist = async (user: AuthenticatedUser, listingId: number) => {
    const removedCount = await Wishlist.destroy({
        where: {
            userId: Number(user.id),
            listingId,
        },
    });

    return {
        listingId,
        removed: removedCount > 0,
    };
};
