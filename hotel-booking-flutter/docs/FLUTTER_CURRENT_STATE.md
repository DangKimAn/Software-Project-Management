# BÁO CÁO HIỆN TRẠNG FLUTTER HIỆN TẠI (FLUTTER_CURRENT_STATE)

**Dự án:** `hotel-booking-flutter`  
**Ngày kiểm toán:** 10/10/2026  
**Vị trí:** `D:\MANAGER-PROJECT\hotel-booking-flutter`  
**Tiêu chuẩn thiết kế:** Airbnb Luxury × Apple Clean Minimalist (Coral `#FF385C`, Surface `#FFFFFF`, Text `#222222`)  
**Quy tắc:** `hotel-booking-flutter/FLUTTER_RULES.md` & `d:\MANAGER-PROJECT\FLUTTER_RULES.md`  

---

## 1. TỔNG QUAN HẠ TẦNG VÀ CÔNG NGHỆ

| Thành phần | Công nghệ / Trạng thái | Đánh giá thực tế |
|---|---|---|
| **Package Name** | `hotel_booking_flutter` | [pubspec.yaml](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/pubspec.yaml) chuẩn hóa, không phụ thuộc tên cũ |
| **Android Application ID** | `com.bronc3.hotel_booking_flutter` | Đã cấu hình flavors `dev`, `staging`, `prod` trong [build.gradle](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/android/app/build.gradle) |
| **iOS Bundle Identifier** | `com.bronc3.hotelBookingFlutter` | Đã cấu hình Info.plist với URL schemes (`tel`, `zalo`, `http`, `https`) |
| **State Management** | `flutter_riverpod` (v2.6.1) | Clean MVVM + Repository pattern |
| **Routing** | `go_router` (v14.8.1) | Hỗ trợ StatefulShellRoute, Bottom Navigation Bar |
| **HTTP Client** | `dio` (v5.8.0+1) | Timeout, logging interceptor, typed AppFailure error mapping |
| **Storage & Security** | `flutter_secure_storage` & `shared_preferences` | Phân tách rõ secure storage cho token và preferences cho UI state |
| **Icons** | `lucide_icons_flutter` (v1.1.0) | Tuân thủ tuyệt đối quy định không dùng icon ngoại lai |
| **L10n** | `flutter_localizations`, ARB files | Hỗ trợ 3 ngôn ngữ: `vi`, `en`, `ko` ([l10n](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/l10n)) |
| **Dữ liệu mẫu / Mock** | **0% MOCK / 0% SEED** | Đã loại bỏ hoàn toàn MockVillaRepository, kết nối trực tiếp với Repository Pattern |

---

## 2. PHÂN LOẠI CHI TIẾT TÌNH TRẠNG CÁC MODULE

### A. Đã hoàn thành và kiểm chứng (COMPLETED_VERIFIED)
1. **Design System & Theme Tokens:**
   - [app_colors.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/app/theme/app_colors.dart): Bộ màu thương hiệu Coral `#FF385C`, `#E00B41`, BrandSoft `#FFE8EC`, TextStrong `#222222`, TextMuted `#717171`.
   - [app_typography.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/app/theme/app_typography.dart): Typography scale Display, SectionHeading, CardTitle, Body, Label, Caption.
   - [app_spacing.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/app/theme/app_spacing.dart), [app_radii.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/app/theme/app_radii.dart): Hệ quy chuẩn spacing (4, 8, 12, 16, 20, 24, 32) và bo góc chuẩn.
   - [app_theme.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/app/theme/app_theme.dart): Material 3 ThemeData cấu hình cho toàn app.
2. **Core Utilities & Infrastructure:**
   - [dio_client.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/core/network/dio_client.dart): Dio singleton, request/response logging, typed AppFailure.
   - [secure_storage_service.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/core/security/secure_storage_service.dart): Android EncryptedSharedPreferences & iOS Keychain.
   - [preferences_service.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/core/storage/preferences_service.dart): SharedPreferences wrapper.
   - [booking_date.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/core/date/booking_date.dart): Độc lập timezone thiết bị, tuân thủ timezone Việt Nam (`Asia/Ho_Chi_Minh`), ISO `YYYY-MM-DD`. Đã có unit test đạt yêu cầu.
   - [currency_formatter.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/core/formatters/currency_formatter.dart): Format tiền VND chuẩn.
   - [app_failure.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/core/errors/app_failure.dart): Hệ thống lỗi kiểu dữ liệu nghiêm ngặt (`NetworkFailure`, `ServerFailure`, `AuthFailure`, `NotFoundFailure`, `ValidationFailure`).
