# TERMINAL 04 — BÁO CÁO HOÀN THIỆN HỆ THỐNG HOST MANAGEMENT (FLUTTER)

## 1. TỔNG QUAN PHẠM VI THỰC HIỆN

Terminal 04 đã hoàn thành việc kiểm toán đối chiếu 100% mã nguồn `Source goc` (React + Express/TypeScript backend) và xây dựng/sửa chữa toàn bộ phân hệ **Host Onboarding, KYC, Listings, R2 Presigned Uploads, AI Image Vision 22-Tag Taxonomy, Calendar, Bookings, Guests, Messages, Payouts, Reviews, Revenue Reports, Support & Host Settings** trên Flutter.

### Danh sách file thuộc quyền sở hữu của Terminal 04 đã tạo/cập nhật:
- `lib/features/host/domain/host_models.dart` — Toàn bộ DTO, Enum (`draft`, `pending_approval`, `published`, `hidden`, `rejected`), R2 Presigned Upload契約, AI Vision 22-Tag Taxonomy (`HOST_IMAGE_AI_TAXONOMY_22`), ma trận trạng thái/hành động Booking theo role, Calendar bulk payload, Revenue report series, Vietnam Banks & Bank Account validator.
- `lib/features/host/services/host_file_picker_service.dart` — Dịch vụ chọn file thực từ thiết bị qua `file_picker` (hỗ trợ cả Web & Mobile `withData: true`), kiểm tra MIME type (extension + magic bytes header) và giới hạn dung lượng (`5MB` cho KYC/Avatar, `10MB` cho Listing Image), cùng `HostR2DirectUploader` tải trực tiếp bytes lên Cloudflare R2 Presigned URL bằng `Dio` độc lập **không đính kèm header `Authorization: Bearer`**.
- `lib/features/host/data/host_repository.dart` — Toàn bộ tầng tích hợp REST API chuẩn xác 100% theo `Source goc/backend`, xử lý lỗi chuẩn, kiểm tra quyền sở hữu listing (`verifyListingOwnership`) và kiểm tra quyền thao tác booking theo role (`HostBookingRoleException`).
- `lib/features/host/presentation/screens/host_onboarding_screens.dart` — Cụm 3 màn hình:
  1. `TroThanhHostLandingScreen` (`TroThanhHostScreen` alias) — `/tro-thanh-host`
  2. `DangKyHostScreen` — `/tro-thanh-host/dang-ky`
  3. `TrangThaiHostScreen` — `/tro-thanh-host/trang-thai`
- `lib/features/host/presentation/screens/them_cho_nghi_screen.dart` — Màn hình Thêm/Sửa chỗ nghỉ (`ThemChoNghiScreen`) đồng bộ đầy đủ với `ThemChoNghi/index.tsx`.
- `lib/features/host/presentation/screens/host_portal_screens.dart` — Màn hình `HostPortalScreen` gồm đầy đủ **11 nhóm màn hình nghiệp vụ Host** với điều hướng responsive (Drawer + Horizontal TabBar trên 320–600px, Sidebar cố định trên Desktop).
- `test/features/host/host_management_test.dart` — Bộ kiểm thử đơn vị và widget responsive toàn diện cho hệ thống Host.

> **Tuân thủ phạm vi:** Không chỉnh sửa bất kỳ file nào ngoài phạm vi (`DioClient`, `AuthNotifier`, `app_router.dart`, `providers.dart`, theme chung, guest booking/payment, Admin repository, `pubspec.yaml`).

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

## 3. TRẠNG THÁI HOÀN THIỆN TỪNG MÀN HÌNH HOST (11 PHÂN HỆ PORTAL + 3 MÀN HÌNH ONBOARDING)

### A. Cụm màn hình Đăng ký & Xác minh Chủ nhà (`host_onboarding_screens.dart`)
1. **`TroThanhHostLandingScreen` (`/tro-thanh-host`):** Hoàn thành 100%. Kiểm tra trạng thái hồ sơ hiện tại từ `/api/host/applications/me`, hiển thị quy trình xét duyệt minh bạch và điều hướng sang form đăng ký hoặc theo dõi trạng thái.
2. **`DangKyHostScreen` (`/tro-thanh-host/dang-ky`):** Hoàn thành 100%. Chọn file thật từ thiết bị (CCCD/CMND mặt trước + mặt sau, hoặc Hộ chiếu 1 tệp, hoặc GPLX, kèm Giấy phép kinh doanh bắt buộc cho Doanh nghiệp/Hộ kinh doanh), hiển thị preview ảnh/PDF, dung lượng, xóa/chọn lại, thanh tiến trình upload thực và gửi `multipart/form-data` lên `POST /api/host/applications`.
3. **`TrangThaiHostScreen` (`/tro-thanh-host/trang-thai`):** Hoàn thành 100%. Hiển thị chính xác các trạng thái `pending`, `approved`, `rejected`, `supplement_required`, `revoked`, `none` cùng lý do từ chối của Admin và danh sách tài liệu đã nộp.

