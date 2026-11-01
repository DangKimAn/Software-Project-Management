import "dotenv/config";
import bcrypt from "bcryptjs";
import sequelize from "../config/database";
import {
    Amenity,
    Blog,
    BlogCategory,
    Coupon,
    HostProfile,
    Listing,
    ListingAmenity,
    ListingImage,
    Review,
    User,
    UserProfile,
    AvailabilityCalendar,
} from "../models";

const VILLA_GALLERIES: Record<
    number,
    Array<{ url: string; caption: string; isCover: boolean }>
> = {
    101: [
        {
            url: "assets/images/109tranphu.jpg",
            caption: "Mặt tiền biệt thự và hồ bơi ngoài trời",
            isCover: true,
        },
        {
            url: "assets/images/19tranphu.jpg",
            caption: "Phòng khách sang trọng hướng biển",
            isCover: false,
        },
        {
            url: "assets/images/87tranphu.jpg",
            caption: "Phòng ngủ Master view biển toàn cảnh",
            isCover: false,
        },
        {
            url: "assets/images/11tranphu.jpg",
            caption: "Khu vực bếp và bàn ăn ngoài trời",
            isCover: false,
        },
        {
            url: "assets/images/NDT05929-HDR1.jpg",
            caption: "Không gian nghỉ dưỡng toàn cảnh",
            isCover: false,
        },
    ],
    102: [
        {
            url: "assets/images/casamar.jpg",
            caption: "Mặt tiền biệt thự và hồ bơi ngoài trời",
            isCover: true,
        },
        {
            url: "assets/images/lacase.jpg",
            caption: "Phòng khách sang trọng hướng biển",
            isCover: false,
        },
        {
            url: "assets/images/diamond.jpg",
            caption: "Phòng ngủ Master view biển toàn cảnh",
            isCover: false,
        },
        {
            url: "assets/images/b25thuyduong.jpg",
            caption: "Khu vực bếp và bàn ăn ngoài trời",
            isCover: false,
        },
        {
            url: "assets/images/a3dtt.jpg",
            caption: "Khuôn viên sân vườn và hồ bơi",
            isCover: false,
        },
    ],
    103: [
        {
            url: "assets/images/22012aphanchutrinh.jpg",
            caption: "Mặt tiền biệt thự và hồ bơi ngoài trời",
            isCover: true,
        },
        {
            url: "assets/images/mocnhien.jpg",
            caption: "Phòng khách sang trọng hướng biển",
            isCover: false,
        },
        {
            url: "assets/images/b5dtt.jpg",
            caption: "Phòng ngủ Master view biển toàn cảnh",
            isCover: false,
        },
        {
            url: "assets/images/16022ahht.jpg",
            caption: "Khu vực bếp và bàn ăn ngoài trời",
            isCover: false,
        },
        {
            url: "assets/images/16hahuytap.jpg",
            caption: "Phòng tắm hiện đại và tiện nghi",
            isCover: false,
        },
    ],
    104: [
        {
            url: "assets/images/sunset.jpg",
            caption: "Không gian homestay view biển Hạ Long",
            isCover: true,
        },
        {
            url: "assets/images/nabi.JPG",
            caption: "Phòng khách thoáng đãng đón nắng",
            isCover: false,
        },
        {
            url: "assets/images/s07.jpg",
            caption: "Phòng ngủ ấm cúng hướng biển",
            isCover: false,
        },
        {
            url: "assets/images/osaka.jpg",
            caption: "Góc thư giãn và bếp tiện nghi",
            isCover: false,
        },
        {
            url: "assets/images/6nguyentuan.jpg",
            caption: "Ban công ngắm hoàng hôn",
            isCover: false,
        },
    ],
    105: [
        {
            url: "assets/images/343vothisau.jpg",
            caption: "Mặt tiền biệt thự sân vườn Bãi Trước",
            isCover: true,
        },
        {
            url: "assets/images/1phanhuychu.jpg",
            caption: "Phòng khách rộng rãi và sang trọng",
            isCover: false,
        },
        {
            url: "assets/images/c12tongocvan.jpg",
            caption: "Phòng ngủ Master thoáng mát",
            isCover: false,
        },
        {
            url: "assets/images/nasa.jpg",
            caption: "Khu vực BBQ sân vườn và hồ bơi",
            isCover: false,
        },
        {
            url: "assets/images/NDT05929-HDR1.jpg",
            caption: "Không gian giải trí và nghỉ dưỡng",
            isCover: false,
        },
    ],
};

