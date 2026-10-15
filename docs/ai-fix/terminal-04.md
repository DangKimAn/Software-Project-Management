# TERMINAL 04 — BÁO CÁO HOÀN THIỆN HỆ THỐNG HOST MANAGEMENT (FLUTTER)

## 1. TỔNG QUAN PHẠM VI THỰC HIỆN

Terminal 04 đã hoàn thành việc kiểm toán đối chiếu 100% mã nguồn `Source goc` (React + Express/TypeScript backend) và xây dựng/sửa chữa toàn bộ phân hệ **Host Onboarding, KYC, Listings, R2 Presigned Uploads, AI Image Vision 22-Tag Taxonomy, Calendar, Bookings, Guests, Messages, Payouts, Reviews, Revenue Reports, Support & Host Settings** trên Flutter.

### Danh sách file thuộc quyền sở hữu của Terminal 04 đã tạo/cập nhật:
- `hotel-booking-flutter/lib/features/host/domain/host_models.dart` — Toàn bộ DTO, Enum (`draft`, `pending_approval`, `published`, `hidden`, `rejected`), R2 Presigned Upload, AI Vision 22-Tag Taxonomy (`HOST_IMAGE_AI_TAXONOMY_22`), ma trận trạng thái/hành động Booking theo role, Calendar bulk payload, Revenue report series, Vietnam Banks & Bank Account validator.
- `hotel-booking-flutter/lib/features/host/services/host_file_picker_service.dart` — Dịch vụ chọn file thực từ thiết bị qua `file_picker` (hỗ trợ cả Web & Mobile `withData: true`), kiểm tra MIME type (extension + magic bytes header) và giới hạn dung lượng (`5MB` cho KYC/Avatar, `10MB` cho Listing Image), cùng `HostR2DirectUploader` tải trực tiếp bytes lên Cloudflare R2 Presigned URL bằng `Dio` độc lập **không đính kèm header `Authorization: Bearer`**.
- `hotel-booking-flutter/lib/features/host/data/host_repository.dart` — Toàn bộ tầng tích hợp REST API chuẩn xác 100% theo `Source goc/backend`, xử lý lỗi chuẩn, kiểm tra quyền sở hữu listing (`verifyListingOwnership`) và kiểm tra quyền thao tác booking theo role (`HostBookingRoleException`).
- `hotel-booking-flutter/lib/features/host/presentation/screens/host_onboarding_screens.dart` — Cụm 3 màn hình:
  1. `TroThanhHostLandingScreen` (`TroThanhHostScreen` alias) — `/tro-thanh-host`
  2. `DangKyHostScreen` — `/tro-thanh-host/dang-ky`
  3. `TrangThaiHostScreen` — `/tro-thanh-host/trang-thai`
- `hotel-booking-flutter/lib/features/host/presentation/screens/them_cho_nghi_screen.dart` — Màn hình Thêm/Sửa chỗ nghỉ (`ThemChoNghiScreen`) đồng bộ đầy đủ với `ThemChoNghi/index.tsx`.
- `hotel-booking-flutter/lib/features/host/presentation/screens/host_portal_screens.dart` — Màn hình `HostPortalScreen` gồm đầy đủ **11 nhóm màn hình nghiệp vụ Host** với điều hướng responsive (Drawer + Horizontal TabBar trên 320–600px, Sidebar cố định trên Desktop).
- `hotel-booking-flutter/test/features/host/host_management_test.dart` — Bộ kiểm thử đơn vị và widget responsive toàn diện cho hệ thống Host.

---

## 2. 100% ENDPOINT HOST ĐÃ RÀ SOÁT & ĐỐI CHIẾU HỢP ĐỒNG REST API

