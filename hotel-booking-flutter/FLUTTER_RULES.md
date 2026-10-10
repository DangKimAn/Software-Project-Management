# MINH THANH VILLA — FLUTTER MOBILE RULES (ANDROID & iOS)

**Loại tài liệu:** Quy tắc bắt buộc cho lập trình viên và AI coding assistants (Cursor, Antigravity, Copilot, Claude, Gemini, ChatGPT).  
**Phiên bản:** 2.0-flutter | **Ngày:** 10/10/2026 | **Phạm vi:** Ứng dụng Flutter Android/iOS phục vụ tìm kiếm, xem thông tin và tư vấn/đặt villa Minh Thanh Villa Vũng Tàu.  
**Nguồn chuyển đổi:** `UI & FRONTEND DESIGN SYSTEM RULES` của dự án web Minh Thanh Villa do chủ dự án cung cấp.  
**Mức độ:** Production / thiết kế cao cấp / bảo mật và kiểm thử bắt buộc.

> **ƯU TIÊN CAO NHẤT:** Giữ nguyên bản sắc **Airbnb Luxury × Apple Clean Minimalist**, nhận diện Coral `#FF385C`, trải nghiệm mobile-first và mục tiêu kết nối đặt phòng qua **Zalo / Hotline**. Chuyển *nguyên tắc* của rule web sang Flutter native — **không sao chép CSS/JSX/DOM hoặc coi ứng dụng Flutter là website**.
>
> **BẢO VỆ HỆ THỐNG:** Bộ rule này quy định ứng dụng di động, **không cấp quyền tự ý thay đổi website, API production, cơ sở dữ liệu, Cloudflare Workers hoặc luồng đặt phòng hiện hữu**. Mọi thay đổi backend hoặc schema cần yêu cầu/phê duyệt riêng.

---

## 0. THỨ TỰ ƯU TIÊN VÀ NGUYÊN TẮC THI HÀNH

1. **An toàn người dùng, dữ liệu cá nhân, quy định Android/iOS và giấy phép tài sản** cao hơn mọi yêu cầu thẩm mỹ.
2. **Nghiệp vụ và dữ liệu thực tế** cao hơn hiệu ứng; không bịa giá, lịch trống, đánh giá, tính năng hoặc trạng thái đặt phòng.
3. **Design tokens và luồng tương tác được quy định tại file này** là nguồn tham chiếu duy nhất cho Flutter UI.
4. **Kiến trúc Flutter đã chọn, quy ước mã nguồn và quality gates** áp dụng cho tất cả feature mới.
5. Khi rule cũ mâu thuẫn với đặc thù native, thực hiện **phương án Flutter an toàn và tương đương**; ghi rõ khác biệt trong phần mô tả thay đổi.
6. Không tự ý đổi màu thương hiệu, typography, điều hướng, hành vi CTA hoặc luồng đặt phòng nếu chưa có quyết định rõ ràng.
7. **Không chỉnh sửa file không liên quan.** Không cài package, migration, commit, push hoặc deploy ngoài phạm vi nhiệm vụ được giao.
8. Quy ước từ ngữ: **PHẢI** = bắt buộc; **NÊN** = mặc định, ngoại lệ có lý do; **CẤM** = không được thực hiện.

## 1. NỀN TẢNG VÀ TECH STACK CHUẨN

| Lớp | Tiêu chuẩn Flutter | Ghi chú |
|---|---|---|
| Flutter & Dart | Flutter **Stable**, Dart đi kèm SDK | Khóa phiên bản trong CI, không tự nâng major |
| Hỗ trợ | **Android và iOS** | Không tự sinh tính năng cho Flutter Web/Desktop |
| Giao diện | `MaterialApp.router`, Material 3 tùy biến, widget thích ứng iOS | Giao diện đồng nhất thương hiệu, tương tác đúng native |
| Kiến trúc | **Feature-first + MVVM + Repository/Service** | Domain/use-case khi nghiệp vụ phức tạp |
| State + DI | `flutter_riverpod` | Một hệ quản lý trạng thái chính |
| Router/deep link | `go_router` | Route khai báo tập trung |
| API | `dio` | Timeout, auth interceptor, typed errors |
| Model | `freezed_annotation`, `json_annotation` + codegen khi cần | DTO không được trộn với UI |
| Icon | **`lucide_icons_flutter`** | Flutter tương đương `lucide-react` của web |
| Ảnh | `Image.network`/cache package được xét duyệt | Placeholder, decode-size, fallback |
| External links | `url_launcher` | Zalo, hotline, link chia sẻ |
| Share/copy | `Clipboard` (SDK); share plugin khi cần | Không thêm package cho tác vụ SDK làm được |
| Lưu phiên | `flutter_secure_storage` nếu có đăng nhập | Không lưu token ở preferences |
| Preferences | `shared_preferences` cho dữ liệu không nhạy cảm | Ví dụ lựa chọn ngôn ngữ |
| i18n | `flutter_localizations`, `intl`, ARB | Tiếng Việt, Anh, Hàn |
| Test | `flutter_test`, `integration_test`, `mocktail` nếu cần | Unit, widget, integration |
| Static analysis | `flutter_lints` hoặc rule lint đã thống nhất | Không suppress lỗi hàng loạt |

**Quy định dependencies:** Chỉ cài thư viện có lý do sử dụng và tương thích với SDK hiện tại. Không hardcode một version package chưa được kiểm chứng. Kiểm tra license, tình trạng bảo trì, số plugin native, kích thước app và rủi ro bảo mật trước khi thêm package. `pubspec.lock` PHẢI được commit đối với ứng dụng.

**Các công nghệ web không dùng trong mã Flutter native:** Vite, React, JSX, Tailwind CSS, CSS variables, `lucide-react`, Framer Motion, Embla, React Leaflet, React Three Fiber, thao tác `window`/`document`/DOM, `localStorage`, CSS hover hoặc Web Core Vitals. Khi cần tính năng tương ứng, dùng Flutter widget/plugin thích hợp.

## 2. KIẾN TRÚC VÀ CÂY THƯ MỤC

**Luồng dữ liệu chuẩn:** `Screen/Widget → ViewModel (Riverpod) → Repository (interface) → Repository Implementation → API/Local Service`. Trạng thái được đưa từ ViewModel về UI. Domain không phụ thuộc Flutter UI, Dio hay plugin; Widget không gọi HTTP hoặc SQL trực tiếp.

