# Hotel Booking Flutter — Mobile Application (Android & iOS)

> Ứng dụng di động cao cấp phục vụ khám phá, tra cứu thông tin và kết nối tư vấn/đặt biệt thự, khách sạn nghỉ dưỡng cao cấp tại Vũng Tàu.

[![Flutter CI](https://github.com/DangKimAn/Software-Project-Management/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/DangKimAn/Software-Project-Management/actions)
[![Flutter Stable](https://img.shields.io/badge/Flutter-Stable-02569B?logo=flutter)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Feature--first%20+%20MVVM%20+%20Riverpod-5C2D91)](https://docs.flutter.dev/app-architecture)
[![Design](https://img.shields.io/badge/Design-Airbnb%20Luxury%20×%20Apple%20Minimalist-FF385C)](FLUTTER_RULES.md)

---

## 1. Tổng quan dự án

- **Tên sản phẩm:** Hotel Booking Mobile
- **Package / Tên Flutter:** `hotel_booking_flutter`
- **Thư mục dự án:** `hotel-booking-flutter`
- **Nền tảng hỗ trợ:** Android & iOS (Native)
- **Framework:** Flutter Stable (Dart)
- **Màu thương hiệu chủ đạo:** Coral `#FF385C`
- **Ngôn ngữ hỗ trợ:** Tiếng Việt (`vi`), English (`en`), 한국어 (`ko`)
- **Kiến trúc:** Feature-first + MVVM + Repository Pattern + Riverpod Dependency Injection
- **Navigation:** GoRouter với Stateful Navigation Shell

---

## 2. Cấu trúc thư mục chuẩn

```text
hotel-booking-flutter/
├── android/                         # Cấu hình native Android & Product Flavors (dev, staging, prod)
├── ios/                             # Cấu hình native iOS Xcode Schemes & Info.plist queries
├── assets/
│   ├── images/                      # Ảnh tài nguyên cục bộ
│   ├── icons/                       # Biểu tượng tĩnh
│   └── fonts/                       # Fonts được phép phân phối hợp pháp
├── config/
│   ├── dev.json                     # Cấu hình môi trường Development
│   ├── staging.json                 # Cấu hình môi trường Staging
│   └── prod.json                    # Cấu hình môi trường Production
├── lib/
│   ├── main.dart                    # Entrypoint Production
│   ├── main_dev.dart                # Entrypoint Development
│   ├── main_staging.dart            # Entrypoint Staging
│   ├── bootstrap.dart               # Khởi tạo DI, SharedPreferences và validate cấu hình
│   ├── app/
│   │   ├── app.dart                 # MaterialApp.router, Localization, Light Luxury Theme
│   │   ├── router/app_router.dart   # Khai báo GoRouter tập trung
│   │   ├── theme/                   # Hệ thống Design Tokens (Colors, Typography, Spacing, Radii)
│   │   └── di/providers.dart        # Dependency Injection & ViewModels qua Riverpod
│   ├── core/
│   │   ├── config/app_config.dart   # Validate biến môi trường build-time
│   │   ├── constants/               # Hằng số toàn cục
│   │   ├── date/booking_date.dart   # Value object xử lý ngày đêm [checkIn, checkOut) chuẩn múi giờ
│   │   ├── errors/app_failure.dart  # Sealed class phân loại lỗi ứng dụng
│   │   ├── formatters/              # Định dạng tiền tệ VND chuẩn
│   │   ├── logging/app_logger.dart  # Logger an toàn không rò rỉ PII hay token
│   │   ├── network/dio_client.dart  # HTTP Client có timeout, interceptors
│   │   ├── security/                # Lưu trữ an toàn bằng FlutterSecureStorage
│   │   └── storage/                 # Lưu trữ tùy chọn (ngôn ngữ, favorites) bằng SharedPreferences
│   ├── features/
│   │   ├── home/                    # Màn hình chính, thanh tìm kiếm, danh mục nhanh, floating actions
│   │   ├── villas/                  # Danh sách biệt thự, thẻ PropertyCard, carousels, specs row
│   │   ├── villa_detail/            # Chi tiết biệt thự, specs 2 tầng, giá theo đêm, FAQ, sticky CTA
│   │   ├── search/                  # Tìm kiếm, bộ chọn khoảng ngày BookingDateRangePicker
│   │   ├── booking_inquiry/         # Dịch vụ ContactService (Zalo, Hotline chuẩn native)
│   │   ├── favorites/               # Danh sách biệt thự yêu thích
│   │   └── settings/                # Đổi ngôn ngữ, kiểm tra môi trường, thông tin liên hệ
│   ├── shared/
│   │   ├── widgets/                 # AppButton, AppTextField, AppCard, AppLoading, VillaBadge...
│   │   └── extensions/              # Tiện ích mở rộng BuildContextX
│   └── l10n/                        # Đa ngôn ngữ (app_vi.arb, app_en.arb, app_ko.arb)
├── test/                            # Unit tests & Widget tests
│   ├── core/                        # Test logic ngày đêm, cấu hình
│   ├── features/                    # Test nghiệp vụ badge ưu tiên, contact service
│   └── shared/                      # Test UI components
├── .github/workflows/               # GitHub Actions CI pipeline
├── analysis_options.yaml            # Cấu hình linter nghiêm ngặt
└── pubspec.yaml                     # Danh sách dependencies được khóa phiên bản
```

---

## 3. Ba môi trường độc lập (Flavors)

| Môi trường | Config file | Entrypoint | Android App ID | iOS Bundle ID |
|---|---|---|---|---|
| **Development** | `config/dev.json` | `lib/main_dev.dart` | `com.bronc3.hotel_booking_flutter.dev` | `com.bronc3.hotel_booking_flutter.dev` |
| **Staging** | `config/staging.json` | `lib/main_staging.dart` | `com.bronc3.hotel_booking_flutter.staging` | `com.bronc3.hotel_booking_flutter.staging` |
| **Production** | `config/prod.json` | `lib/main.dart` | `com.bronc3.hotel_booking_flutter` | `com.bronc3.hotel_booking_flutter` |

---

## 4. Hướng dẫn chạy dự án

### Cài đặt thư viện:
```bash
cd hotel-booking-flutter
flutter pub get
```

### Chạy môi trường Development:
```bash
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev.json
```

### Chạy môi trường Staging:
```bash
flutter run --flavor staging -t lib/main_staging.dart --dart-define-from-file=config/staging.json
```

### Chạy môi trường Production:
```bash
flutter run --flavor prod -t lib/main.dart --dart-define-from-file=config/prod.json
```

---

## 5. Kiểm thử & Quality Gates

Tuân thủ nghiêm ngặt quy định CI/CD trước khi tạo Pull Request:

```bash
# 1. Kiểm tra format mã nguồn Dart
dart format --output=none --set-exit-if-changed .

# 2. Phân tích tĩnh mã nguồn (linter)
flutter analyze

# 3. Chạy toàn bộ Unit & Widget Tests với báo cáo coverage
flutter test --coverage
```

---

## 6. Tiêu chuẩn bảo mật & Quy tắc dữ liệu

- **Tuyệt đối không dùng dữ liệu Mock và Seed:** Toàn bộ dữ liệu hiển thị được truy xuất trực tiếp từ REST API thông qua `VillaRepositoryImpl`. Khi chưa có dữ liệu mạng hoặc server offline, giao diện hiển thị trạng thái trung thực (Loading, Empty, Error) và 'Liên hệ báo giá', không tạo dữ liệu giả lập.
- **Không hardcode Secrets:** Các file cấu hình `config/*.json` chỉ chứa thông tin công khai (Base URL, Hotline, Zalo OA). Mọi private key, signing password, DB secret tuyệt đối không lưu trong ứng dụng di động.
- **Bảo vệ PII:** Tuyệt đối không log tên khách hàng, số điện thoại hoặc lịch đặt phòng vào console/Crashlytics.
- **Lưu trữ nhạy cảm:** Token xác thực lưu trong Keychain/EncryptedSharedPreferences thông qua `FlutterSecureStorage`.
- **An toàn giao thức:** Toàn bộ API endpoint bắt buộc chạy qua HTTPS; cấm tắt kiểm tra chứng chỉ TLS (`badCertificateCallback`).

---

## 7. Tài liệu quy chuẩn

Vui lòng đọc chi tiết file [FLUTTER_RULES.md](FLUTTER_RULES.md) để nắm rõ các quy tắc thiết kế UI/UX, thứ tự thông số biệt thự, bảng màu chuẩn và quy tắc nghiệp vụ lưu trú.
