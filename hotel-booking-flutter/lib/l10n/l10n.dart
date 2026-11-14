import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';
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