```text
minh_thanh_villa_mobile/
├── android/                         # Native Android; flavors, permissions, signing
├── ios/                             # Xcode schemes, plist, entitlements
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/                       # Chỉ đặt font được phép phân phối
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
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── app_colors.dart
│   │   │   ├── app_typography.dart
│   │   │   ├── app_spacing.dart
│   │   │   └── app_radii.dart
│   │   └── di/providers.dart
│   ├── core/
│   │   ├── config/app_config.dart
│   │   ├── network/dio_client.dart
│   │   ├── errors/app_failure.dart
│   │   ├── security/
│   │   ├── localization/
│   │   ├── date/booking_date.dart
│   │   ├── formatters/
│   │   ├── logging/
│   │   └── utils/
│   ├── features/
│   │   ├── discovery/                # Khám phá/tìm kiếm villa
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │       ├── screens/
│   │   │       ├── view_models/
│   │   │       └── widgets/
│   │   ├── property_detail/          # Chi tiết villa, ảnh, tiện ích
│   │   ├── availability/             # Giá và lịch có thể đặt
│   │   ├── booking_inquiry/          # Tư vấn Zalo/Hotline
│   │   ├── favorites/                # Yêu thích (nếu sản phẩm hỗ trợ)
│   │   ├── settings/                 # Ngôn ngữ, cài đặt
│   │   └── auth/                     # Chỉ tạo nếu thật sự cần đăng nhập
│   └── shared/
│       ├── widgets/                 # AppButton, AppTextField, Loading...
│       └── extensions/
├── l10n/
│   ├── app_vi.arb
│   ├── app_en.arb
│   └── app_ko.arb
├── test/
│   ├── core/
│   ├── features/
│   └── golden/
├── integration_test/
├── .github/workflows/flutter_ci.yml
├── analysis_options.yaml
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

- **PHẢI** có `loading`, `empty`, `error`, `success` cho mọi nội dung bất đồng bộ.
- **PHẢI** có typed model/DTO và xử lý rõ `null`, dữ liệu thiếu, giá chưa xác định.
- **CẤM** tạo khối widget khổng lồ chứa đồng thời call API, parsing, pricing và navigation.
- Tách shared widget **khi có tái sử dụng thực tế**; không dựng abstraction vô ích.
- **CẤM** tái sử dụng business logic từ website bằng cách nhúng WebView thay cho native UI, trừ trường hợp được phê duyệt riêng.

## 3. TRIẾT LÝ GIAO DIỆN (DESIGN PHILOSOPHY)

- **Airbnb Luxury × Apple Clean Minimalist:** sạch, thoáng, cao cấp, lấy ảnh villa thật làm trung tâm; không gradient lòe loẹt, bóng đổ nặng, bảng màu rối.
- **Conversion-centric:** hành trình khám phá → tìm villa phù hợp → xem tình trạng/giá → liên hệ Zalo hoặc gọi hotline phải rõ và ngắn.
- **Mobile-first:** thiết kế theo điện thoại một tay trước; thử kích thước nhỏ, text scale lớn và bàn phím xuất hiện; tablet dùng bố cục mở rộng khi cần.
- **Nội dung xác thực:** tên, ảnh, số phòng, khoảng cách, giá, trạng thái phải đến từ nguồn tin cậy; ảnh demo ghi rõ placeholder.
- **Linguistic-first:** hỗ trợ `vi`, `en`, `ko`; mỗi bản dịch có thể dài hơn tiếng Việt, bố cục phải co giãn.
- **Light Luxury là chuẩn:** theme sáng là mặc định. Không tự thêm dark palette trái hệ màu gốc; muốn hỗ trợ dark mode phải được duyệt design tokens riêng. Vẫn thử các accessibility preferences của OS.

## 4. TYPOGRAPHY VÀ VIỆT/HÀN FONT SAFETY

**Mục tiêu tạo cảm giác SF Pro của Apple, nhưng tuyệt đối tôn trọng giấy phép font theo nền tảng.**

1. **Trên iOS:** ưu tiên **San Francisco là font hệ thống** thông qua typography platform mặc định và thiết kế tương đương SF Pro Display/Text. Không đưa file SF Pro `.otf` vào app trừ khi quyền sử dụng và phân phối phù hợp đã được xác nhận.
2. **Trên Android:** dùng font có license cho phép phân phối đa nền tảng, ví dụ **Be Vietnam Pro** (sau khi kiểm tra license/font asset) hoặc font hệ thống với Unicode tiếng Việt đầy đủ; **không tự đóng gói SF Pro lên Android**.
3. **Tiếng Hàn:** dùng font fallback có glyph Hàn đầy đủ như **Noto Sans KR** nếu được phân phối hợp lệ; cấu hình fallback qua `TextStyle.fontFamilyFallback`, không có CSS `html:lang(ko)`.
4. Mẫu text phải kiểm tra các chuỗi: `Biệt thự nghỉ dưỡng Vũng Tàu`, `ệ ư ỗ ợ đ`, giá `₫`, và chữ Hàn trong VI/EN/KO.
5. Dùng `ThemeData.textTheme`, `Text`, `Text.rich`, `TextStyle`, `StrutStyle` khi cần; **không áp dụng `font-family`, em, `text-wrap` CSS**.
6. Tracking từ rule web chuyển tương đối sang `TextStyle.letterSpacing` tính bằng logical pixel (ví dụ tiêu đề 28sp × -0.025 ≈ -0.7; body 14sp × -0.005 ≈ -0.07). Tránh tracking âm quá mức làm hỏng tiếng Việt/Hàn.
7. Tiêu đề ngắn cân đối số dòng bằng ràng buộc chiều rộng/`maxLines` phù hợp; text quan trọng **CẤM bị cắt vô nghĩa**. Nội dung mô tả dài được cuộn hoặc mở rộng.

**Phân cấp mặc định (logical pixel/sp, cần kiểm tra với text scaling):**

| Loại | Font size gợi ý | Weight | Ứng dụng |
|---|---:|---|---|
| Display/Hero | 28–32 | 700 | Trang chủ |
| Section heading | 22–24 | 700 | Tiêu đề section |
| Card title | 16–18 | 600 | Tên villa |
| Body | 14–16 | 400 | Mô tả |
| Label/Button | 14–16 | 600 | Form / CTA |
| Caption | 12–13 | 400–500 | Thông tin phụ |

**PHẢI** tôn trọng text scaling và thử với chữ phóng to. **CẤM** khóa toàn app về text scale = 1 chỉ để tránh overflow.

## 5. DESIGN TOKENS CHO FLUTTER

Tất cả màu thương hiệu được đặt trong `app_colors.dart`, kích thước và bo góc trong files token tương ứng. **CẤM** rải nhiều màu hex trực tiếp khắp screens.

| Token | Mã màu / giá trị | Mục đích |
|---|---|---|
| `primary` | `#FF385C` | Nút CTA, active state, ngày được chọn |
| `primaryPressed` | `#E00B41` | Pressed state, không áp hover mặc định trên touch |
| `brandSoft` | `#FFE8EC` | Highlight nhẹ |
| `rangeBackground` | `#FFF1F3` | Dải chọn ngày |
| `textStrong` | `#222222` | Chữ chính |
| `textMuted` | `#717171` | Chữ phụ (kiểm tra tương phản) |
| `textTertiary` | `#B0B0B0` | Placeholder không thiết yếu; không dùng cho thông tin bắt buộc |
| `surfaceBase` | `#FFFFFF` | Mặt nền |
| `surfaceMuted` | `#F8FAFC` hoặc `#000000` opacity 4% | Nền phụ |
| `borderSoft` | `#EBEBEB` | Viền mờ |
| `borderStrong` | `#DDDDDD` | Viền input/secondary |
| `starAmber` | `#F59E0B` | Sao đánh giá |
| `iconStrong` | `#000000` | Icon trên nền trắng |
| `iconOnBrand` | `#FFFFFF` | Icon trên nền Coral |
| `shadowSoft` | black opacity 6%, blur 16, offset y=4 | Card nhẹ |
| `shadowGlass` | black opacity 4%, blur 8, offset y=2 | Overlay nhẹ |

