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

  /// No description provided for @aiSearchTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm thông minh bằng AI'**
  String get aiSearchTitle;

  /// No description provided for @aiSearchPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả kỳ nghỉ mong muốn (VD: Villa sát biển Bãi Sau cho 15 người có hồ bơi nước mặn, BBQ)...'**
  String get aiSearchPlaceholder;

  /// No description provided for @aiSearchAction.
  ///
  /// In vi, this message translates to:
  /// **'Tìm bằng AI'**
  String get aiSearchAction;

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
  /// **'Trở thành Chủ nhà tại Minh Thanh Villa'**
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
