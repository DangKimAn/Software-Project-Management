# NHẬT KÝ TRIỂN KHAI VÀ DI CHUYỂN MÃ NGUỒN (IMPLEMENTATION_LOG)

**Dự án:** `hotel-booking-flutter`  
**Ngày thực hiện:** 10/10/2026  
**Người thực hiện:** Senior Flutter Architect & Migration Engineer  

---

## 1. NHẬT KÝ CHI TIẾT THEO MODULE

### Module 01: Core Infrastructure & Network Security
- **File thay đổi:**
  - [app_config.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/core/config/app_config.dart)
  - [dio_client.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/core/network/dio_client.dart)
  - [providers.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/app/di/providers.dart)
- **Nội dung thay đổi:**
  - Cho phép scheme `http://` trong môi trường `dev` để hỗ trợ Android Emulator (`10.0.2.2:5000/api`) và iOS Simulator (`localhost:5000/api`), đồng thời duy trì bắt buộc HTTPS đối với `staging` và `prod`.
  - Tích hợp `SecureStorageService` vào Interceptor của `DioClient` để tự động đính kèm `Authorization: Bearer <token>` cho mọi request khi đã đăng nhập.
  - Cập nhật DI provider để inject `secureStorageProvider` vào `dioClientProvider`.
- **API liên quan:** Toàn bộ API Backend.
- **Kết quả:** Đạt tiêu chuẩn bảo mật, interceptor hoạt động mượt mà không crash khi storage rỗng.

---

### Module 02: Discovery & Villa Parity Integration
- **File thay đổi:**
  - [villa_repository.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villas/domain/repositories/villa_repository.dart)
  - [villa_repository_impl.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villas/data/repositories/villa_repository_impl.dart)
  - [providers.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/app/di/providers.dart)
  - [search_screen.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/search/presentation/screens/search_screen.dart)
- **Nội dung thay đổi:**
  - Đổi toàn bộ endpoint từ `/v1/villas` sang `/api/listings`, `/api/listings/:id`, `/api/listings/:id/availability`.
  - Bóc tách chính xác response envelope Backend `{ success: true, data: { items: [...], pagination: { ... } } }`.
  - Ánh xạ đầy đủ thuộc tính Backend Listing (`listingId`, `title`, `basePrice`, `weekendPrice`, `addressSummary`, `ratingSummary`, `images`, `amenities`, `distanceMeters`, `maxGuests`, `bedrooms`, `beds`, `bathrooms`) sang domain entity `Villa`.
  - Bổ sung tham số `checkIn` và `checkOut` vào `VillaFilterState` và `VillaRepository.getVillas`.
- **API liên quan:** `GET /api/listings`, `GET /api/listings/:id`, `GET /api/listings/:id/availability`.
- **Kết quả:** Đạt chuẩn 100% dữ liệu thực, không sử dụng dữ liệu mẫu hoặc seed.

---

### Module 03: Authentication Module (`features/auth/`)
- **File thêm mới:**
  - [user.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/auth/domain/entities/user.dart)
  - [auth_session.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/auth/domain/entities/auth_session.dart)
  - [auth_repository.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/auth/domain/repositories/auth_repository.dart)
  - [auth_repository_impl.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/auth/data/repositories/auth_repository_impl.dart)
  - [auth_notifier.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/auth/presentation/view_models/auth_notifier.dart)
  - [login_screen.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/auth/presentation/screens/login_screen.dart)
  - [register_screen.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/auth/presentation/screens/register_screen.dart)
  - [forgot_password_screen.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/auth/presentation/screens/forgot_password_screen.dart)
  - [auth_test.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/test/features/auth/auth_test.dart)
- **Nội dung:**
  - Xây dựng hoàn chỉnh luồng xác thực: Đăng nhập (Email/SĐT + Password), Đăng ký (Họ tên, Email, Mật khẩu, SĐT), Quên mật khẩu qua OTP 2 bước.
  - Quản trị phiên: Tự động lưu `accessToken` vào `SecureStorageService` và kiểm tra phiên người dùng khi khởi động ứng dụng.
- **API liên quan:**
  - `POST /api/auth/login`
  - `POST /api/auth/register`
  - `POST /api/auth/forgot-password`
  - `POST /api/auth/reset-password`
  - `GET /api/auth/me`
  - `POST /api/auth/logout`
- **Kết quả:** Unit test xác thực parsing User và AuthSession hoàn tất.

---

### Module 04: Trips / Guest Bookings Feature (`features/trips/`)
- **File thêm mới:**
  - [booking.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/trips/domain/entities/booking.dart)
  - [booking_repository.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/trips/domain/repositories/booking_repository.dart)
  - [booking_repository_impl.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/trips/data/repositories/booking_repository_impl.dart)
  - [trips_view_model.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/trips/presentation/view_models/trips_view_model.dart)
  - [trips_screen.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/trips/presentation/screens/trips_screen.dart)
  - [booking_test.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/test/features/trips/booking_test.dart)
