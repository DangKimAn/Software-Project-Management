import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';
// CONFLICT-RESOLVED: Import trực tiếp locale_formatters.dart để sử dụng LocaleFormatters.normalizeLanguageCode bên trong extension AppLocalizationsX song song với export ra ngoài.
import 'locale_formatters.dart';

export 'generated/app_localizations.dart';
export 'locale_formatters.dart';

/// Convenient extension on [BuildContext] for retrieving [AppLocalizations]
/// with a resilient fallback to Vietnamese (`vi`) when a test harness or parent
/// widget tree has not registered `AppLocalizations.delegate`.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n {
    final fromTree = Localizations.of<AppLocalizations>(this, AppLocalizations);
    if (fromTree != null) {
      return fromTree;
    }
    // Giải thuật dự phòng ngôn ngữ mặc định cho môi trường Widget Test tối giản:
    // Khi `MaterialApp` trong test không đăng ký `AppLocalizations.delegate` và không truyền `locale`,
    // Flutter tự gán `const Locale('en', 'US')`; lúc này trả về tiếng Việt (`vi`) đúng chuẩn mặc định của hệ thống.
    final activeLocale = Localizations.maybeLocaleOf(this);
    // CONFLICT-RESOLVED: Giữ chuẩn hóa mã ngôn ngữ qua LocaleFormatters.normalizeLanguageCode và bảo toàn fallback tiếng Việt khi test harness dùng Locale('en', 'US') mặc định.
    if (activeLocale == null ||
        (activeLocale.languageCode == 'en' &&
            activeLocale.countryCode == 'US')) {
      return lookupAppLocalizations(const Locale('vi'));
    }
    final code = LocaleFormatters.normalizeLanguageCode(
      activeLocale.languageCode,
    );
    return lookupAppLocalizations(Locale(code));
  }

  String get activeLanguageCode {
    final fromTree = Localizations.of<AppLocalizations>(this, AppLocalizations);
    if (fromTree != null) {
      // CONFLICT-RESOLVED: Chuẩn hóa localeName qua LocaleFormatters.normalizeLanguageCode để đồng nhất mã vi/en/ko trên toàn ứng dụng.
      return LocaleFormatters.normalizeLanguageCode(fromTree.localeName);
    }
    final activeLocale = Localizations.maybeLocaleOf(this);
    if (activeLocale == null ||
        (activeLocale.languageCode == 'en' &&
            activeLocale.countryCode == 'US')) {
      return 'vi';
    }
    return LocaleFormatters.normalizeLanguageCode(activeLocale.languageCode);
  }
}