Ví dụ mã token Dart (copy được vào dự án):

```dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFFFF385C);
  static const primaryPressed = Color(0xFFE00B41);
  static const brandSoft = Color(0xFFFFE8EC);
  static const rangeBackground = Color(0xFFFFF1F3);
  static const textStrong = Color(0xFF222222);
  static const textMuted = Color(0xFF717171);
  static const textTertiary = Color(0xFFB0B0B0);
  static const surfaceBase = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF8FAFC);
  static const borderSoft = Color(0xFFEBEBEB);
  static const borderStrong = Color(0xFFDDDDDD);
  static const starAmber = Color(0xFFF59E0B);
}
```

**Tokens layout:** spacing scale 4/8/12/16/20/24/32 logical pixel; `Card` bo góc 16–20, `BottomSheet` góc trên 32–36, `TextField` và CTA chính dạng stadium/pill. Material 3 `ColorScheme`, `TextTheme`, `InputDecorationTheme`, `FilledButtonThemeData` là nơi cấu hình chung.

**Tương phản:** Màu đã chốt về nhận diện nhưng phải đo WCAG; nội dung nhỏ và placeholder có thể cần màu phụ đậm hơn hoặc kích thước/weight lớn hơn. Không hy sinh khả năng đọc để giữ nguyên màu ít tương phản.

## 6. HỆ THỐNG ICON — LUCIDE FLUTTER

- **Một nguồn icon chủ đạo:** `lucide_icons_flutter` thay cho `lucide-react`. Import theo API thực của version đã cài. Không pha icon Material/Cupertino/FontAwesome vào UI thương hiệu nếu không có lý do native/accessibility rõ ràng.
- Chỉ dùng icon phục vụ ý nghĩa; **CẤM** dùng emoji thay icon chức năng, gradient icon hoặc nhiều vòng tròn pastel màu mè.
- Nền trắng: `#000000`/`textStrong`; nền Coral/nền tối: `#FFFFFF`; sao: Amber `#F59E0B`; icon nhấn thương hiệu: Coral.
- Size chuẩn: 14–16 (tag), 18–20 (thông số/nút), 24 (heading/dialog). Với nét vẽ/stroke, sử dụng biến thể trọng lượng được package hỗ trợ (nếu có), không tự giả lập stroke CSS.
- **PHẢI** dùng `Semantics(label: ...)`, `Tooltip`, hoặc nhãn văn bản với icon-only buttons. Icon trang trí khỏi semantic tree khi cần.
- Icon touch target 48×48 logical pixel khuyến nghị; không nhầm kích thước vẽ icon 18px với kích thước vùng bấm.

Ví dụ import (cần kiểm tra API theo bản package đã khóa):

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const Icon(LucideIcons.heart, size: 20, color: Color(0xFF222222));
```

## 7. PROPERTY CARD / VILLA LISTING

**Widget chuẩn:** `PropertyCard`, `PropertyImageCarousel`, `PropertyPrimaryBadge`, `PropertySpecsRow`, `PropertyPriceSummary`, `FavoriteButton`.

**7.1. Ảnh + carousel**
- Điện thoại: `AspectRatio(aspectRatio: 4 / 3)`. Tablet hoặc bố cục card ngang: xem xét 16/10 theo thiết kế.
- Dùng `PageView` + `PageController`, vuốt trái/phải tự nhiên; parent `ListView` cuộn dọc. Test gesture conflict và định vị index.
- Dùng `ClipRRect`, ảnh `BoxFit.cover`, loading/error placeholder giữ nguyên kích thước. Chọn decode/cache phù hợp DPR, không tải ảnh full-resolution vô ích.
- Chấm indicator nhỏ, tương phản đủ. **CẤM** để ảnh loading gây đổi chiều cao card giật màn hình.
- Ảnh từ CDN/HTTPS được phép và có quyền sử dụng; không dùng URL Google Drive riêng tư hoặc hotlink không ổn định.

**7.2. Badge và yêu thích**
- Tối đa **01 badge chính** ở góc trái trên ảnh. Thứ tự ưu tiên **`featured > new > near-beach > saltwater > group`**.
- Badge pill: nền trắng ~95% opacity, chữ `#222222`, icon nhỏ, viền trắng rất nhẹ, shadow mềm.
- Yêu thích: icon trái tim ở góc phải trên ảnh, animation nhấn nhỏ (scale 1 → 0.9 → 1 nếu reduced motion cho phép), có trạng thái và semantic label. Nếu backend chưa có favorites, không giả vờ lưu lâu dài.

