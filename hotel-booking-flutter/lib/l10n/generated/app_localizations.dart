import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
    Locale('vi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'The Palm Villa'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In vi, this message translates to:
  /// **'Biệt thự nghỉ dưỡng cao cấp Vũng Tàu'**
  String get appTagline;

  /// No description provided for @searchPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu tìm kiếm...'**
  String get searchPlaceholder;

  /// No description provided for @navDiscover.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá'**
  String get navDiscover;

  /// No description provided for @navZalo.
  ///
  /// In vi, this message translates to:
  /// **'Zalo'**
  String get navZalo;

  /// No description provided for @navHotline.
  ///
  /// In vi, this message translates to:
  /// **'Hotline'**
  String get navHotline;

  /// No description provided for @navFavorites.
  ///
  /// In vi, this message translates to:
  /// **'Yêu thích'**
  String get navFavorites;

  /// No description provided for @navSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get navSettings;

  /// No description provided for @bedroomsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} phòng'**
  String bedroomsCount(int count);

  /// No description provided for @bedsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} giường'**
  String bedsCount(int count);

  /// No description provided for @guestsCapacity.
  ///
  /// In vi, this message translates to:
  /// **'{count} khách'**
  String guestsCapacity(int count);

  /// No description provided for @bathroomsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} WC'**
  String bathroomsCount(int count);

  /// No description provided for @beachDistance.
  ///
  /// In vi, this message translates to:
  /// **'{distance}m tới biển'**
  String beachDistance(int distance);

  /// No description provided for @priceFrom.
  ///
  /// In vi, this message translates to:
  /// **'Từ {price} / đêm'**
  String priceFrom(String price);

  /// No description provided for @saturdayPrice.
  ///
  /// In vi, this message translates to:
  /// **'Thứ 7: {price}'**
  String saturdayPrice(String price);

  /// No description provided for @contactForPrice.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ báo giá'**
  String get contactForPrice;

  /// No description provided for @badgeFeatured.
  ///
  /// In vi, this message translates to:
  /// **'Nổi bật'**
  String get badgeFeatured;

  /// No description provided for @badgeNew.
  ///
  /// In vi, this message translates to:
  /// **'Mới'**
  String get badgeNew;

  /// No description provided for @badgeNearBeach.
  ///
  /// In vi, this message translates to:
  /// **'Gần biển'**
  String get badgeNearBeach;

  /// No description provided for @badgeSaltwater.
  ///
  /// In vi, this message translates to:
  /// **'Hồ bơi nước mặn'**
  String get badgeSaltwater;

  /// No description provided for @badgeGroup.
  ///
  /// In vi, this message translates to:
  /// **'Đoàn đông'**
  String get badgeGroup;

  /// No description provided for @ctaContactZalo.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin Zalo'**
  String get ctaContactZalo;

  /// No description provided for @ctaCallHotline.
  ///
  /// In vi, this message translates to:
  /// **'Gọi Hotline'**
  String get ctaCallHotline;

  /// No description provided for @ctaBookNow.
  ///
  /// In vi, this message translates to:
  /// **'Tư vấn đặt phòng'**
  String get ctaBookNow;

  /// No description provided for @ctaViewDetail.
  ///
  /// In vi, this message translates to:
  /// **'Xem chi tiết'**
  String get ctaViewDetail;

  /// No description provided for @ctaCopyLink.
  ///
  /// In vi, this message translates to:
  /// **'Sao chép liên kết'**
  String get ctaCopyLink;

  /// No description provided for @ctaCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép liên kết vào bộ nhớ tạm'**
  String get ctaCopied;

  /// No description provided for @ctaRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get ctaRetry;

  /// No description provided for @ctaResetFilter.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại bộ lọc'**
  String get ctaResetFilter;

  /// No description provided for @loadingText.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải dữ liệu...'**
  String get loadingText;

  /// No description provided for @emptyList.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy villa nào phù hợp'**
  String get emptyList;

  /// No description provided for @emptyListDesc.
  ///
  /// In vi, this message translates to:
  /// **'Hãy thử thay đổi tiêu chí tìm kiếm hoặc khoảng thời gian lưu trú.'**
  String get emptyListDesc;

  /// No description provided for @errorOccurred.
  ///
  /// In vi, this message translates to:
  /// **'Đã có lỗi xảy ra'**
  String get errorOccurred;

  /// No description provided for @errorTryAgain.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng kiểm tra kết nối mạng và thử lại.'**
  String get errorTryAgain;

  /// No description provided for @dateBooked.
  ///
  /// In vi, this message translates to:
  /// **'Ngày này đã kín'**
  String get dateBooked;

  /// No description provided for @checkInDate.
  ///
  /// In vi, this message translates to:
  /// **'Nhận phòng'**
  String get checkInDate;

  /// No description provided for @checkOutDate.
  ///
  /// In vi, this message translates to:
  /// **'Trả phòng'**
  String get checkOutDate;

  /// No description provided for @guestCount.
  ///
  /// In vi, this message translates to:
  /// **'Số khách'**
  String get guestCount;

  /// No description provided for @priceBreakdown.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết giá theo đêm'**
  String get priceBreakdown;

  /// No description provided for @faqTitle.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi thường gặp'**
  String get faqTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get settingsLanguage;

  /// No description provided for @settingsEnvironment.
  ///
  /// In vi, this message translates to:
  /// **'Môi trường'**
  String get settingsEnvironment;

  /// No description provided for @settingsVersion.
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản'**
  String get settingsVersion;

  /// No description provided for @favoritesEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có villa nào được lưu'**
  String get favoritesEmpty;

  /// No description provided for @favoritesEmptyDesc.
  ///
  /// In vi, this message translates to:
  /// **'Bấm vào biểu tượng trái tim ở góc thẻ villa để lưu vào danh sách yêu thích.'**
  String get favoritesEmptyDesc;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
