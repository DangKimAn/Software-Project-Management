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

  /// No description provided for @calendarPrevMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng trước'**
  String get calendarPrevMonth;

  /// No description provided for @calendarNextMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng tiếp theo'**
  String get calendarNextMonth;

  /// No description provided for @calendarDay.
  ///
  /// In vi, this message translates to:
  /// **'Ngày {day}'**
  String calendarDay(int day);

  /// No description provided for @calendarDayBooked.
  ///
  /// In vi, this message translates to:
  /// **'Ngày {day} đã kín'**
  String calendarDayBooked(int day);

  /// No description provided for @calendarDayCheckOutOnly.
  ///
  /// In vi, this message translates to:
  /// **'Ngày {day} chỉ trả phòng'**
  String calendarDayCheckOutOnly(int day);

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

  /// No description provided for @footerSupport.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ'**
  String get footerSupport;

  /// No description provided for @footerBookingGuide.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn đặt phòng'**
  String get footerBookingGuide;

  /// No description provided for @footerCancellationPolicy.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách hủy phòng'**
  String get footerCancellationPolicy;

  /// No description provided for @footerFeedback.
  ///
  /// In vi, this message translates to:
  /// **'Khiếu nại & Góp ý'**
  String get footerFeedback;

  /// No description provided for @footerFaq.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi thường gặp (FAQ)'**
  String get footerFaq;

  /// No description provided for @footerDiscover.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá Vũng Tàu'**
  String get footerDiscover;

  /// No description provided for @footerAboutUs.
  ///
  /// In vi, this message translates to:
  /// **'Về chúng tôi'**
  String get footerAboutUs;

  /// No description provided for @footerTravelGuide.
  ///
  /// In vi, this message translates to:
  /// **'Cẩm nang du lịch'**
  String get footerTravelGuide;

  /// No description provided for @footerAddonServices.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ đi kèm'**
  String get footerAddonServices;

  /// No description provided for @footerMemberOffers.
  ///
  /// In vi, this message translates to:
  /// **'Ưu đãi thành viên'**
  String get footerMemberOffers;

  /// No description provided for @footerContact.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ'**
  String get footerContact;

  /// No description provided for @footerOnlineConsultation.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ tư vấn trực tuyến'**
  String get footerOnlineConsultation;

  /// No description provided for @footerHotline.
  ///
  /// In vi, this message translates to:
  /// **'Hotline: {phone}'**
  String footerHotline(String phone);

  /// No description provided for @footerAddress.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ: 28 Thi Sách'**
  String get footerAddress;

  /// No description provided for @footerEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email: {email}'**
  String footerEmail(String email);

  /// No description provided for @footerSocial.
  ///
  /// In vi, this message translates to:
  /// **'Mạng xã hội'**
  String get footerSocial;

  /// No description provided for @footerCopyright.
  ///
  /// In vi, this message translates to:
  /// **'© Bản quyền thuộc về Villa Vũng Tàu 2026'**
  String get footerCopyright;

  /// No description provided for @settingsAvatarUpdateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật ảnh đại diện'**
  String get settingsAvatarUpdateTitle;

  /// No description provided for @settingsAvatarUpdateHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ảnh định dạng JPG, PNG, WebP hoặc GIF từ máy của bạn (dung lượng tối đa 5MB).'**
  String get settingsAvatarUpdateHint;

  /// No description provided for @settingsAvatarPickFromDevice.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ảnh từ thiết bị (Tối đa 5MB)'**
  String get settingsAvatarPickFromDevice;

  /// No description provided for @settingsAvatarUploading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải ảnh lên...'**
  String get settingsAvatarUploading;

  /// No description provided for @settingsAvatarSelected.
  ///
  /// In vi, this message translates to:
  /// **'Đã chọn: {fileName} ({sizeKb} KB)'**
  String settingsAvatarSelected(String fileName, String sizeKb);

  /// No description provided for @settingsAvatarPickError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể chọn ảnh từ thiết bị. Vui lòng thử lại.'**
  String get settingsAvatarPickError;

  /// No description provided for @settingsAvatarUpdateSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật ảnh đại diện thành công.'**
  String get settingsAvatarUpdateSuccess;

  /// No description provided for @settingsChangeAvatarTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Đổi ảnh'**
  String get settingsChangeAvatarTooltip;

  /// No description provided for @settingsEditProfileTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Sửa hồ sơ'**
  String get settingsEditProfileTooltip;

  /// No description provided for @settingsEditProfileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hồ sơ cá nhân'**
  String get settingsEditProfileTitle;

  /// No description provided for @settingsAvatarSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đại diện'**
  String get settingsAvatarSectionTitle;

  /// No description provided for @settingsAvatarPickFromDeviceShort.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ảnh từ máy'**
  String get settingsAvatarPickFromDeviceShort;

  /// No description provided for @settingsAvatarUploadingShort.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải...'**
  String get settingsAvatarUploadingShort;

  /// No description provided for @settingsAvatarPickHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ảnh từ thiết bị (tối đa 5MB)'**
  String get settingsAvatarPickHint;

  /// No description provided for @settingsAvatarSelectedShort.
  ///
  /// In vi, this message translates to:
  /// **'Đã chọn: {fileName}'**
  String settingsAvatarSelectedShort(String fileName);

  /// No description provided for @settingsFullNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên *'**
  String get settingsFullNameLabel;

  /// No description provided for @settingsFullNameHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập họ và tên đầy đủ'**
  String get settingsFullNameHint;

  /// No description provided for @settingsPhoneLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get settingsPhoneLabel;

  /// No description provided for @settingsPhoneHint.
  ///
  /// In vi, this message translates to:
  /// **'0912345678 hoặc +84912345678'**
  String get settingsPhoneHint;

  /// No description provided for @settingsLocationLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nơi sinh sống'**
  String get settingsLocationLabel;

  /// No description provided for @settingsLocationHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Vũng Tàu, Việt Nam'**
  String get settingsLocationHint;

  /// No description provided for @settingsDreamDestinationLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nơi tôi luôn muốn đến'**
  String get settingsDreamDestinationLabel;

  /// No description provided for @settingsDreamDestinationHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập điểm đến yêu thích của bạn'**
  String get settingsDreamDestinationHint;

  /// No description provided for @settingsJobLabel.
  ///
  /// In vi, this message translates to:
  /// **'Công việc / Nghề nghiệp'**
  String get settingsJobLabel;

  /// No description provided for @settingsJobHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập công việc hiện tại'**
  String get settingsJobHint;

  /// No description provided for @settingsSchoolLabel.
  ///
  /// In vi, this message translates to:
  /// **'Trường học'**
  String get settingsSchoolLabel;

  /// No description provided for @settingsSchoolHint.
  ///
  /// In vi, this message translates to:
  /// **'Nơi bạn từng theo học'**
  String get settingsSchoolHint;

  /// No description provided for @settingsLanguagesLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ giao tiếp'**
  String get settingsLanguagesLabel;

  /// No description provided for @settingsLanguagesHint.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt, English (phân cách bằng dấu phẩy)'**
  String get settingsLanguagesHint;

  /// No description provided for @settingsBioLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu bản thân'**
  String get settingsBioLabel;

  /// No description provided for @settingsBioHint.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ đôi nét về bản thân...'**
  String get settingsBioHint;

  /// No description provided for @settingsSaving.
  ///
  /// In vi, this message translates to:
  /// **'Đang lưu...'**
  String get settingsSaving;

  /// No description provided for @settingsProfileUpdateSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật hồ sơ thành công.'**
  String get settingsProfileUpdateSuccess;

  /// No description provided for @settingsUnsavedDraftBanner.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có bản nháp hồ sơ chưa lưu thành công.'**
  String get settingsUnsavedDraftBanner;

  /// No description provided for @settingsResumeEditing.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục sửa'**
  String get settingsResumeEditing;

  /// No description provided for @settingsConfirmPhoneTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận thay đổi số điện thoại'**
  String get settingsConfirmPhoneTitle;

  /// No description provided for @settingsConfirmPhoneRemove.
  ///
  /// In vi, this message translates to:
  /// **'Bạn sắp xóa số điện thoại liên hệ đã lưu ({oldPhone}). Bạn có chắc chắn muốn tiếp tục?'**
  String settingsConfirmPhoneRemove(String oldPhone);

  /// No description provided for @settingsConfirmPhoneChange.
  ///
  /// In vi, this message translates to:
  /// **'Bạn sắp thay đổi số điện thoại liên hệ từ {oldPhone} sang {newPhone}. Bạn có chắc chắn muốn lưu thay đổi này?'**
  String settingsConfirmPhoneChange(String oldPhone, String newPhone);

  /// No description provided for @settingsConfirmPhoneReview.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra lại'**
  String get settingsConfirmPhoneReview;

  /// No description provided for @settingsConfirmPhoneSave.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận lưu'**
  String get settingsConfirmPhoneSave;

  /// No description provided for @settingsConfirmLogoutTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận đăng xuất'**
  String get settingsConfirmLogoutTitle;

  /// No description provided for @settingsConfirmLogoutDraft.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang có bản nháp chỉnh sửa hồ sơ chưa lưu. Đăng xuất sẽ xóa dữ liệu nháp tạm thời trên phiên này. Bạn có chắc chắn muốn đăng xuất?'**
  String get settingsConfirmLogoutDraft;

  /// No description provided for @settingsConfirmLogout.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này không?'**
  String get settingsConfirmLogout;

  /// No description provided for @settingsRoleAdmin.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị viên (Admin)'**
  String get settingsRoleAdmin;

  /// No description provided for @settingsRoleHost.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà (Host)'**
  String get settingsRoleHost;

  /// No description provided for @settingsRoleHostPending.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ Chủ nhà đang chờ duyệt'**
  String get settingsRoleHostPending;

  /// No description provided for @settingsRoleGuest.
  ///
  /// In vi, this message translates to:
  /// **'Khách lưu trú'**
  String get settingsRoleGuest;

  /// No description provided for @settingsLoadingAccount.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải thông tin tài khoản...'**
  String get settingsLoadingAccount;

  /// No description provided for @settingsNotLoggedIn.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đăng nhập'**
  String get settingsNotLoggedIn;

  /// No description provided for @settingsLoginPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để xem kỳ nghỉ, tin nhắn và đồng bộ yêu thích'**
  String get settingsLoginPrompt;

  /// No description provided for @settingsSignInSignUp.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập / Đăng ký'**
  String get settingsSignInSignUp;

  /// No description provided for @settingsReLogin.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập lại'**
  String get settingsReLogin;

  /// No description provided for @settingsContactSupportCenter.
  ///
  /// In vi, this message translates to:
  /// **'Trung tâm Liên hệ & Hỗ trợ'**
  String get settingsContactSupportCenter;

  /// No description provided for @settingsCallHotline.
  ///
  /// In vi, this message translates to:
  /// **'Gọi tổng đài tư vấn'**
  String get settingsCallHotline;

  /// No description provided for @settingsZaloSupport.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin qua Zalo OA'**
  String get settingsZaloSupport;

  /// No description provided for @settingsZaloInquiryDefaultMessage.
  ///
  /// In vi, this message translates to:
  /// **'Xin chào The Palm, tôi cần hỗ trợ thông tin ứng dụng.'**
  String get settingsZaloInquiryDefaultMessage;

  /// No description provided for @settingsManageProperties.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý chỗ nghỉ'**
  String get settingsManageProperties;

  /// No description provided for @settingsMyTrips.
  ///
  /// In vi, this message translates to:
  /// **'Chuyến đi của tôi'**
  String get settingsMyTrips;

  /// No description provided for @settingsMyFavorites.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách yêu thích'**
  String get settingsMyFavorites;

  /// No description provided for @settingsMessagesWithHost.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn với Chủ nhà'**
  String get settingsMessagesWithHost;

  /// No description provided for @settingsStatusOfflineTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thiết bị đang ngoại tuyến'**
  String get settingsStatusOfflineTitle;

  /// No description provided for @settingsStatusUnauthorizedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phiên đăng nhập hết hạn hoặc bị từ chối'**
  String get settingsStatusUnauthorizedTitle;

  /// No description provided for @settingsStatusServerErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thể đồng bộ dữ liệu máy chủ'**
  String get settingsStatusServerErrorTitle;

  /// No description provided for @settingsStatusOfflineMessage.
  ///
  /// In vi, this message translates to:
  /// **'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.'**
  String get settingsStatusOfflineMessage;

  /// No description provided for @settingsStatusUnauthorizedMessage.
  ///
  /// In vi, this message translates to:
  /// **'Phiên đăng nhập không hợp lệ hoặc bạn không có quyền truy cập (401/403).'**
  String get settingsStatusUnauthorizedMessage;

  /// No description provided for @settingsStatusServerErrorMessage.
  ///
  /// In vi, this message translates to:
  /// **'Máy chủ đang gặp sự cố tạm thời. Vui lòng thử lại sau.'**
  String get settingsStatusServerErrorMessage;

  /// No description provided for @villaDetailViewAllPhotos.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả {count} ảnh'**
  String villaDetailViewAllPhotos(int count);

  /// No description provided for @villaDetailShareCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép liên kết vào bộ nhớ tạm'**
  String get villaDetailShareCopied;

  /// No description provided for @villaDetailAboutTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu biệt thự'**
  String get villaDetailAboutTitle;

  /// No description provided for @villaDetailTranslatedBadge.
  ///
  /// In vi, this message translates to:
  /// **'Đã dịch sang Tiếng Việt'**
  String get villaDetailTranslatedBadge;

  /// No description provided for @villaDetailShowOriginal.
  ///
  /// In vi, this message translates to:
  /// **'Xem bản gốc'**
  String get villaDetailShowOriginal;

  /// No description provided for @villaDetailShowTranslation.
  ///
  /// In vi, this message translates to:
  /// **'Xem bản dịch'**
  String get villaDetailShowTranslation;

  /// No description provided for @villaDetailOriginalBadge.
  ///
  /// In vi, this message translates to:
  /// **'Bản gốc (Tiếng Việt)'**
  String get villaDetailOriginalBadge;

  /// No description provided for @villaDetailAmenitiesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tiện nghi có sẵn'**
  String get villaDetailAmenitiesTitle;

  /// No description provided for @villaDetailBookingCalendarTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn lịch lưu trú & Đặt phòng'**
  String get villaDetailBookingCalendarTitle;

  /// No description provided for @villaDetailStayNightsRange.
  ///
  /// In vi, this message translates to:
  /// **'Tối thiểu {min} đêm • Tối đa {max} đêm'**
  String villaDetailStayNightsRange(int min, int max);

  /// No description provided for @villaDetailGuestCapacityInfo.
  ///
  /// In vi, this message translates to:
  /// **'Tiêu chuẩn {included} · Tối đa {max} khách'**
  String villaDetailGuestCapacityInfo(int included, int max);

  /// No description provided for @villaDetailGuestCapacityMax.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa {max} khách'**
  String villaDetailGuestCapacityMax(int max);

  /// No description provided for @villaDetailPromoCodeHint.
  ///
  /// In vi, this message translates to:
  /// **'Mã ưu đãi'**
  String get villaDetailPromoCodeHint;

  /// No description provided for @villaDetailPromoApply.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng'**
  String get villaDetailPromoApply;

  /// No description provided for @villaDetailPromoChecking.
  ///
  /// In vi, this message translates to:
  /// **'Đang kiểm tra...'**
  String get villaDetailPromoChecking;

  /// No description provided for @villaDetailSpecialRequestsHint.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú cho chủ nhà (tùy chọn)'**
  String get villaDetailSpecialRequestsHint;

  /// No description provided for @villaDetailRoomSubtotal.
  ///
  /// In vi, this message translates to:
  /// **'Tiền phòng ({nights} đêm)'**
  String villaDetailRoomSubtotal(int nights);

  /// No description provided for @villaDetailWeekendNights.
  ///
  /// In vi, this message translates to:
  /// **', {count} đêm cuối tuần'**
  String villaDetailWeekendNights(int count);

  /// No description provided for @villaDetailExtraGuestFee.
  ///
  /// In vi, this message translates to:
  /// **'Phụ thu vượt khách tiêu chuẩn'**
  String get villaDetailExtraGuestFee;

  /// No description provided for @villaDetailCleaningFee.
  ///
  /// In vi, this message translates to:
  /// **'Phí vệ sinh'**
  String get villaDetailCleaningFee;

  /// No description provided for @villaDetailServiceFee.
  ///
  /// In vi, this message translates to:
  /// **'Phí dịch vụ'**
  String get villaDetailServiceFee;

  /// No description provided for @villaDetailDiscountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giảm giá ({code})'**
  String villaDetailDiscountLabel(String code);

  /// No description provided for @villaDetailEstimatedTotal.
  ///
  /// In vi, this message translates to:
  /// **'Tổng thanh toán tạm tính'**
  String get villaDetailEstimatedTotal;

  /// No description provided for @villaDetailPoliciesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nội quy chỗ nghỉ & Chính sách hoàn hủy'**
  String get villaDetailPoliciesTitle;

  /// No description provided for @villaDetailCheckInTime.
  ///
  /// In vi, this message translates to:
  /// **'Nhận phòng: {from} – {until}'**
  String villaDetailCheckInTime(String from, String until);

  /// No description provided for @villaDetailCheckOutTime.
  ///
  /// In vi, this message translates to:
  /// **'Trả phòng: Trước {time}'**
  String villaDetailCheckOutTime(String time);

  /// No description provided for @villaDetailQuietHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ yên tĩnh: {hours}'**
  String villaDetailQuietHours(String hours);

  /// No description provided for @villaDetailPetsAllowed.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép mang thú cưng'**
  String get villaDetailPetsAllowed;

  /// No description provided for @villaDetailPetsNotAllowed.
  ///
  /// In vi, this message translates to:
  /// **'Không mang thú cưng'**
  String get villaDetailPetsNotAllowed;

  /// No description provided for @villaDetailPolicyFlexible.
  ///
  /// In vi, this message translates to:
  /// **'Linh hoạt — Hoàn tiền 100% trước 24 giờ nhận phòng'**
  String get villaDetailPolicyFlexible;

  /// No description provided for @villaDetailPolicyModerate.
  ///
  /// In vi, this message translates to:
  /// **'Trung bình — Hoàn tiền 100% trước 5 ngày nhận phòng'**
  String get villaDetailPolicyModerate;

  /// No description provided for @villaDetailPolicyStrict.
  ///
  /// In vi, this message translates to:
  /// **'Nghiêm ngặt — Hoàn tiền 50% trước 7 ngày nhận phòng'**
  String get villaDetailPolicyStrict;

  /// No description provided for @villaDetailSimilarTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gợi ý chỗ nghỉ tương tự gần đây'**
  String get villaDetailSimilarTitle;

  /// No description provided for @villaDetailMessageHostTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin cho Chủ nhà'**
  String get villaDetailMessageHostTooltip;

  /// No description provided for @villaDetailHostPrefix.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà: {name}'**
  String villaDetailHostPrefix(String name);

  /// No description provided for @villaDetailMinNightsRequired.
  ///
  /// In vi, this message translates to:
  /// **'Chỗ nghỉ này yêu cầu tối thiểu {min} đêm.'**
  String villaDetailMinNightsRequired(int min);

  /// No description provided for @villaDetailMaxNightsExceeded.
  ///
  /// In vi, this message translates to:
  /// **'Chỗ nghỉ này giới hạn tối đa {max} đêm mỗi lần đặt.'**
  String villaDetailMaxNightsExceeded(int max);

  /// No description provided for @villaDetailLoginToBook.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng đăng nhập để hoàn tất đặt phòng.'**
  String get villaDetailLoginToBook;

  /// No description provided for @villaDetailBookingSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi yêu cầu đặt phòng! Bạn có thể thanh toán ngay hoặc theo dõi tại Chuyến đi.'**
  String get villaDetailBookingSuccess;

  /// No description provided for @specSaltwaterPool.
  ///
  /// In vi, this message translates to:
  /// **'Hồ bơi nước mặn'**
  String get specSaltwaterPool;

  /// No description provided for @specBeachDistance.
  ///
  /// In vi, this message translates to:
  /// **'Cách biển {meters}m'**
  String specBeachDistance(int meters);

  /// No description provided for @specBeachfront.
  ///
  /// In vi, this message translates to:
  /// **'Sát biển'**
  String get specBeachfront;

  /// No description provided for @specGuestsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} khách'**
  String specGuestsCount(int count);

  /// No description provided for @specBedroomsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} phòng'**
  String specBedroomsCount(int count);

  /// No description provided for @specBedsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} giường'**
  String specBedsCount(int count);

  /// No description provided for @specBathsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} WC'**
  String specBathsCount(int count);

  /// No description provided for @reviewsTranslate.
  ///
  /// In vi, this message translates to:
  /// **'Dịch đánh giá'**
  String get reviewsTranslate;

  /// No description provided for @reviewsShowOriginal.
  ///
  /// In vi, this message translates to:
  /// **'Xem bản gốc'**
  String get reviewsShowOriginal;

  /// No description provided for @reviewsTranslating.
  ///
  /// In vi, this message translates to:
  /// **'Đang dịch...'**
  String get reviewsTranslating;

  /// No description provided for @reviewsTranslatedBadge.
  ///
  /// In vi, this message translates to:
  /// **'Đã dịch tự động'**
  String get reviewsTranslatedBadge;

  /// No description provided for @reviewsFilterAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get reviewsFilterAll;

  /// No description provided for @reviewsFilterStar.
  ///
  /// In vi, this message translates to:
  /// **'{star} sao'**
  String reviewsFilterStar(int star);

  /// No description provided for @reviewsHostReply.
  ///
  /// In vi, this message translates to:
  /// **'Phản hồi từ chủ nhà'**
  String get reviewsHostReply;

  /// No description provided for @reviewsLoadMore.
  ///
  /// In vi, this message translates to:
  /// **'Xem thêm đánh giá'**
  String get reviewsLoadMore;

  /// No description provided for @reviewsLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải đánh giá vào lúc này.'**
  String get reviewsLoadError;

  /// No description provided for @reviewsEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đánh giá nào cho villa này. Hãy là vị khách đầu tiên trải nghiệm!'**
  String get reviewsEmpty;

  /// No description provided for @reviewsEmptyRating.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đánh giá {rating} sao nào cho chỗ nghỉ này.'**
  String reviewsEmptyRating(int rating);

  /// No description provided for @chatBackToList.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại danh sách'**
  String get chatBackToList;

  /// No description provided for @chatShowTimestamps.
  ///
  /// In vi, this message translates to:
  /// **'Hiện khung thời gian'**
  String get chatShowTimestamps;

  /// No description provided for @chatHideTimestamps.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn thời gian'**
  String get chatHideTimestamps;

  /// No description provided for @chatViewListing.
  ///
  /// In vi, this message translates to:
  /// **'Xem chỗ nghỉ'**
  String get chatViewListing;

  /// No description provided for @chatAboutListing.
  ///
  /// In vi, this message translates to:
  /// **'Trao đổi về chỗ nghỉ'**
  String get chatAboutListing;

  /// No description provided for @chatSelectConversationPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Chọn một hội thoại để xem tin nhắn'**
  String get chatSelectConversationPrompt;

  /// No description provided for @chatInputPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin'**
  String get chatInputPlaceholder;

  /// No description provided for @chatMoreOptions.
  ///
  /// In vi, this message translates to:
  /// **'Tiện ích mở rộng'**
  String get chatMoreOptions;

  /// No description provided for @chatCamera.
  ///
  /// In vi, this message translates to:
  /// **'Chụp ảnh'**
  String get chatCamera;

  /// No description provided for @chatGallery.
  ///
  /// In vi, this message translates to:
  /// **'Gửi hình ảnh'**
  String get chatGallery;

  /// No description provided for @chatGalleryLabel.
  ///
  /// In vi, this message translates to:
  /// **'Thư viện ảnh'**
  String get chatGalleryLabel;

  /// No description provided for @chatVoiceMessage.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn thoại'**
  String get chatVoiceMessage;

  /// No description provided for @chatStopRecording.
  ///
  /// In vi, this message translates to:
  /// **'Dừng ghi âm'**
  String get chatStopRecording;

  /// No description provided for @chatEmojiTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Biểu tượng cảm xúc'**
  String get chatEmojiTooltip;

  /// No description provided for @chatSendMessage.
  ///
  /// In vi, this message translates to:
  /// **'Gửi tin nhắn'**
  String get chatSendMessage;

  /// No description provided for @chatSendQuickEmoji.
  ///
  /// In vi, this message translates to:
  /// **'Gửi biểu tượng nhanh'**
  String get chatSendQuickEmoji;

  /// No description provided for @chatSendQuickEmojiHint.
  ///
  /// In vi, this message translates to:
  /// **'Gửi biểu tượng nhanh (nhấn giữ để đổi)'**
  String get chatSendQuickEmojiHint;

  /// No description provided for @chatSending.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi...'**
  String get chatSending;

  /// No description provided for @chatSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi'**
  String get chatSent;

  /// No description provided for @chatSeen.
  ///
  /// In vi, this message translates to:
  /// **' • Đã xem'**
  String get chatSeen;

  /// No description provided for @chatFailed.
  ///
  /// In vi, this message translates to:
  /// **'Gửi thất bại'**
  String get chatFailed;

  /// No description provided for @chatRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get chatRetry;

  /// No description provided for @chatDeleteFailedMessage.
  ///
  /// In vi, this message translates to:
  /// **'Xóa tin nhắn lỗi'**
  String get chatDeleteFailedMessage;

  /// No description provided for @chatEmptyPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Hãy gửi tin nhắn đầu tiên để bắt đầu trao đổi.'**
  String get chatEmptyPrompt;

  /// No description provided for @chatLoadMoreHistory.
  ///
  /// In vi, this message translates to:
  /// **'Tải thêm tin nhắn cũ hơn'**
  String get chatLoadMoreHistory;

  /// No description provided for @chatLoadingHistory.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải lịch sử...'**
  String get chatLoadingHistory;

  /// No description provided for @chatNewMessagesCount.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn mới ({count})'**
  String chatNewMessagesCount(int count);

  /// No description provided for @chatUserTyping.
  ///
  /// In vi, this message translates to:
  /// **'{user} đang nhập tin nhắn...'**
  String chatUserTyping(String user);

  /// No description provided for @chatDraftPrefix.
  ///
  /// In vi, this message translates to:
  /// **'Nháp: '**
  String get chatDraftPrefix;

  /// No description provided for @chatNoMessagesYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin nhắn.'**
  String get chatNoMessagesYet;

  /// No description provided for @chatSearchConversationsPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm hội thoại...'**
  String get chatSearchConversationsPlaceholder;

  /// No description provided for @chatLoginTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để xem tin nhắn'**
  String get chatLoginTitle;

  /// No description provided for @chatLoginDescription.
  ///
  /// In vi, this message translates to:
  /// **'Trao đổi trực tiếp với Chủ nhà Vũng Tàu về lịch phòng, tiện nghi và ưu đãi.'**
  String get chatLoginDescription;

  /// No description provided for @chatLoginAction.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập ngay'**
  String get chatLoginAction;

  /// No description provided for @chatEmptyAdminTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có cuộc trò chuyện hỗ trợ nào'**
  String get chatEmptyAdminTitle;

  /// No description provided for @chatEmptyAdminDesc.
  ///
  /// In vi, this message translates to:
  /// **'Các hội thoại hỗ trợ trực tiếp với Chủ nhà và Khách hàng trên hệ thống sẽ hiển thị tại đây.'**
  String get chatEmptyAdminDesc;

  /// No description provided for @chatEmptyAdminAction.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý người dùng'**
  String get chatEmptyAdminAction;

  /// No description provided for @chatEmptyHostTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có cuộc trò chuyện nào'**
  String get chatEmptyHostTitle;

  /// No description provided for @chatEmptyHostDesc.
  ///
  /// In vi, this message translates to:
  /// **'Khi khách hàng nhắn tin hỏi phòng hoặc đặt chỗ, hội thoại sẽ hiển thị tại đây.'**
  String get chatEmptyHostDesc;

  /// No description provided for @chatEmptyGuestTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có cuộc trò chuyện nào'**
  String get chatEmptyGuestTitle;

  /// No description provided for @chatEmptyGuestDesc.
  ///
  /// In vi, this message translates to:
  /// **'Hãy chọn một biệt thự và bấm \"Nhắn tin cho Chủ nhà\" để bắt đầu trò chuyện.'**
  String get chatEmptyGuestDesc;

  /// No description provided for @chatEmptyGuestAction.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá biệt thự'**
  String get chatEmptyGuestAction;

  /// No description provided for @chatExtensionsAndTemplatesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tiện ích mở rộng & Mẫu tin nhanh'**
  String get chatExtensionsAndTemplatesTitle;

  /// No description provided for @chatSelectEmojiTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn biểu tượng cảm xúc'**
  String get chatSelectEmojiTitle;

  /// No description provided for @chatSelectQuickEmojiTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn biểu tượng gửi nhanh'**
  String get chatSelectQuickEmojiTitle;

  /// No description provided for @chatQuickReplyGuest1.
  ///
  /// In vi, this message translates to:
  /// **'Dạ căn còn trống lịch này không ạ?'**
  String get chatQuickReplyGuest1;

  /// No description provided for @chatQuickReplyGuest2.
  ///
  /// In vi, this message translates to:
  /// **'Cho mình hỏi giờ nhận và trả phòng ạ?'**
  String get chatQuickReplyGuest2;

  /// No description provided for @chatQuickReplyGuest3.
  ///
  /// In vi, this message translates to:
  /// **'Biệt thự có sẵn bếp BBQ và hồ bơi riêng không ạ?'**
  String get chatQuickReplyGuest3;

  /// No description provided for @chatQuickReplyGuest4.
  ///
  /// In vi, this message translates to:
  /// **'Cảm ơn Chủ nhà nhiều ạ!'**
  String get chatQuickReplyGuest4;

  /// No description provided for @chatQuickReplyHost1.
  ///
  /// In vi, this message translates to:
  /// **'Dạ vâng, bên em đã nhận thông tin ạ!'**
  String get chatQuickReplyHost1;

  /// No description provided for @chatQuickReplyHost2.
  ///
  /// In vi, this message translates to:
  /// **'Quý khách nhận phòng lúc mấy giờ ạ?'**
  String get chatQuickReplyHost2;

  /// No description provided for @chatQuickReplyHost3.
  ///
  /// In vi, this message translates to:
  /// **'The Palm Villa xin chào bạn! 🌴'**
  String get chatQuickReplyHost3;

  /// No description provided for @chatQuickReplyHost4.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí biệt thự em đã cập nhật trên hệ thống ạ.'**
  String get chatQuickReplyHost4;

  /// No description provided for @chatQuickReplyAdmin1.
  ///
  /// In vi, this message translates to:
  /// **'Chào bạn, Quản trị viên hệ thống hỗ trợ bạn vấn đề gì ạ?'**
  String get chatQuickReplyAdmin1;

  /// No description provided for @chatQuickReplyAdmin2.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống đã tiếp nhận thông tin và đang kiểm tra ạ.'**
  String get chatQuickReplyAdmin2;

  /// No description provided for @chatQuickReplyAdmin3.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ/bài đăng của bạn đã được cập nhật trạng thái.'**
  String get chatQuickReplyAdmin3;

  /// No description provided for @chatQuickReplyAdmin4.
  ///
  /// In vi, this message translates to:
  /// **'Cảm ơn bạn đã phản hồi cho Ban quản trị!'**
  String get chatQuickReplyAdmin4;

  /// No description provided for @chatTplAdminDocsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu bổ sung hồ sơ / giấy tờ'**
  String get chatTplAdminDocsTitle;

  /// No description provided for @chatTplAdminDocsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc Chủ nhà hoặc Khách cập nhật thông tin xác minh'**
  String get chatTplAdminDocsSubtitle;

  /// No description provided for @chatTplAdminDocsContent.
  ///
  /// In vi, this message translates to:
  /// **'📋 Ban quản trị đề nghị bạn kiểm tra và bổ sung giấy tờ xác minh rõ nét để hệ thống hoàn tất phê duyệt.'**
  String get chatTplAdminDocsContent;

  /// No description provided for @chatTplHostLocationTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gửi vị trí chỗ nghỉ'**
  String get chatTplHostLocationTitle;

  /// No description provided for @chatTplHostLocationSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ chi tiết và hướng dẫn di chuyển'**
  String get chatTplHostLocationSubtitle;

  /// No description provided for @chatTplHostLocationContent.
  ///
  /// In vi, this message translates to:
  /// **'📍 Vị trí {villaTitle}: Đường Thùy Vân, TP. Vũng Tàu (gần bãi tắm Bãi Sau).'**
  String chatTplHostLocationContent(String villaTitle);

  /// No description provided for @chatTplGuestInquiryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hỏi lịch trống & báo giá'**
  String get chatTplGuestInquiryTitle;

  /// No description provided for @chatTplGuestInquirySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra tình trạng phòng và phụ thu cuối tuần'**
  String get chatTplGuestInquirySubtitle;

  /// No description provided for @chatTplGuestInquiryContent.
  ///
  /// In vi, this message translates to:
  /// **'📅 Chào Chủ nhà, cho mình hỏi căn còn trống lịch cuối tuần này và giá trọn gói cho đoàn mình nhé ạ?'**
  String get chatTplGuestInquiryContent;

  /// No description provided for @chatTplAdminReviewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo kết quả kiểm duyệt'**
  String get chatTplAdminReviewTitle;

  /// No description provided for @chatTplAdminReviewSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật trạng thái bài đăng hoặc tài khoản'**
  String get chatTplAdminReviewSubtitle;

  /// No description provided for @chatTplAdminReviewContent.
  ///
  /// In vi, this message translates to:
  /// **'✅ Quản trị viên đã kiểm tra và cập nhật trạng thái hồ sơ/bài đăng của bạn trên hệ thống.'**
  String get chatTplAdminReviewContent;

  /// No description provided for @chatTplHostCheckinTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giờ nhận & trả phòng'**
  String get chatTplHostCheckinTitle;

  /// No description provided for @chatTplHostCheckinSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Check-in: 14:00 • Check-out: 12:00'**
  String get chatTplHostCheckinSubtitle;

  /// No description provided for @chatTplHostCheckinContent.
  ///
  /// In vi, this message translates to:
  /// **'⏰ Thời gian nhận phòng: từ 14:00 | Thời gian trả phòng: trước 12:00 ngày hôm sau.'**
  String get chatTplHostCheckinContent;

  /// No description provided for @chatTplGuestCheckinTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xin nhận phòng sớm / trả phòng muộn'**
  String get chatTplGuestCheckinTitle;

  /// No description provided for @chatTplGuestCheckinSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Hỏi hỗ trợ linh hoạt giờ check-in / check-out'**
  String get chatTplGuestCheckinSubtitle;

  /// No description provided for @chatTplGuestCheckinContent.
  ///
  /// In vi, this message translates to:
  /// **'⏰ Đoàn mình dự kiến đến sớm hơn 14:00 một chút, Chủ nhà có thể hỗ trợ gửi hành lý hoặc nhận phòng sớm không ạ?'**
  String get chatTplGuestCheckinContent;

  /// No description provided for @chatTplAdminPolicyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn chính sách nền tảng'**
  String get chatTplAdminPolicyTitle;

  /// No description provided for @chatTplAdminPolicySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Giải đáp quy định đặt phòng & phí dịch vụ'**
  String get chatTplAdminPolicySubtitle;

  /// No description provided for @chatTplAdminPolicyContent.
  ///
  /// In vi, this message translates to:
  /// **'ℹ️ Mọi giao dịch trên hệ thống đều được bảo vệ theo chính sách đặt phòng và hoàn hủy minh bạch của The Palm Villa.'**
  String get chatTplAdminPolicyContent;

  /// No description provided for @chatTplHostHouseRulesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gửi nội quy lưu trú'**
  String get chatTplHostHouseRulesTitle;

  /// No description provided for @chatTplHostHouseRulesSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Giữ gìn vệ sinh, yên tĩnh sau 22:00'**
  String get chatTplHostHouseRulesSubtitle;

  /// No description provided for @chatTplHostHouseRulesContent.
  ///
  /// In vi, this message translates to:
  /// **'📋 Nội quy lưu trú: Vui lòng giữ gìn tài sản chung và hạn chế tiếng ồn lớn sau 22:00. Chúc quý khách kỳ nghỉ tuyệt vời!'**
  String get chatTplHostHouseRulesContent;

  /// No description provided for @chatTplGuestAmenitiesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hỏi tiện ích BBQ & hồ bơi'**
  String get chatTplGuestAmenitiesTitle;

  /// No description provided for @chatTplGuestAmenitiesSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Bếp nướng, than, phao bơi và chỗ đậu xe'**
  String get chatTplGuestAmenitiesSubtitle;

  /// No description provided for @chatTplGuestAmenitiesContent.
  ///
  /// In vi, this message translates to:
  /// **'🔥 Biệt thự có sẵn lò nướng BBQ, dụng cụ bếp, hồ bơi riêng và chỗ đậu ô tô trong sân không ạ?'**
  String get chatTplGuestAmenitiesContent;

  /// No description provided for @chatToastUploadingPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải ảnh lên Cloudflare R2...'**
  String get chatToastUploadingPhoto;

  /// No description provided for @chatToastUploadPhotoFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tải ảnh lên R2 thất bại'**
  String get chatToastUploadPhotoFailed;

  /// No description provided for @chatToastUploadingVoice.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải tin nhắn thoại lên Cloudflare R2...'**
  String get chatToastUploadingVoice;

  /// No description provided for @chatToastUploadVoiceFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tải âm thanh lên R2 thất bại'**
  String get chatToastUploadVoiceFailed;

  /// No description provided for @chatToastMicNoAudio.
  ///
  /// In vi, this message translates to:
  /// **'Không ghi nhận được âm thanh từ Micro. Vui lòng cấp quyền Microphone hoặc nói to hơn.'**
  String get chatToastMicNoAudio;

  /// No description provided for @chatToastMicAccessError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể truy cập Micro. Vui lòng cấp quyền Microphone trên trình duyệt / thiết bị.'**
  String get chatToastMicAccessError;

  /// No description provided for @chatErrorNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Mất kết nối mạng'**
  String get chatErrorNetwork;

  /// No description provided for @chatErrorForbidden.
  ///
  /// In vi, this message translates to:
  /// **'Không có quyền truy cập'**
  String get chatErrorForbidden;

  /// No description provided for @chatErrorUnauthorized.
  ///
  /// In vi, this message translates to:
  /// **'Phiên đăng nhập hết hạn'**
  String get chatErrorUnauthorized;

  /// No description provided for @chatErrorNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy cuộc trò chuyện'**
  String get chatErrorNotFound;

  /// No description provided for @chatErrorRateLimit.
  ///
  /// In vi, this message translates to:
  /// **'Thao tác quá nhanh'**
  String get chatErrorRateLimit;

  /// No description provided for @chatErrorServer.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi máy chủ'**
  String get chatErrorServer;

  /// No description provided for @chatErrorValidation.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu không hợp lệ'**
  String get chatErrorValidation;

  /// No description provided for @chatErrorGeneric.
  ///
  /// In vi, this message translates to:
  /// **'Đã có lỗi xảy ra'**
  String get chatErrorGeneric;

  /// No description provided for @hostMsgBackToVilla.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại trang biệt thự'**
  String get hostMsgBackToVilla;

  /// No description provided for @hostMsgContactTitle.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ Chủ nhà'**
  String get hostMsgContactTitle;

  /// No description provided for @hostMsgHostLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà: {name}'**
  String hostMsgHostLabel(String name);

  /// No description provided for @hostMsgDefaultHost.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà The Palm Villa'**
  String get hostMsgDefaultHost;

  /// No description provided for @hostMsgFaqTitle.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi thường gặp cho Chủ nhà:'**
  String get hostMsgFaqTitle;

  /// No description provided for @hostMsgInputLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung tin nhắn gửi Chủ nhà '**
  String get hostMsgInputLabel;

  /// No description provided for @hostMsgInputPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'Nhập câu hỏi của bạn về lịch trống, tiện nghi hoặc yêu cầu đặc biệt...'**
  String get hostMsgInputPlaceholder;

  /// No description provided for @hostMsgSendAction.
  ///
  /// In vi, this message translates to:
  /// **'Gửi tin nhắn & Mở phòng chat'**
  String get hostMsgSendAction;

  /// No description provided for @hostMsgSendingAction.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi tin nhắn...'**
  String get hostMsgSendingAction;

  /// No description provided for @hostMsgQuestion1.
  ///
  /// In vi, this message translates to:
  /// **'Chào Chủ nhà, biệt thự còn trống lịch cuối tuần này không ạ?'**
  String get hostMsgQuestion1;

  /// No description provided for @hostMsgQuestion2.
  ///
  /// In vi, this message translates to:
  /// **'Hồ bơi của biệt thự là nước ngọt hay nước mặn và có phao bơi không ạ?'**
  String get hostMsgQuestion2;

  /// No description provided for @hostMsgQuestion3.
  ///
  /// In vi, this message translates to:
  /// **'Biệt thự có sẵn lò nướng BBQ, than và dụng cụ bếp đầy đủ không ạ?'**
  String get hostMsgQuestion3;

  /// No description provided for @hostMsgQuestion4.
  ///
  /// In vi, this message translates to:
  /// **'Đoàn mình muốn nhận phòng sớm hơn 14:00 có được hỗ trợ không ạ?'**
  String get hostMsgQuestion4;

  /// No description provided for @galleryPhotoCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} ảnh'**
  String galleryPhotoCount(int count);

  /// No description provided for @galleryViewAllPhotosSemantic.
  ///
  /// In vi, this message translates to:
  /// **'Xem toàn bộ ảnh'**
  String get galleryViewAllPhotosSemantic;

  /// No description provided for @gallerySpacePrefix.
  ///
  /// In vi, this message translates to:
  /// **'Không gian: {type}'**
  String gallerySpacePrefix(String type);

  /// No description provided for @spaceBedroom.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ngủ'**
  String get spaceBedroom;

  /// No description provided for @spaceLivingRoom.
  ///
  /// In vi, this message translates to:
  /// **'Phòng khách'**
  String get spaceLivingRoom;

  /// No description provided for @spaceKitchen.
  ///
  /// In vi, this message translates to:
  /// **'Phòng bếp'**
  String get spaceKitchen;

  /// No description provided for @spaceBathroom.
  ///
  /// In vi, this message translates to:
  /// **'Phòng tắm'**
  String get spaceBathroom;

  /// No description provided for @spacePool.
  ///
  /// In vi, this message translates to:
  /// **'Hồ bơi'**
  String get spacePool;

  /// No description provided for @spaceExterior.
  ///
  /// In vi, this message translates to:
  /// **'Ngoại thất'**
  String get spaceExterior;

  /// No description provided for @spaceView.
  ///
  /// In vi, this message translates to:
  /// **'Tầm nhìn'**
  String get spaceView;

  /// No description provided for @spaceDining.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ăn'**
  String get spaceDining;

  /// No description provided for @spaceOther.
  ///
  /// In vi, this message translates to:
  /// **'Không gian khác'**
  String get spaceOther;
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