**7.3. Thông số villa — đúng thứ tự**
1. Phòng ngủ (`X phòng`, icon bed).
2. Giường (`Y giường`, icon bed-double).
3. Sức chứa (`Z khách`, icon users).
4. WC (`W WC`, icon bath).
5. Khoảng cách biển (`N m tới biển`, icon map-pin).

Dùng `Wrap` hoặc layout thích ứng; **CẤM** cố nhét năm mục khiến chữ bị cắt/tràn. Giá trị không có dữ liệu thì không hiển thị sai `0`.

**7.4. Giá — đúng thứ bậc**
- Chính: `Từ [giá đã xác minh] ₫ / đêm` — size 16–18, đậm, `textStrong`.
- Phụ: `Thứ 7: [giá] ₫` — `textMuted`, chỉ khi có dữ liệu.
- Chưa có giá: **`Liên hệ báo giá`**, dẫn tới kênh tư vấn được cấu hình.
- Định dạng tiền Việt Nam dùng `intl`/`NumberFormat` với số nguyên VND; backend là nguồn quyết định giá, ngày lễ/cuối tuần, phụ thu và khả dụng.
- Không tự tính giá cuối tuần bằng công thức tùy ý. Không hiển thị giá giả làm giá công bố.

## 8. PROPERTY DETAIL / TRANG CHI TIẾT

**Widget chuẩn:** `PropertyDetailScreen`, `PropertyGallery`, `MobileSpecSummary`, `PropertyOverviewSection`, `PropertyFaqSection`, `BookingActionBar`.

**8.1. Thông số 2 tầng**
- **4 core specs** khi thu gọn: **Sức chứa → Phòng ngủ → Giường → WC**.
- **4 supporting specs** khi mở rộng: **Hồ bơi riêng → Bếp/BBQ → Đậu xe → Khoảng cách biển**.
- Mặc định một hàng gọn nếu đủ chỗ; nếu thiết bị hẹp hoặc chữ phóng to thì xuống dòng thay vì overflow.
- Khi mở rộng hiển thị lưới 2 cột (`AnimatedSize`/`AnimatedSwitcher`) và có semantics trạng thái expanded/collapsed.

**8.2. Overview và FAQ**
- Trên mobile mặc định thu gọn, mở theo `ExpansionTile` hoặc accordion widget riêng.
- Nút mũi tên xoay 90° theo trạng thái, animation 180–250ms nếu không có yêu cầu giảm chuyển động.
- Không render FAQ lỗi markup hoặc cho nội dung nguy hiểm tùy tiện vào HTML widget.

**8.3. Chia sẻ**
- Tiêu đề villa cùng nút chia sẻ/copy link (`IconButton` có tooltip/label). Link dẫn đến URL công khai/canonical thật và ổn định, không tự dựng ID URL không được backend hỗ trợ.
- Khi copy thành công, `SnackBar` hoặc thông báo overlay **không đẩy layout**. Thông báo cho accessibility và không hiển thị thành công nếu tác vụ thất bại.
- Nếu dùng share sheet của hệ điều hành, chỉ bật khi cấu hình deep link/canonical URL đã kiểm thử.

## 9. SEARCH, FILTER VÀ DATE PICKER

**9.1. Mobile search**
- Trang chủ hiển thị thanh gọn: icon tìm kiếm + `Bắt đầu tìm kiếm`.
- Nhấn mở `showModalBottomSheet(isScrollControlled: true, useSafeArea: true, ...)` hoặc full-screen route theo đặc thù kích thước màn hình.
- Form: **Điểm đến/vị trí → Nhận phòng → Trả phòng → Số khách → Tìm kiếm**. Các ô tương tác cao khoảng 56–64 logical pixel.
- Khi mở bàn phím, đảm bảo có thể cuộn, nút xác nhận không bị che bởi `viewInsets.bottom`.
- Bộ lọc dùng các lựa chọn thực của backend; số kết quả/chỉ báo phải là dữ liệu đúng.

**9.2. Date range visual**
- Ngày bắt đầu và kết thúc được chọn: ô tròn **Coral `#FF385C`**, chữ trắng.
- Ngày trong khoảng: **`#FFF1F3`**, chữ `#222222`.
- Hôm nay: chấm Coral nhỏ; điều hướng tháng neutral, không cyan/teal.
- Ngày không khả dụng: chữ xám + gạch ngang (`TextDecoration.lineThrough`) + chặn chọn; semantic label: `Ngày này đã kín`.
- **KHÔNG hiển thị tên khách/đoàn đã đặt** trong tooltip hay accessibility label. Source web cũ có ví dụ tên người đặt: loại bỏ để bảo vệ dữ liệu cá nhân.

**9.3. Quy tắc nghiệp vụ ngày ở (bắt buộc)**
- Xử lý **ngày lịch của villa theo `Asia/Ho_Chi_Minh`**, tách khỏi timezone thiết bị. Dữ liệu API dạng **`YYYY-MM-DD`**, không biến ngày check-in thành timestamp UTC tùy tiện.
- Mô hình đêm lưu trú là **nửa mở**: `[checkIn, checkOut)`. Ví dụ 15/10–17/10 gồm **đêm 15 và 16**, check-out 17 không phải đêm ở.
- `checkOut > checkIn`; áp dụng giới hạn số đêm, ngày đặt trước, quy tắc phụ thu theo dữ liệu server.
- Mọi đêm trong khoảng **phải khả dụng**, không cho chọn range xuyên ngày kín. Một ngày có khách check-in mới vẫn có thể là ngày check-out của khách trước: tránh vô hiệu hóa sai ngày check-out bằng logic "ngày này bị booked" nếu API đã mô hình hóa theo đêm.
- Khi đổi check-in, xác minh/recompute check-out và giá. Nếu dữ liệu trống/không đồng bộ, chặn gửi yêu cầu đặt chắc chắn.
- **Tính hợp lệ cuối cùng do backend kiểm tra** để tránh tranh chấp đặt cùng thời điểm; lịch client không phải nguồn chân lý.
- Dùng helper/value object `BookingDate` và test khoảng ngày ở. `DateTime.utc(y,m,d)` có thể dùng **chỉ để tính toán ngày lịch** nhất quán (không xem là thời điểm nhận phòng); khi serialize lấy riêng y-m-d. **CẤM** dùng `toUtc().toIso8601String()` để biểu diễn ngày đặt phòng.

