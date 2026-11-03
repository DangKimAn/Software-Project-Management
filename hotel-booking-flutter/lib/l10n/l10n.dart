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
    if (activeLocale?.languageCode == 'ko') {
      return lookupAppLocalizations(const Locale('ko'));
    }
    return lookupAppLocalizations(const Locale('vi'));
  }

  String get activeLanguageCode {
    final fromTree = Localizations.of<AppLocalizations>(this, AppLocalizations);
    if (fromTree != null) {
      return fromTree.localeName;
    }
    final activeLocale = Localizations.maybeLocaleOf(this);
    if (activeLocale?.languageCode == 'ko') {
      return 'ko';
    }
    return 'vi';
  }
}
