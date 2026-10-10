# BẢNG ĐỐI CHIẾU & KIỂM TOÁN TÍCH HỢP API BACKEND (API_PARITY)

**Dự án:** `hotel-booking-flutter`  
**Ngày kiểm toán:** 10/10/2026  
**Kỹ sư thực hiện:** Senior Backend Integration & QA Automation Engineer  
**Nguồn tham chiếu Backend:** `Source goc/backend` (Express.js, Sequelize, MySQL, Qdrant)  
**Nguồn tham chiếu Frontend:** `Source goc/frontend/src/services`  
**Flutter Codebase:** `hotel-booking-flutter/lib/`

---

## 1. BẢNG TỔNG HỢP TRẠNG THÁI KẾT NỐI API

| Chức năng | Method | Endpoint | Frontend sử dụng | Flutter sử dụng | Trạng thái |
|---|---|---|---|---|---|
| **Danh sách biệt thự** | `GET` | `/api/listings` | `listingService.getListings` | `VillaRepositoryImpl.getVillas` | `CONNECTED_VERIFIED` |
| **Chi tiết biệt thự** | `GET` | `/api/listings/:id` | `listingService.getListingById` | `VillaRepositoryImpl.getVillaById` | `CONNECTED_VERIFIED` |
| **Lịch trống & giá theo ngày** | `GET` | `/api/listings/:id/availability` | `listingService.getListingAvailability` | `VillaRepositoryImpl.getAvailability` | `CONNECTED_VERIFIED` |
| **Quy định nhận/trả phòng** | `GET` | `/api/listings/:id/rules` | `listingService.getListingRules` | `VillaRepositoryImpl` | `CONNECTED_VERIFIED` |
| **Đánh giá & phản hồi** | `GET` | `/api/listings/:id/reviews` | `listingService.getListingReviews` | `ReviewRepositoryImpl.getReviews` | `CONNECTED_VERIFIED` |
| **Đăng nhập người dùng** | `POST` | `/api/auth/login` | `authService.login` | `AuthRepositoryImpl.login` | `CONNECTED_VERIFIED` |
| **Đăng ký tài khoản** | `POST` | `/api/auth/register` | `authService.register` | `AuthRepositoryImpl.register` | `CONNECTED_VERIFIED` |
| **Quên mật khẩu (OTP)** | `POST` | `/api/auth/forgot-password` | `authService.forgotPassword` | `AuthRepositoryImpl.forgotPassword` | `CONNECTED_VERIFIED` |
| **Đặt lại mật khẩu** | `POST` | `/api/auth/reset-password` | `authService.resetPassword` | `AuthRepositoryImpl.resetPassword` | `CONNECTED_VERIFIED` |
| **Lấy thông tin phiên hiện tại** | `GET` | `/api/auth/me` | `authService.getMe` | `AuthRepositoryImpl.getCurrentUser` | `CONNECTED_VERIFIED` |
| **Đăng xuất** | `POST` | `/api/auth/logout` | `authService.logout` | `AuthRepositoryImpl.logout` | `CONNECTED_VERIFIED` |
| **Danh sách chuyến đi của tôi** | `GET` | `/api/bookings/mine` | `bookingService.getMyBookings` | `BookingRepositoryImpl.getMyBookings` | `CONNECTED_VERIFIED` |
| **Chi tiết đặt phòng** | `GET` | `/api/bookings/:id` | `bookingService.getBookingDetail` | `BookingRepositoryImpl.getBookingById` | `CONNECTED_VERIFIED` |
| **Hủy đặt phòng** | `POST` | `/api/bookings/:id/cancel` | `bookingService.cancelBooking` | `BookingRepositoryImpl.cancelBooking` | `CONNECTED_VERIFIED` |
| **Tạo đặt phòng mới** | `POST` | `/api/bookings` | `bookingService.createBooking` | `BookingRepositoryImpl.createBooking` | `CONNECTED_VERIFIED` |
| **Lấy danh sách yêu thích** | `GET` | `/api/wishlist` | `wishlistService.getWishlist` | `WishlistRepositoryImpl.getWishlist` | `CONNECTED_VERIFIED` |
| **Thêm vào yêu thích** | `POST` | `/api/wishlist/:listingId` | `wishlistService.addWishlistListing` | `WishlistRepositoryImpl.addWishlistListing` | `CONNECTED_VERIFIED` |
| **Xóa khỏi yêu thích** | `DELETE` | `/api/wishlist/:listingId` | `wishlistService.removeWishlistListing` | `WishlistRepositoryImpl.removeWishlistListing` | `CONNECTED_VERIFIED` |
| **Tư vấn Zalo OA** | `DEEP LINK` | `https://zalo.me/...` | `ContactService` | `ContactService.openZaloInquiry` | `CONNECTED_VERIFIED` |
| **Tổng đài Hotline** | `TEL SCHEME` | `tel:0901234567` | `ContactService` | `ContactService.callHotline` | `CONNECTED_VERIFIED` |
| **Admin Quản trị tổng** | `GET/POST` | `/api/admin/*` | `adminService.ts` | Không thuộc Mobile Guest App | `NOT_REQUIRED_ON_MOBILE` |
| **Host Quản lý phòng** | `GET/POST` | `/api/host/*` | `hostService.ts` | Không thuộc Mobile Guest App | `NOT_REQUIRED_ON_MOBILE` |

---

## 2. BẢNG ĐẶC TẢ CHI TIẾT CÁC ENDPOINT TÍCH HỢP TRÊN FLUTTER

