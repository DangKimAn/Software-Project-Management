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
    Locale('vi'),
    Locale('en'),
    Locale('ko')
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

  /// No description provided for @greetingMorning.
  ///
  /// In vi, this message translates to:
  /// **'Chào buổi sáng!'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In vi, this message translates to:
  /// **'Chào buổi chiều!'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In vi, this message translates to:
  /// **'Chào buổi tối!'**
  String get greetingEvening;

  /// No description provided for @homeWelcomeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Trân trọng được chào đón bạn tại thành phố biển Vũng Tàu'**
  String get homeWelcomeSubtitle;

  /// No description provided for @homeRecentlyViewedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã xem gần đây'**
  String get homeRecentlyViewedTitle;

  /// No description provided for @homePopularDestinationsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đến phổ biến tại Vũng Tàu'**
  String get homePopularDestinationsTitle;

  /// No description provided for @homeApprovedListingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách chỗ nghỉ đã duyệt'**
  String get homeApprovedListingsTitle;

  /// No description provided for @homeSeeMoreVillas.
  ///
  /// In vi, this message translates to:
  /// **'Xem thêm villa'**
  String get homeSeeMoreVillas;

  /// No description provided for @homeSeeNext.
  ///
  /// In vi, this message translates to:
  /// **'Xem tiếp'**
  String get homeSeeNext;

  /// No description provided for @homeShowLess.
  ///
  /// In vi, this message translates to:
  /// **'Thu gọn'**
  String get homeShowLess;

  /// No description provided for @homeBlogBadge.
  ///
  /// In vi, this message translates to:
  /// **'BÀI VIẾT MỚI'**
  String get homeBlogBadge;

  /// No description provided for @homeBlogTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kinh nghiệm lưu trú nổi bật'**
  String get homeBlogTitle;

  /// No description provided for @homeBlogSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung tập trung vào nhu cầu thực tế khi đặt villa tại Vũng Tàu, từ nhóm gia đình đến nhóm bạn đông người.'**
  String get homeBlogSubtitle;

  /// No description provided for @homeBlogSeeAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả bài viết'**
  String get homeBlogSeeAll;

  /// No description provided for @searchPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu tìm kiếm...'**
  String get searchPlaceholder;

  /// No description provided for @searchDestinationLabel.
  ///
  /// In vi, this message translates to:
  /// **'Địa điểm'**
  String get searchDestinationLabel;

  /// No description provided for @searchDestinationHint.
  ///
  /// In vi, this message translates to:
  /// **'Bạn muốn nghỉ dưỡng ở đâu tại Vũng Tàu?'**
  String get searchDestinationHint;

  /// No description provided for @searchModeDates.
  ///
  /// In vi, this message translates to:
  /// **'Theo ngày'**
  String get searchModeDates;

  /// No description provided for @searchModeMonths.
  ///
  /// In vi, this message translates to:
  /// **'Theo tháng'**
  String get searchModeMonths;

  /// No description provided for @searchModeFlexible.
  ///
  /// In vi, this message translates to:
  /// **'Linh hoạt'**
  String get searchModeFlexible;

  /// No description provided for @searchFlexibleWeekend.
  ///
  /// In vi, this message translates to:
  /// **'Cuối tuần'**
  String get searchFlexibleWeekend;

  /// No description provided for @searchFlexibleWeek.
  ///
  /// In vi, this message translates to:
  /// **'1 tuần'**
  String get searchFlexibleWeek;

  /// No description provided for @searchFlexibleMonth.
  ///
  /// In vi, this message translates to:
  /// **'1 tháng'**
  String get searchFlexibleMonth;

  /// No description provided for @searchExactDates.
  ///
  /// In vi, this message translates to:
  /// **'Chính xác ngày'**
  String get searchExactDates;

  /// No description provided for @searchPlusMinusDays.
  ///
  /// In vi, this message translates to:
  /// **'± {days} ngày'**
  String searchPlusMinusDays(int days);

  /// No description provided for @searchAdults.
  ///
  /// In vi, this message translates to:
  /// **'Người lớn'**
  String get searchAdults;

  /// No description provided for @searchAdultsDesc.
  ///
  /// In vi, this message translates to:
  /// **'Từ 13 tuổi trở lên'**
  String get searchAdultsDesc;

  /// No description provided for @searchChildren.
  ///
  /// In vi, this message translates to:
  /// **'Trẻ em'**
  String get searchChildren;

  /// No description provided for @searchChildrenDesc.
  ///
  /// In vi, this message translates to:
  /// **'Độ tuổi 2 – 12'**
  String get searchChildrenDesc;

  /// No description provided for @searchInfants.
  ///
  /// In vi, this message translates to:
  /// **'Em bé'**
  String get searchInfants;

  /// No description provided for @searchInfantsDesc.
  ///
  /// In vi, this message translates to:
  /// **'Dưới 2 tuổi'**
  String get searchInfantsDesc;

  /// No description provided for @searchPets.
  ///
  /// In vi, this message translates to:
  /// **'Thú cưng'**
  String get searchPets;

  /// No description provided for @searchPetsDesc.
  ///
  /// In vi, this message translates to:
  /// **'Mang theo thú cưng'**
  String get searchPetsDesc;

  /// No description provided for @searchFilterTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bộ lọc nâng cao'**
  String get searchFilterTitle;

  /// No description provided for @searchSortNewest.
  ///
  /// In vi, this message translates to:
  /// **'Mới nhất'**
  String get searchSortNewest;

  /// No description provided for @searchSortPriceAsc.
  ///
  /// In vi, this message translates to:
  /// **'Giá thấp đến cao'**
  String get searchSortPriceAsc;

  /// No description provided for @searchSortPriceDesc.
  ///
  /// In vi, this message translates to:
  /// **'Giá cao đến thấp'**
  String get searchSortPriceDesc;

  /// No description provided for @searchSortRatingDesc.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá cao nhất'**
  String get searchSortRatingDesc;

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

  /// No description provided for @navTrips.
  ///
  /// In vi, this message translates to:
  /// **'Chuyến đi'**
  String get navTrips;

  /// No description provided for @navAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get navAccount;

  /// No description provided for @navSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get navSettings;

  /// No description provided for @navStays.
  ///
  /// In vi, this message translates to:
  /// **'Nơi lưu trú'**
  String get navStays;

  /// No description provided for @navBlog.
  ///
  /// In vi, this message translates to:
  /// **'Cẩm nang'**
  String get navBlog;

  /// No description provided for @navContact.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ'**
  String get navContact;

  /// No description provided for @navMessages.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get navMessages;

  /// No description provided for @navNotifications.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo'**
  String get navNotifications;

  /// No description provided for @navBookingQueue.
  ///
  /// In vi, this message translates to:
  /// **'Giỏ chờ đặt'**
  String get navBookingQueue;

  /// No description provided for @navBecomeHost.
  ///
  /// In vi, this message translates to:
  /// **'Trở thành Host'**
  String get navBecomeHost;

  /// No description provided for @navHostPortal.
  ///
  /// In vi, this message translates to:
  /// **'Kênh Chủ nhà'**
  String get navHostPortal;

  /// No description provided for @navAdminPortal.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị hệ thống'**
  String get navAdminPortal;

  /// No description provided for @bedroomsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 phòng} other{{count} phòng}}'**
  String bedroomsCount(int count);

  /// No description provided for @bedsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 giường} other{{count} giường}}'**
  String bedsCount(int count);

  /// No description provided for @guestsCapacity.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 khách} other{{count} khách}}'**
  String guestsCapacity(int count);

  /// No description provided for @guestsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 khách} other{{count} khách}}'**
  String guestsCount(int count);

  /// No description provided for @adultsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 người lớn} other{{count} người lớn}}'**
  String adultsCount(int count);

  /// No description provided for @childrenCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 trẻ em} other{{count} trẻ em}}'**
  String childrenCount(int count);

  /// No description provided for @infantsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 em bé} other{{count} em bé}}'**
  String infantsCount(int count);

  /// No description provided for @petsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 thú cưng} other{{count} thú cưng}}'**
  String petsCount(int count);

  /// No description provided for @bathroomsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 WC} other{{count} WC}}'**
  String bathroomsCount(int count);

  /// No description provided for @nightsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 đêm} other{{count} đêm}}'**
  String nightsCount(int count);

  /// No description provided for @reviewsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =0{Chưa có đánh giá} =1{1 đánh giá} other{{count} đánh giá}}'**
  String reviewsCount(int count);

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

  /// No description provided for @pricePerNightUnit.
  ///
  /// In vi, this message translates to:
  /// **'/ đêm'**
  String get pricePerNightUnit;

  /// No description provided for @saturdayPrice.
  ///
  /// In vi, this message translates to:
  /// **'Thứ 7: {price}'**
  String saturdayPrice(String price);

  /// No description provided for @totalNightsWithFee.
  ///
  /// In vi, this message translates to:
  /// **'{nights, plural, =1{Tổng 1 đêm • Đã gồm phí} other{Tổng {nights} đêm • Đã gồm phí}}'**
  String totalNightsWithFee(int nights);

  /// No description provided for @contactForPrice.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ báo giá'**
  String get contactForPrice;

  /// No description provided for @statusAvailable.
  ///
  /// In vi, this message translates to:
  /// **'Còn trống'**
  String get statusAvailable;

  /// No description provided for @statusBooked.
  ///
  /// In vi, this message translates to:
  /// **'Đã kín phòng'**
  String get statusBooked;

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

  /// No description provided for @ctaBookInstant.
  ///
  /// In vi, this message translates to:
  /// **'Đặt phòng ngay'**
  String get ctaBookInstant;

  /// No description provided for @ctaRequestBooking.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu đặt'**
  String get ctaRequestBooking;

  /// No description provided for @ctaAddToQueue.
  ///
  /// In vi, this message translates to:
  /// **'Thêm vào giỏ chờ đặt'**
  String get ctaAddToQueue;

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

  /// No description provided for @ctaZaloCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép nội dung tư vấn và mở Zalo'**
  String get ctaZaloCopied;

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

  /// No description provided for @ctaBack.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get ctaBack;

  /// No description provided for @ctaBackHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get ctaBackHome;

  /// No description provided for @ctaClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get ctaClose;

  /// No description provided for @ctaCancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get ctaCancel;

  /// No description provided for @ctaConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get ctaConfirm;

  /// No description provided for @ctaSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get ctaSave;

  /// No description provided for @ctaPrevPage.
  ///
  /// In vi, this message translates to:
  /// **'Trang trước'**
  String get ctaPrevPage;

  /// No description provided for @ctaNextPage.
  ///
  /// In vi, this message translates to:
  /// **'Trang sau'**
  String get ctaNextPage;

  /// No description provided for @paginationPageOf.
  ///
  /// In vi, this message translates to:
  /// **'Trang {page} / {totalPages}'**
  String paginationPageOf(int page, int totalPages);

  /// No description provided for @loadingText.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải dữ liệu...'**
  String get loadingText;

  /// No description provided for @loadingVillas.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải chỗ nghỉ...'**
  String get loadingVillas;

  /// No description provided for @loadingVillaDetail.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải thông tin chi tiết biệt thự...'**
  String get loadingVillaDetail;

  /// No description provided for @loadingFavorites.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải danh sách yêu thích...'**
  String get loadingFavorites;

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
  /// **'Không thể hoàn tất yêu cầu lúc này. Vui lòng thử lại.'**
  String get errorTryAgain;

  /// No description provided for @errorOfflineTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không có kết nối mạng'**
  String get errorOfflineTitle;

  /// No description provided for @errorOfflineMessage.
  ///
  /// In vi, this message translates to:
  /// **'Không có kết nối mạng hoặc mạng không ổn định. Vui lòng kiểm tra kết nối và thử lại.'**
  String get errorOfflineMessage;

  /// No description provided for @errorServerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi máy chủ'**
  String get errorServerTitle;

  /// No description provided for @errorServerMessage.
  ///
  /// In vi, this message translates to:
  /// **'Máy chủ đang bận hoặc gặp sự cố tạm thời. Vui lòng thử lại sau.'**
  String get errorServerMessage;

  /// No description provided for @errorUnauthorizedMessage.
  ///
  /// In vi, this message translates to:
  /// **'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.'**
  String get errorUnauthorizedMessage;

  /// No description provided for @errorForbiddenMessage.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không có quyền truy cập chức năng này.'**
  String get errorForbiddenMessage;

  /// No description provided for @errorNotFoundTitle.
  ///
  /// In vi, this message translates to:
  /// **'404 — Không tìm thấy trang'**
  String get errorNotFoundTitle;

  /// No description provided for @errorNotFoundMessage.
  ///
  /// In vi, this message translates to:
  /// **'Đường dẫn bạn truy cập không tồn tại hoặc đã được di chuyển.'**
  String get errorNotFoundMessage;

  /// No description provided for @errorVillaNotFoundTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy biệt thự'**
  String get errorVillaNotFoundTitle;

  /// No description provided for @errorVillaNotFoundMessage.
  ///
  /// In vi, this message translates to:
  /// **'Biệt thự bạn tìm kiếm không tồn tại hoặc đã ngừng phục vụ.'**
  String get errorVillaNotFoundMessage;

  /// No description provided for @errorRateLimitMessage.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã thao tác quá nhanh. Vui lòng thử lại sau ít phút.'**
  String get errorRateLimitMessage;

  /// No description provided for @errorValidationMessage.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin gửi lên không hợp lệ. Vui lòng kiểm tra lại.'**
  String get errorValidationMessage;

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

  /// No description provided for @dailyPriceBreakdownTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bảng giá theo từng đêm'**
  String get dailyPriceBreakdownTitle;

  /// No description provided for @specCapacityLabel.
  ///
  /// In vi, this message translates to:
  /// **'Sức chứa'**
  String get specCapacityLabel;

  /// No description provided for @specBedroomsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ngủ'**
  String get specBedroomsLabel;

  /// No description provided for @specBedsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giường'**
  String get specBedsLabel;

  /// No description provided for @specBathroomsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phòng tắm'**
  String get specBathroomsLabel;

  /// No description provided for @specHighlightsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tiện ích nổi bật & Vị trí'**
  String get specHighlightsTitle;

  /// No description provided for @specExpandAction.
  ///
  /// In vi, this message translates to:
  /// **'Xem thêm thông số chi tiết'**
  String get specExpandAction;

  /// No description provided for @specCollapseAction.
  ///
  /// In vi, this message translates to:
  /// **'Thu gọn thông số'**
  String get specCollapseAction;

  /// No description provided for @specPrivatePool.
  ///
  /// In vi, this message translates to:
  /// **'Hồ bơi riêng'**
  String get specPrivatePool;

  /// No description provided for @specNoPool.
  ///
  /// In vi, this message translates to:
  /// **'Không có hồ bơi'**
  String get specNoPool;

  /// No description provided for @specBbqKitchen.
  ///
  /// In vi, this message translates to:
  /// **'Bếp & Lò BBQ đầy đủ'**
  String get specBbqKitchen;

  /// No description provided for @specBasicKitchen.
  ///
  /// In vi, this message translates to:
  /// **'Bếp cơ bản'**
  String get specBasicKitchen;

  /// No description provided for @specParking.
  ///
  /// In vi, this message translates to:
  /// **'Chỗ đậu xe ô tô'**
  String get specParking;

  /// No description provided for @specSelfParking.
  ///
  /// In vi, this message translates to:
  /// **'Đậu xe tự túc'**
  String get specSelfParking;

  /// No description provided for @specNearCenter.
  ///
  /// In vi, this message translates to:
  /// **'Gần trung tâm'**
  String get specNearCenter;

  /// No description provided for @hostDefaultName.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà VungTauStay'**
  String get hostDefaultName;

  /// No description provided for @hostDefaultBio.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà tại Vũng Tàu, hỗ trợ thông tin lưu trú và nhận phòng.'**
  String get hostDefaultBio;

  /// No description provided for @bookingInstantConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Đặt phòng xác nhận ngay'**
  String get bookingInstantConfirm;

  /// No description provided for @bookingSupport247.
  ///
  /// In vi, this message translates to:
  /// **'Tư vấn & Đặt phòng 24/7'**
  String get bookingSupport247;

  /// No description provided for @faqTitle.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi thường gặp'**
  String get faqTitle;

  /// No description provided for @rulesAndFaqTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quy định & Câu hỏi thường gặp'**
  String get rulesAndFaqTitle;

  /// No description provided for @faqCheckInTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian nhận và trả villa như thế nào?'**
  String get faqCheckInTitle;

  /// No description provided for @faqCheckInBody.
  ///
  /// In vi, this message translates to:
  /// **'Giờ nhận villa tiêu chuẩn từ 14:00 chiều và giờ trả trước 12:00 trưa hôm sau. Quý khách có nhu cầu nhận sớm hoặc trả muộn vui lòng thông báo trước để được hỗ trợ tùy theo tình trạng phòng trống.'**
  String get faqCheckInBody;

  /// No description provided for @faqNoiseTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quy định về tiếng ồn và sử dụng karaoke?'**
  String get faqNoiseTitle;

  /// No description provided for @faqNoiseBody.
  ///
  /// In vi, this message translates to:
  /// **'Theo quy định trật tự đô thị tại Vũng Tàu, dàn karaoke và âm thanh ngoài trời hoạt động đến 22:00 tối. Sau 22:00, quý khách vui lòng sinh hoạt văn minh trong không gian phòng kín để không ảnh hưởng các biệt thự lân cận.'**
  String get faqNoiseBody;

  /// No description provided for @faqKitchenTitle.
  ///
  /// In vi, this message translates to:
  /// **'Biệt thự có trang bị đầy đủ gia vị và đồ dùng nấu ăn không?'**
  String get faqKitchenTitle;

  /// No description provided for @faqKitchenBody.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực bếp và lò nướng BBQ được trang bị sẵn chén bát, đũa muỗng, nồi niêu xoong chảo, bếp từ/gas và vỉ nướng. Quý khách chỉ cần chuẩn bị thực phẩm tươi sống và than nướng theo sở thích.'**
  String get faqKitchenBody;

  /// No description provided for @faqDepositTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách đặt cọc và hủy phòng?'**
  String get faqDepositTitle;

  /// No description provided for @faqDepositBody.
  ///
  /// In vi, this message translates to:
  /// **'Để giữ lịch villa, quý khách vui lòng đặt cọc 50% giá trị hợp đồng. Số tiền còn lại thanh toán khi nhận bàn giao villa. Chính sách dời ngày linh hoạt khi thông báo trước ít nhất 7 ngày.'**
  String get faqDepositBody;

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

  /// No description provided for @bookingStatusPendingPayment.
  ///
  /// In vi, this message translates to:
  /// **'Chờ thanh toán'**
  String get bookingStatusPendingPayment;

  /// No description provided for @bookingStatusPaymentExpired.
  ///
  /// In vi, this message translates to:
  /// **'Quá hạn thanh toán'**
  String get bookingStatusPaymentExpired;

  /// No description provided for @bookingStatusPaid.
  ///
  /// In vi, this message translates to:
  /// **'Đã thanh toán'**
  String get bookingStatusPaid;

  /// No description provided for @bookingStatusConfirmed.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác nhận'**
  String get bookingStatusConfirmed;

  /// No description provided for @bookingStatusCheckedIn.
  ///
  /// In vi, this message translates to:
  /// **'Đang lưu trú'**
  String get bookingStatusCheckedIn;

  /// No description provided for @bookingStatusCheckedOut.
  ///
  /// In vi, this message translates to:
  /// **'Đã trả phòng'**
  String get bookingStatusCheckedOut;

  /// No description provided for @bookingStatusCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã hoàn thành'**
  String get bookingStatusCompleted;

  /// No description provided for @bookingStatusCancelledByGuest.
  ///
  /// In vi, this message translates to:
  /// **'Khách đã hủy'**
  String get bookingStatusCancelledByGuest;

  /// No description provided for @bookingStatusCancelledByHost.
  ///
  /// In vi, this message translates to:
  /// **'Host đã hủy'**
  String get bookingStatusCancelledByHost;

  /// No description provided for @bookingStatusCancelledByAdmin.
  ///
  /// In vi, this message translates to:
  /// **'Admin đã hủy'**
  String get bookingStatusCancelledByAdmin;

  /// No description provided for @bookingStatusRejected.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get bookingStatusRejected;

  /// No description provided for @bookingStatusRefundPending.
  ///
  /// In vi, this message translates to:
  /// **'Đang hoàn tiền'**
  String get bookingStatusRefundPending;

  /// No description provided for @bookingStatusRefunded.
  ///
  /// In vi, this message translates to:
  /// **'Đã hoàn tiền'**
  String get bookingStatusRefunded;

  /// No description provided for @paymentUnverifiedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa xác nhận được giao dịch'**
  String get paymentUnverifiedTitle;

  /// No description provided for @paymentUnverifiedDesc.
  ///
  /// In vi, this message translates to:
  /// **'Tạm thời chưa thể xác minh trạng thái giao dịch với máy chủ. Vui lòng kiểm tra kết nối mạng và thử xác minh lại.'**
  String get paymentUnverifiedDesc;

  /// No description provided for @paymentRecheckStatus.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra lại trạng thái'**
  String get paymentRecheckStatus;

  /// No description provided for @authLoginTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get authLoginTitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký tài khoản'**
  String get authRegisterTitle;

  /// No description provided for @authForgotPasswordTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quên mật khẩu'**
  String get authForgotPasswordTitle;

  /// No description provided for @authGoogleSignIn.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục với Google'**
  String get authGoogleSignIn;

  /// No description provided for @authLogout.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get authLogout;

  /// No description provided for @profileVerified.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh'**
  String get profileVerified;

  /// No description provided for @profileUnverified.
  ///
  /// In vi, this message translates to:
  /// **'Chưa xác minh'**
  String get profileUnverified;

  /// No description provided for @hostOnboardingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trở thành Chủ nhà tại The Palm'**
  String get hostOnboardingTitle;

  /// No description provided for @hostKycTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký & Xác minh Hồ sơ Chủ nhà'**
  String get hostKycTitle;

  /// No description provided for @hostKycStatusTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái xét duyệt Hồ sơ Chủ nhà'**
  String get hostKycStatusTitle;

  /// No description provided for @hostTabOverview.
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan'**
  String get hostTabOverview;

  /// No description provided for @hostTabProperties.
  ///
  /// In vi, this message translates to:
  /// **'Chỗ nghỉ'**
  String get hostTabProperties;

  /// No description provided for @hostTabNewProperty.
  ///
  /// In vi, this message translates to:
  /// **'Thêm chỗ nghỉ'**
  String get hostTabNewProperty;

  /// No description provided for @hostTabBookings.
  ///
  /// In vi, this message translates to:
  /// **'Đặt phòng'**
  String get hostTabBookings;

  /// No description provided for @hostTabCalendar.
  ///
  /// In vi, this message translates to:
  /// **'Lịch lưu trú'**
  String get hostTabCalendar;

  /// No description provided for @hostTabGuests.
  ///
  /// In vi, this message translates to:
  /// **'Khách lưu trú'**
  String get hostTabGuests;

  /// No description provided for @hostTabMessages.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get hostTabMessages;

  /// No description provided for @hostTabPayouts.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán'**
  String get hostTabPayouts;

  /// No description provided for @hostTabReviews.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get hostTabReviews;

  /// No description provided for @hostTabReports.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo'**
  String get hostTabReports;

  /// No description provided for @hostTabSupport.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ'**
  String get hostTabSupport;

  /// No description provided for @hostTabSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get hostTabSettings;

  /// No description provided for @hostListingDraft.
  ///
  /// In vi, this message translates to:
  /// **'Bản nháp'**
  String get hostListingDraft;

  /// No description provided for @hostListingPendingApproval.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get hostListingPendingApproval;

  /// No description provided for @hostListingPublished.
  ///
  /// In vi, this message translates to:
  /// **'Đang hiển thị'**
  String get hostListingPublished;

  /// No description provided for @hostListingHidden.
  ///
  /// In vi, this message translates to:
  /// **'Đang ẩn'**
  String get hostListingHidden;

  /// No description provided for @hostListingRejected.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối duyệt'**
  String get hostListingRejected;

  /// No description provided for @adminTabOverview.
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan'**
  String get adminTabOverview;

  /// No description provided for @adminTabUsers.
  ///
  /// In vi, this message translates to:
  /// **'Người dùng'**
  String get adminTabUsers;

  /// No description provided for @adminTabModeration.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm duyệt bài đăng'**
  String get adminTabModeration;

  /// No description provided for @adminTabHostApplications.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt hồ sơ Host'**
  String get adminTabHostApplications;

  /// No description provided for @adminTabRoles.
  ///
  /// In vi, this message translates to:
  /// **'Phân quyền hệ thống'**
  String get adminTabRoles;

  /// No description provided for @adminUserStatusActive.
  ///
  /// In vi, this message translates to:
  /// **'Hoạt động'**
  String get adminUserStatusActive;

  /// No description provided for @adminUserStatusSuspended.
  ///
  /// In vi, this message translates to:
  /// **'Đang khóa'**
  String get adminUserStatusSuspended;

  /// No description provided for @adminUserStatusInactive.
  ///
  /// In vi, this message translates to:
  /// **'Ngừng hoạt động'**
  String get adminUserStatusInactive;

  /// No description provided for @settingsCurrency.
  ///
  /// In vi, this message translates to:
  /// **'Tiền tệ hiển thị'**
  String get settingsCurrency;

  /// No description provided for @currencyFollowLanguage.
  ///
  /// In vi, this message translates to:
  /// **'Theo ngôn ngữ'**
  String get currencyFollowLanguage;

  /// No description provided for @currencyFollowLanguageDesc.
  ///
  /// In vi, this message translates to:
  /// **'Tự động chuyển đổi theo ngôn ngữ giao diện'**
  String get currencyFollowLanguageDesc;

  /// No description provided for @currencyNameVnd.
  ///
  /// In vi, this message translates to:
  /// **'Đồng Việt Nam (VND - ₫)'**
  String get currencyNameVnd;

  /// No description provided for @currencyNameUsd.
  ///
  /// In vi, this message translates to:
  /// **'Đô la Mỹ (USD - \$)'**
  String get currencyNameUsd;

  /// No description provided for @currencyNameKrw.
  ///
  /// In vi, this message translates to:
  /// **'Won Hàn Quốc (KRW - ₩)'**
  String get currencyNameKrw;

  /// No description provided for @fxEstimatedPrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá tham khảo: ≈ {amount}'**
  String fxEstimatedPrice(String amount);

  /// No description provided for @fxTotalPayableVnd.
  ///
  /// In vi, this message translates to:
  /// **'Tổng thanh toán thực tế: {amountVnd}'**
  String fxTotalPayableVnd(String amountVnd);

  /// No description provided for @fxChargedInVndNotice.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán thực tế bằng VND.'**
  String get fxChargedInVndNotice;

  /// No description provided for @fxReferenceRateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tỷ giá tham khảo ({source})'**
  String fxReferenceRateLabel(String source);

  /// No description provided for @fxRateUpdatedAt.
  ///
  /// In vi, this message translates to:
  /// **'Tỷ giá cập nhật: {time}'**
  String fxRateUpdatedAt(String time);

  /// No description provided for @fxRateUnavailableFallback.
  ///
  /// In vi, this message translates to:
  /// **'Chưa tải được tỷ giá ngoại tệ. Đang hiển thị giá chính thức bằng VND.'**
  String get fxRateUnavailableFallback;

  /// No description provided for @fxRateStaleNotice.
  ///
  /// In vi, this message translates to:
  /// **'Đang sử dụng tỷ giá cập nhật gần nhất ({time}).'**
  String fxRateStaleNotice(String time);

  /// No description provided for @fxBankConversionFeeNotice.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng phát hành thẻ có thể áp dụng tỷ giá và phí chuyển đổi riêng.'**
  String get fxBankConversionFeeNotice;

  /// No description provided for @fxPaymentMethodUnsupported.
  ///
  /// In vi, this message translates to:
  /// **'Phương thức thanh toán này hiện chưa được hỗ trợ.'**
  String get fxPaymentMethodUnsupported;

  /// No description provided for @fxRefundInVndNotice.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tiền thực tế bằng VND. Số tiền ngoại tệ trên sao kê có thể khác do tỷ giá ngân hàng tại thời điểm hoàn.'**
  String get fxRefundInVndNotice;

  /// No description provided for @fxHistoricalReferenceNote.
  ///
  /// In vi, this message translates to:
  /// **'Giá quy đổi chỉ để tham khảo, không phải số tiền thực tế trên sao kê thanh toán.'**
  String get fxHistoricalReferenceNote;

  /// No description provided for @fxPayButtonVnd.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán {amountVnd} qua {method}'**
  String fxPayButtonVnd(String amountVnd, String method);

  /// No description provided for @fxPriceRangePerNight.
  ///
  /// In vi, this message translates to:
  /// **'Khoảng giá mỗi đêm'**
  String get fxPriceRangePerNight;

  /// No description provided for @vnpayGatewayTitle.
  ///
  /// In vi, this message translates to:
  /// **'VNPay (QR Pay / Thẻ ATM nội địa)'**
  String get vnpayGatewayTitle;

  /// No description provided for @vnpayGatewaySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận thanh toán VND qua cổng bảo mật VNPay'**
  String get vnpayGatewaySubtitle;

  /// No description provided for @momoGatewayTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ví điện tử MoMo'**
  String get momoGatewayTitle;

  /// No description provided for @momoGatewaySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán VND qua ứng dụng MoMo hoặc quét mã QR MoMo'**
  String get momoGatewaySubtitle;

  /// No description provided for @footerSupportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ'**
  String get footerSupportTitle;

  /// No description provided for @footerLinkBookingGuide.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn đặt phòng'**
  String get footerLinkBookingGuide;

  /// No description provided for @footerLinkCancellationPolicy.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách hủy phòng'**
  String get footerLinkCancellationPolicy;

  /// No description provided for @footerLinkComplaintsFeedback.
  ///
  /// In vi, this message translates to:
  /// **'Khiếu nại & Góp ý'**
  String get footerLinkComplaintsFeedback;

  /// No description provided for @footerLinkFaq.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi thường gặp (FAQ)'**
  String get footerLinkFaq;

  /// No description provided for @footerExploreTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá & Dịch vụ'**
  String get footerExploreTitle;

  /// No description provided for @footerLinkAboutUs.
  ///
  /// In vi, this message translates to:
  /// **'Về chúng tôi'**
  String get footerLinkAboutUs;

  /// No description provided for @footerLinkExploreVungTau.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá Vũng Tàu'**
  String get footerLinkExploreVungTau;

  /// No description provided for @footerLinkTravelGuide.
  ///
  /// In vi, this message translates to:
  /// **'Cẩm nang du lịch'**
  String get footerLinkTravelGuide;

  /// No description provided for @footerLinkAddonServices.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ đi kèm'**
  String get footerLinkAddonServices;

  /// No description provided for @footerLinkMemberOffers.
  ///
  /// In vi, this message translates to:
  /// **'Ưu đãi thành viên'**
  String get footerLinkMemberOffers;

  /// No description provided for @footerContactTitle.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ'**
  String get footerContactTitle;

  /// No description provided for @footerHotlineLabel.
  ///
  /// In vi, this message translates to:
  /// **'Hotline: {phone}'**
  String footerHotlineLabel(String phone);

  /// No description provided for @footerOnlineConsultLink.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ tư vấn trực tuyến'**
  String get footerOnlineConsultLink;

  /// No description provided for @footerAddressLabel.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ: {address}'**
  String footerAddressLabel(String address);

  /// No description provided for @footerEmailLabel.
  ///
  /// In vi, this message translates to:
  /// **'Email: {email}'**
  String footerEmailLabel(String email);

  /// No description provided for @footerEmailSubject.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ đặt phòng The Palm Villa Vũng Tàu'**
  String get footerEmailSubject;

  /// No description provided for @footerSocialTitle.
  ///
  /// In vi, this message translates to:
  /// **'Social'**
  String get footerSocialTitle;

  /// No description provided for @footerCopyright.
  ///
  /// In vi, this message translates to:
  /// **'© 2026 The Palm Villa Vũng Tàu. Bảo lưu mọi quyền.'**
  String get footerCopyright;

  /// No description provided for @supportGuideStep1Title.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm theo phân khu & lịch trống thực tế'**
  String get supportGuideStep1Title;

  /// No description provided for @supportGuideStep1Desc.
  ///
  /// In vi, this message translates to:
  /// **'Chọn phân khu biển tại Vũng Tàu (Bãi Sau, Bãi Trước, Chí Linh, Long Cung), khoảng ngày lưu trú [Nhận phòng, Trả phòng) và tổng số khách đoàn để lọc đúng các căn biệt thự đang mở lịch.'**
  String get supportGuideStep1Desc;

  /// No description provided for @supportGuideStep2Title.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra bảng giá theo đêm & áp dụng mã ưu đãi'**
  String get supportGuideStep2Title;

  /// No description provided for @supportGuideStep2Desc.
  ///
  /// In vi, this message translates to:
  /// **'Xem chi tiết thông số biệt thự (phòng ngủ, giường, WC, khoảng cách biển), bảng giá từng đêm ngày thường / cuối tuần, phụ thu khách vượt tiêu chuẩn (nếu có) và nhập mã ưu đãi hợp lệ.'**
  String get supportGuideStep2Desc;

  /// No description provided for @supportGuideStep3Title.
  ///
  /// In vi, this message translates to:
  /// **'Khóa lịch giữ chỗ tạm thời 15 phút'**
  String get supportGuideStep3Title;

  /// No description provided for @supportGuideStep3Desc.
  ///
  /// In vi, this message translates to:
  /// **'Ngay khi tạo đơn đặt phòng, hệ thống tự động khóa khoảng ngày lưu trú trong 15 phút (trạng thái Chờ thanh toán) để bảo vệ bạn khỏi tình trạng trùng lịch với đoàn khách khác.'**
  String get supportGuideStep3Desc;

  /// No description provided for @supportGuideStep4Title.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán trực tuyến & nhận xác nhận lưu trú'**
  String get supportGuideStep4Title;

  /// No description provided for @supportGuideStep4Desc.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tất thanh toán qua cổng thanh toán được hỗ trợ (VNPay, MoMo hoặc VietQR) trong thời gian giữ chỗ. Theo dõi trạng thái đơn và nhắn tin trực tiếp với Chủ nhà ngay tại mục Chuyến đi.'**
  String get supportGuideStep4Desc;

  /// No description provided for @supportCancelFlexName.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách Linh hoạt (Flexible)'**
  String get supportCancelFlexName;

  /// No description provided for @supportCancelFlexBadge.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn 100% trước 24 giờ'**
  String get supportCancelFlexBadge;

  /// No description provided for @supportCancelFlexRule1.
  ///
  /// In vi, this message translates to:
  /// **'Hủy trước thời điểm nhận phòng từ đủ 24 giờ trở lên: hoàn 100% tổng số tiền đã thanh toán.'**
  String get supportCancelFlexRule1;

  /// No description provided for @supportCancelFlexRule2.
  ///
  /// In vi, this message translates to:
  /// **'Hủy trong vòng dưới 24 giờ trước giờ nhận phòng: không áp dụng hoàn tiền.'**
  String get supportCancelFlexRule2;

  /// No description provided for @supportCancelModName.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách Trung bình (Moderate)'**
  String get supportCancelModName;

  /// No description provided for @supportCancelModBadge.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn 100% trước 5 ngày'**
  String get supportCancelModBadge;

  /// No description provided for @supportCancelModRule1.
  ///
  /// In vi, this message translates to:
  /// **'Hủy trước thời điểm nhận phòng từ đủ 5 ngày (120 giờ) trở lên: hoàn 100% tổng số tiền đã thanh toán.'**
  String get supportCancelModRule1;

  /// No description provided for @supportCancelModRule2.
  ///
  /// In vi, this message translates to:
  /// **'Hủy trong khoảng từ đủ 24 giờ đến dưới 5 ngày (120 giờ): hoàn 50% tổng số tiền đã thanh toán.'**
  String get supportCancelModRule2;

  /// No description provided for @supportCancelModRule3.
  ///
  /// In vi, this message translates to:
  /// **'Hủy trong vòng dưới 24 giờ trước giờ nhận phòng: không áp dụng hoàn tiền.'**
  String get supportCancelModRule3;

  /// No description provided for @supportCancelStrictName.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách Nghiêm ngặt (Strict)'**
  String get supportCancelStrictName;

  /// No description provided for @supportCancelStrictBadge.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn 50% trước 7 ngày'**
  String get supportCancelStrictBadge;

  /// No description provided for @supportCancelStrictRule1.
  ///
  /// In vi, this message translates to:
  /// **'Hủy trước thời điểm nhận phòng từ đủ 7 ngày (168 giờ) trở lên: hoàn 50% tổng số tiền đã thanh toán.'**
  String get supportCancelStrictRule1;

  /// No description provided for @supportCancelStrictRule2.
  ///
  /// In vi, this message translates to:
  /// **'Hủy trong vòng dưới 7 ngày (168 giờ) trước giờ nhận phòng: không áp dụng hoàn tiền.'**
  String get supportCancelStrictRule2;

  /// No description provided for @supportComplaintStep1Title.
  ///
  /// In vi, this message translates to:
  /// **'Gửi phản ánh kèm mã đơn hoặc mã chỗ nghỉ'**
  String get supportComplaintStep1Title;

  /// No description provided for @supportComplaintStep1Desc.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập tài khoản và gửi báo cáo trực tuyến kèm mã đơn đặt phòng (Booking ID) hoặc mã biệt thự (Listing ID), nêu rõ vấn đề thực tế cần đối soát.'**
  String get supportComplaintStep1Desc;

  /// No description provided for @supportComplaintStep2Title.
  ///
  /// In vi, this message translates to:
  /// **'Đối soát lịch sử lưu trú & luồng thanh toán'**
  String get supportComplaintStep2Title;

  /// No description provided for @supportComplaintStep2Desc.
  ///
  /// In vi, this message translates to:
  /// **'Bộ phận Kiểm duyệt & An toàn (Trust & Safety) kiểm tra nhật ký trạng thái đơn, lịch sử trao đổi tin nhắn trên ứng dụng và chứng từ thanh toán độc lập.'**
  String get supportComplaintStep2Desc;

  /// No description provided for @supportComplaintStep3Title.
  ///
  /// In vi, this message translates to:
  /// **'Phản hồi kết quả & bảo vệ quyền lợi khách hàng'**
  String get supportComplaintStep3Title;

  /// No description provided for @supportComplaintStep3Desc.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả xử lý được cập nhật minh bạch vào trạng thái báo cáo (Đã giải quyết / Từ chối kèm lý do) và kích hoạt quy trình hoàn tiền nếu Chủ nhà vi phạm cam kết.'**
  String get supportComplaintStep3Desc;

  /// No description provided for @supportFaqCatAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get supportFaqCatAll;

  /// No description provided for @supportFaqCatBooking.
  ///
  /// In vi, this message translates to:
  /// **'Đặt phòng & Lịch trống'**
  String get supportFaqCatBooking;

  /// No description provided for @supportFaqCatPayment.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán & Hoàn tiền'**
  String get supportFaqCatPayment;

  /// No description provided for @supportFaqCatAmenities.
  ///
  /// In vi, this message translates to:
  /// **'Tiện ích & Nội quy'**
  String get supportFaqCatAmenities;

  /// No description provided for @supportFaqCatHost.
  ///
  /// In vi, this message translates to:
  /// **'Đối tác Chủ nhà'**
  String get supportFaqCatHost;

  /// No description provided for @supportFaq1Q.
  ///
  /// In vi, this message translates to:
  /// **'Số đêm lưu trú được hệ thống tính như thế nào?'**
  String get supportFaq1Q;

  /// No description provided for @supportFaq1A.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống áp dụng mô hình đêm lưu trú nửa mở [Nhận phòng, Trả phòng) theo múi giờ Việt Nam (Asia/Ho_Chi_Minh). Ví dụ chọn nhận phòng ngày 15 và trả phòng ngày 17 sẽ gồm 2 đêm ở (đêm 15 và đêm 16); ngày 17 là ngày trả phòng.'**
  String get supportFaq1A;

  /// No description provided for @supportFaq2Q.
  ///
  /// In vi, this message translates to:
  /// **'Tại sao đơn đặt phòng có thời gian giữ chỗ 15 phút?'**
  String get supportFaq2Q;

  /// No description provided for @supportFaq2A.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi căn biệt thự nguyên căn là tài sản đơn chiếc. Khi bạn tạo đơn, hệ thống khóa ngày lưu trú trong 15 phút để không ai khác đặt trùng trong lúc bạn thao tác thanh toán. Quá 15 phút chưa thanh toán, khóa ngày sẽ tự động giải phóng.'**
  String get supportFaq2A;

  /// No description provided for @supportFaq3Q.
  ///
  /// In vi, this message translates to:
  /// **'Giá cuối tuần và phụ thu đoàn đông được tính ra sao?'**
  String get supportFaq3Q;

  /// No description provided for @supportFaq3A.
  ///
  /// In vi, this message translates to:
  /// **'Bảng giá từng đêm (ngày thường, thứ Bảy/cuối tuần), phí dọn dẹp và phụ thu khách vượt mức tiêu chuẩn đều lấy trực tiếp từ cấu hình đã kiểm duyệt của từng căn biệt thự và hiển thị minh bạch trước khi bạn xác nhận đặt phòng.'**
  String get supportFaq3A;

  /// No description provided for @supportFaq4Q.
  ///
  /// In vi, this message translates to:
  /// **'Tôi có thể thanh toán bằng những phương thức nào?'**
  String get supportFaq4Q;

  /// No description provided for @supportFaq4A.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống hỗ trợ thanh toán trực tuyến qua cổng VNPay, ví MoMo và chuyển khoản mã VietQR. Mọi giao dịch đều được đối soát tự động và cập nhật tức thời vào mục Chuyến đi.'**
  String get supportFaq4A;

  /// No description provided for @supportFaq5Q.
  ///
  /// In vi, this message translates to:
  /// **'Khi hủy phòng hợp lệ hoặc Chủ nhà từ chối đơn, tôi nhận lại tiền bằng cách nào?'**
  String get supportFaq5Q;

  /// No description provided for @supportFaq5A.
  ///
  /// In vi, this message translates to:
  /// **'Nếu đơn đã thanh toán được hủy trong khung giờ hoàn tiền của căn biệt thự (hoặc bị Chủ nhà hủy/từ chối — hoàn 100%), hệ thống tự động khởi tạo yêu cầu hoàn tiền riêng biệt để bộ phận tài chính đối soát hoàn trả về tài khoản/kênh thanh toán của bạn.'**
  String get supportFaq5A;

  /// No description provided for @supportFaq6Q.
  ///
  /// In vi, this message translates to:
  /// **'Tôi có thể trao đổi trực tiếp với Chủ nhà trước khi đặt không?'**
  String get supportFaq6Q;

  /// No description provided for @supportFaq6A.
  ///
  /// In vi, this message translates to:
  /// **'Có. Tại trang chi tiết từng biệt thự, bạn có thể bấm Nhắn tin cho Host hoặc kết nối qua kênh tư vấn Zalo OA / Hotline tại trang Liên hệ để hỏi rõ về hồ bơi, bếp BBQ hoặc chỗ đậu xe đoàn.'**
  String get supportFaq6A;

  /// No description provided for @supportFaq7Q.
  ///
  /// In vi, this message translates to:
  /// **'Làm thế nào để đăng ký cho thuê biệt thự trên The Palm Villa?'**
  String get supportFaq7Q;

  /// No description provided for @supportFaq7A.
  ///
  /// In vi, this message translates to:
  /// **'Bạn truy cập mục Trở thành Host trên thanh điều hướng hoặc chân trang, hoàn tất hồ sơ xác thực danh tính (KYC CCCD) và thông tin chỗ nghỉ. Sau khi Quản trị viên phê duyệt, bạn có thể quản lý lịch 30 ngày và đồng bộ hai chiều với Google Sheets.'**
  String get supportFaq7A;

  /// No description provided for @supportZoneBaiSauName.
  ///
  /// In vi, this message translates to:
  /// **'Phân khu Bãi Sau (Thùy Vân – Thi Sách)'**
  String get supportZoneBaiSauName;

  /// No description provided for @supportZoneBaiSauHint.
  ///
  /// In vi, this message translates to:
  /// **'Bờ biển dài, sôi động, thuận tiện đi bộ ra bãi tắm'**
  String get supportZoneBaiSauHint;

  /// No description provided for @supportZoneBaiSauHighlight.
  ///
  /// In vi, this message translates to:
  /// **'Tập trung nhiều biệt thự hồ bơi riêng diện tích lớn cho nhóm bạn và gia đình, gần trục đường Thùy Vân, Thi Sách, Võ Thị Sáu.'**
  String get supportZoneBaiSauHighlight;

  /// No description provided for @supportZoneBaiTruocName.
  ///
  /// In vi, this message translates to:
  /// **'Phân khu Bãi Trước (Trần Phú – Quang Trung)'**
  String get supportZoneBaiTruocName;

  /// No description provided for @supportZoneBaiTruocHint.
  ///
  /// In vi, this message translates to:
  /// **'Ngắm hoàng hôn biển trực diện, gần trung tâm ẩm thực'**
  String get supportZoneBaiTruocHint;

  /// No description provided for @supportZoneBaiTruocHighlight.
  ///
  /// In vi, this message translates to:
  /// **'Không gian biệt thự nghỉ dưỡng hướng biển Trần Phú yên tĩnh, tầm nhìn hoàng hôn thoáng đãng và di chuyển thuận tiện tới công viên Bãi Trước.'**
  String get supportZoneBaiTruocHighlight;

  /// No description provided for @supportZoneChiLinhName.
  ///
  /// In vi, this message translates to:
  /// **'Phân khu Chí Linh'**
  String get supportZoneChiLinhName;

  /// No description provided for @supportZoneChiLinhHint.
  ///
  /// In vi, this message translates to:
  /// **'Khu nghỉ dưỡng biệt lập, an ninh, bãi tắm riêng tư'**
  String get supportZoneChiLinhHint;

  /// No description provided for @supportZoneChiLinhHighlight.
  ///
  /// In vi, this message translates to:
  /// **'Phù hợp đoàn gia đình nhiều thế hệ hoặc nhóm công ty yêu thích không gian xanh mát, yên tĩnh và bãi biển sạch thoáng.'**
  String get supportZoneChiLinhHighlight;

  /// No description provided for @supportZoneLongCungName.
  ///
  /// In vi, this message translates to:
  /// **'Phân khu Long Cung – Thủy Tiên'**
  String get supportZoneLongCungName;

  /// No description provided for @supportZoneLongCungHint.
  ///
  /// In vi, this message translates to:
  /// **'Quần thể biệt thự nghỉ dưỡng sát biển cho đoàn đông'**
  String get supportZoneLongCungHint;

  /// No description provided for @supportZoneLongCungHighlight.
  ///
  /// In vi, this message translates to:
  /// **'Nổi bật với các căn biệt thự sân vườn rộng, hồ bơi riêng và khu tổ chức tiệc nướng BBQ ngoài trời gần bãi tắm Long Cung.'**
  String get supportZoneLongCungHighlight;

  /// No description provided for @supportAddonPoolTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ bơi riêng tại biệt thự'**
  String get supportAddonPoolTitle;

  /// No description provided for @supportAddonPoolDesc.
  ///
  /// In vi, this message translates to:
  /// **'Không gian hồ bơi riêng tư ngay trong khuôn viên căn biệt thự, phù hợp thư giãn cùng gia đình và nhóm bạn.'**
  String get supportAddonPoolDesc;

  /// No description provided for @supportAddonPoolNote.
  ///
  /// In vi, this message translates to:
  /// **'Có sẵn theo thông số công bố của từng căn biệt thự.'**
  String get supportAddonPoolNote;

  /// No description provided for @supportAddonBbqTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực bếp nướng BBQ sân vườn'**
  String get supportAddonBbqTitle;

  /// No description provided for @supportAddonBbqDesc.
  ///
  /// In vi, this message translates to:
  /// **'Trang bị khu vực nướng ngoài trời, bàn ghế sân vườn và dụng cụ bếp cơ bản phục vụ tiệc tối ấm cúng.'**
  String get supportAddonBbqDesc;

  /// No description provided for @supportAddonBbqNote.
  ///
  /// In vi, this message translates to:
  /// **'Trao đổi trước với Chủ nhà về than nướng hoặc hỗ trợ dọn rửa.'**
  String get supportAddonBbqNote;

  /// No description provided for @supportAddonKitchenTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bếp nấu tiêu chuẩn gia đình'**
  String get supportAddonKitchenTitle;

  /// No description provided for @supportAddonKitchenDesc.
  ///
  /// In vi, this message translates to:
  /// **'Đầy đủ tủ lạnh, bếp nấu, nồi chảo và bát đĩa để đoàn tự chuẩn bị hải sản tươi sống mua tại chợ địa phương.'**
  String get supportAddonKitchenDesc;

  /// No description provided for @supportAddonKitchenNote.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng giữ vệ sinh khu bếp theo nội quy từng chỗ nghỉ.'**
  String get supportAddonKitchenNote;

  /// No description provided for @supportAddonKaraokeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phòng giải trí & Âm thanh Karaoke'**
  String get supportAddonKaraokeTitle;

  /// No description provided for @supportAddonKaraokeDesc.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống loa giải trí hoặc phòng sinh hoạt chung tại các căn biệt thự có gắn nhãn tiện nghi Karaoke.'**
  String get supportAddonKaraokeDesc;

  /// No description provided for @supportAddonKaraokeNote.
  ///
  /// In vi, this message translates to:
  /// **'Tuân thủ khung giờ yên tĩnh khu dân cư (trước 22:00).'**
  String get supportAddonKaraokeNote;

  /// No description provided for @supportAddonParkingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỗ đậu xe ô tô & xe đoàn an toàn'**
  String get supportAddonParkingTitle;

  /// No description provided for @supportAddonParkingDesc.
  ///
  /// In vi, this message translates to:
  /// **'Sân đậu xe trong khuôn viên hoặc đường nội khu rộng rãi thuận tiện cho ô tô cá nhân và xe du lịch 7–29 chỗ.'**
  String get supportAddonParkingDesc;

  /// No description provided for @supportAddonParkingNote.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra sức chứa xe cụ thể trong phần mô tả chi tiết villa.'**
  String get supportAddonParkingNote;

  /// No description provided for @supportAddonBeachTitle.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí gần bãi tắm biển'**
  String get supportAddonBeachTitle;

  /// No description provided for @supportAddonBeachDesc.
  ///
  /// In vi, this message translates to:
  /// **'Các căn biệt thự có khoảng cách thực tế tới bãi tắm được công bố rõ ràng bằng đơn vị mét ngay trên thẻ thông tin.'**
  String get supportAddonBeachDesc;

  /// No description provided for @supportAddonBeachNote.
  ///
  /// In vi, this message translates to:
  /// **'Lọc nhanh các căn sát biển chỉ với một chạm bên dưới.'**
  String get supportAddonBeachNote;

  /// No description provided for @supportExploreZoneAction.
  ///
  /// In vi, this message translates to:
  /// **'Xem biệt thự khu vực này'**
  String get supportExploreZoneAction;

  /// No description provided for @supportServiceNotePrefix.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ý: {note}'**
  String supportServiceNotePrefix(String note);

  /// No description provided for @supportFilterByAmenityAction.
  ///
  /// In vi, this message translates to:
  /// **'Lọc villa có tiện ích này'**
  String get supportFilterByAmenityAction;

  /// No description provided for @supportFaqSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm câu hỏi theo từ khóa (ví dụ: giữ chỗ, hoàn tiền)...'**
  String get supportFaqSearchHint;

  /// No description provided for @supportFaqClearSearchTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Xóa từ khóa'**
  String get supportFaqClearSearchTooltip;

  /// No description provided for @supportFaqEmptyResult.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy câu hỏi phù hợp với từ khóa hiện tại. Vui lòng thử từ khóa khác hoặc liên hệ trực tiếp đội ngũ tư vấn.'**
  String get supportFaqEmptyResult;

  /// No description provided for @supportBookingGuideEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ đặt phòng'**
  String get supportBookingGuideEyebrow;

  /// No description provided for @supportBookingGuideTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn đặt biệt thự nguyên căn'**
  String get supportBookingGuideTitle;

  /// No description provided for @supportBookingGuideSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Quy trình đặt chỗ 4 bước minh bạch với cơ chế khóa lịch 15 phút chống trùng phòng và đối soát thanh toán trực tuyến tức thời.'**
  String get supportBookingGuideSubtitle;

  /// No description provided for @supportBookingGuideNoteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ý khi nhận và trả phòng'**
  String get supportBookingGuideNoteTitle;

  /// No description provided for @supportBookingGuideNoteBody.
  ///
  /// In vi, this message translates to:
  /// **'Mọi đơn đặt đều tính theo đêm lưu trú [Nhận phòng, Trả phòng) theo múi giờ Việt Nam. Trước khi khởi hành, bạn có thể nhắn tin trực tiếp với Chủ nhà trong mục Tin nhắn để thống nhất giờ đón đoàn và danh sách xe.'**
  String get supportBookingGuideNoteBody;

  /// No description provided for @supportBookingGuideCtaTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sẵn sàng tìm căn biệt thự phù hợp cho đoàn của bạn?'**
  String get supportBookingGuideCtaTitle;

  /// No description provided for @supportBookingGuideCtaDesc.
  ///
  /// In vi, this message translates to:
  /// **'Tra cứu ngay danh sách biệt thự đang mở lịch trống kèm giá niêm yết theo đêm tại Vũng Tàu.'**
  String get supportBookingGuideCtaDesc;

  /// No description provided for @supportBookingGuidePrimaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Tìm biệt thự ngay'**
  String get supportBookingGuidePrimaryAction;

  /// No description provided for @supportBookingGuideSecondaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ tư vấn'**
  String get supportBookingGuideSecondaryAction;

  /// No description provided for @supportCancelEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách lưu trú & hoàn tiền'**
  String get supportCancelEyebrow;

  /// No description provided for @supportCancelTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách hủy phòng & Hoàn tiền'**
  String get supportCancelTitle;

  /// No description provided for @supportCancelSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tỷ lệ hoàn tiền được hệ thống tính tự động dựa trên loại chính sách công bố của từng căn biệt thự và số giờ còn lại trước ngày nhận phòng.'**
  String get supportCancelSubtitle;

  /// No description provided for @supportCancelHostProtectTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bảo vệ khách lưu trú 100% khi Chủ nhà hủy đơn'**
  String get supportCancelHostProtectTitle;

  /// No description provided for @supportCancelHostProtectBody.
  ///
  /// In vi, this message translates to:
  /// **'Trong trường hợp đơn đã thanh toán bị Chủ nhà từ chối hoặc chủ động hủy, hệ thống tự động tạo lệnh hoàn 100% giá trị thanh toán không phụ thuộc bậc chính sách. Các đơn giữ chỗ chưa thanh toán sẽ tự hủy miễn phí sau 15 phút.'**
  String get supportCancelHostProtectBody;

  /// No description provided for @supportCancelCtaTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra trạng thái đơn hoặc yêu cầu hủy phòng'**
  String get supportCancelCtaTitle;

  /// No description provided for @supportCancelCtaDesc.
  ///
  /// In vi, this message translates to:
  /// **'Truy cập mục Chuyến đi để xem chính sách áp dụng riêng cho đơn đặt phòng của bạn hoặc liên hệ bộ phận hỗ trợ.'**
  String get supportCancelCtaDesc;

  /// No description provided for @supportCancelPrimaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Xem Chuyến đi của tôi'**
  String get supportCancelPrimaryAction;

  /// No description provided for @supportCancelSecondaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi thường gặp'**
  String get supportCancelSecondaryAction;

  /// No description provided for @supportComplaintsEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'An toàn & Minh bạch'**
  String get supportComplaintsEyebrow;

  /// No description provided for @supportComplaintsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khiếu nại, Báo cáo & Góp ý dịch vụ'**
  String get supportComplaintsTitle;

  /// No description provided for @supportComplaintsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Mọi phản ánh về chất lượng biệt thự, sai lệch thông tin tin đăng hoặc thái độ phục vụ đều được ghi vết và đối soát độc lập.'**
  String get supportComplaintsSubtitle;

  /// No description provided for @supportComplaintsCtaTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cần hỗ trợ khẩn cấp trong thời gian đang lưu trú?'**
  String get supportComplaintsCtaTitle;

  /// No description provided for @supportComplaintsCtaDesc.
  ///
  /// In vi, this message translates to:
  /// **'Kết nối trực tiếp qua Hotline hoặc Zalo OA tại văn phòng Vũng Tàu (08:00 – 22:00) để được hỗ trợ ngay.'**
  String get supportComplaintsCtaDesc;

  /// No description provided for @supportComplaintsPrimaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Mở trang Liên hệ'**
  String get supportComplaintsPrimaryAction;

  /// No description provided for @supportComplaintsSecondaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn với Host'**
  String get supportComplaintsSecondaryAction;

  /// No description provided for @supportFaqEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Trung tâm giải đáp'**
  String get supportFaqEyebrow;

  /// No description provided for @supportFaqPageTitle.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi thường gặp (FAQ)'**
  String get supportFaqPageTitle;

  /// No description provided for @supportFaqSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Giải đáp nhanh các thắc mắc về cách tính đêm lưu trú, khóa lịch 15 phút, phương thức thanh toán, hoàn tiền và đăng ký đối tác Chủ nhà.'**
  String get supportFaqSubtitle;

  /// No description provided for @supportFaqCtaTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa tìm thấy câu trả lời bạn cần?'**
  String get supportFaqCtaTitle;

  /// No description provided for @supportFaqCtaDesc.
  ///
  /// In vi, this message translates to:
  /// **'Đội ngũ tư vấn tại 28 Thi Sách, TP. Vũng Tàu luôn sẵn sàng giải đáp chi tiết theo nhu cầu riêng của đoàn.'**
  String get supportFaqCtaDesc;

  /// No description provided for @supportFaqPrimaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ tư vấn trực tuyến'**
  String get supportFaqPrimaryAction;

  /// No description provided for @supportFaqSecondaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Xem hướng dẫn đặt phòng'**
  String get supportFaqSecondaryAction;

  /// No description provided for @supportAboutEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Về The Palm Villa'**
  String get supportAboutEyebrow;

  /// No description provided for @supportAboutTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nền tảng đặt biệt thự nghỉ dưỡng nguyên căn tại Vũng Tàu'**
  String get supportAboutTitle;

  /// No description provided for @supportAboutSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết nối trực tiếp du khách với hệ thống biệt thự nghỉ dưỡng đã qua kiểm duyệt thực tế và xác thực danh tính Chủ nhà (KYC) tại TP. Vũng Tàu.'**
  String get supportAboutSubtitle;

  /// No description provided for @supportAboutPillar1Title.
  ///
  /// In vi, this message translates to:
  /// **'Chỗ nghỉ kiểm duyệt & Host xác thực KYC'**
  String get supportAboutPillar1Title;

  /// No description provided for @supportAboutPillar1Body.
  ///
  /// In vi, this message translates to:
  /// **'Mọi hồ sơ đối tác Chủ nhà đều trải qua bước xác minh danh tính và kiểm duyệt thông tin, hình ảnh thực tế trước khi mở lịch đón khách.'**
  String get supportAboutPillar1Body;

  /// No description provided for @supportAboutPillar2Title.
  ///
  /// In vi, this message translates to:
  /// **'Khóa lịch chống đặt trùng (Zero Double-Booking)'**
  String get supportAboutPillar2Title;

  /// No description provided for @supportAboutPillar2Body.
  ///
  /// In vi, this message translates to:
  /// **'Cơ chế khóa ngày mức giao dịch ngay khi tạo đơn giúp bảo vệ tuyệt đối lịch lưu trú của đoàn trong suốt thời gian thanh toán.'**
  String get supportAboutPillar2Body;

  /// No description provided for @supportAboutPillar3Title.
  ///
  /// In vi, this message translates to:
  /// **'Giá niêm yết minh bạch theo từng đêm'**
  String get supportAboutPillar3Title;

  /// No description provided for @supportAboutPillar3Body.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị rõ giá ngày thường, giá cuối tuần, phí vệ sinh và phụ thu khách vượt tiêu chuẩn từ dữ liệu máy chủ trước khi thanh toán.'**
  String get supportAboutPillar3Body;

  /// No description provided for @supportAboutCtaTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đồng hành cùng The Palm Villa'**
  String get supportAboutCtaTitle;

  /// No description provided for @supportAboutCtaDesc.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá các căn biệt thự đang mở lịch hoặc đăng ký trở thành đối tác Chủ nhà để quản lý lịch và doanh thu minh bạch.'**
  String get supportAboutCtaDesc;

  /// No description provided for @supportAboutPrimaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá nơi lưu trú'**
  String get supportAboutPrimaryAction;

  /// No description provided for @supportAboutSecondaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Trở thành Host'**
  String get supportAboutSecondaryAction;

  /// No description provided for @supportExploreVtEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Bản đồ phân khu nghỉ dưỡng'**
  String get supportExploreVtEyebrow;

  /// No description provided for @supportExploreVtTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá Vũng Tàu theo từng phân khu biển'**
  String get supportExploreVtTitle;

  /// No description provided for @supportExploreVtSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi phân khu tại Vũng Tàu mang một nét trải nghiệm riêng. Chọn khu vực phù hợp với lịch trình của đoàn để lọc ngay các căn biệt thự thực tế.'**
  String get supportExploreVtSubtitle;

  /// No description provided for @supportExploreVtCtaTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết hợp lịch trình ăn chơi & kinh nghiệm đi biển'**
  String get supportExploreVtCtaTitle;

  /// No description provided for @supportExploreVtCtaDesc.
  ///
  /// In vi, this message translates to:
  /// **'Tham khảo thêm các bài viết cẩm nang du lịch địa phương để lên kế hoạch trọn vẹn cho kỳ nghỉ tại Vũng Tàu.'**
  String get supportExploreVtCtaDesc;

  /// No description provided for @supportExploreVtPrimaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Đọc Cẩm nang du lịch'**
  String get supportExploreVtPrimaryAction;

  /// No description provided for @supportExploreVtSecondaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Mở bản đồ tìm kiếm'**
  String get supportExploreVtSecondaryAction;

  /// No description provided for @supportAddonEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Tiện nghi & Trải nghiệm'**
  String get supportAddonEyebrow;

  /// No description provided for @supportAddonTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tiện ích biệt thự & Dịch vụ lưu trú đi kèm'**
  String get supportAddonTitle;

  /// No description provided for @supportAddonSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tổng hợp các nhóm tiện nghi đặc trưng của biệt thự nguyên căn và cách trao đổi nhu cầu chuẩn bị tiệc BBQ, đậu xe đoàn cùng Chủ nhà.'**
  String get supportAddonSubtitle;

  /// No description provided for @supportAddonNoteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cách đặt dịch vụ hoặc yêu cầu chuẩn bị trước giờ nhận phòng'**
  String get supportAddonNoteTitle;

  /// No description provided for @supportAddonNoteBody.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi căn biệt thự có cấu hình tiện nghi và quy định phụ thu khách đoàn riêng được niêm yết công khai. Sau khi chọn căn ưng ý, bạn có thể nhấn Nhắn tin cho Host ngay trên trang chi tiết để xác nhận các nhu cầu riêng.'**
  String get supportAddonNoteBody;

  /// No description provided for @supportAddonCtaTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tìm biệt thự có đầy đủ hồ bơi riêng & sân BBQ?'**
  String get supportAddonCtaTitle;

  /// No description provided for @supportAddonCtaDesc.
  ///
  /// In vi, this message translates to:
  /// **'Sử dụng bộ lọc đa tiêu chí trên trang Tìm kiếm để chọn chính xác các tiện ích đoàn của bạn mong muốn.'**
  String get supportAddonCtaDesc;

  /// No description provided for @supportAddonPrimaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Mở bộ lọc nơi lưu trú'**
  String get supportAddonPrimaryAction;

  /// No description provided for @supportAddonSecondaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ tư vấn đoàn'**
  String get supportAddonSecondaryAction;

  /// No description provided for @supportMemberEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Quyền lợi tài khoản'**
  String get supportMemberEyebrow;

  /// No description provided for @supportMemberTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ưu đãi thành viên & Mã giảm giá đặt phòng'**
  String get supportMemberTitle;

  /// No description provided for @supportMemberSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký tài khoản thành viên miễn phí để áp dụng mã ưu đãi trực tiếp khi đặt biệt thự, đồng bộ danh sách yêu thích và quản lý lịch sử chuyến đi.'**
  String get supportMemberSubtitle;

  /// No description provided for @supportMemberNote1Title.
  ///
  /// In vi, this message translates to:
  /// **'Sử dụng Mã giảm giá (Coupon) trực tiếp khi đặt phòng'**
  String get supportMemberNote1Title;

  /// No description provided for @supportMemberNote1Body.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên đã đăng nhập có thể áp dụng mã ưu đãi theo phần trăm (%) hoặc số tiền cố định trên trang chi tiết biệt thự. Hệ thống tự động kiểm tra hạn dùng, giá trị đơn tối thiểu và số lượt sử dụng của từng tài khoản.'**
  String get supportMemberNote1Body;

  /// No description provided for @supportMemberNote2Title.
  ///
  /// In vi, this message translates to:
  /// **'Đồng bộ Danh sách yêu thích & Theo dõi Chuyến đi thời gian thực'**
  String get supportMemberNote2Title;

  /// No description provided for @supportMemberNote2Body.
  ///
  /// In vi, this message translates to:
  /// **'Lưu lại các căn biệt thự ưng ý trên mọi thiết bị, nhận thông báo trạng thái đơn tức thời và nhắn tin trực tiếp với Chủ nhà không qua trung gian.'**
  String get supportMemberNote2Body;

  /// No description provided for @supportMemberCtaTitle.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng ưu đãi cho kỳ nghỉ sắp tới tại Vũng Tàu'**
  String get supportMemberCtaTitle;

  /// No description provided for @supportMemberCtaDesc.
  ///
  /// In vi, this message translates to:
  /// **'Chọn căn biệt thự yêu thích, kiểm tra giá niêm yết theo đêm và nhập mã giảm giá ngay tại bước xác nhận đặt phòng.'**
  String get supportMemberCtaDesc;

  /// No description provided for @supportMemberPrimaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Tìm biệt thự đang mở lịch'**
  String get supportMemberPrimaryAction;

  /// No description provided for @supportMemberSecondaryAction.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách yêu thích'**
  String get supportMemberSecondaryAction;

  /// No description provided for @supportReportTargetBooking.
  ///
  /// In vi, this message translates to:
  /// **'Đơn đặt phòng (Mã Booking)'**
  String get supportReportTargetBooking;

  /// No description provided for @supportReportTargetListing.
  ///
  /// In vi, this message translates to:
  /// **'Chỗ nghỉ / Biệt thự (Mã Villa)'**
  String get supportReportTargetListing;

  /// No description provided for @supportReportTargetReview.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá lưu trú (Mã Review)'**
  String get supportReportTargetReview;

  /// No description provided for @supportReportTargetUser.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản người dùng (Mã User)'**
  String get supportReportTargetUser;

  /// No description provided for @supportReportSuccessMessage.
  ///
  /// In vi, this message translates to:
  /// **'Đã ghi nhận phản ánh thành công. Bộ phận Kiểm duyệt & An toàn sẽ đối soát và phản hồi sớm nhất.'**
  String get supportReportSuccessMessage;

  /// No description provided for @supportReportErrorFallback.
  ///
  /// In vi, this message translates to:
  /// **'Không thể gửi phản ánh lúc này. Vui lòng thử lại.'**
  String get supportReportErrorFallback;

  /// No description provided for @supportReportStatusResolved.
  ///
  /// In vi, this message translates to:
  /// **'Đã giải quyết'**
  String get supportReportStatusResolved;

  /// No description provided for @supportReportStatusRejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối'**
  String get supportReportStatusRejected;

  /// No description provided for @supportReportStatusOpen.
  ///
  /// In vi, this message translates to:
  /// **'Đang xử lý'**
  String get supportReportStatusOpen;

  /// No description provided for @supportReportGuestCardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gửi báo cáo & khiếu nại trực tuyến'**
  String get supportReportGuestCardTitle;

  /// No description provided for @supportReportGuestCardBody.
  ///
  /// In vi, this message translates to:
  /// **'Để đảm bảo tính xác thực và đối soát đúng mã đơn đặt phòng, vui lòng đăng nhập tài khoản trước khi gửi phản ánh trực tuyến hoặc kết nối nhanh qua trang Liên hệ.'**
  String get supportReportGuestCardBody;

  /// No description provided for @supportReportLoginAction.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để gửi phản ánh'**
  String get supportReportLoginAction;

  /// No description provided for @supportReportDirectContactAction.
  ///
  /// In vi, this message translates to:
  /// **'Mở kênh Liên hệ trực tiếp'**
  String get supportReportDirectContactAction;

  /// No description provided for @supportReportAuthCardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gửi phản ánh / báo cáo tới bộ phận Kiểm duyệt'**
  String get supportReportAuthCardTitle;

  /// No description provided for @supportReportAuthCardSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin phản ánh được lưu vết trực tiếp để Quản trị viên kiểm tra và phản hồi minh bạch.'**
  String get supportReportAuthCardSubtitle;

  /// No description provided for @supportReportTargetGroupLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm đối tượng phản ánh'**
  String get supportReportTargetGroupLabel;

  /// No description provided for @supportReportTargetIdLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã định danh số (ví dụ: mã đơn 102 hoặc mã villa 15)'**
  String get supportReportTargetIdLabel;

  /// No description provided for @supportReportTargetIdError.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập mã số nguyên dương hợp lệ'**
  String get supportReportTargetIdError;

  /// No description provided for @supportReportReasonLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tiêu đề khiếu nại / góp ý'**
  String get supportReportReasonLabel;

  /// No description provided for @supportReportReasonEmptyError.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tiêu đề phản ánh'**
  String get supportReportReasonEmptyError;

  /// No description provided for @supportReportReasonMaxError.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 255 ký tự'**
  String get supportReportReasonMaxError;

  /// No description provided for @supportReportDescLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả chi tiết sự việc (tùy chọn)'**
  String get supportReportDescLabel;

  /// No description provided for @supportReportSubmittingLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi phản ánh...'**
  String get supportReportSubmittingLabel;

  /// No description provided for @supportReportSubmitAction.
  ///
  /// In vi, this message translates to:
  /// **'Gửi phản ánh'**
  String get supportReportSubmitAction;

  /// No description provided for @supportReportRecentTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phản ánh gần đây của bạn ({count})'**
  String supportReportRecentTitle(int count);

  /// No description provided for @supportCouponEmptyError.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập mã ưu đãi cần kiểm tra.'**
  String get supportCouponEmptyError;

  /// No description provided for @supportCouponValidStatus.
  ///
  /// In vi, this message translates to:
  /// **'Mã {code} hợp lệ — ước tính giảm {discount} cho đơn tạm tính.'**
  String supportCouponValidStatus(String code, String discount);

  /// No description provided for @supportCouponInvalidFallback.
  ///
  /// In vi, this message translates to:
  /// **'Mã ưu đãi chưa đủ điều kiện hoặc đã hết hạn.'**
  String get supportCouponInvalidFallback;

  /// No description provided for @supportCouponCheckError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể kiểm tra mã ưu đãi lúc này.'**
  String get supportCouponCheckError;

  /// No description provided for @supportCouponCardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tra cứu hiệu lực Mã ưu đãi (Coupon)'**
  String get supportCouponCardTitle;

  /// No description provided for @supportCouponGuestHint.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập tài khoản thành viên để kiểm tra trực tiếp hiệu lực mã giảm giá theo giá trị đơn dự kiến hoặc áp dụng ngay tại bước đặt biệt thự.'**
  String get supportCouponGuestHint;

  /// No description provided for @supportCouponAuthHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã ưu đãi bạn đang có và giá trị đơn lưu trú dự kiến (VNĐ) để kiểm tra điều kiện áp dụng trực tiếp từ hệ thống.'**
  String get supportCouponAuthHint;

  /// No description provided for @supportCouponLoginAction.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập thành viên'**
  String get supportCouponLoginAction;

  /// No description provided for @supportCouponRegisterAction.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản miễn phí'**
  String get supportCouponRegisterAction;

  /// No description provided for @supportCouponCodeInputLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã ưu đãi (ví dụ: PALM2026)'**
  String get supportCouponCodeInputLabel;

  /// No description provided for @supportCouponAmountInputLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giá trị đơn tạm tính (VNĐ)'**
  String get supportCouponAmountInputLabel;

  /// No description provided for @supportCouponCheckingLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đang kiểm tra...'**
  String get supportCouponCheckingLabel;

  /// No description provided for @supportCouponCheckAction.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra mã ưu đãi'**
  String get supportCouponCheckAction;
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
