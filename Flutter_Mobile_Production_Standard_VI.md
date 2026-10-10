# BỘ TIÊU CHUẨN KHỞI TẠO DỰ ÁN FLUTTER – ANDROID & iOS

**Phiên bản:** 1.0 · **Ngày:** 10/10/2026 · **Cấp độ:** Production / chuyên nghiệp  
**Phạm vi:** Ứng dụng Flutter phát hành thực tế trên Android và iOS.

> Đây là bộ quy chuẩn triển khai và nghiệm thu dự án, không phải mã nguồn Flutter đã sinh sẵn. Cấu hình native phải được ghép vào các tệp mà Flutter SDK thực tế tạo ra, không ghi đè máy móc.

## 1. Nguyên tắc bắt buộc

1. **Stable only:** sử dụng Flutter stable, thống nhất phiên bản Flutter/Dart giữa máy phát triển và CI. Nâng cấp SDK có kiểm thử.
2. **Separation of concerns:** giao diện không gọi API/cơ sở dữ liệu trực tiếp; Repository là nguồn dữ liệu chuẩn.
3. **Một hướng dữ liệu:** `UI → ViewModel → Repository → Service`; kết quả quay về theo chiều ngược lại.
4. **Bảo mật phía máy chủ:** quyền truy cập phải được backend kiểm tra. Không xem route guard trên app là cơ chế phân quyền.
5. **Ba môi trường độc lập:** `dev`, `staging`, `prod` có API URL, ID ứng dụng và signing thích hợp.
6. **Test trước phát hành:** format, lint/analyze, unit/widget tests, kiểm thử các luồng chính Android/iOS đều đạt.
7. **Có thể truy vết:** version, build number, thay đổi, artifact, signing, cấu hình build và crash symbols phải quản lý rõ ràng.

## 2. Yêu cầu môi trường

| Thành phần | Tiêu chuẩn |
|---|---|
| Flutter SDK | Stable, được team/CI khóa cùng phiên bản |
| Dart SDK | Phiên bản đi kèm Flutter |
| IDE | VS Code hoặc Android Studio |
| Android | Android SDK, JDK/Gradle tương thích, emulator/thiết bị thật |
| iOS | **macOS + Xcode**, iOS Simulator/thiết bị iPhone |
| Git | Bắt buộc |
| Apple Developer | Cần để ký và phát hành ứng dụng iOS |
| Google Play Console | Cần để phát hành Google Play |

```bash
flutter channel stable
flutter upgrade
flutter --version
flutter doctor -v
flutter devices
```

**Lưu ý:** Có thể lập trình và build Android trên Windows. Build, ký và phát hành iOS phải thực hiện trên macOS với Xcode; iOS flavors cũng cần thiết lập trong Xcode.

## 3. Khởi tạo và định danh

Thông tin mẫu (thay theo thương hiệu thật):

| Mục | Ví dụ |
|---|---|
| Tên project | `bronc3_mobile` |
| Organization | `com.bronc3` |
| Android applicationId / iOS Bundle ID production | `com.bronc3.mobile` |
| Tên hiển thị | `BRONC3 Mobile` |
| Version đầu tiên | `1.0.0+1` |
| Flavors | `dev`, `staging`, `prod` |

```bash
flutter create --org com.bronc3 --platforms=android,ios bronc3_mobile
cd bronc3_mobile
flutter pub get
git init
flutter run
```

Sau khởi tạo, kiểm tra và chỉnh lại **Android `applicationId`** và **iOS `PRODUCT_BUNDLE_IDENTIFIER`** để khớp định danh đã thống nhất. Không giả định `flutter create` tự tạo đúng ID production mong muốn. Chốt định danh trước khi phát hành.

## 4. Kiến trúc

Áp dụng **Feature-first + MVVM + Repository/Service**, dùng Riverpod để quản lý trạng thái và dependency injection. Chỉ thêm domain use cases khi nghiệp vụ phức tạp hoặc dùng lại ở nhiều nơi.