### 1. `GET /api/listings`
- **Method:** `GET`
- **Authentication:** Không bắt buộc (Public).
- **Request Parameters:**
  - `page`: int (mặc định 1)
  - `limit`: int (mặc định 12)
  - `q`: string (từ khóa tìm kiếm)
  - `guests`: int (sức chứa tối thiểu)
  - `checkIn`: YYYY-MM-DD
  - `checkOut`: YYYY-MM-DD
  - `sort`: string (`rating_desc`, `price_asc`, `price_desc`, `newest`)
- **Response Schema:**
  ```json
  {
    "success": true,
    "data": {
      "items": [
        {
          "id": 1,
          "title": "Villa Bãi Sau Hồ Bơi Nước Mặn",
          "basePrice": 3500000,
          "weekendPrice": 5200000,
          "addressSummary": "Bãi Sau, Vũng Tàu",
          "ratingSummary": 4.9,
          "reviewCount": 24,
          "maxGuests": 20,
          "bedrooms": 5,
          "beds": 7,
          "bathrooms": 6,
          "distanceMeters": 150,
          "images": ["https://..."]
        }
      ],
      "pagination": { "page": 1, "limit": 12, "total": 1, "totalPages": 1 }
    }
  }
  ```
- **Flutter Repository:** [VillaRepositoryImpl](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villas/data/repositories/villa_repository_impl.dart)
- **Bài test:** [villa_test.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/test/features/villas/villa_test.dart)

---

### 2. `GET /api/listings/:id/availability`
- **Method:** `GET`
- **Authentication:** Không bắt buộc.
- **Request Parameters:** `month` (1-12), `year` (2026).
- **Response Schema:**
  ```json
  {
    "success": true,
    "data": {
      "listingId": 1,
      "days": [
        { "date": "2026-10-15", "isAvailable": true, "price": 3500000, "minNights": 1 },
        { "date": "2026-10-16", "isAvailable": false, "price": 5200000, "minNights": 1 }
      ]
    }
  }
  ```
- **Flutter Model:** `BookingDate` xử lý độc lập múi giờ `Asia/Ho_Chi_Minh`.
- **Flutter Repository:** `VillaRepositoryImpl.getAvailability`
- **Bài test:** [booking_date_test.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/test/core/booking_date_test.dart)

---

### 3. `POST /api/auth/login`
- **Method:** `POST`
- **Authentication:** Không.
- **Request Body:**
  ```json
  {
    "identifier": "khachhang@example.com",
    "password": "Password123@"
  }
  ```
- **Response Schema:**
  ```json
  {
    "success": true,
    "data": {
      "accessToken": "eyJhbGciOi...",
      "user": {
        "id": 10,
        "email": "khachhang@example.com",
        "fullName": "Nguyễn Văn A",
        "role": "guest"
      }
    }
  }
  ```
- **Lưu trữ bảo mật:** Lưu trữ accessToken vào `FlutterSecureStorage` (EncryptedSharedPreferences trên Android / Keychain trên iOS).
- **Flutter Repository:** [AuthRepositoryImpl](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/auth/data/repositories/auth_repository_impl.dart)
- **Bài test:** [auth_test.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/test/features/auth/auth_test.dart)

---

### 4. `GET /api/bookings/mine`
- **Method:** `GET`
- **Authentication:** Bắt buộc (`Authorization: Bearer <accessToken>`).
- **Request Query:** `status` (`confirmed`, `completed`, `cancelled`, `pending`), `page`, `limit`.
- **Response Schema:**
  ```json
  {
    "success": true,
    "data": {
      "items": [
        {
          "id": 101,
          "listingId": 1,
          "listingTitle": "Villa Bãi Sau Hồ Bơi Nước Mặn",
          "listingImage": "https://...",
          "checkIn": "2026-10-20",
          "checkOut": "2026-10-22",
          "totalPrice": 7000000,
          "status": "confirmed",
          "guests": 12,
          "createdAt": "2026-10-01T10:00:00.000Z"
        }
      ],
      "pagination": { "page": 1, "limit": 10, "total": 1, "totalPages": 1 }
    }
  }
  ```
- **Flutter Repository:** [BookingRepositoryImpl](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/trips/data/repositories/booking_repository_impl.dart)
- **Bài test:** [booking_test.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/test/features/trips/booking_test.dart)

---

### 5. `GET /api/wishlist` & `POST/DELETE /api/wishlist/:listingId`
- **Method:** `GET`, `POST`, `DELETE`
- **Authentication:** Bắt buộc (`Authorization: Bearer <token>`).
- **Flutter Repository:** [WishlistRepositoryImpl](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/favorites/data/repositories/wishlist_repository_impl.dart)
- **Cơ chế Fallback:** Khi chưa đăng nhập, danh sách yêu thích lưu trữ cục bộ tại `PreferencesService` (SharedPreferences). Khi đăng nhập, tự động đồng bộ 2 chiều với Backend.

---

## 3. KIỂM TOÁN DỮ LIỆU GIẢ (MOCK AUDIT)
- **Kiểm tra mã nguồn `lib/`:** KHÔNG CÓ danh sách fix cứng (hardcoded list), KHÔNG DÙNG Mock JSON, KHÔNG CÓ fake credentials.
- **Tất cả Repositories:** Gọi trực tiếp `DioClient` kết nối máy chủ REST API thật của Backend (`http://10.0.2.2:5000/api` trên Dev Android Emulator, `http://localhost:5000/api` trên Web/iOS, và `https://dev-api.minhthanhvilla.com` trên Staging/Prod).