## 10. DANH SÁCH GIÁ THEO ĐÊM, SCROLL VÀ STICKY CTA

**Mục tiêu từ rule web:** danh sách giá 10–20 đêm **không bao giờ đẩy nút Zalo, Hotline, Đặt phòng ra khỏi vùng tương tác**.

- Widget: `DailyPriceBreakdown`, `BookingPriceList`, `BookingActionBar`.
- Điện thoại: vùng danh sách chi tiết giá có **chiều cao tối đa ~220 logical px**; tablet có thể ~248. Tùy chỉnh nếu text scaling cao để không cắt thông tin.
- Dùng `ConstrainedBox` + `ListView.builder(shrinkWrap: true, primary: false)`. Nếu ít dòng, list co theo nội dung; nếu nhiều, list cuộn độc lập. Không lạm dụng `SingleChildScrollView` lồng vô hạn với `ListView`.
- Không hiện scrollbar khi không cần. Nếu cần, `Scrollbar`/`RawScrollbar` neutral slate mờ; không dùng thanh màu Coral đậm hay gradient. Trên touch, thanh cuộn được framework/OS xử lý thích hợp; không áp quy tắc CSS `5px` cứng cho mọi nền tảng.
- `Scaffold.bottomNavigationBar` hoặc `bottomSheet` có `SafeArea` chứa CTA chính, quản lý bàn phím và vùng nút điều hướng. Khi mở modal/filter full screen thì **ẩn launcher nổi** và tránh để hai CTA chồng nhau.
- Widget parent cuộn dọc, child list cuộn có physics được test thực tế; không đặt scroll lock kiểu `document.body`.

Mẫu kỹ thuật (minh họa, cần ghép dữ liệu từ ViewModel):

```dart
ConstrainedBox(
  constraints: const BoxConstraints(maxHeight: 220),
  child: ListView.builder(
    primary: false,
    shrinkWrap: true,
    itemCount: nightlyPrices.length,
    itemBuilder: (context, index) {
      return NightlyPriceRow(item: nightlyPrices[index]);
    },
  ),
)
```

## 11. BUTTONS, FORMS, CHIPS VÀ MODALS

**11.1. AppButton**
- `primary`: Coral `#FF385C`, chữ trắng, pill, tối thiểu 48 logical px cao, loading và disabled rõ ràng.
- `secondary`: nền trắng, viền `#DDDDDD`, chữ `#222222`; khi focus/pressed có visual feedback.
- `ghost`: nền trong suốt, pressed sử dụng surface tối 4%.
- `icon`: hit area **tối thiểu 44×44**, chuẩn thiết kế mặc định 48×48; icon thường size 18–20.
- Có `enableFeedback`, loading tránh double submit; haptic phản hồi nhẹ khi phù hợp; không spam rung.
- Nhấn có scale nhẹ khoảng 0.98 khi phù hợp và user không bật reduce motion; **không làm thay đổi layout xung quanh**.

**11.2. Inputs**
- `TextFormField` có `InputDecorationTheme`, viền `#DDDDDD`, shape stadium/pill (multiline dùng rounded rect). Focus viền `#222222`, không dùng màu focus xanh mặc định lệch thương hiệu.
- Nội dung nhập dài: multiline bo góc khoảng 24px, tối thiểu khoảng 128 logical px khi phù hợp.
- Dùng `Form` + validators; `autofillHints`, `textInputAction`, `keyboardType`, input formatters theo ngữ nghĩa.
- Hiển thị lỗi ngay cạnh field, không chỉ bằng màu; giữ nội dung khi API lỗi.

**11.3. Chips**
- Mặc định trắng, viền `#EBEBEB`, chữ đậm vừa `#222222`.
- Active đen than `#222222`, chữ trắng. Có semantics selected, kích thước bấm chuẩn.

**11.4. Bottom sheets, dialogs và focus**
- Mobile filter/booking: `showModalBottomSheet`, bo góc **trên** khoảng 36px, có `SafeArea`, hỗ trợ `viewInsets.bottom` khi bàn phím mở.
- Modal Flutter quản lý barrier và scroll riêng; **CẤM** thao tác `document.body.style.overflow`.
- Dismiss bằng Back/Escape theo ngữ cảnh; **không đóng đột ngột** form đang có dữ liệu chưa lưu.
- Focus chỉ điều hướng trong modal theo traversal policy thích hợp; khi đóng khôi phục focus vào control khởi tạo nếu cần, test với bàn phím ngoài/VoiceOver/TalkBack.
- Kiểm tra cả thiết bị có gesture-navigation, notch, Dynamic Island và kích thước màn hình nhỏ.

## 12. ZALO, HOTLINE VÀ MOBILE QUICK NAVIGATION

**12.1. Zalo CTA có ngữ cảnh**
- Helper ở `lib/features/booking_inquiry/.../contact_service.dart` tạo **nội dung gợi ý** gồm tên/mã villa, ngày check-in/check-out, số người, nhu cầu tư vấn — chỉ lấy từ dữ liệu khách đồng ý chia sẻ.
- **Không giả định Zalo hỗ trợ deep link điền sẵn tin nhắn.** Chỉ dùng deep link/URL có **tài liệu chính thức và đã kiểm thử trên Android+iOS**. Nếu không điền trước được, dùng luồng an toàn: tạo văn bản → người dùng chọn sao chép/chia sẻ → mở Zalo bằng liên kết hợp lệ → hướng dẫn dán nội dung.
- Nếu `launchUrl` thất bại/không có app, hiện fallback hợp lệ (trang liên hệ chính thức hoặc copy text) thay vì chỉ màn hình trắng.
- Không tự gửi tin nhắn dưới danh nghĩa khách khi chưa có thao tác xác nhận; không nhúng access token của Zalo vào Flutter.

**12.2. Hotline**
- Gọi qua `url_launcher` với `Uri(scheme: 'tel', path: hotlineNumber)` sau khi validate số điện thoại đã cấu hình; không hardcode số chưa xác nhận.
- Có fallback copy số khi không thể gọi (ví dụ simulator/tablet). Chỉ thực hiện hành động sau khi người dùng bấm.