3. **Shared UI Components:**
   - [app_button.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/widgets/app_button.dart): Hỗ trợ Primary, Secondary, Outline, Ghost, Danger với loading state và min touch target 48px.
   - [app_card.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/widgets/app_card.dart), [app_text_field.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/widgets/app_text_field.dart), [app_loading.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/widgets/app_loading.dart), [app_error_view.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/widgets/app_error_view.dart), [app_empty_view.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/widgets/app_empty_view.dart).
   - [villa_badge.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/widgets/villa_badge.dart): Huy hiệu ưu tiên (`featured > new > near-beach > saltwater > group`).
   - [price_display.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/shared/widgets/price_display.dart): Hiển thị giá đêm chính và giá thứ 7.
4. **Booking Inquiry & Contact Integration:**
   - [contact_service.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/booking_inquiry/domain/services/contact_service.dart): Native launcher Zalo OA và Hotline điện thoại qua `url_launcher`. Có unit test đầy đủ.

---

### B. Đã có mã nguồn nhưng cần chỉnh sửa / kết nối Backend thực (PARTIAL / TO_ADAPT)
1. **Villa Repository ([villa_repository_impl.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villas/data/repositories/villa_repository_impl.dart)):**
   - *Hiện trạng:* Đang trỏ đường dẫn nhầm sang `/v1/villas` thay vì `/api/listings`.
   - *Giải pháp:* Cập nhật ánh xạ endpoint sang `/api/listings`, `/api/listings/:id`, `/api/listings/:id/availability`. Ánh xạ DTO từ backend response envelope (`{ success: true, data: { items: [...] } }`).
2. **Discovery & Home Screen ([home_screen.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/home/presentation/screens/home_screen.dart)):**
   - Đã có thanh tìm kiếm nhanh, banner và danh sách villa nổi bật tải từ Riverpod `villaListProvider`. Cần hỗ trợ refresh kéo xuống (Pull-to-refresh) và hiển thị phân trang.
3. **Villa Detail Screen ([villa_detail_screen.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villa_detail/presentation/screens/villa_detail_screen.dart)):**
   - Đã có Carousel ảnh, thông số 2 tầng ([mobile_spec_summary.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villa_detail/presentation/widgets/mobile_spec_summary.dart)), bảng giá ([daily_price_breakdown.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villa_detail/presentation/widgets/daily_price_breakdown.dart)), FAQ ([property_faq_section.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villa_detail/presentation/widgets/property_faq_section.dart)), Action Bar ([booking_action_bar.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/villa_detail/presentation/widgets/booking_action_bar.dart)).
   - *Còn thiếu:* Tích hợp danh sách đánh giá từ backend `/api/listings/:id/reviews` và liên kết đặt phòng / tư vấn.
4. **Favorites Screen ([favorites_screen.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/features/favorites/presentation/screens/favorites_screen.dart)):**
   - *Hiện trạng:* Lưu trữ tạm trên state Riverpod.
   - *Giải pháp:* Tích hợp hai chế độ: Nếu người dùng đã đăng nhập thì đồng bộ với backend `/api/wishlist` (GET, POST, DELETE); nếu là khách vãng lai thì lưu trữ qua PreferencesService.

---

### C. Chưa triển khai (NOT_STARTED - Cần bổ sung ngay)
1. **Module Authentication (`features/auth/`):**
   - Màn hình Đăng nhập (Login), Đăng ký (Register), Quên mật khẩu (ForgotPassword).
   - `AuthRepository` kết nối `/api/auth/login`, `/api/auth/register`, `/api/auth/me`, `/api/auth/logout`.
   - Quản lý JWT Token qua `SecureStorageService` và gắn `Authorization: Bearer <token>` vào `DioClient`.
2. **Module Chuyến đi / Đặt phòng (`features/trips/`):**
   - Màn hình Danh sách chuyến đi (TripsScreen) phân chia tab: Đang diễn ra (Upcoming/Active), Đã hoàn thành (Completed), Đã hủy (Cancelled).
   - Kết nối API `GET /api/bookings/mine`, `GET /api/bookings/:id`, `POST /api/bookings/:id/cancel`.
3. **Module Đánh giá (`features/reviews/`):**
   - Hiển thị nhận xét của khách và phản hồi của chủ nhà trên trang chi tiết villa.
4. **Deep Linking & Mở rộng Router:**
   - Đăng ký các route `/login`, `/register`, `/forgot-password`, `/trips` vào [app_router.dart](file:///D:/MANAGER-PROJECT/hotel-booking-flutter/lib/app/router/app_router.dart).
