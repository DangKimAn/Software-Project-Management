# The Palm Villa — Ứng dụng Đa nền tảng Flutter (Android, iOS & Web)

> Ứng dụng khách đa nền tảng phục vụ khám phá biệt thự bằng AI, đặt phòng trực tuyến, vận hành cổng Chủ nhà (*Host Studio*) và quản trị toàn sàn (*Admin Console*) cho hệ sinh thái **The Palm Villa**.

[![Flutter CI](https://github.com/DangKimAn/Software-Project-Management/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/DangKimAn/Software-Project-Management/actions/workflows/flutter_ci.yml)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.19.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Feature--first%20%2B%20MVVM%20%2B%20Riverpod-5C2D91)](https://docs.flutter.dev/app-architecture)
[![Design](https://img.shields.io/badge/Design-Airbnb%20Luxury%20%C3%97%20Apple%20Studio-FF385C)](../README.md)

*(Quay lại tài liệu tổng quan toàn hệ thống tại [`../README.md`](../README.md))*

---

## 1. Đặc tả Kỹ thuật Sản phẩm

| Thuộc tính | Thông số kỹ thuật |
| :--- | :--- |
| **Tên định danh gói (`pubspec.yaml`)** | `hotel_booking_flutter` (`1.0.0+1`) |
| **Nền tảng mục tiêu** | Android, iOS & Web SPA |
| **SDK yêu cầu** | Flutter `>=3.19.0` • Dart `>=3.3.0 <4.0.0` |
| **Kiến trúc phần mềm** | Feature-first + MVVM + Repository Pattern + Riverpod (`^2.6.1`) |
| **Điều hướng & Phân quyền** | `go_router` (`^14.8.1`) với Stateful Navigation Shell & RBAC Route Guard |
| **Ngôn ngữ thiết kế & Phông chữ** | Airbnb Luxury × Apple Studio Minimalist • Họ phông `SF Pro Display` / `SF Pro Text` / `SF Pro Rounded` • Biểu tượng `lucide_icons_flutter` |
| **Đa ngôn ngữ & Đa tiền tệ** | Tiếng Việt (`vi`), English (`en`), 한국어 (`ko`) • Quy đổi tỷ giá trực tiếp từ Backend |

---

## 2. Cấu trúc Thư mục Chuẩn (`146` tệp Dart / `15` Phân hệ)

```text
hotel-booking-flutter/
├── android/ & ios/ & web/           # Cấu hình nền tảng gốc Android (Flavors), iOS (Schemes) & Web SPA
├── assets/
│   ├── images/ & icons/             # Tài nguyên hình ảnh và biểu tượng cục bộ
│   └── fonts/                       # Bộ phông chữ SF Pro Display, SF Pro Text & SF Pro Rounded
├── config/
│   ├── dev.json                     # Cấu hình môi trường Development (kết nối localhost:7000)
│   ├── staging.json                 # Cấu hình môi trường Staging
│   └── prod.json                    # Cấu hình môi trường Production
├── lib/
│   ├── main.dart                    # Entrypoint Production
│   ├── main_dev.dart                # Entrypoint Development
│   ├── main_staging.dart            # Entrypoint Staging
│   ├── bootstrap.dart               # Khởi tạo Riverpod DI, SharedPreferences, Firebase & cấu hình
│   ├── app/
│   │   ├── app.dart                 # MaterialApp.router, Localization & Hệ thống chủ đề giao diện
│   │   ├── router/                  # Cấu hình GoRouter tập trung & bảo vệ định tuyến theo vai trò
│   │   ├── theme/                   # Design Tokens (Bảng màu, Typography SF Pro, Spacing, Radii)
│   │   └── di/                      # Khai báo Providers & Dependency Injection toàn cục
│   ├── core/
│   │   ├── config/                  # Kiểm tra tính hợp lệ của biến môi trường lúc biên dịch
│   │   ├── date/                    # Value Object xử lý khoảng lưu trú [checkIn, checkOut) chuẩn múi giờ
│   │   ├── errors/                  # Phân loại lỗi bất biến bằng Sealed Class (AppFailure)
│   │   ├── formatters/              # Định dạng tiền tệ và quy đổi tỷ giá đa quốc gia
│   │   ├── logging/                 # Bộ ghi nhật ký an toàn (chống rò rỉ PII và JWT)
│   │   ├── network/                 # Dio HTTP Client tích hợp Interceptor tự động làm mới Access Token
│   │   └── security/ & storage/     # Lưu trữ khóa mật mã (FlutterSecureStorage) & tùy chọn người dùng
│   ├── features/                    # 15 Phân hệ chức năng độc lập theo mô hình MVVM
│   │   ├── admin/                   # Trung tâm điều hành Admin: Dashboard, RBAC, KYC, Tin đăng, Giải ngân
│   │   ├── auth/                    # Đăng nhập, Đăng ký, Xác thực OTP, Quên mật khẩu & Google Sign-In
│   │   ├── blog/                    # Cẩm nang du lịch và bài viết khám phá Vũng Tàu
│   │   ├── booking_inquiry/         # Luồng đặt phòng, áp mã giảm giá, thanh toán VNPay/MoMo/VietQR & Tư vấn
│   │   ├── contact/                 # Gửi yêu cầu liên hệ và kết nối Hotline / Zalo OA
│   │   ├── favorites/               # Quản lý danh sách biệt thự yêu thích (Wishlist đồng bộ tài khoản)
│   │   ├── home/                    # Trang chủ khám phá, danh mục nhanh và lối tắt tìm kiếm AI
│   │   ├── host/                    # Cổng Chủ nhà Studio: Tổng quan, Biệt thự, Lịch 30 ngày, Đơn đặt, Google Sheets, KYC
│   │   ├── messages/                # Nhắn tin thời gian thực Socket.IO kiểu Messenger (cảm xúc, ảnh, trả lời nhanh)
│   │   ├── reviews/                 # Đánh giá xếp hạng sau lưu trú và phản hồi của Chủ nhà
│   │   ├── search/                  # Tìm kiếm ngữ nghĩa văn bản AI, tìm bằng hình ảnh & bộ lọc nâng cao
│   │   ├── settings/                # Hồ sơ cá nhân, chuyển đổi ngôn ngữ (vi/en/ko), tiền tệ & thông báo
│   │   ├── trips/                   # Quản lý lịch trình chuyến đi của Khách theo trạng thái Booking FSM
│   │   ├── villas/                  # Danh sách biệt thự, thẻ hiển thị thông số và bộ lọc thông minh
│   │   └── villa_detail/            # Chi tiết biệt thự, thư viện ảnh, lịch trống, bản đồ tiện ích & đánh giá
│   ├── shared/                      # Thành phần giao diện tái sử dụng (Buttons, Cards, Frosted Notifications...)
│   └── l10n/                        # Tệp ngôn ngữ nguồn (app_vi.arb, app_en.arb, app_ko.arb)
├── test/                            # 52 bộ kiểm thử tự động (Unit, Widget, Multi-Viewport, Golden & Integration)
├── integration_test/                # Kịch bản kiểm thử đầu-cuối (App E2E Tests)
└── tools/quality/                   # Kịch bản kiểm toán bảo mật và quy chuẩn mã nguồn Dart
```

---

## 3. Cấu hình Đa Môi trường (Product Flavors)

| Môi trường | Tệp cấu hình | Điểm khởi chạy | Android Application ID / iOS Bundle ID |
| :--- | :--- | :--- | :--- |
| **Development** | `config/dev.json` | `lib/main_dev.dart` | `com.bronc3.hotel_booking_flutter.dev` |
| **Staging** | `config/staging.json` | `lib/main_staging.dart` | `com.bronc3.hotel_booking_flutter.staging` |
| **Production** | `config/prod.json` | `lib/main.dart` | `com.bronc3.hotel_booking_flutter` |

---

## 4. Hướng dẫn Khởi chạy và Đóng gói

### Cài đặt phụ thuộc & Sinh mã nguồn đa ngôn ngữ
```bash
cd hotel-booking-flutter
flutter pub get
flutter gen-l10n
```

### Khởi chạy trên trình duyệt Web (Chrome)
```bash
flutter run -d chrome --dart-define-from-file=config/dev.json
```

### Khởi chạy trên Android / iOS theo từng Flavor
```bash
# Development
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev.json

# Staging
flutter run --flavor staging -t lib/main_staging.dart --dart-define-from-file=config/staging.json

# Production
flutter run --flavor prod -t lib/main.dart --dart-define-from-file=config/prod.json
```

### Đóng gói bản phát hành (Release Artifacts)
```bash
# Bản dựng Web SPA tối ưu hóa
flutter build web --release --dart-define-from-file=config/prod.json

# Bản dựng Android APK & Google Play App Bundle (AAB)
flutter build apk --release --flavor prod --dart-define-from-file=config/prod.json
flutter build appbundle --release --flavor prod --dart-define-from-file=config/prod.json
```

---

## 5. Cổng Kiểm định Chất lượng & Bảo mật (Quality Gates)

Trước khi khởi tạo Pull Request, mã nguồn bắt buộc vượt qua đầy đủ các bước kiểm tra tương đương trên đường ống GitHub Actions (`flutter_ci.yml`):

```bash
# 1. Quét rò rỉ khóa bí mật, chính sách Zero-Mock và chuẩn an toàn TLS
dart run tools/quality/secret_and_rule_audit.dart

# 2. Kiểm tra định dạng chuẩn Dart
dart format --output=none --set-exit-if-changed test/integration integration_test tools/quality

# 3. Phân tích tĩnh mã nguồn (0 lỗi, 0 cảnh báo)
flutter analyze --no-fatal-infos

# 4. Chạy bộ kiểm thử Đơn vị & Widget (loại trừ ảnh chụp Golden phụ thuộc hệ điều hành)
flutter test --exclude-tags=golden

# 5. Chạy bộ kiểm thử Luồng E2E & Danh sách kiểm tra hiển thị đa kích thước màn hình (320dp–430dp)
flutter test test/integration/e2e_all_flows_test.dart test/integration/visual_ui_checklist_test.dart
```

---

## 6. Nguyên tắc An toàn Dữ liệu và Bảo mật Ứng dụng Khách

1. **Chính sách Không Dữ liệu Giả lập (*Zero-Mock Policy*):** Mã nguồn sản xuất trong `lib/` tuyệt đối không chứa dữ liệu mẫu cứng; mọi màn hình phản ánh trung thực trạng thái dữ liệu từ REST API / WebSocket (`Loading`, `Empty`, `Error`, `Success`).
2. **Bảo vệ Khóa Bí mật (*Zero Client Secrets*):** Các tệp `config/*.json` chỉ chứa cấu hình định tuyến công khai (`API_BASE_URL`, `GOOGLE_SERVER_CLIENT_ID`). Tuyệt đối không nhúng khóa OpenAI, R2 hay khóa ký thanh toán vào gói ứng dụng.
3. **Lưu trữ An toàn & Bảo vệ PII:** Token phiên đăng nhập trên thiết bị di động được mã hóa qua `FlutterSecureStorage`; bộ ghi nhật ký `AppLogger` tự động lược bỏ thông tin định danh cá nhân (PII) và tiêu đề `Authorization`.
4. **Toàn vẹn Giao thức TLS:** Nghiêm cấm vô hiệu hóa xác thực chứng chỉ SSL/TLS (`badCertificateCallback`) trên mọi môi trường thực thi.
5. **Đồng bộ Lịch Host:** Hỗ trợ chuẩn hóa quản lý lịch dọc không giới hạn số căn (*Agency Mode*) và đồng bộ tự động 2 chiều an toàn qua Google Sheets.