**12.3. Launcher và điều hướng đáy**
- Launcher nổi: Zalo + Hotline phía dưới bên phải, có offset trên `SafeArea`/bottom bar để không chồng CTA.
- Khi bộ lọc hoặc modal toàn màn hình mở, **ẩn launcher** qua state (Riverpod/local UI state); không hack CSS attribute.
- Bottom navigation dành cho màn hình khám phá mặc định có 3 tác vụ: **Khám phá → Zalo → Hotline**. Nếu nút Zalo/Hotline là hành động, không biến chúng thành tab trống; dùng `NavigationBar` hoặc thanh hành động native được thiết kế riêng.
- Trên màn chi tiết có sticky CTA giá/liên hệ. Không hiển thị hai lớp bottom bar che nhau.

## 13. RESPONSIVE, ACCESSIBILITY VÀ NATIVE BEHAVIOR

- Flutter sử dụng **logical pixels**, `MediaQuery`, `LayoutBuilder`, `SafeArea`, không dùng CSS breakpoints, `vh`, `env(safe-area-inset-bottom)` hay `overflow-x:hidden`.
- **PHẢI** không để `RenderFlex overflowed` trên iPhone nhỏ, Android màn hình hẹp, tablet hoặc khi text scaling tăng.
- **PHẢI** hỗ trợ vùng chạm tối thiểu **44×44 logical px**; mục tiêu 48×48 cho nút/chip/ô ngày.
- Với text scaling lớn, ưu tiên `Wrap`, `Flexible`, `Expanded`, layout dọc và `Scrollable.ensureVisible` thay vì ép chữ nhỏ.
- `Semantics`, `Tooltip`, labels/hints cho icon-only controls; kiểm tra TalkBack/VoiceOver, contrast, thứ tự focus, chế độ chữ to.
- Dùng `MediaQuery.disableAnimationsOf(context)` cho platform hỗ trợ; **iOS giảm chuyển động phải xét cả `AccessibilityFeatures.reduceMotion`/API tương ứng**, không cho rằng cờ `disableAnimations` bao phủ mọi OS.
- Không dùng animation kéo dài khiến app chậm hoặc khó chịu; animation mặc định thường 150–250ms, dùng curve ease-out theo cảm giác native. Không tự ý thêm 3D.
- `PageView` phải không tranh gesture với cuộn dọc; có cách truy cập ảnh khác ngoài vuốt khi cần a11y.
- Không dùng hover làm kênh tương tác duy nhất vì mobile là touch; luôn có pressed/focus/selected/disabled states.
- Thiết bị/OS có dark appearance: đảm bảo text/status bar/surface dễ đọc trong **Light Luxury** nếu dark mode chưa được hỗ trợ.

## 14. HIỆU NĂNG VÀ HÌNH ẢNH

- Tải danh sách bằng `ListView.builder`/`SliverList`; tránh dựng hàng trăm item cùng lúc.
- Ảnh dùng kích thước decode/cached phù hợp màn hình, `AspectRatio` cố định, placeholder + retry có kiểm soát.
- Tránh `setState`/provider rebuild toàn màn hình khi đổi một favorite hoặc carousel index. Phân rã widget và dùng `select` hợp lý nếu cần.
- Không thực hiện JSON parse cực lớn, transform hình ảnh hay tác vụ CPU tốn thời gian trên UI isolate. Với tải nặng, cân nhắc isolate (`compute`) sau khi đo.
- Giữ page transitions và scroll mượt; đo bằng **Flutter DevTools (profile mode)** trên thiết bị thật, không tự tuyên bố "60 FPS" khi chưa đo.
- Theo dõi cold start, jank, dung lượng app, lỗi crash, mạng chậm/offline, ảnh lỗi. Tối ưu theo số đo và ưu tiên luồng tìm/chọn villa.
- **Core Web Vitals / CLS / `loading="lazy"` là chỉ số/cú pháp website**, không phải quality gate native. Thay bằng đo jank, frame time, rasterization, network/image loading và layout ổn định.
- Không đặt mục tiêu "API < 500ms" như cam kết tuyệt đối của client; đo p50/p95, cache, timeout và hiển thị loading trung thực.

## 15. API, BẢO MẬT, QUYỀN RIÊNG TƯ

- **HTTPS bắt buộc** cho production, kiểm tra hostname/chứng chỉ đúng; CẤM `badCertificateCallback => true` hoặc tắt TLS validation.
- **Không chứa secrets trong app:** `--dart-define` là cấu hình build, có thể trích xuất; API key bí mật, Zalo OA token, DB credentials, signing keys ở backend/secret manager.
- Không ghi token, mật khẩu, số điện thoại khách, tên đoàn đã đặt hoặc dữ liệu cá nhân vào log/Crashlytics/analytics nếu không được phép và cần thiết.
- Nếu có đăng nhập: token ở `flutter_secure_storage`; logout hủy thông tin xác thực; backend xác nhận quyền, token rotation/revocation và expiry.
- Kiểm tra đầu vào/số khách/ngày lưu trú/định dạng giá ở UI để cải thiện trải nghiệm **và kiểm tra lại tại backend**.
- API availability/pricing phải là nguồn dữ liệu chính thức. Khi gửi yêu cầu đặt/giữ chỗ, backend kiểm tra giao dịch một cách nhất quán; client không thể đảm bảo chống double-booking.
- Không hiển thị thông tin khách đã đặt trong lịch công khai. Chỉ hiện `Đã kín`/`Không khả dụng` hoặc lý do đã được phép công bố.
- Chỉ xin quyền thiết bị thực sự cần thiết; cấu hình `AndroidManifest.xml`, `Info.plist`, Android queries và iOS URL schemes tối thiểu.
- Không viết cơ chế tự động liên hệ/gửi message trong nền khi người dùng chưa đồng ý.
- Link đích phải đáng tin: Zalo official/chat đã cấu hình, số hotline xác thực, domain chính thức; không lấy URI tùy ý từ API rồi mở trực tiếp mà không allowlist/validate.
- Xử lý mạng: connect/receive timeout, lỗi HTTP 401/403/429/5xx, offline, duplicate-submit, retry chỉ khi thao tác an toàn (idempotent).
- Dữ liệu đặt villa/tư vấn cần chính sách bảo mật và thời gian lưu theo quy định áp dụng.

## 16. BUILD CONFIG / ANDROID + iOS FLAVORS