```text
Screen / View
    ↓ sự kiện người dùng
ViewModel (Riverpod Notifier/AsyncNotifier hoặc Provider thích hợp)
    ↓
Repository interface  ←  nghiệp vụ và nguồn dữ liệu chuẩn
    ↓
Repository implementation
    ↓
API Service (Dio) / Secure Storage / Local Database
```

**Luật phụ thuộc:** Domain không import thư viện giao diện, Dio hay plugin storage; View không trực tiếp dùng Dio; ViewModel không biết chi tiết JSON/HTTP; dữ liệu đi vào giao diện dưới dạng model/state bất biến. Mọi phụ thuộc cần thay thế trong kiểm thử được inject.

### Cây thư mục chuẩn

```text
bronc3_mobile/
├── android/
├── ios/
├── assets/
│   ├── icons/
│   ├── images/
│   └── fonts/
├── config/
│   ├── dev.json
│   ├── staging.json
│   └── prod.json
├── lib/
│   ├── main.dart
│   ├── main_dev.dart
│   ├── main_staging.dart
│   ├── bootstrap.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── router/app_router.dart
│   │   ├── theme/app_theme.dart
│   │   └── di/providers.dart
│   ├── core/
│   │   ├── config/app_config.dart
│   │   ├── errors/
│   │   ├── network/
│   │   │   ├── dio_client.dart
│   │   │   └── auth_interceptor.dart
│   │   ├── security/token_storage.dart
│   │   ├── storage/preferences_service.dart
│   │   └── logging/app_logger.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── dto/
│   │   │   │   ├── services/auth_api_service.dart
│   │   │   │   └── repositories/auth_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/user.dart
│   │   │   │   └── repositories/auth_repository.dart
│   │   │   └── presentation/
│   │   │       ├── screens/login_screen.dart
│   │   │       ├── view_models/auth_view_model.dart
│   │   │       └── widgets/
│   │   └── home/
│   └── shared/widgets/
├── test/
├── integration_test/
├── .github/workflows/flutter_ci.yml
├── analysis_options.yaml
├── pubspec.yaml
├── pubspec.lock
├── README.md
└── CHANGELOG.md
```

Thư mục `data/domain/presentation` được tổ chức theo tính năng. Với tính năng đơn giản, có thể bỏ các thư mục rỗng; không tạo use case chỉ để chuyển tiếp một lệnh.

## 5. Dependencies

| Mục đích | Gói đề xuất | Mức độ |
|---|---|---|
| State/DI | `flutter_riverpod` | Cốt lõi |
| Routing/deep link | `go_router` | Cốt lõi |
| HTTP/Interceptor | `dio` | Cốt lõi nếu có backend |
| Token an toàn | `flutter_secure_storage` | Cốt lõi nếu có đăng nhập |
| Cài đặt không nhạy cảm | `shared_preferences` | Khi cần |
| i18n | `flutter_localizations` (SDK), `intl` | Khi cần đa ngôn ngữ |
| Models bất biến | `freezed_annotation`, `json_annotation` | Khi có nhiều DTO/model |
| Sinh code | `build_runner`, `freezed`, `json_serializable` | Dev dependencies |
| Mock test | `mocktail` | Dev dependency |
| Lint | `flutter_lints` | Dev dependency |
| Kiểm thử tích hợp | `integration_test` (SDK) | Dev dependency |

```bash
flutter pub add flutter_riverpod go_router dio flutter_secure_storage shared_preferences intl
flutter pub add freezed_annotation json_annotation
flutter pub add --dev build_runner freezed json_serializable flutter_lints mocktail
flutter pub add "dev:integration_test:{sdk: flutter}"
flutter pub get
```

Thêm `flutter_localizations` đúng dạng SDK dependency vào `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
```

Không thay toàn bộ `pubspec.yaml` bằng ví dụ này: giữ nguyên phần cấu hình project và ràng buộc Dart/Flutter mà công cụ sinh ra. **Commit `pubspec.lock`** đối với ứng dụng. Cài đặt phiên bản package tương thích với SDK đang sử dụng bằng `flutter pub add`; đánh giá thay đổi trước khi nâng major version.

