# BÁO CÁO KIỂM TOÁN MÃ NGUỒN GỐC (SOURCE_AUDIT)

**Thư mục tham chiếu:**
- Frontend: `D:\MANAGER-PROJECT\Source goc\frontend`
- Backend: `D:\MANAGER-PROJECT\Source goc\backend`

---

## 1. KIỂM TOÁN FRONTEND GỐC (REACT / TYPESCRIPT / VITE)

### 1.1. Cấu trúc Routing & Pages
Nguồn: [AppRouter.tsx](file:///D:/MANAGER-PROJECT/Source%20goc/frontend/src/router/AppRouter.tsx) & [routes.ts](file:///D:/MANAGER-PROJECT/Source%20goc/frontend/src/config/routes.ts)

| Tuyến đường (Route) | Trang giao diện | Mục đích nghiệp vụ | Phù hợp Mobile |
|---|---|---|---|
| `/` | `HomePage` | Khám phá, danh sách villa nổi bật, banner hero, giới thiệu | **Có (Native Screen)** |
| `/tim-kiem` | `SearchPage` | Tìm kiếm theo ngày, số khách, giá, khu vực Vũng Tàu, tiện ích | **Có (Native Screen)** |
| `/ai-tim-kiem` | `AiSearchPage` | Tìm kiếm bằng ngôn ngữ tự nhiên qua vector search | **Có (Chuyển đổi sau)** |
| `/villa/:villaId` | `ListingDetailPage` | Xem chi tiết villa, ảnh, bảng giá, tiện ích, quy định, review | **Có (Native Screen)** |
| `/yeu-thich` | `WishlistPage` | Danh sách các căn lưu trú đã thích của người dùng | **Có (Native Screen)** |
| `/account/trips` | `ProfilePage` (Trips tab) | Lịch sử chuyến đi, quản lý đơn đặt phòng (Active, Completed, Cancelled) | **Có (Native Screen)** |
| `/dang-nhap` | `LoginPage` | Đăng nhập tài khoản (Email/SĐT + Password) | **Có (Native Screen)** |
| `/dang-ky` | `RegisterPage` | Đăng ký tài khoản mới (Họ tên, Email, Mật khẩu, SĐT) | **Có (Native Screen)** |
| `/quen-mat-khau` | `ForgotPasswordPage` | Quên mật khẩu, gửi mã OTP và đặt lại mật khẩu mới | **Có (Native Screen)** |
| `/bai-viet` | `BlogPage` | Tin tức, cẩm nang du lịch Vũng Tàu | **Tùy chọn** |
| `/lien-he` | `ContactPage` | Thông tin liên hệ, hotline, Zalo OA, bản đồ | **Có (Native Widget/Screen)** |
| `/tin-nhan` | `MessagesPage` | Chat trực tiếp với chủ nhà / hỗ trợ | **Phase tiếp theo** |
| `/chu-nha/*` | `HostLayout` | Bảng điều khiển quản lý phòng của chủ nhà (Host Portal) | **Web/Desktop First** |
| `/admin/*` | `AdminLayout` | Quản trị hệ thống, kiểm duyệt bài đăng, phân quyền người dùng | **Web/Desktop Only** |

### 1.2. Dịch vụ & Kết nối API của Frontend
- [apiClient.ts](file:///D:/MANAGER-PROJECT/Source%20goc/frontend/src/services/api/apiClient.ts): Axios client, baseURL `/api`, quản lý JWT trong cookie/localStorage.
- [listingService.ts](file:///D:/MANAGER-PROJECT/Source%20goc/frontend/src/services/listingService.ts):
  - `getListings(query)` -> `GET /api/listings`
  - `getListingById(id)` -> `GET /api/listings/:id`
  - `getListingAvailability(id, query)` -> `GET /api/listings/:id/availability`
  - `getListingReviews(id, query)` -> `GET /api/listings/:id/reviews`
  - `getListingRules(id)` -> `GET /api/listings/:id/rules`
- [bookingService.ts](file:///D:/MANAGER-PROJECT/Source%20goc/frontend/src/services/bookingService.ts):
  - `getMyBookings(query)` -> `GET /api/bookings/mine`
  - `createBooking(payload)` -> `POST /api/bookings`
  - `cancelBooking(id, payload)` -> `POST /api/bookings/:id/cancel`
- [wishlistService.ts](file:///D:/MANAGER-PROJECT/Source%20goc/frontend/src/services/wishlistService.ts):
  - `getWishlist()` -> `GET /api/wishlist`
  - `addWishlistListing(id)` -> `POST /api/wishlist/:id`
  - `removeWishlistListing(id)` -> `DELETE /api/wishlist/:id`
- [authService.ts](file:///D:/MANAGER-PROJECT/Source%20goc/frontend/src/services/authService.ts):
  - `login(payload)` -> `POST /api/auth/login`
  - `register(payload)` -> `POST /api/auth/register`
  - `logout()` -> `POST /api/auth/logout`
  - `getMe()` -> `GET /api/auth/me`

---

## 2. KIỂM TOÁN BACKEND GỐC (NODE.JS / EXPRESS / TYPESCRIPT)

### 2.1. Cấu hình & Middleware
- [app.ts](file:///D:/MANAGER-PROJECT/Source%20goc/backend/src/app.ts):
  - Express app với bảo mật Helmet, CORS, Rate Limiters, JSON body parser, Cookie parser, Request ID, Request logger.
  - Định dạng chuẩn đầu ra: `sendSuccess(res, { data, message, statusCode })` -> `{ success: true, message: "...", data: ... }`.
  - Định dạng lỗi: `sendError(res, statusCode, message, details, code)` -> `{ success: false, message: "...", code: "...", details: ... }`.

### 2.2. Danh mục API & Controller
1. **Public Listings Module (`/api/listings`):**
   - File: [listings.routes.ts](file:///D:/MANAGER-PROJECT/Source%20goc/backend/src/modules/listings/listings.routes.ts) & [listings.service.ts](file:///D:/MANAGER-PROJECT/Source%20goc/backend/src/modules/listings/listings.service.ts)
   - `GET /api/listings`: Hỗ trợ lọc `q`, `city`, `district`, `checkIn`, `checkOut`, `guests`, `propertyType`, `priceMin`, `priceMax`, `amenities`, `sort`, `page`, `limit`.
   - `GET /api/listings/:listingId`: Chi tiết đầy đủ của chỗ nghỉ kèm thông số phòng, giường, sức chứa, tiện ích, ảnh và host info.
   - `GET /api/listings/:listingId/availability`: Trả về mảng ngày trong tháng (`month`, `year`) với cờ `isAvailable`, `price`, `minNights`.
   - `GET /api/listings/:listingId/reviews`: Danh sách review của chỗ nghỉ kèm phân trang và xếp hạng sao.
   - `GET /api/listings/:listingId/rules`: Giờ nhận/trả phòng, quy định thú cưng, hút thuốc.
2. **Authentication Module (`/api/auth`):**
   - File: [auth.routes.ts](file:///D:/MANAGER-PROJECT/Source%20goc/backend/src/modules/auth/auth.routes.ts) & [auth.controller.ts](file:///D:/MANAGER-PROJECT/Source%20goc/backend/src/modules/auth/auth.controller.ts)
   - `POST /api/auth/login`: Xác thực email/sđt và mật khẩu. Trả về `accessToken`, thông tin `user` (id, email, name, role).
   - `POST /api/auth/register`: Đăng ký tài khoản khách/chủ nhà.
   - `POST /api/auth/logout`: Hủy refresh token và xóa phiên.
   - `GET /api/auth/me`: Lấy thông tin phiên hiện tại của người dùng.
   - `POST /api/auth/forgot-password`: Gửi OTP khôi phục mật khẩu.
   - `POST /api/auth/reset-password`: Đổi mật khẩu với mã OTP.
3. **Bookings Module (`/api/bookings`):**
   - File: [bookings.routes.ts](file:///D:/MANAGER-PROJECT/Source%20goc/backend/src/modules/bookings/bookings.routes.ts) & [bookings.service.ts](file:///D:/MANAGER-PROJECT/Source%20goc/backend/src/modules/bookings/bookings.service.ts)
   - `GET /api/bookings/mine`: Danh sách đặt phòng của khách hiện tại.
   - `POST /api/bookings`: Tạo đơn đặt phòng mới.
   - `GET /api/bookings/:bookingId`: Chi tiết đơn đặt phòng.
   - `POST /api/bookings/:bookingId/cancel`: Khách hủy đặt phòng kèm lý do.
4. **Wishlist Module (`/api/wishlist`):**
   - File: [wishlist.routes.ts](file:///D:/MANAGER-PROJECT/Source%20goc/backend/src/modules/wishlist/wishlist.routes.ts)
   - `GET /api/wishlist`: Lấy danh sách ID và thông tin tóm tắt các căn yêu thích.
   - `POST /api/wishlist/:listingId`: Lưu căn vào danh sách yêu thích.
   - `DELETE /api/wishlist/:listingId`: Xóa căn khỏi danh sách yêu thích.
5. **Reviews Module (`/api/reviews`):**
   - File: [reviews.routes.ts](file:///D:/MANAGER-PROJECT/Source%20goc/backend/src/modules/reviews/reviews.routes.ts)
   - `POST /api/reviews`: Khách gửi đánh giá và số sao sau khi hoàn tất chuyến đi.
