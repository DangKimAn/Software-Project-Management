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
    final activeLocale = Localizations.maybeLocaleOf(this);
    final code = LocaleFormatters.normalizeLanguageCode(
      activeLocale?.languageCode,
    );
    return lookupAppLocalizations(Locale(code));
  }

  String get activeLanguageCode {
    final activeLocale = Localizations.maybeLocaleOf(this);
    return LocaleFormatters.normalizeLanguageCode(activeLocale?.languageCode);
  }
}