const seed = async () => {
    console.info("🌱 Bắt đầu nạp dữ liệu mẫu (Seeding Database)...");
    await sequelize.authenticate();

    // 1. Seed Amenities
    console.info("1. Seeding Amenities...");
    const amenitiesData = [
        { amenityId: 1, name: "Wifi tốc độ cao", icon: "wifi" },
        { amenityId: 2, name: "Hồ bơi riêng", icon: "pool" },
        { amenityId: 3, name: "Điều hòa từng phòng", icon: "ac_unit" },
        { amenityId: 4, name: "Bếp đầy đủ dụng cụ", icon: "kitchen" },
        { amenityId: 5, name: "Bãi đỗ xe ô tô", icon: "local_parking" },
        { amenityId: 6, name: "Smart TV 65 inch", icon: "tv" },
        { amenityId: 7, name: "Máy giặt sấy", icon: "local_laundry_service" },
        { amenityId: 8, name: "Bếp nướng BBQ sân vườn", icon: "outdoor_grill" },
        { amenityId: 9, name: "View biển trực diện", icon: "beach_access" },
        { amenityId: 10, name: "Bồn tắm Jacuzzi", icon: "bathtub" },
        { amenityId: 11, name: "Ban công thoáng mát", icon: "balcony" },
        { amenityId: 12, name: "Gần bãi tắm (đi bộ 3 phút)", icon: "waves" },
    ];

    for (const a of amenitiesData) {
        await Amenity.findOrCreate({
            where: { amenityId: a.amenityId },
            defaults: {
                ...a,
                active: true,
                isActive: true,
                deletedAt: null,
            },
        });
    }

    // 2. Seed Users
    console.info("2. Seeding Users (Admin, Hosts, Guests)...");
    const passwordHash = await bcrypt.hash("12345678", 10);
    const adminPasswordHash = await bcrypt.hash("Admin@123", 10);

    const usersData = [
        {
            email: "admin@minhthanhvilla.com",
            phone: "0901000001",
            username: "admin",
            fullName: "Quản trị viên The Palm Villa",
            passwordHash: adminPasswordHash,
            roleId: 4, // admin
        },
        {
            email: "host.thanh@minhthanhvilla.com",
            phone: "0901000002",
            username: "host_thanh",
            fullName: "Nguyễn Minh Thành",
            passwordHash,
            roleId: 2, // host
            isHostVerified: true,
            hostApplicationStatus: "approved" as const,
        },
        {
            email: "host.lan@minhthanhvilla.com",
            phone: "0901000003",
            username: "host_lan",
            fullName: "Trần Ngọc Lan",
            passwordHash,
            roleId: 2, // host
            isHostVerified: true,
            hostApplicationStatus: "approved" as const,
        },
        {
            email: "guest@gmail.com",
            phone: "0901000004",
            username: "guest_demo",
            fullName: "Lê Hoàng Long",
            passwordHash,
            roleId: 1, // guest
        },
    ];

    const userMap = new Map<string, any>();

    for (const u of usersData) {
        const [user] = await User.findOrCreate({
            where: { email: u.email },
            defaults: {
                email: u.email,
                phone: u.phone,
                username: u.username,
                fullName: u.fullName,
                passwordHash: u.passwordHash,
                isEmailVerified: true,
                isPhoneVerified: true,
                isHostVerified: Boolean(u.isHostVerified),
                hostApplicationStatus: u.hostApplicationStatus ?? null,
                status: "active",
                dateOfBirth: new Date("1995-05-15"),
                bio: `Tài khoản ${u.fullName} tại hệ thống The Palm Villa`,
            },
        });

        if (user.fullName !== u.fullName || (user.bio && user.bio.includes("MinhThanh"))) {
            await user.update({
                fullName: u.fullName,
                bio: `Tài khoản ${u.fullName} tại hệ thống The Palm Villa`,
            });
        }

        userMap.set(u.email, user);

        // Link Role
        await sequelize.query(
            "INSERT IGNORE INTO user_role (user_id, role_id, assigned_at) VALUES (?, ?, NOW())",
            {
                replacements: [user.userId, u.roleId],
            }
        );

        // Profile
        await UserProfile.findOrCreate({
            where: { userId: user.userId },
            defaults: {
                userId: user.userId,
                firstName: user.firstName,
                lastName: user.lastName,
                location: "Vũng Tàu, Việt Nam",
                country: "VN",
                job: u.roleId === 2 ? "Chủ biệt thự nghỉ dưỡng" : "Khách du lịch",
            },
        });

        // Host profile if role is host
        if (u.roleId === 2) {
            await HostProfile.findOrCreate({
                where: { userId: user.userId },
                defaults: {
                    userId: user.userId,
                    displayName: u.fullName,
                    bio: `Chủ villa tận tâm với hơn 5 năm kinh nghiệm đón tiếp khách nghỉ dưỡng tại Vũng Tàu.`,
                    isSuperhost: true,
                    verificationStatus: "approved",
                    responseRate: 99,
                    responseTimeMinutes: 10,
                },
            });
        }
    }

    const hostThanh = userMap.get("host.thanh@minhthanhvilla.com");
    const hostLan = userMap.get("host.lan@minhthanhvilla.com");
    const guestUser = userMap.get("guest@gmail.com");

    // 3. Seed Listings
    console.info("3. Seeding Villas & Homestays...");
    const listingsData = [
        {
            listingId: 101,
            hostId: hostThanh.userId,
            title: "The Palm Luxury Sea View Villa Bãi Dâu",
            description:
                "Biệt thự nghỉ dưỡng cao cấp trực diện biển Bãi Dâu, ngắm trọn hoàng hôn tuyệt đẹp. Trang bị hồ bơi vô cực tràn bờ, phòng khách không gian mở, đầy đủ tiện nghi BBQ và dàn karaoke chất lượng cao.",
            addressLine: "120 Trần Phú",
            ward: "Phường 5",
            district: "Thành phố Vũng Tàu",
            city: "Vũng Tàu",
            stateRegion: "Bà Rịa - Vũng Tàu",
            latitude: 10.3621,
            longitude: 107.0628,
            propertyType: "villa" as const,
            roomType: "entire_place" as const,
            maxGuests: 12,
            bedrooms: 4,
            beds: 5,
            bathrooms: 4,
            basePrice: 3500000,
            weekendPrice: 4500000,
            cleaningFee: 300000,
            amenityIds: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        },
        {
            listingId: 102,
            hostId: hostThanh.userId,
            title: "Aria Resort Beachfront Villa Bãi Sau",
            description:
                "Nằm trong khuôn viên resort Aria yên bình sát bãi biển Bãi Sau. Villa có hồ bơi riêng, khuôn viên sân vườn xanh mát thích hợp cho gia đình có trẻ nhỏ và tiệc nướng hải sản ngoài trời.",
            addressLine: "Đường D5, Phường 10",
            ward: "Phường 10",
            district: "Thành phố Vũng Tàu",
            city: "Vũng Tàu",
            stateRegion: "Bà Rịa - Vũng Tàu",
            latitude: 10.3752,
            longitude: 107.1124,
            propertyType: "villa" as const,
            roomType: "entire_place" as const,
            maxGuests: 8,
            bedrooms: 3,
            beds: 4,
            bathrooms: 3,
            basePrice: 2800000,
            weekendPrice: 3800000,
            cleaningFee: 250000,
            amenityIds: [1, 2, 3, 4, 5, 6, 7, 8, 12],
        },
        {
            listingId: 103,
            hostId: hostLan.userId,
            title: "White Lotus Pool Villa Phan Chu Trinh",
            description:
                "Biệt thự thiết kế phong cách Địa Trung Hải tối giản, tông màu trắng sang trọng. Tọa lạc tại trung tâm Bãi Sau, cách biển chỉ 300m, gần các nhà hàng hải sản và quán cafe nổi tiếng.",
            addressLine: "24/6 Phan Chu Trinh",
            ward: "Phường 2",
            district: "Thành phố Vũng Tàu",
            city: "Vũng Tàu",
            stateRegion: "Bà Rịa - Vũng Tàu",
            latitude: 10.3341,
            longitude: 107.0856,
            propertyType: "villa" as const,
            roomType: "entire_place" as const,
            maxGuests: 15,
            bedrooms: 5,
            beds: 7,
            bathrooms: 5,
            basePrice: 4200000,
            weekendPrice: 5600000,
            cleaningFee: 350000,
            amenityIds: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11],
        },
        {
            listingId: 104,
            hostId: hostLan.userId,
            title: "Seaside Sunset Homestay & Studio Hạ Long",
            description:
                "Căn hộ homestay view cung đường biển Hạ Long lãng mạn. Phù hợp cho cặp đôi hoặc nhóm bạn nhỏ 4 người thích sự yên tĩnh, ngắm tàu thuyền qua lại và đi dạo ngọn Hải Đăng.",
            addressLine: "84 Hạ Long",
            ward: "Phường 2",
            district: "Thành phố Vũng Tàu",
            city: "Vũng Tàu",
            stateRegion: "Bà Rịa - Vũng Tàu",
            latitude: 10.3398,
            longitude: 107.0712,
            propertyType: "homestay" as const,
            roomType: "entire_place" as const,
            maxGuests: 4,
            bedrooms: 2,
            beds: 2,
            bathrooms: 2,
            basePrice: 1300000,
            weekendPrice: 1800000,
            cleaningFee: 150000,
            amenityIds: [1, 3, 4, 5, 6, 9, 11],
        },
        {
            listingId: 105,
            hostId: hostThanh.userId,
            title: "Ocean Pearl Garden Villa Bãi Trước",
            description:
                "Biệt thự sân vườn view Bãi Trước với hồ cá Koi, sân cỏ tiệc BBQ và phòng giải trí bi-a. Vị trí đắc địa ngay trung tâm thành phố, thuận tiện đi lại và ăn uống.",
            addressLine: "15 Quang Trung",
            ward: "Phường 1",
            district: "Thành phố Vũng Tàu",
            city: "Vũng Tàu",
            stateRegion: "Bà Rịa - Vũng Tàu",
            latitude: 10.3475,
            longitude: 107.0745,
            propertyType: "villa" as const,
            roomType: "entire_place" as const,
            maxGuests: 14,
            bedrooms: 4,
            beds: 6,
            bathrooms: 4,
            basePrice: 3800000,
            weekendPrice: 4900000,
            cleaningFee: 300000,
            amenityIds: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12],
        },
    ];

    for (const l of listingsData) {
        const gallery = VILLA_GALLERIES[l.listingId] ?? VILLA_GALLERIES[101];
        const imagesWithMeta = gallery.map((img, idx) => ({
            imageId: l.listingId * 10 + idx + 1,
            url: img.url,
            caption: img.caption,
            sortOrder: idx,
            isCover: img.isCover,
        }));

        const [listingRecord, created] = await Listing.findOrCreate({
            where: { listingId: l.listingId },
            defaults: {
                listingId: l.listingId,
                hostId: l.hostId,
                title: l.title,
                description: l.description,
                addressLine: l.addressLine,
                ward: l.ward,
                district: l.district,
                city: l.city,
                stateRegion: l.stateRegion,
                country: "VN",
                latitude: l.latitude,
                longitude: l.longitude,
                propertyType: l.propertyType,
                roomType: l.roomType,
                maxGuests: l.maxGuests,
                bedrooms: l.bedrooms,
                beds: l.beds,
                bathrooms: l.bathrooms,
                basePrice: l.basePrice,
                weekendPrice: l.weekendPrice,
                cleaningFee: l.cleaningFee,
                currency: "VND",
                minNights: 1,
                maxNights: 30,
                checkInFrom: "14:00",
                checkOutBefore: "12:00",
                cancellationPolicy: "flexible",
                instantBookEnabled: true,
                status: "active",
                amenityIds: l.amenityIds,
                images: imagesWithMeta,
                smokingAllowed: false,
                petsAllowed: true,
                partyAllowed: true,
                availabilityCalendar: [],
                deletedAt: null,
            },
        });
        if (!created) {
            await listingRecord.update({ title: l.title, images: imagesWithMeta });
        }

        // Seed Listing Images table
        for (let idx = 0; idx < gallery.length; idx++) {
            const img = gallery[idx];
            const [imgRecord, imgCreated] = await ListingImage.findOrCreate({
                where: {
                    listingId: l.listingId,
                    sortOrder: idx,
                },
                defaults: {
                    listingId: l.listingId,
                    url: img.url,
                    caption: img.caption,
                    sortOrder: idx,
                    isCover: img.isCover,
                    aiAnalysisStatus: "analyzed",
                },
            });
            if (!imgCreated) {
                await imgRecord.update({
                    url: img.url,
                    caption: img.caption,
                    isCover: img.isCover,
                });
            }
        }

        // Seed Listing Amenities mapping
        for (const amenityId of l.amenityIds) {
            await ListingAmenity.findOrCreate({
                where: {
                    listingId: l.listingId,
                    amenityId,
                },
                defaults: {
                    listingId: l.listingId,
                    amenityId,
                },
            });
        }

        // Seed 60 days availability calendar
        const today = new Date();
        for (let d = 0; d < 60; d++) {
            const current = new Date(today);
            current.setDate(today.getDate() + d);
            const dateStr = current.toISOString().slice(0, 10);

            await AvailabilityCalendar.findOrCreate({
                where: {
                    listingId: l.listingId,
                    date: dateStr,
                },
                defaults: {
                    listingId: l.listingId,
                    date: dateStr,
                    isAvailable: true,
                    isBlockedByHost: false,
                    priceOverride: null,
                    minNightsOverride: null,
                },
            });
        }

        // Seed Reviews
        await Review.findOrCreate({
            where: {
                listingId: l.listingId,
                reviewerName: "Lê Hoàng Long",
            },
            defaults: {
                reviewId: l.listingId * 10 + 1,
                bookingId: null,
                listingId: l.listingId,
                reviewerUserId: guestUser.userId,
                reviewerName: "Lê Hoàng Long",
                rating: 5,
                comment:
                    "Villa quá đẹp, hồ bơi sạch và view biển ngắm hoàng hôn đỉnh cao! Chủ nhà nhiệt tình hỗ trợ đoàn mình tiệc BBQ rất chu đáo. Chắc chắn sẽ quay lại!",
                hostReply: "Cảm ơn bạn Long và đoàn đã ghé thăm, rất hân hạnh được đón tiếp bạn lần sau nhé!",
                isVisible: true,
                deletedAt: null,
            },
        });

        await Review.findOrCreate({
            where: {
                listingId: l.listingId,
                reviewerName: "Nguyễn Hải Đăng",
            },
            defaults: {
                reviewId: l.listingId * 10 + 2,
                bookingId: null,
                listingId: l.listingId,
                reviewerUserId: null,
                reviewerName: "Nguyễn Hải Đăng",
                rating: 5,
                comment: "Không gian rộng rãi, tiện nghi cao cấp, phòng ốc thơm tho sạch sẽ. 10/10 điểm!",
                hostReply: null,
                isVisible: true,
                deletedAt: null,
            },
        });
    }

    // 4. Seed Coupons
    console.info("4. Seeding Coupons...");
    const nextYear = new Date();
    nextYear.setFullYear(nextYear.getFullYear() + 1);

    await Coupon.findOrCreate({
        where: { code: "MINHTHANH10" },
        defaults: {
            code: "MINHTHANH10",
            title: "Giảm 10% cho khách hàng mới",
            description: "Áp dụng giảm 10% tối đa 500.000đ cho đơn đặt phòng đầu tiên.",
            type: "percent",
            discountValue: 10,
            maxDiscountAmount: 500000,
            minOrderValue: 2000000,
            startDate: new Date(),
            endDate: nextYear,
            totalLimit: 500,
            limitPerUser: 1,
            isActive: true,
        },
    });

    await Coupon.findOrCreate({
        where: { code: "VUNGTAU200K" },
        defaults: {
            code: "VUNGTAU200K",
            title: "Ưu đãi mùa hè Vũng Tàu - Giảm 200.000đ",
            description: "Giảm ngay 200.000đ cho các đơn đặt phòng từ 2 đêm trở lên.",
            type: "fixed_amount",
            discountValue: 200000,
            maxDiscountAmount: 200000,
            minOrderValue: 3000000,
            startDate: new Date(),
            endDate: nextYear,
            totalLimit: 300,
            limitPerUser: 1,
            isActive: true,
        },
    });

    // 5. Seed Blogs & Categories
    console.info("5. Seeding Blog Categories & Posts...");
    const [cat1] = await BlogCategory.findOrCreate({
        where: { slug: "cam-nang-du-lich" },
        defaults: {
            name: "Cẩm nang du lịch",
            slug: "cam-nang-du-lich",
        },
    });

    const [cat2] = await BlogCategory.findOrCreate({
        where: { slug: "review-villa" },
        defaults: {
            name: "Review Villa & Homestay",
            slug: "review-villa",
        },
    });

    const [blog1, blog1Created] = await Blog.findOrCreate({
        where: { slug: "top-5-bai-bien-dep-nhat-vung-tau" },
        defaults: {
            slug: "top-5-bai-bien-dep-nhat-vung-tau",
            title: "Top 5 bãi biển đẹp và yên bình nhất tại Vũng Tàu bạn nên ghé thăm",
            categoryId: cat1.categoryId,
            categoryName: cat1.name,
            readTime: "5 phút đọc",
            location: "Vũng Tàu",
            excerpt: "Khám phá vẻ đẹp hoang sơ của Bãi Dâu, Bãi Dứa và những cung đường biển check-in triệu view tại Vũng Tàu.",
            coverImage: "assets/images/NDT05929-HDR1.jpg",
            content: [
                "Vũng Tàu luôn là điểm đến nghỉ dưỡng số 1 cho cư dân miền Nam vào mỗi dịp cuối tuần.",
                "Bên cạnh Bãi Sau nhộn nhịp, Bãi Dâu và Bãi Dứa sở hữu làn nước trong xanh và sự yên tĩnh hiếm có.",
                "Nghỉ dưỡng tại các căn villa sát biển sẽ giúp bạn ngắm trọn vẹn cảnh bình minh và hoàng hôn buông xuống mặt biển.",
            ],
            status: "published",
            publishedAt: new Date(),
            createdByUserId: hostThanh.userId,
        },
    });
    if (!blog1Created) {
        await blog1.update({ coverImage: "assets/images/NDT05929-HDR1.jpg" });
    }

    const [blog2, blog2Created] = await Blog.findOrCreate({
        where: { slug: "kinh-nghiem-thue-villa-vung-tau-gia-dinh" },
        defaults: {
            slug: "kinh-nghiem-thue-villa-vung-tau-gia-dinh",
            title: "Kinh nghiệm chọn thuê biệt thự nghỉ dưỡng Vũng Tàu cho gia đình và nhóm bạn",
            categoryId: cat2.categoryId,
            categoryName: cat2.name,
            readTime: "7 phút đọc",
            location: "Vũng Tàu",
            excerpt: "Những tiêu chí quan trọng khi đặt villa: hồ bơi riêng, tiện ích BBQ, vị trí sát biển và độ uy tín của chủ nhà.",
            coverImage: "assets/images/19tranphu.jpg",
            content: [
                "Khi đi du lịch theo đoàn từ 8 - 15 người, thuê trọn gói một căn villa luôn là lựa chọn tiết kiệm và riêng tư nhất.",
                "Hãy ưu tiên các căn có hồ bơi riêng và sân vườn rộng để tổ chức tiệc nướng hải sản buổi tối.",
                "Hệ thống The Palm Villa hỗ trợ đặt phòng trực tuyến nhanh chóng với thông tin minh bạch và cam kết chất lượng.",
            ],
            status: "published",
            publishedAt: new Date(),
            createdByUserId: hostThanh.userId,
        },
    });
    if (!blog2Created) {
        await blog2.update({ coverImage: "assets/images/19tranphu.jpg" });
    }

    console.info("🎉 Seeding Database hoàn tất thành công 100%!");
};

if (process.env.NODE_ENV === "production" && process.env.ALLOW_PRODUCTION_SEED !== "true") {
    console.error("Refusing to run seed script in production without ALLOW_PRODUCTION_SEED=true");
    process.exit(1);
}

seed()
    .then(async () => {
        await sequelize.close();
        process.exit(0);
    })
    .catch(async (error) => {
        console.error("❌ Seeding thất bại:", error);
        await sequelize.close();
        process.exit(1);
    });