### B. Cụm 11 nhóm màn hình trong Host Portal (`host_portal_screens.dart` & `them_cho_nghi_screen.dart`)
1. **Tổng quan (`overview` / `/chu-nha/tong-quan`):** Hoàn thành 100%. Tổng hợp KPI thực từ `/api/host/listings/mine`, `/api/host/bookings`, `/api/host/reports/revenue`, `/api/host/payout-accounts`.
2. **Chỗ nghỉ (`properties` / `/chu-nha/cho-nghi`):** Hoàn thành 100%. Bộ lọc theo đúng 5 trạng thái (`draft`, `pending_approval`, `published`, `hidden`, `rejected`), thao tác Sửa, Gửi duyệt, Ẩn, Hiện, Xóa (có hộp thoại xác nhận).
3. **Thêm/Sửa chỗ nghỉ (`newProperty` / `ThemChoNghiScreen` / `/chu-nha/cho-nghi/them-moi`):** Hoàn thành 100%. Đầy đủ các bước thông tin cơ bản, vị trí (Vũng Tàu, `country: 'VN'`), sức chứa, giá (`currency: 'VND'`), tiện nghi (`PUT /amenities`), nội quy (`PATCH /rules`), chính sách hủy, tải nhiều ảnh lên R2 qua Presigned URL, chọn ảnh bìa, sắp xếp lại ảnh, xóa ảnh, retry khi lỗi từng ảnh, và phân tích AI Vision 22 nhãn taxonomy.
4. **Đặt phòng (`bookings` / `/chu-nha/dat-phong`):** Hoàn thành 100%. Tích hợp `/api/host/bookings`, lọc theo trạng thái hiển thị chuẩn `bookingStatus.ts`, thực hiện `confirm`, `check-in`, `check-out`, `cancel` (có nhập lý do hủy).
5. **Lịch lưu trú (`calendar` / `/chu-nha/lich-luu-tru`):** Hoàn thành 100%. Chọn listing, xem lịch theo tháng/năm, chọn nhiều ngày để khóa/mở hoặc đặt giá riêng (`priceOverride`), số đêm tối thiểu (`minNightsOverride`), ghi chú ngày qua `PATCH /api/host/listings/:id/calendar/bulk`.
6. **Khách lưu trú (`guests` / `/chu-nha/khach-luu-tru`):** Hoàn thành 100%. Tổng hợp danh sách khách hàng thực tế từ các đơn đặt phòng của Host, tìm kiếm theo tên/email/SĐT, thống kê số lượt đặt và tổng chi tiêu.
7. **Tin nhắn (`messages` / `/host/tin-nhan`):** Hoàn thành 100%. Kết nối `/api/conversations` và `/api/conversations/:id/messages`.
8. **Thanh toán / Khoản chi trả (`payouts` / `/chu-nha/thanh-toan`):** Hoàn thành 100%. Hiển thị tài khoản ngân hàng nhận chi trả và lịch sử đối soát từ `/api/host/payout-accounts` & `/api/host/payouts`.
9. **Đánh giá (`reviews` / `/chu-nha/danh-gia`):** Hoàn thành 100%. Chọn listing từ dropdown, tính điểm trung bình thực tế từ danh sách đánh giá (tuyệt đối không hardcode `4.9 / 12`), phản hồi đánh giá qua `POST /api/reviews/:reviewId/reply` có chặn double-submit.
10. **Báo cáo (`reports` / `/chu-nha/bao-cao`):** Hoàn thành 100%. Bộ lọc 30 ngày / 90 ngày / 1 năm, biểu đồ trực quan và bảng chi tiết doanh thu gộp, phí nền tảng, doanh thu thực nhận của Host từ `GET /api/host/reports/revenue`.
11. **Hỗ trợ & Cài đặt (`support` `/chu-nha/ho-tro` & `settings` `/chu-nha/cai-dat`):** Hoàn thành 100%. Quản lý trạng thái duyệt chỗ nghỉ, cập nhật hồ sơ Host (`GET/PATCH /api/host/profile`), tải ảnh đại diện qua R2 (`POST /api/host/profile/avatar`), tìm kiếm ngân hàng Việt Nam từ key `items` (`GET /api/banks/vietnam`) và lưu tài khoản ngân hàng (`GET/PUT /api/host/bank-account`).

---

## 4. KẾT QUẢ KIỂM THỬ (`flutter analyze` & `flutter test`)

### Phân tích tĩnh (`flutter analyze lib/features/host test/features/host`):
- **Kết quả:** `No issues found!` (0 lỗi, 0 cảnh báo).