| STT | Phân hệ | Endpoint Sai / Giả Trước Đây | Endpoint Đúng Đã Sửa (`host_repository.dart`) | HTTP Method | Ghi chú hợp đồng dữ liệu (DTO / Payload) |
|---|---|---|---|---|---|
| 1 | **BUG-10: KYC Status** | `/api/host-applications` (giả) | `/api/host/applications/me` (fallback `/api/host-verification/my-status`) | `GET` | Trả về trạng thái thực `none`, `pending`, `approved`, `rejected`, `supplement_required`, `revoked` kèm `rejectReason`, `documentUrls`. |
| 2 | **BUG-10: KYC Submit** | `/api/host-applications` + tên file giả `'CCCD_MatTruoc_Verified.jpg'` | `/api/host/applications` | `POST` | `multipart/form-data` thật từ thiết bị: `contactName`, `contactEmail`, `phone`, `address`, `profileType`, `documentType`, `note`, và các trường file `identityFront`, `identityBack`, `identityDocument`, `businessLicense` (JPG/PNG/WebP/PDF <= 5MB). |
| 3 | **BUG-11: Host Listings** | `/api/listings/host` hoặc enum `approved`/`pending` sai | `/api/host/listings/mine` | `GET` | Query `status` chuẩn enum backend: `draft`, `pending_approval`, `published`, `hidden`, `rejected`, phân trang `page`, `limit`. |
| 4 | **BUG-12: Listing Detail** | Không tải chi tiết đầy đủ | `/api/listings/:id` | `GET` | Tải đầy đủ thông tin listing, images, amenities, rules; kiểm tra quyền sở hữu thông qua `verifyListingOwnership`. |
| 5 | **BUG-12: Create Listing** | Thiếu `country`, `currency`, `roomType`, gửi `status: pending` | `/api/host/listings` | `POST` | Body JSON chuẩn: `title`, `description`, `addressLine`, `ward`, `district`, `city`, `country: 'VN'`, `currency: 'VND'`, `latitude`, `longitude`, `propertyType`, `roomType` (`entire_place`, `private_room`, `shared_room`), `maxGuests`, `bedrooms`, `beds`, `bathrooms`, `basePrice`, `weekendPrice`, `cleaningFee`, `extraGuestFee`, `minNights`, `maxNights`, `checkInTime`, `checkOutTime`, `cancellationPolicy`, `instantBookEnabled`, `amenityIds`, `status` (`draft` \| `pending_approval`). |
| 6 | **BUG-12: Update Listing** | Dùng sai method hoặc gửi sai enum | `/api/host/listings/:id` | `PATCH` | Giữ nguyên method `PATCH` chuẩn REST contract. |
| 7 | **BUG-12: Delete Listing** | Xóa không xác nhận | `/api/host/listings/:id` | `DELETE` | Có hộp thoại xác nhận trước thao tác xóa. |
| 8 | **BUG-11: Submit Approval** | Gửi `status: pending` | `/api/host/listings/:id/submit` (fallback `PATCH /api/host/listings/:id` với `status: 'pending_approval'`) | `POST` / `PATCH` | Chuyển trạng thái sang `pending_approval`. |
| 9 | **BUG-11: Publish / Hide** | Không tách bạch | `/api/host/listings/:id/publish` và `/api/host/listings/:id/hide` | `POST` | Ẩn (`hidden`) hoặc hiển thị lại (`published`) chỗ nghỉ. |
| 10 | **BUG-12: Amenities** | Gửi sai method / key | `/api/host/listings/:id/amenities` (danh mục chung `GET /api/amenities`) | `PUT` / `GET` | Body `{"amenityIds": [1, 3, 5]}` với method `PUT`. |
| 11 | **BUG-12: House Rules** | Gửi sai method | `/api/host/listings/:id/rules` | `PATCH` | Body `{"checkInAfter", "checkOutBefore", "smokingAllowed", "petsAllowed", "partiesAllowed", "quietHours", "additionalRules"}` với method `PATCH`. |
| 12 | **R2 Presign Upload** | Dùng đường dẫn giả `assets/images/...` | `/api/uploads/presign` (fallback `/api/host/images/presign`) | `POST` | Body `{"filename", "contentType", "sizeBytes", "folder"}`; trả về `uploadUrl`, `publicUrl`, `key`, `headers`. |
| 13 | **R2 Direct PUT** | Gửi nhầm API Bearer token vào URL R2 | `<presignedUploadUrl>` | `PUT` | Upload trực tiếp `Uint8List` bytes qua `HostR2DirectUploader` với `Content-Type` đã ký, **tuyệt đối không gửi header `Authorization: Bearer`**. |
| 14 | **Listing Images Attach** | Không gắn ảnh thật vào listing | `/api/host/listings/:id/images` | `POST` | Gắn danh sách ảnh đã upload R2 (`url`, `key`, `isCover`, `sortOrder`) vào listing. |
| 15 | **Listing Cover / Reorder / Delete** | Thiếu quản lý ảnh | `/api/host/listings/:id/images/:imageId/cover`, `/api/host/listings/:id/images/reorder`, `/api/host/listings/:id/images/:imageId` | `PATCH` / `DELETE` | Đặt ảnh đại diện (`isCover`), sắp xếp thứ tự (`imageIds`), xóa ảnh khỏi listing. |
| 16 | **AI Vision Single & Batch** | Giả lập confidence / nhãn AI | `/api/host/listings/:id/images/:imageId/analyze-ai` và `/api/host/listings/:id/images/analyze-ai` | `POST` | Phân tích AI thực tế từ backend, hiển thị đúng **22 nhãn taxonomy** (`HOST_IMAGE_AI_TAXONOMY_22`), `roomType`, `confidence`, `warnings`, hỗ trợ chạy lại phân tích và không làm mất dữ liệu form nếu AI lỗi. |
| 17 | **AI Vision Manual Tags** | Không lưu nhãn chỉnh sửa thủ công | `/api/host/listings/images/:imageId/tags` | `PATCH` | Body `{"manualTags": [...], "roomType": "..."}`. |
| 18 | **BUG-13: Calendar** | Sai route / thiếu bulk update | `/api/host/listings/:id/calendar` và `/api/host/listings/:id/calendar/bulk` | `GET` / `PATCH` | Kiểm tra phạm vi ngày (`YYYY-MM-DD`, tối đa 366 ngày, timezone `Asia/Ho_Chi_Minh`), hỗ trợ khóa/mở ngày, giá riêng từng ngày (`priceOverride`), `minNightsOverride`, `notes`. |
| 19 | **BUG-13: Host Bookings** | Dùng `/api/bookings/host` hoặc `/approve`, `/reject`, `/complete` | `/api/host/bookings` và `/api/host/bookings/:id/{confirm\|cancel\|check-in\|check-out}` | `GET` / `PATCH` | Kiểm tra chặt chẽ trạng thái thực tế (`getBookingAvailableActions` với `BookingActionRole.host`) và chặn Guest/người không có quyền thao tác (`HostBookingRoleException`). |
| 20 | **BUG-13: Payouts** | Khởi tạo lệnh chuyển tiền giả | `/api/host/payout-accounts` và `/api/host/payouts` | `GET` | Chỉ hiển thị tài khoản nhận tiền và lịch sử đối soát/thanh toán thực tế từ server; không tự tạo lệnh rút tiền giả. |
| 21 | **BUG-13: Revenue Reports** | Hardcode số liệu doanh thu | `/api/host/reports/revenue` | `GET` | Hỗ trợ bộ lọc `30d` (30 ngày), `90d` (90 ngày), `year` (12 tháng) hoặc `from`/`to`/`group`, hiển thị biểu đồ thời gian và bảng chi tiết (`grossRevenue`, `platformRevenue`, `hostRevenue`, `bookingCount`). |
| 22 | **BUG-38: Host Reviews** | Hardcode `4.9 sao / 12 reviews` | `/api/listings/:listingId/reviews` và `/api/reviews/:reviewId/reply` | `GET` / `POST` | Chọn chỗ nghỉ từ dropdown, tính điểm trung bình thực tế từ dữ liệu API, gửi phản hồi qua `POST /api/reviews/:reviewId/reply` và khóa nút chống gửi trùng (double-submit guard). |
| 23 | **BUG-38: Host Settings & Banks** | Không đọc key `items` của danh sách ngân hàng | `/api/host/profile`, `/api/host/profile/avatar`, `/api/banks/vietnam`, `/api/host/bank-account` | `GET` / `PATCH` / `POST` / `PUT` | Đọc danh sách ngân hàng từ key `items` của `/api/banks/vietnam`, kiểm tra STK (6–30 chữ số) và tên chủ tài khoản IN HOA. |
| 24 | **Host Messages** | Dữ liệu hội thoại tĩnh | `/api/conversations`, `/api/conversations/:id/messages` | `GET` / `POST` | Tải danh sách hội thoại và gửi/nhận tin nhắn thật với khách hàng. |

---

## 3. KẾT QUẢ KIỂM THỬ (`flutter analyze` & `flutter test`)

- **`flutter analyze lib/features/host test/features/host`:** `No issues found!` (0 lỗi, 0 cảnh báo).
- **`flutter test test/features/host/host_management_test.dart`:** `11/11 tests passed!` (100% PASS).