## 6. Cấu hình theo môi trường

`config/dev.json`:

```json
{
  "APP_ENV": "dev",
  "API_BASE_URL": "https://dev-api.example.com"
}
```

`config/staging.json` và `config/prod.json` tương tự, tương ứng `staging`, `prod` và các máy chủ HTTPS riêng.

`lib/core/config/app_config.dart`:

```dart
class AppConfig {
  static const environment = String.fromEnvironment('APP_ENV');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static void validate({required String expectedEnvironment}) {
    if (environment != expectedEnvironment) {
      throw StateError('Build environment mismatch');
    }

    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('API_BASE_URL must be an HTTPS URL');
    }
  }
}
```

`lib/bootstrap.dart` (cần có `app/app.dart` trước khi chạy):

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/config/app_config.dart';

void bootstrap({required String expectedEnvironment}) {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate(expectedEnvironment: expectedEnvironment);
  runApp(const ProviderScope(child: App()));
}
```

`lib/main_dev.dart`:

```dart
import 'bootstrap.dart';
void main() => bootstrap(expectedEnvironment: 'dev');
```

`lib/main_staging.dart`:

```dart
import 'bootstrap.dart';
void main() => bootstrap(expectedEnvironment: 'staging');
```

`lib/main.dart`:

```dart
import 'bootstrap.dart';
void main() => bootstrap(expectedEnvironment: 'prod');
```

**QUAN TRỌNG:** `--dart-define` hoặc `--dart-define-from-file` chỉ cấu hình giá trị được đóng gói trong ứng dụng, **không bảo vệ bí mật**. Không để API secret, private key, mật khẩu hay service-account credentials trong source/app binary.

## 7. Flavors Android và iOS

Giữ cùng tên `dev`, `staging`, `prod` ở cả Flutter CLI và hai nền tảng.

### Android

Trong block `android { ... }` hiện có của `android/app/build.gradle.kts`, bổ sung và điều chỉnh phù hợp với cấu hình Gradle thực tế:

```kotlin
flavorDimensions += "env"
productFlavors {
    create("dev") {
        dimension = "env"
        applicationIdSuffix = ".dev"
        resValue("string", "app_name", "BRONC3 DEV")
    }
    create("staging") {
        dimension = "env"
        applicationIdSuffix = ".staging"
        resValue("string", "app_name", "BRONC3 STAGING")
    }
    create("prod") {
        dimension = "env"
        resValue("string", "app_name", "BRONC3")
    }
}
```

`defaultConfig.applicationId` production phải là `com.bronc3.mobile`; flavor dev/staging tạo thành `com.bronc3.mobile.dev` và `com.bronc3.mobile.staging`. Cấu hình launcher để dùng `@string/app_name` nếu muốn đổi tên từng flavor, tránh khai báo trùng resource.

### iOS

Trên **macOS**, mở `ios/Runner.xcworkspace` bằng Xcode. Tạo **Shared Schemes** `dev`, `staging`, `prod`. Mỗi scheme ánh xạ tới ba Build Configurations `Debug-*`, `Profile-*`, `Release-*` có hậu tố trùng tên flavor viết thường. Thiết lập Bundle ID, display name và signing theo từng môi trường:

| Flavor | Android ID | iOS Bundle ID |
|---|---|---|
| dev | `com.bronc3.mobile.dev` | `com.bronc3.mobile.dev` |
| staging | `com.bronc3.mobile.staging` | `com.bronc3.mobile.staging` |
| prod | `com.bronc3.mobile` | `com.bronc3.mobile` |

Rà soát thêm Xcode configurations, `ios/Podfile`, entitlements, URL schemes, app icons và provisioning theo tài liệu flavors chính thức. Không thể chỉ thêm `--flavor` vào lệnh mà bỏ qua cấu hình native này.

### Lệnh chạy sau khi cấu hình xong flavors

```bash
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev.json
flutter run --flavor staging -t lib/main_staging.dart --dart-define-from-file=config/staging.json
flutter run --flavor prod -t lib/main.dart --dart-define-from-file=config/prod.json
```

**Release gate:** bộ ba `native flavor / entrypoint / Dart defines` phải cùng môi trường.

## 8. Bảo mật bắt buộc

- **Truyền tải:** chỉ HTTPS, xác thực chứng chỉ TLS; không tắt kiểm tra chứng chỉ trong release.
- **Đăng nhập:** ưu tiên OAuth 2.0/OIDC Authorization Code + PKCE và system browser khi dùng nhà cung cấp danh tính; không nhúng client secret.
- **Token:** lưu qua Keychain/secure storage (`flutter_secure_storage`); không lưu trong `shared_preferences`. Làm mới token có đồng bộ, không tạo nhiều yêu cầu refresh song song; logout khi refresh thất bại.
- **Phân quyền:** máy chủ kiểm tra role/permission từng API. Không tin các claim do client tự gửi.
- **API:** timeout, cancellation, mã lỗi chuẩn; retry có backoff và chỉ tự retry thao tác an toàn/idempotent.
- **Logging:** không ghi token, Authorization headers, cookie, mật khẩu hoặc dữ liệu cá nhân vào log/crash reports.
- **Lưu trữ:** dữ liệu nhạy cảm offline phải có cơ chế mã hóa, migration và xóa khi đăng xuất (nếu nghiệp vụ yêu cầu).
- **Quyền hệ điều hành:** chỉ yêu cầu permissions được sử dụng. Android có INTERNET khi gọi API; iOS có purpose strings/khai báo privacy phù hợp với API/plugin thực dùng.
- **Secrets cho CI/signing:** không commit keystore, password, provisioning profile hay signing certificates. Quản lý qua secret manager và quyền truy cập hạn chế.
- **Phụ thuộc:** kiểm tra cập nhật/vulnerabilities thường xuyên; `flutter pub outdated`. Obfuscation không thay thế bảo mật backend.

Tối thiểu `.gitignore` cần loại trừ file bí mật như `android/key.properties`, `*.jks`, `*.keystore`, credential JSON riêng và file cấu hình chứa secret. **Không loại trừ** ba file JSON môi trường nêu trên nếu chúng chỉ chứa cấu hình công khai.

## 9. Quy tắc UI/UX

Sử dụng Material 3, hệ thống màu/typography/spacing thống nhất, theme sáng/tối, SafeArea, responsive cho điện thoại nhỏ/lớn, hỗ trợ text scaling và accessibility. Mỗi màn hình truy xuất dữ liệu phải có `loading`, `empty`, `error`, `success`; form có validation, thông báo lỗi rõ ràng và phòng chống double-submit. Logic nghiệp vụ không đặt trong `build()`; chuỗi hiển thị cần sẵn sàng cho localization.

## 10. Quy tắc mã nguồn

`analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml
```

Áp dụng tên file `snake_case.dart`, tên class `PascalCase`, tên biến `camelCase`, model/state bất biến, import rõ ràng, không sử dụng global mutable singleton cho nghiệp vụ. Mọi API access phải qua service/repository; không gọi API trong `build()` hoặc lưu token bằng bộ nhớ không mã hóa.

```bash
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter pub outdated
```

Thống nhất chính sách lưu file sinh tự động (`*.g.dart`, `*.freezed.dart`). Đối với ứng dụng, nên commit file sinh đã kiểm tra để build tái lập, đồng thời cho CI xác thực lại.

## 11. Kiểm thử và CI/CD

| Kiểm thử | Tối thiểu |
|---|---|
| Unit | ViewModel, mapper, repository, config validation, token refresh |
| Widget | Login form, lỗi/loading, route guard, accessibility |
| Integration | Cold start → đăng nhập → tác vụ chính → đăng xuất |
| Thiết bị | Android và iPhone thật; ít nhất hai cỡ màn hình |
| Mạng | Offline, chậm, timeout, 401/403/500, reconnect |
| Vòng đời | Background/foreground, kill/restart, nâng cấp ứng dụng |

`integration_test` cần thiết bị hoặc emulator/simulator thích hợp; tích hợp thêm công cụ native-UI test nếu luồng yêu cầu thao tác trên permission dialogs.

Mẫu `.github/workflows/flutter_ci.yml` (chỉ là **quality pipeline**, chưa bao gồm ký và phát hành):

```yaml
name: Flutter CI
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test
```

**Khi dùng thật:** pin Flutter SDK cụ thể và GitHub Actions theo commit SHA được duyệt; thêm workflow macOS cho iOS; quản lý CI secrets và quyền duyệt phát hành; lưu artifact, logs, crash symbols và thông tin bản build.

## 12. Build production

Sau khi Android signing, iOS schemes/provisioning và toàn bộ cấu hình hoàn tất:

**Android App Bundle (Google Play):**

```bash
flutter build appbundle --release --flavor prod -t lib/main.dart --dart-define-from-file=config/prod.json
```

**iOS IPA (chỉ trên macOS):**

```bash
flutter build ipa --release --flavor prod -t lib/main.dart --dart-define-from-file=config/prod.json
```

Có thể bổ sung `--obfuscate --split-debug-info=<đường-dẫn>` để làm khó việc reverse engineering và tạo symbol map; phải sao lưu symbols gắn với từng release để phân tích crash.

Phát hành qua Play Console Internal Testing và TestFlight trước khi rollout công khai. Kiểm tra định danh ứng dụng, signing, quyền, chính sách dữ liệu, icon, screenshot, version/build number và quy trình hotfix/rollback.

## 13. Checklist nghiệm thu

- [ ] Flutter stable được khóa phiên bản, `flutter doctor` không còn lỗi liên quan nền tảng mục tiêu.
- [ ] App ID / Bundle ID production đã chốt; không có định danh demo.
- [ ] Android `dev/staging/prod` chạy được; iOS shared schemes và signing đã kiểm chứng.
- [ ] Cả ba môi trường trỏ đúng API; app không thể chạy nhầm `prod` với `dev` config.
- [ ] Cấu trúc feature-first, phân lớp View/ViewModel/Repository/Service và dependency injection đã áp dụng.
- [ ] Theme, accessibility, localization, loading/error/empty states đã được chuẩn hóa.
- [ ] Tất cả API qua client chung; authentication, refresh, timeout và error mapping được kiểm thử.
- [ ] Không có secret trong source/binary; token được lưu an toàn; server phân quyền thực tế.
- [ ] Android/iOS chỉ xin quyền thật sự cần; privacy disclosures phù hợp.
- [ ] Unit/widget/integration tests cho luồng quan trọng đạt; CI xanh.
- [ ] Release signing secrets được lưu an toàn, tách khỏi Git.
- [ ] Android AAB và iOS IPA production build thành công; lưu artifact và symbols.
- [ ] Đã chạy trên thiết bị thật, test offline, update, logout và quy trình lỗi.
- [ ] Có README, CHANGELOG, chủ sở hữu phát hành, kế hoạch hỗ trợ và hotfix.

## 14. Tài liệu tham chiếu

- Flutter architecture: https://docs.flutter.dev/app-architecture/guide
- Architecture recommendations: https://docs.flutter.dev/app-architecture/recommendations
- Android flavors: https://docs.flutter.dev/deployment/flavors
- iOS flavors: https://docs.flutter.dev/deployment/flavors-ios
- Android release: https://docs.flutter.dev/deployment/android
- iOS release: https://docs.flutter.dev/deployment/ios
- Testing: https://docs.flutter.dev/testing/overview
- Flutter security: https://docs.flutter.dev/security

**Phạm vi hoàn thành:** Tài liệu định nghĩa quy chuẩn kiến trúc, thư mục, packages, config, bảo mật, kiểm thử và release; không tự động tạo một repository Flutter chạy được khi chưa chạy `flutter create`, chưa ghép mã `App`, các tầng nghiệp vụ và cấu hình Android/Xcode thực tế.