**Phải tách `dev`, `staging`, `prod`**: backend URL, app ID/bundle ID, tên hiển thị, icon khi cần và signing riêng. `prod` PHẢI không trỏ tới staging/dev.

```text
config/dev.json       APP_ENV=dev;     API_BASE_URL=https://<dev-host>
config/staging.json   APP_ENV=staging; API_BASE_URL=https://<staging-host>
config/prod.json      APP_ENV=prod;    API_BASE_URL=https://<prod-host>
```

Các placeholder host là **ví dụ, không được build production** khi chưa thay bằng URL đã xác minh và bảo vệ server.

**Mẫu mã cấu hình:**

```dart
class AppConfig {
  static const environment = String.fromEnvironment('APP_ENV');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static void validate(String expectedEnvironment) {
    if (environment != expectedEnvironment) {
      throw StateError('Build environment mismatch');
    }
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('Invalid HTTPS API_BASE_URL');
    }
  }
}
```

- Android: cấu hình `productFlavors` trong Gradle, `applicationIdSuffix` dev/staging khi phù hợp, release keystore riêng.
- iOS: tạo shared Xcode Schemes (`dev`,`staging`,`prod`), map Debug/Profile/Release configurations và Bundle IDs tương ứng. Build iOS chỉ trên **macOS + Xcode**.
- Lệnh bên dưới chỉ áp dụng **sau khi cấu hình flavor native thành công**.

```bash
flutter --version
flutter doctor -v
flutter pub get
flutter pub add flutter_riverpod go_router dio intl url_launcher lucide_icons_flutter
flutter pub add flutter_localizations --sdk=flutter
flutter pub add --dev flutter_lints mocktail
flutter pub add integration_test --sdk=flutter --dev

# Chạy môi trường đã cấu hình
flutter run --flavor dev --dart-define-from-file=config/dev.json
flutter run --flavor staging --dart-define-from-file=config/staging.json

# Chỉ khi signing + flavor native sẵn sàng:
flutter build appbundle --release --flavor prod --dart-define-from-file=config/prod.json
flutter build ipa --release --flavor prod --dart-define-from-file=config/prod.json
```

> Các gói cho auth, storage, model generation, image cache và observability chỉ thêm khi ứng dụng có nhu cầu thực. Lệnh ví dụ không thay thế bước tạo dự án `flutter create --org <org> --platforms=android,ios <project_name>` và cấu hình native.

## 17. KIỂM THỬ BẮT BUỘC

**17.1. Unit tests**
- Chuẩn ngày `YYYY-MM-DD` và nghiệp vụ nửa mở `[checkIn, checkOut)`.
- Khoảng ngày giao qua một hoặc nhiều đêm không khả dụng phải bị chặn.
- Ngày check-out trùng ngày check-in khách mới phải xử lý đúng theo nghiệp vụ đêm.
- Giá ngày thường, thứ Bảy, lễ, phụ thu lấy từ backend, format VND không sai dấu.
- Độ ưu tiên badge `featured > new > near-beach > saltwater > group`.
- Helper tạo nội dung yêu cầu Zalo không bỏ qua mã villa, ngày, số khách khi đã có dữ liệu.

**17.2. Widget/golden tests**
- PropertyCard: aspect ratio, badge tối đa 1, specs đúng thứ tự, giá/`Liên hệ báo giá`.
- Date picker: Coral selection, range background, booked nights disabled, a11y labels.
- `DailyPriceBreakdown`: 1–4 đêm co gọn, 10–20 đêm cuộn trong giới hạn, CTA luôn hiển thị.
- Modal + bàn phím: nút xác nhận không bị che, focus và back/dismiss hợp lý.
- VI/EN/KO, chữ Việt có dấu, font Hàn, text scale 1.0/1.3/2.0 (kiểm tra các thiết bị hỗ trợ).
- Android/iOS light theme, màn nhỏ và tablet, không RenderFlex overflow.

**17.3. Integration tests**
- Khám phá → lọc → mở chi tiết → xem lịch → tư vấn Zalo/hotline.
- Mạng lỗi, mạng chậm, empty result, ảnh lỗi, API 401/403/500.
- Zalo chưa cài, không mở được deep link, `tel:` không hỗ trợ.
- Quay lại từ external app, lifecycle resumed, mở link chia sẻ/canonical.
- Trên thiết bị thật: Android + iPhone, TalkBack/VoiceOver khi có thể.

**17.4. CI quality gates:**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
```

- Không merge code khi formatter/analyzer/test thất bại.
- Test thất bại cần điều tra và sửa; **CẤM** xóa test hoặc thêm `ignore` chỉ để xanh pipeline.
- Không khẳng định "đã test", "đã build iOS" hay "đã chạy device" nếu thực tế chưa chạy.
- Test coverage là chỉ số tham khảo; các logic đặt villa quan trọng phải có bài test thực, không chạy theo % ảo.

## 18. CHECKLIST TRƯỚC COMMIT, MERGE VÀ RELEASE

### A. Thiết kế và trải nghiệm

- [ ] Coral `#FF385C` nhất quán; không xuất hiện bảng màu/gradient lệch thương hiệu.
- [ ] Typography iOS/Android hợp lệ về license; tiếng Việt/Anh/Hàn hiển thị không lỗi glyph.
- [ ] Dùng bộ icon Lucide Flutter; màu/sizes/labels đúng, vùng chạm ≥44×44.
- [ ] Ảnh có aspect ratio 4:3 trên card mobile và có placeholder/fallback.
- [ ] Tối đa 1 badge theo đúng độ ưu tiên `featured > new > near-beach > saltwater > group`.
- [ ] Specs card: phòng → giường → khách → WC → biển. Detail: core 4 + supporting 4.
- [ ] Giá VND và giá thứ Bảy có dữ liệu nguồn; thiếu giá hiển thị `Liên hệ báo giá`.
- [ ] Form tìm kiếm/Date Picker hiển thị và validate theo ngày đêm địa phương.
- [ ] Ngày kín không chọn được và **không tiết lộ danh tính khách đã đặt**.
- [ ] Danh sách giá dài cuộn riêng, sticky CTA Zalo/Hotline không bị đẩy khỏi màn hình.
- [ ] Bottom sheet, keyboard, notch, safe area, back navigation và focus hoạt động đúng.
- [ ] Launcher ẩn khi filter toàn màn hình mở; không có CTA bị chồng.
- [ ] Không RenderFlex overflow; test text scaling lớn, reduced motion, screen reader.