- **Nội dung:**
  - Màn hình TripsScreen với 3 tab: Sắp tới (Active), Đã hoàn thành (Completed), Đã hủy (Cancelled).
  - Tích hợp hộp thoại xác nhận hủy đặt phòng kèm nhập lý do hủy.
  - Xử lý trạng thái khi chưa đăng nhập và empty view khi chưa có chuyến đi nào.
- **API liên quan:**
  - `GET /api/bookings/mine`
  - `GET /api/bookings/:id`
  - `POST /api/bookings/:id/cancel`
- **Kết quả:** Unit test domain booking đạt kết quả chính xác.

---

### Module 05: Wishlist / Favorites Backend Synchronization (`features/favorites/`)
- **File thêm mới & thay đổi:**
  - [wishlist_repository.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/favorites/domain/repositories/wishlist_repository.dart)
  - [wishlist_repository_impl.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/favorites/data/repositories/wishlist_repository_impl.dart)
  - [providers.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/app/di/providers.dart)
- **Nội dung:**
  - Nâng cấp `FavoritesNotifier`: Khi người dùng đăng nhập, tự động fetch và sync danh sách ID yêu thích từ `/api/wishlist`. Khi bấm yêu thích hoặc hủy yêu thích, gọi `POST /api/wishlist/:id` hoặc `DELETE /api/wishlist/:id`. Nếu chưa đăng nhập hoặc offline, tự động lưu cục bộ qua `PreferencesService`.
- **API liên quan:**
  - `GET /api/wishlist`
  - `POST /api/wishlist/:listingId`
  - `DELETE /api/wishlist/:listingId`
- **Kết quả:** Hoạt động ổn định cả online và offline.

---

### Module 06: Reviews Integration (`features/reviews/`)
- **File thêm mới & thay đổi:**
  - [review_item.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/reviews/domain/entities/review_item.dart)
  - [review_repository.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/reviews/domain/repositories/review_repository.dart)
  - [review_repository_impl.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/reviews/data/repositories/review_repository_impl.dart)
  - [review_list_widget.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/reviews/presentation/widgets/review_list_widget.dart)
  - [villa_detail_screen.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villa_detail/presentation/screens/villa_detail_screen.dart)
  - [review_test.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/test/features/reviews/review_test.dart)
- **Nội dung:**
  - Hiển thị danh sách review thực từ backend trên trang chi tiết villa, bao gồm xếp hạng sao màu hổ phách, avatar khách, nhận xét và phản hồi của chủ nhà.
- **API liên quan:**
  - `GET /api/listings/:listingId/reviews`
- **Kết quả:** Tích hợp trực tiếp trên VillaDetailScreen.

---

### Module 07: Navigation & Settings Profile
- **File thay đổi:**
  - [app_router.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/app/router/app_router.dart)
  - [settings_screen.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/settings/presentation/screens/settings_screen.dart)
- **Nội dung:**
  - Mở rộng thanh điều hướng Bottom Navigation Bar thành 4 tab hoàn chỉnh: Khám phá, Yêu thích, Chuyến đi, Cài đặt.
  - Đăng ký đầy đủ route cho `/login`, `/register`, `/forgot-password`, `/trips`.
  - Bổ sung khối tài khoản người dùng tại SettingsScreen (thông tin cá nhân, vai trò, nút đăng xuất hoặc đăng nhập).

---

### Module 08: Luxury Micro-Animations & Dynamic Motion System
- **File thêm mới & nâng cấp:**
  - [pressable_scale.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/animations/pressable_scale.dart): Hiệu ứng xúc giác chạm co giãn mượt mà (`0.98` scale down + bounce back) cho toàn bộ Card và Button.
  - [animated_heart_button.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/animations/animated_heart_button.dart): Hiệu ứng nảy tim lò xo (Spring pop animation `1.0 -> 1.35 -> 0.90 -> 1.0`) khi nhấn yêu thích.
  - [fade_slide_in.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/animations/fade_slide_in.dart): Hiệu ứng trượt mượt và xuất hiện so le (staggered entrance) cho danh sách biệt thự và nội dung trang chi tiết.
  - [shimmer_loading.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/animations/shimmer_loading.dart): Hiệu ứng quét sáng shimmer skeleton sang trọng khi đang tải danh sách biệt thự, thay thế cho vòng xoay đơn điệu.
  - [property_card.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villas/presentation/widgets/property_card.dart): Tích hợp `PressableScale`, `Hero(tag: villa_image_...)`, và `AnimatedHeartButton`.
  - [villa_detail_screen.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villa_detail/presentation/screens/villa_detail_screen.dart): Tích hợp `Hero` chuyển cảnh ảnh mượt mà, `AnimatedHeartButton`, và `FadeSlideIn`.
  - [app_button.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/widgets/app_button.dart): Tích hợp phản hồi lực chạm lò xo `PressableScale`.
  - [app_router.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/app/router/app_router.dart): Tích hợp hiệu ứng chuyển trang `CustomTransitionPage` (Slide up & Fade).
- **Kết quả:** Giao diện chuyển động sống động, tinh tế theo phong cách Airbnb Luxury & Apple Minimalist. Đạt 19/19 tests và 0 linter issues.
