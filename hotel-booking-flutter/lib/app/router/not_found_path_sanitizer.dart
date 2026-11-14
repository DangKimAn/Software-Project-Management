import 'package:flutter/widgets.dart';
import '../../l10n/l10n.dart';

/// Làm sạch đường dẫn lỗi 404 trước khi hiển thị lên giao diện.
///
/// Giải thuật chuẩn hóa & bảo mật đường dẫn (Safe Path Sanitization):
/// 1. Tách phân đoạn `path` qua `Uri.tryParse`, chủ động loại bỏ toàn bộ
///    `queryParameters`, `fragment`, `userInfo` và `host` để tuyệt đối không
///    làm lộ token xác thực, mã OTP hay dữ liệu nhạy cảm trên màn hình.
/// 2. Gộp các dấu gạch chéo liên tiếp (`//`) thành một dấu `/` duy nhất và
///    bỏ dấu `/` thừa ở cuối.
/// 3. Ẩn nhãn nếu đường dẫn rỗng hoặc chỉ là gốc `/`; cắt gọn có dấu `…` nếu
///    độ dài vượt quá `maxLength` ký tự nhằm bảo toàn bố cục trên màn hình hẹp.
String? sanitizeNotFoundDisplayPath(
  String? rawLocation, {
  int maxLength = 44,
}) {
  if (rawLocation == null) return null;
  final trimmed = rawLocation.trim();
  if (trimmed.isEmpty) return null;

  final withoutQueryOrFragment = trimmed.split(RegExp(r'[?#]')).first.trim();
  if (withoutQueryOrFragment.isEmpty) return null;

  final parsed = Uri.tryParse(withoutQueryOrFragment);
  var rawPath = (parsed != null && parsed.path.isNotEmpty)
      ? parsed.path
      : withoutQueryOrFragment;

  if (!rawPath.startsWith('/')) {
    rawPath = '/$rawPath';
  }
  rawPath = rawPath.replaceAll(RegExp(r'/+'), '/');
  if (rawPath.length > 1 && rawPath.endsWith('/')) {
    rawPath = rawPath.substring(0, rawPath.length - 1);
  }
  if (rawPath.isEmpty || rawPath == '/') {
    return null;
  }

  if (rawPath.length <= maxLength) {
    return rawPath;
  }
  final keep = (maxLength - 1).clamp(8, rawPath.length);
  return '${rawPath.substring(0, keep)}…';
}

/// Dữ liệu văn bản đa ngôn ngữ (`vi` / `en` / `ko`) cho màn hình 404.
class NotFoundLocalizedCopy {
  final String eyebrow;
  final String pathPrefix;
  final String quickSectionTitle;
  final String staysSubtitle;
  final String blogSubtitle;
  final String contactSubtitle;
  final AppLocalizations l10n;

  const NotFoundLocalizedCopy({
    required this.eyebrow,
    required this.pathPrefix,
    required this.quickSectionTitle,
    required this.staysSubtitle,
    required this.blogSubtitle,
    required this.contactSubtitle,
    required this.l10n,
  });

  /// Giải thuật phân giải ngôn ngữ an toàn (Resilient Locale Resolution):
  /// Ưu tiên `AppLocalizations` từ cây widget; khi chạy trong môi trường test
  /// tối giản không đăng ký delegate, tự động quay về tiếng Việt (`vi`) chuẩn.
  static NotFoundLocalizedCopy resolve(BuildContext context) {
    final delegatedL10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final lang = delegatedL10n != null
        ? LocaleFormatters.normalizeLanguageCode(delegatedL10n.localeName)
        : 'vi';
    final l10n = delegatedL10n ?? lookupAppLocalizations(const Locale('vi'));
    return switch (lang) {
      'en' => NotFoundLocalizedCopy(
          eyebrow: 'WAYFINDING • THE PALM VILLA',
          pathPrefix: 'Requested path',
          quickSectionTitle: 'Or jump straight to popular sections',
          staysSubtitle: 'Whole-villa stays in Vung Tau',
          blogSubtitle: 'Local guides & travel tips',
          contactSubtitle: '24/7 booking concierge',
          l10n: l10n,
        ),
      'ko' => NotFoundLocalizedCopy(
          eyebrow: '길 찾기 • THE PALM VILLA',
          pathPrefix: '요청 경로',
          quickSectionTitle: '또는 주요 메뉴로 바로 이동하세요',
          staysSubtitle: '붕따우 독채 풀빌라 탐색',
          blogSubtitle: '현지 여행 & 숙박 가이드',
          contactSubtitle: '24/7 예약 컨시어지 문의',
          l10n: l10n,
        ),
      _ => NotFoundLocalizedCopy(
          eyebrow: 'ĐIỀU HƯỚNG • THE PALM VILLA',
          pathPrefix: 'Đường dẫn truy cập',
          quickSectionTitle: 'Hoặc khám phá nhanh các chuyên mục chính',
          staysSubtitle: 'Biệt thự nghỉ dưỡng Vũng Tàu',
          blogSubtitle: 'Kinh nghiệm du lịch & lưu trú',
          contactSubtitle: 'Hỗ trợ tư vấn đặt phòng 24/7',
          l10n: l10n,
        ),
    };
  }
}
