# MA TRẬN ĐỐI CHIẾU CHỨC NĂNG (FEATURE_PARITY_MATRIX)

**Đối chiếu:** FRONTEND GỐC ↔ BACKEND GỐC ↔ FLUTTER HIỆN TẠI  
**Ngày cập nhật:** 10/10/2026  
**Quy chuẩn trạng thái:**
- `COMPLETED_VERIFIED`: Đã hoàn thiện mã nguồn, kiểm chứng cấu trúc và có bài kiểm thử tương ứng.
- `IMPLEMENTED_UNVERIFIED`: Đã kết nối mã nguồn, DTO và Repository với Backend API, chờ khởi động server thật.
- `PARTIAL`: Đã triển khai một phần.
- `NOT_STARTED`: Chưa bắt đầu triển khai.
- `BLOCKED`: Bị phụ thuộc dịch vụ ngoài (ví dụ WebSocket socket.io).
- `NOT_APPLICABLE`: Tính năng chỉ dành riêng cho Web/Desktop (Admin/Host Portal quản trị lớn).

---

## BẢNG MA TRẬN ĐỐI CHIẾU CHI TIẾT

| Module | Chức năng gốc | File Frontend | Backend API | Flutter hiện có | Phần còn thiếu | Trạng thái |
|---|---|---|---|---|---|---|
| **Discovery / Home** | Danh sách villa nổi bật & banner | `src/views/pages/Home/HomePage.tsx` | `GET /api/listings` | `home_screen.dart`, `villa_repository_impl.dart` | Không | `COMPLETED_VERIFIED` |
| **Discovery / Card** | PropertyCard hiển thị ảnh, thông số, huy hiệu, giá | `src/views/components/stays/StayCard.tsx` | `GET /api/listings` | `property_card.dart`, `property_image_carousel.dart` | Không (đạt chuẩn FLUTTER_RULES) | `COMPLETED_VERIFIED` |
| **Search & Filter** | Lọc theo địa điểm, ngày lưu trú, số khách | `src/views/pages/Search/SearchPage.tsx` | `GET /api/listings` | `search_screen.dart`, `booking_date_range_picker.dart` | Không (đã truyền checkIn/checkOut/guests) | `COMPLETED_VERIFIED` |
| **Property Detail** | Chi tiết villa, thông số 2 tầng, ảnh, FAQ | `src/views/pages/ListingDetail/ListingDetailPage.tsx` | `GET /api/listings/:id` | `villa_detail_screen.dart`, `mobile_spec_summary.dart` | Không | `COMPLETED_VERIFIED` |
| **Availability & Pricing** | Bảng giá từng đêm và kiểm tra lịch trống | `src/views/pages/ListingDetail/ListingDetailPage.tsx` | `GET /api/listings/:id/availability` | `daily_price_breakdown.dart`, `booking_action_bar.dart` | Không (gọi `/api/listings/:id/availability`) | `COMPLETED_VERIFIED` |
| **Inquiry & Contact** | Tư vấn nhanh qua Hotline và Zalo OA | `src/views/pages/Contact/ContactPage.tsx` | N/A (External links) | `contact_service.dart` | Không (Native launcher URL hoàn chỉnh) | `COMPLETED_VERIFIED` |
| **Wishlist** | Danh sách yêu thích, đồng bộ backend | `src/views/pages/Wishlist/WishlistPage.tsx` | `GET /api/wishlist`, `POST /api/wishlist/:id`, `DELETE /api/wishlist/:id` | `favorites_screen.dart`, `wishlist_repository_impl.dart` | Không (đồng bộ backend khi auth, fallback local) | `COMPLETED_VERIFIED` |
| **Auth / Login** | Đăng nhập bằng Email/SĐT + Mật khẩu | `src/views/pages/Auth/LoginPage.tsx` | `POST /api/auth/login` | `login_screen.dart`, `auth_repository_impl.dart` | Không | `COMPLETED_VERIFIED` |
| **Auth / Register** | Đăng ký tài khoản mới | `src/views/pages/Auth/RegisterPage.tsx` | `POST /api/auth/register` | `register_screen.dart`, `auth_repository_impl.dart` | Không | `COMPLETED_VERIFIED` |
| **Auth / Forgot Pwd** | Quên mật khẩu qua OTP | `src/views/pages/Auth/ForgotPasswordPage.tsx` | `POST /api/auth/forgot-password`, `/reset-password` | `forgot_password_screen.dart`, `auth_repository_impl.dart` | Không | `COMPLETED_VERIFIED` |
| **Auth / Session** | Quản lý phiên JWT, profile & Logout | `src/store/authStore.ts` | `GET /api/auth/me`, `POST /api/auth/logout` | `auth_notifier.dart`, `secure_storage_service.dart` | Không | `COMPLETED_VERIFIED` |
| **Trips / Bookings** | Danh sách đặt phòng (Active, Completed, Cancelled) | `src/views/pages/Trips/index.tsx` | `GET /api/bookings/mine` | `trips_screen.dart`, `booking_repository_impl.dart` | Không | `COMPLETED_VERIFIED` |
| **Trips / Cancel** | Khách hủy đặt phòng kèm lý do | `src/views/pages/Trips/index.tsx` | `POST /api/bookings/:id/cancel` | `trips_screen.dart`, `booking_repository_impl.dart` | Không | `COMPLETED_VERIFIED` |
| **Reviews** | Đọc nhận xét của khách & phản hồi của chủ nhà | `src/views/pages/ListingDetail/` | `GET /api/listings/:id/reviews` | `review_list_widget.dart`, `review_repository_impl.dart` | Không | `COMPLETED_VERIFIED` |
| **Navigation Shell** | Thanh điều hướng 4 tab (Khám phá, Yêu thích, Chuyến đi, Cài đặt) | `src/views/layouts/MainLayout.tsx` | N/A | `app_router.dart` (StatefulShellRoute) | Không | `COMPLETED_VERIFIED` |
| **Host Portal** | Quản lý chỗ nghỉ, lịch, thanh toán của chủ nhà | `src/views/pages/Host/*` | `/api/host/*` | N/A | Giữ nguyên trên Web/Desktop | `NOT_APPLICABLE` |
| **Admin Panel** | Quản trị người dùng, duyệt bài đăng | `src/views/pages/Admin/*` | `/api/admin/*` | N/A | Chỉ dành riêng cho Web Admin | `NOT_APPLICABLE` |
| **Messages / Chat** | Nhắn tin thời gian thực | `src/views/pages/Messages/` | `GET /api/conversations`, WebSocket | N/A | Cấu hình WebSocket trên mobile | `BLOCKED` |
