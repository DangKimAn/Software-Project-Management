# The Palm Villa — Phân hệ Backend API, AI Vision Services & Background Workers

> Máy chủ RESTful API, WebSocket thời gian thực, Thị giác máy tính AI (KYC & gắn nhãn ảnh) và Tiến trình đồng bộ nền phục vụ nền tảng đặt biệt thự nghỉ dưỡng **The Palm Villa**.

[![Backend CI](https://github.com/DangKimAn/Software-Project-Management/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/DangKimAn/Software-Project-Management/actions/workflows/backend-ci.yml)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D18.0.0-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![Express 5](https://img.shields.io/badge/Express-5.2.1-000000?logo=express&logoColor=white)](https://expressjs.com)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9.3-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)

*(Quay lại tài liệu tổng quan toàn hệ thống tại [`../README.md`](../README.md))*

---

## 1. Kiến trúc kỹ thuật và Quy ước giao thức

Phân hệ Backend được xây dựng trên nền tảng **Node.js + Express 5 + TypeScript + Sequelize (`mysql2`)**, kết nối cơ sở dữ liệu quan hệ **MySQL 8.0 / TiDB Cloud Serverless** (hỗ trợ mã hóa SSL/TLS).

### Chuẩn hóa phản hồi HTTP (Unified Envelope Contract)

Mọi phản hồi từ hệ thống `/api/*` đều tuân thủ nghiêm ngặt cấu trúc JSON đồng nhất kèm mã truy vết `requestId`:

- **Thành công (`2xx`):**
  ```json
  {
    "success": true,
    "message": "OK",
    "data": {}
  }
  ```
- **Thất bại / Lỗi nghiệp vụ (`4xx`, `5xx`):**
  ```json
  {
    "success": false,
    "message": "Mô tả lỗi chuẩn hóa",
    "errors": []
  }
  ```

---

## 2. Cấu trúc 25 Phân hệ Nghiệp vụ (`src/modules/`)

| Nhóm miền (Domain Group) | Các mô-đun thành phần (`src/modules/*`) | Trách nhiệm cốt lõi |
| :--- | :--- | :--- |
| **Xác thực & Người dùng** | `auth`, `users`, `notifications` | Đăng ký/Đăng nhập, OTP băm mật mã, Google OAuth 2.0, JWT xoay vòng qua HttpOnly Cookie, RBAC, FCM Push & thông báo trong ứng dụng. |
| **Danh mục & Thị giác AI** | `listings`, `amenities`, `blogs`, `wishlist`, `ai`, `exchange-rates` | Tra cứu biệt thự công khai theo khu vực/bản đồ & kiểm tra lịch trống, phân tích nhãn ảnh biệt thự & bóc tách CCCD (`gpt-4.1-mini`), tỷ giá ngoại tệ. |
| **Đặt phòng & Thanh toán** | `bookings`, `payments`, `coupons`, `reviews`, `conversations` | Máy trạng thái đơn đặt phòng 11 trạng thái, khóa ngày `booking_date_locks`, thanh toán lũy đẳng VNPay/MoMo/VietQR, áp mã giảm giá, nhắn tin thời gian thực Socket.IO. |
| **Vận hành Chủ nhà (Host)** | `host-onboarding`, `host-applications`, `verifications`, `host-listings`, `host-sheet-sync`, `host-bank-account`, `payouts`, `banks`, `uploads` | Hồ sơ đăng ký Host, xác minh KYC qua Cloudflare R2 Private Signed URL, quản lý lịch 30 ngày, đồng bộ hai chiều Google Sheets, đối soát doanh thu. |
| **Quản trị & An toàn Sàn** | `admin`, `reports` | Thống kê toàn sàn, kiểm duyệt tin đăng, cấu hình phí nền tảng (*Platform Fee*), phê duyệt giải ngân 2 lớp (*Maker–Checker*), xử lý báo cáo vi phạm. |

### Tiến trình nền bất đồng bộ (Background Workers)

Khi máy chủ khởi chạy (`src/server.ts`), hai tiến trình nền tự động kích hoạt và hỗ trợ dừng an toàn (*Graceful Shutdown* khi nhận tín hiệu `SIGINT`/`SIGTERM`):
1. **`booking-expiration.service.ts`:** Quét định kỳ mỗi `30s` để thu hồi các đơn `pending_payment` quá hạn giữ chỗ `15 phút`, giải phóng khóa ngày trong `booking_date_locks` và ghi lịch sử trạng thái.
2. **`host-sheet-sync.worker.ts`:** Đồng bộ hai chiều lịch đặt phòng và trạng thái phòng trống giữa hệ thống cơ sở dữ liệu và bảng tính Google Sheets riêng của từng Chủ nhà.

---

## 3. Cấu hình Môi trường (`backend/.env`)

Sao chép tệp mẫu trước khi khởi chạy:

```bash
cp .env.example .env
```

Các nhóm biến môi trường bắt buộc và trọng yếu:
- **Máy chủ & Mạng:** `PORT` (mặc định `7000` khi chạy cục bộ, `5000` trong Docker), `NODE_ENV`, `CLIENT_ORIGIN`, `CORS_ORIGINS`.
- **MySQL / TiDB:** `MYSQLHOST`, `MYSQLPORT`, `MYSQLDATABASE`, `MYSQLUSER`, `MYSQLPASSWORD`, `MYSQL_SSL`, `MYSQL_SSL_CA`.
- **Bảo mật & Mật mã (tối thiểu 32 ký tự):** `JWT_SECRET_KEY`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `TOKEN_HASH_SECRET`, `OTP_HASH_SECRET`, `COOKIE_SECRET`.
- **AI Thị giác máy tính (OpenAI Vision):** `OPENAI_API_KEY`, `OPENAI_VISION_MODEL=gpt-4.1-mini`.
- **Cloudflare R2:** `R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_PUBLIC_BASE_URL`, `R2_PRIVATE_BUCKET`, `R2_PRIVATE_SIGNED_URL_EXPIRES_SECONDS`.
- **Thanh toán, FCM & Google Sheets:** `VNPAY_*`, `MOMO_*`, `FIREBASE_SERVICE_ACCOUNT_PATH`, `GOOGLE_SHEETS_SYNC_ENABLED`, `GOOGLE_SHEETS_SERVICE_ACCOUNT_PATH`.

---

## 4. Quản trị Lược đồ Cơ sở dữ liệu & Di trú (Migrations)

Hệ thống bao gồm **52 tệp định nghĩa mô hình Sequelize (`src/models/`)** và **22 tệp kịch bản di trú lũy đẳng (`database/migrations/`)** thiết lập hơn 49 bảng quan hệ thực tế:

```bash
# Kiểm tra kết nối tới MySQL / TiDB
npm run db:check

# Đảm bảo lược đồ nền tảng lúc khởi chạy
npm run db:ensure-runtime-schema
npm run db:ensure-final-modules

# Thực thi toàn bộ chuỗi 22 migration an toàn theo đúng thứ tự phụ thuộc
npm run db:migrate

# Khởi tạo dữ liệu mẫu phục vụ phát triển cục bộ
npm run db:seed
```

---

## 5. Danh mục Điểm cuối API Trọng tâm (Core API Endpoints)

| Phân nhóm | Đường dẫn cơ sở (Base Route) | Mô tả chức năng chính |
| :--- | :--- | :--- |
| **Giám sát Sức khỏe** | `GET /api/health`, `GET /api/health/db` | Kiểm tra trạng thái hoạt động của tiến trình Express và kết nối MySQL. |
| **Xác thực (`auth`)** | `/api/auth/*` | `register`, `login`, `logout`, `refresh`, `send-otp`, `forgot-password`, `reset-password`, `google`, `me`. |
| **Biệt thự & Tiện ích** | `/api/listings/*`, `/api/amenities`, `/api/blogs` | Danh sách biệt thự công khai, lọc khu vực/bản đồ, chi tiết, lịch trống, nội quy, đánh giá và bài viết cẩm nang. |
| **Thị giác máy tính AI** | `/api/ai/listings/*`, `/api/ai/identity/*` | Phân tích tự động nhãn không gian ảnh biệt thự và bóc tách thông tin CCCD phục vụ KYC. |
| **Đặt phòng & Thanh toán** | `/api/bookings/*`, `/api/payments/*`, `/api/coupons/*` | Tạo đơn giữ chỗ, tra cứu đơn, hủy đơn, thanh toán & Webhook IPN VNPay/MoMo, áp dụng mã giảm giá. |
| **Tương tác Khách hàng** | `/api/wishlist/*`, `/api/conversations/*`, `/api/reviews/*`, `/api/notifications/*` | Lưu biệt thự yêu thích, nhắn tin trực tiếp với Chủ nhà, gửi/phản hồi đánh giá, quản lý thông báo & FCM token. |
| **Không gian Chủ nhà** | `/api/host/*`, `/api/host/listings/*`, `/api/host/bookings/*`, `/api/host/sheet-sync/*` | Đăng ký Host, KYC, quản lý biệt thự & lịch 30 ngày, đồng bộ Google Sheets, tài khoản nhận tiền & đối soát. |
| **Quản trị Hệ thống** | `/api/admin/*`, `/api/users/*`, `/api/reports/*`, `/api/exchange-rates` | Quản trị người dùng RBAC, duyệt tin & KYC, giải ngân Maker–Checker, cấu hình phí sàn, tỷ giá tiền tệ. |

---

## 6. Vận hành và Kiểm thử Tự động

```bash
# Chạy máy chủ ở chế độ phát triển (tự động tải lại qua nodemon + ts-node)
npm run dev

# Kiểm tra nghiêm ngặt kiểu dữ liệu tĩnh TypeScript (trên cả mã nguồn và bộ kiểm thử)
npm run typecheck

# Biên dịch sang mã JavaScript sản xuất (dist/) và khởi chạy
npm run build
npm start

# Chạy bộ kiểm thử nhanh (Auth, Listings, Bookings)
npm run test:quick

# Thực thi toàn bộ 25 bộ kiểm thử tích hợp (Auth/RBAC, Tương tranh đặt phòng, Thanh toán, AI Vision, Sheet Sync...)
npm test
```