### B. Kiến trúc và chất lượng

- [ ] UI không gọi Dio/storage trực tiếp; sử dụng ViewModel + Repository.
- [ ] Các trạng thái loading/empty/error/retry đầy đủ.
- [ ] Không có mã React/Tailwind/CSS/DOM trong Flutter native.
- [ ] Không thêm package không cần thiết; cập nhật `pubspec.lock`.
- [ ] Không hardcode secret/token/URL môi trường trong code.
- [ ] Không log PII; số hotline/URL Zalo phải được xác minh.
- [ ] Unit, widget, integration tests liên quan đã chạy và đạt.
- [ ] `dart format`, `flutter analyze`, `flutter test` đạt.
- [ ] Đã test device Android và iOS trước release; kiểm tra version, signing, flavor.
- [ ] Không thay website/backend/database/production ngoài phạm vi được phép.

## 19. HƯỚNG DẪN BẮT BUỘC CHO AI CODING ASSISTANTS

Khi AI nhận nhiệm vụ sửa/tạo màn hình Flutter cho Minh Thanh Villa, **PHẢI** thực hiện theo thứ tự:

1. **Đọc file rule này và đọc mã nguồn hiện có** (`pubspec.yaml`, `lib/app/theme`, router, provider, widget shared) trước khi quyết định sửa. Không giả định dự án trống.
2. Tóm tắt yêu cầu và **file dự kiến thay đổi**; chỉ thực hiện trong phạm vi được giao.
3. Xác minh API/models hiện hữu; nếu thiếu giá/lịch/trạng thái, làm state hoặc ghi rõ cần backend, **không bịa dữ liệu production**.
4. Tái sử dụng tokens, UI components, providers, repository interfaces. Không tạo cùng một widget `AppButton`/`PropertyCard` lần thứ hai.
5. Đảm bảo Android/iOS native: safe area, gestures, keyboard, external intents, localization, back và a11y.
6. Viết/sửa unit + widget tests cho logic/thành phần thay đổi; integration test luồng chính khi có ảnh hưởng.
7. Chạy formatter, analyzer, test có thể chạy được; với iOS chỉ báo đã build nếu có Mac/Xcode và lệnh build thật sự thành công.
8. Báo cáo kết quả bằng: **file đã sửa → hành vi thay đổi → test đã chạy/kết quả → phần chưa xác minh → rủi ro/cần quyết định**.
9. Không lén thay đổi rule hoặc xóa tests/lint checks để giải quyết lỗi.
10. Nếu yêu cầu mới xung đột rule, chỉ rõ điểm xung đột và ưu tiên bảo mật, dữ liệu đúng, nền tảng hợp pháp.

## 20. BẢNG QUY ĐỔI TỪ RULE WEB CŨ SANG FLUTTER NATIVE

| Rule web ban đầu | Quy tắc Flutter tương ứng |
|---|---|
| `src/index.css` / Tailwind `@theme` | `ThemeData`, `ColorScheme`, `AppColors`, `AppSpacing` |
| SF Pro local `.otf` | iOS font hệ thống SF; Android font phù hợp giấy phép và Unicode |
| `lucide-react` | `lucide_icons_flutter` |
| Framer Motion | `AnimatedSize`, `AnimatedSwitcher`, `TweenAnimationBuilder`, `AnimationController` |
| Embla carousel / `touch-action` | `PageView` + `PageController` và gesture tests |
| `aspect-[4/3]` | `AspectRatio(aspectRatio: 4 / 3)` |
| `.font-display`, text-wrap | `TextTheme`, `TextStyle`, `maxLines`, responsive layout |
| Badge pill HTML/CSS | `Positioned`/`Container` trong `Stack` |
| `DatePickerModal` DOM | `showModalBottomSheet` + date-range widget/provider |
| `overflow-y:auto`, scrollbar CSS | `ConstrainedBox` + `ListView` + `Scrollbar` khi cần |
| `position: sticky`/fixed footer | `Scaffold.bottomNavigationBar`, `SafeArea` |
| `env(safe-area-inset-bottom)` | `SafeArea`, `MediaQuery.viewPaddingOf` |
| `document.body` scroll lock | Native Flutter dialog/sheet barrier và scroll management |
| `aria-label`, `tabIndex`, `role` | `Semantics`, `Focus`, `FocusTraversalGroup`, `Tooltip` |
| `prefers-reduced-motion` | Flutter/OS accessibility flags, tối giản animation |
| `zaloCta.js` | `ContactService` + `url_launcher` + fallback copy/share |
| `navigator.clipboard.writeText` | `Clipboard.setData(ClipboardData(text: ...))` |
| CSS hover color | pressed/focus/disabled/selected states thích hợp cho touch |
| CLS/Core Web Vitals | Profile-mode jank/frame performance và placeholder/size ổn định |
| CSS test `scrollbar.test.jsx` | Flutter `test/` widget tests + integration tests |
| React Leaflet / React Three | Chỉ chọn Flutter mapping/3D plugin nếu feature thật sự cần |

---

## 21. TÀI LIỆU THAM KHẢO KỸ THUẬT

- Flutter App Architecture: https://docs.flutter.dev/app-architecture/guide
- Flutter Android/iOS flavors: https://docs.flutter.dev/deployment
- Flutter iOS Flavors: https://docs.flutter.dev/deployment/flavors-ios
- Flutter Localization: https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization
- Flutter API — `MediaQuery.disableAnimationsOf`: https://api.flutter.dev/flutter/widgets/MediaQuery/disableAnimationsOf.html
- Flutter Package `lucide_icons_flutter`: https://pub.dev/packages/lucide_icons_flutter
- Flutter Package `url_launcher`: https://pub.dev/packages/url_launcher
- Apple San Francisco Fonts — đọc đầy đủ điều khoản quyền sử dụng trước khi phân phối: https://developer.apple.com/fonts/

**Kết luận:** Đây là **file rule để hướng dẫn code và nghiệm thu**, không phải bằng chứng ứng dụng đã được build, test hoặc backend đã sẵn sàng. Những điểm phụ thuộc API hiện hữu, Zalo deep links, số hotline, font assets, bundle ID, thiết bị test và signing phải được xác minh khi triển khai.
