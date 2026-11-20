import { z } from "zod";

import { isValidLocationGroup } from "./vung-tau-location-groups";

/**
 * Giải thuật xác thực tham số đường dẫn `listingId`:
 * Ép kiểu sang số (`z.coerce.number()`) và ràng buộc số nguyên dương chặt (`> 0`) nhằm chặn sớm ID âm, số thập phân hoặc chuỗi không hợp lệ tại tầng biên HTTP.
 */
export const listingIdParamSchema = z.object({
    listingId: z.coerce.number().int().positive(),
});

/**
 * Giải thuật xác thực và chuẩn hóa lược đồ tham số truy vấn tìm kiếm chỗ nghỉ công khai bằng Zod:
 * - Cắt khoảng trắng thừa và giới hạn chiều dài từ khóa tìm kiếm (`1..255` ký tự).
 * - Ràng buộc miền giá trị tập đóng cho loại hình bất động sản, loại phòng, tiêu chí sắp xếp và kiểm tra phân khu Vũng Tàu qua `isValidLocationGroup`.
 * - Kẹp biên tọa độ địa lý WGS84 (`lat` thuộc [-90, 90], `lng` thuộc [-180, 180]), bán kính tìm kiếm bản đồ [1, 10000]m, mức giá không âm và giới hạn phân trang.
 */
export const publicListingsQuerySchema = z.object({
    q: z.string().trim().min(1).max(255).optional(),
    city: z.string().trim().min(1).optional(),
    district: z.string().trim().min(1).optional(),
    checkIn: z.string().optional(),
    checkOut: z.string().optional(),
    guests: z.coerce.number().int().positive().optional(),
    bedrooms: z.coerce.number().int().min(0).optional(),
    beds: z.coerce.number().int().min(0).optional(),
    bathrooms: z.coerce.number().int().min(0).optional(),
    pets: z.preprocess(
        (value) =>
            value === "true" || value === true
                ? true
                : value === "false" || value === false
                    ? false
                    : undefined,
        z.boolean().optional(),
    ),
    propertyType: z.enum(["apartment", "villa", "hotel", "homestay"]).optional(),
    roomType: z.enum(["entire_place", "private_room", "shared_room"]).optional(),
    priceMin: z.coerce.number().min(0).optional(),
    priceMax: z.coerce.number().min(0).optional(),
    minPrice: z.coerce.number().min(0).optional(),
    maxPrice: z.coerce.number().min(0).optional(),
    amenities: z.string().trim().min(1).optional(),
    locationGroup: z.string().trim().refine(isValidLocationGroup, "locationGroup is invalid").optional(),
    lat: z.coerce.number().min(-90).max(90).optional(),
    lng: z.coerce.number().min(-180).max(180).optional(),
    radius: z.coerce.number().min(1).max(10000).optional(),
    sort: z.enum(["price_asc", "price_desc", "rating_desc", "newest", "relevance"]).optional(),
    page: z.coerce.number().int().positive().optional(),
    limit: z.coerce.number().int().positive().max(100).optional(),
});