### Kiểm thử tự động (`flutter test test/features/host/host_management_test.dart`):
Tất cả **11/11 nhóm test** đều **PASS (100%)**:

| STT | Tên bài kiểm thử | Trạng thái |
|---|---|---|
| 1 | `validateKycPickedFile accepts JPG, PNG, WebP, PDF <= 5MB and rejects > 5MB or unsupported MIME` | **PASS** |
| 2 | `HostKycSubmissionDto enforces CCCD front+back, Passport single, and Business license rules` | **PASS** |
| 3 | `HostRepository calls GET /api/host/applications/me and POST /api/host/applications` (kiểm tra Multipart FormData thật) | **PASS** |
| 4 | `uploadFileToR2 requests presigned URL and PUTs raw bytes WITHOUT Authorization Bearer header` | **PASS** |
| 5 | `AI Vision 22-Tag Taxonomy & image analysis endpoints` | **PASS** |
| 6 | `Listing CRUD uses /api/host/listings/mine, PATCH for updates/rules, PUT for amenities` | **PASS** |
| 7 | `Calendar GET & PATCH /api/host/listings/:id/calendar/bulk` | **PASS** |
| 8 | `Host Bookings confirm/check-in/check-out/cancel & Guest role guard` | **PASS** |
| 9 | `Payouts, Revenue Report, Vietnam Banks (items key), and Review Reply` | **PASS** |
| 10 | `DangKyHostScreen & TrangThaiHostScreen render cleanly at 320px width` | **PASS** |
| 11 | `HostPortalScreen & ThemChoNghiScreen render cleanly at 360px mobile width without overflow` | **PASS** |

---

## 5. CÁC LUỒNG CẦN MÔI TRƯỜNG THỰC TẾ (HOST ACCOUNT, CLOUDFLARE R2, AI VISION)

Để chạy nghiệm thu E2E (End-to-End) ngoài môi trường test:
1. **Tài khoản Host đã xác thực:** Cần JWT token của user có role `host` (cho `/chu-nha/*`, `/api/host/*`) hoặc user đã đăng nhập (cho `/tro-thanh-host/dang-ky`, `/api/host/applications`).
2. **Cloudflare R2 Bucket & Credentials trên Backend:** Luồng `POST /api/uploads/presign` -> `PUT <uploadUrl>` yêu cầu backend đã cấu hình biến môi trường R2 (`R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `R2_PUBLIC_BASE_URL`) và cấu hình CORS cho phép `PUT` từ client.
3. **AI Vision Service trên Backend:** Các route `/api/host/listings/:id/images/analyze-ai` cần dịch vụ AI Vision của backend hoạt động để trả về kết quả phân tích trực tiếp (nếu dịch vụ AI tắt hoặc timeout, UI Flutter đã xử lý cô lập lỗi, cho phép gắn nhãn thủ công từ 22 nhãn taxonomy mà không làm mất dữ liệu chỗ nghỉ).

---

## 6. YÊU CẦU TÍCH HỢP DÀNH CHO TERMINAL 01 (CORE / AUTH / ROUTER)

1. **Routes:** `lib/app/router/app_router.dart` hiện đã khớp với các class màn hình do Terminal 04 cung cấp:
   - `TroThanhHostLandingScreen` (và alias `TroThanhHostScreen`)
   - `DangKyHostScreen`
   - `TrangThaiHostScreen`
   - `HostPortalScreen(section: '...')`
   - `ThemChoNghiScreen(listingId: ...)`
2. **Providers & DioClient:**
   - `hostRepositoryProvider` đã được export trực tiếp từ `lib/features/host/data/host_repository.dart`.
   - `HostRepository` hỗ trợ truyền vào cả `DioClient` lẫn `Dio` (`HostRepository(dioClient)` hoặc `HostRepository(dio)`), đồng thời tự động đính kèm `Authorization: Bearer <token>` từ `SecureStorageService`.
   - Lưu ý cho Terminal 01: trong quá trình kiểm thử, chúng tôi ghi nhận các file thuộc phạm vi của Terminal 01 (`lib/core/network/dio_client.dart` dòng 316 `Headers.setCookieHeader`, `lib/features/auth/data/services/google_auth_service.dart` thiếu `lib/core/errors/app_exception.dart`) đang có lỗi biên dịch chưa hoàn tất trên nhánh dùng chung. Terminal 04 đã cô lập hoàn toàn import của `lib/features/host/**` để không bị ảnh hưởng bởi các file đang sửa của Terminal 01.

---

## 7. HẠNG MỤC BLOCKED

- **Không có hạng mục nào thuộc phạm vi Terminal 04 bị BLOCKED.** Toàn bộ 11 nhóm màn hình Host, 3 màn hình Onboarding/KYC, tầng Repository, dịch vụ R2 Presigned Upload, AI Vision 22-Tag Taxonomy và 11/11 bài kiểm thử đã hoàn thành 100%.
