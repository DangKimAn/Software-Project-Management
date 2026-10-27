// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Minh Thanh Villa';

  @override
  String get appTagline => 'Biệt thự nghỉ dưỡng cao cấp Vũng Tàu';

  @override
  String get greetingMorning => 'Chào buổi sáng!';

  @override
  String get greetingAfternoon => 'Chào buổi chiều!';

  @override
  String get greetingEvening => 'Chào buổi tối!';

  @override
  String get homeWelcomeSubtitle =>
      'Trân trọng được chào đón bạn tại thành phố biển Vũng Tàu';

  @override
  String get homeRecentlyViewedTitle => 'Đã xem gần đây';

  @override
  String get homePopularDestinationsTitle => 'Điểm đến phổ biến tại Vũng Tàu';

  @override
  String get homeApprovedListingsTitle => 'Danh sách chỗ nghỉ đã duyệt';

  @override
  String get homeSeeMoreVillas => 'Xem thêm villa';

  @override
  String get homeSeeNext => 'Xem tiếp';

  @override
  String get homeShowLess => 'Thu gọn';

  @override
  String get homeBlogBadge => 'BÀI VIẾT MỚI';

  @override
  String get homeBlogTitle => 'Kinh nghiệm lưu trú nổi bật';

  @override
  String get homeBlogSubtitle =>
      'Nội dung tập trung vào nhu cầu thực tế khi đặt villa tại Vũng Tàu, từ nhóm gia đình đến nhóm bạn đông người.';

  @override
  String get homeBlogSeeAll => 'Xem tất cả bài viết';

  @override
  String get searchPlaceholder => 'Bắt đầu tìm kiếm...';

  @override
  String get searchDestinationLabel => 'Địa điểm';

  @override
  String get searchDestinationHint => 'Bạn muốn nghỉ dưỡng ở đâu tại Vũng Tàu?';

  @override
  String get searchModeDates => 'Theo ngày';

  @override
  String get searchModeMonths => 'Theo tháng';

  @override
  String get searchModeFlexible => 'Linh hoạt';

  @override
  String get searchFlexibleWeekend => 'Cuối tuần';

  @override
  String get searchFlexibleWeek => '1 tuần';

  @override
  String get searchFlexibleMonth => '1 tháng';

  @override
  String get searchExactDates => 'Chính xác ngày';

  @override
  String searchPlusMinusDays(int days) {
    return '± $days ngày';
  }

  @override
  String get searchAdults => 'Người lớn';

  @override
  String get searchAdultsDesc => 'Từ 13 tuổi trở lên';

  @override
  String get searchChildren => 'Trẻ em';

  @override
  String get searchChildrenDesc => 'Độ tuổi 2 – 12';

  @override
  String get searchInfants => 'Em bé';

  @override
  String get searchInfantsDesc => 'Dưới 2 tuổi';

  @override
  String get searchPets => 'Thú cưng';

  @override
  String get searchPetsDesc => 'Mang theo thú cưng';

  @override
  String get searchFilterTitle => 'Bộ lọc nâng cao';

  @override
  String get searchSortNewest => 'Mới nhất';

  @override
  String get searchSortPriceAsc => 'Giá thấp đến cao';

  @override
  String get searchSortPriceDesc => 'Giá cao đến thấp';

  @override
  String get searchSortRatingDesc => 'Đánh giá cao nhất';

  @override
  String get aiSearchTitle => 'Tìm kiếm thông minh bằng AI';

  @override
  String get aiSearchPlaceholder =>
      'Mô tả kỳ nghỉ mong muốn (VD: Villa sát biển Bãi Sau cho 15 người có hồ bơi nước mặn, BBQ)...';

  @override
  String get aiSearchAction => 'Tìm bằng AI';

  @override
  String get navDiscover => 'Khám phá';

  @override
  String get navZalo => 'Zalo';

  @override
  String get navHotline => 'Hotline';

  @override
  String get navFavorites => 'Yêu thích';

  @override
  String get navTrips => 'Chuyến đi';

  @override
  String get navAccount => 'Tài khoản';

  @override
  String get navSettings => 'Cài đặt';

  @override
  String get navStays => 'Nơi lưu trú';

  @override
  String get navBlog => 'Cẩm nang';

  @override
  String get navContact => 'Liên hệ';

  @override
  String get navMessages => 'Tin nhắn';

  @override
  String get navNotifications => 'Thông báo';

  @override
  String get navBookingQueue => 'Giỏ chờ đặt';

  @override
  String get navBecomeHost => 'Trở thành Host';

  @override
  String get navHostPortal => 'Kênh Chủ nhà';

  @override
  String get navAdminPortal => 'Quản trị hệ thống';

  @override
  String bedroomsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phòng',
      one: '1 phòng',
    );
    return '$_temp0';
  }

  @override
  String bedsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giường',
      one: '1 giường',
    );
    return '$_temp0';
  }

  @override
  String guestsCapacity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count khách',
      one: '1 khách',
    );
    return '$_temp0';
  }

  @override
  String guestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count khách',
      one: '1 khách',
    );
    return '$_temp0';
  }

  @override
  String adultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count người lớn',
      one: '1 người lớn',
    );
    return '$_temp0';
  }

  @override
  String childrenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trẻ em',
      one: '1 trẻ em',
    );
    return '$_temp0';
  }

  @override
  String infantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count em bé',
      one: '1 em bé',
    );
    return '$_temp0';
  }

  @override
  String petsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count thú cưng',
      one: '1 thú cưng',
    );
    return '$_temp0';
  }

  @override
  String bathroomsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count WC',
      one: '1 WC',
    );
    return '$_temp0';
  }

  @override
  String nightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count đêm',
      one: '1 đêm',
    );
    return '$_temp0';
  }

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count đánh giá',
      one: '1 đánh giá',
      zero: 'Chưa có đánh giá',
    );
    return '$_temp0';
  }

  @override
  String beachDistance(int distance) {
    return '${distance}m tới biển';
  }

  @override
  String priceFrom(String price) {
    return 'Từ $price / đêm';
  }

  @override
  String get pricePerNightUnit => '/ đêm';

  @override
  String saturdayPrice(String price) {
    return 'Thứ 7: $price';
  }

  @override
  String totalNightsWithFee(int nights) {
    String _temp0 = intl.Intl.pluralLogic(
      nights,
      locale: localeName,
      other: 'Tổng $nights đêm • Đã gồm phí',
      one: 'Tổng 1 đêm • Đã gồm phí',
    );
    return '$_temp0';
  }

  @override
  String get contactForPrice => 'Liên hệ báo giá';

  @override
  String get statusAvailable => 'Còn trống';

  @override
  String get statusBooked => 'Đã kín phòng';

  @override
  String get badgeFeatured => 'Nổi bật';

  @override
  String get badgeNew => 'Mới';

  @override
  String get badgeNearBeach => 'Gần biển';

  @override
  String get badgeSaltwater => 'Hồ bơi nước mặn';

  @override
  String get badgeGroup => 'Đoàn đông';

  @override
  String get ctaContactZalo => 'Nhắn tin Zalo';

  @override
  String get ctaCallHotline => 'Gọi Hotline';

  @override
  String get ctaBookNow => 'Tư vấn đặt phòng';

  @override
  String get ctaBookInstant => 'Đặt phòng ngay';

  @override
  String get ctaRequestBooking => 'Gửi yêu cầu đặt';

  @override
  String get ctaAddToQueue => 'Thêm vào giỏ chờ đặt';

  @override
  String get ctaViewDetail => 'Xem chi tiết';

  @override
  String get ctaCopyLink => 'Sao chép liên kết';

  @override
  String get ctaCopied => 'Đã sao chép liên kết vào bộ nhớ tạm';

  @override
  String get ctaZaloCopied => 'Đã sao chép nội dung tư vấn và mở Zalo';

  @override
  String get ctaRetry => 'Thử lại';

  @override
  String get ctaResetFilter => 'Đặt lại bộ lọc';

  @override
  String get ctaBack => 'Quay lại';

  @override
  String get ctaBackHome => 'Về trang chủ';

  @override
  String get ctaClose => 'Đóng';

  @override
  String get ctaCancel => 'Hủy';

  @override
  String get ctaConfirm => 'Xác nhận';

  @override
  String get ctaSave => 'Lưu thay đổi';

  @override
  String get ctaPrevPage => 'Trang trước';

  @override
  String get ctaNextPage => 'Trang sau';

  @override
  String paginationPageOf(int page, int totalPages) {
    return 'Trang $page / $totalPages';
  }

  @override
  String get loadingText => 'Đang tải dữ liệu...';

  @override
  String get loadingVillas => 'Đang tải chỗ nghỉ...';

  @override
  String get loadingVillaDetail => 'Đang tải thông tin chi tiết biệt thự...';

  @override
  String get loadingFavorites => 'Đang tải danh sách yêu thích...';

  @override
  String get emptyList => 'Không tìm thấy villa nào phù hợp';

  @override
  String get emptyListDesc =>
      'Hãy thử thay đổi tiêu chí tìm kiếm hoặc khoảng thời gian lưu trú.';

  @override
  String get errorOccurred => 'Đã có lỗi xảy ra';

  @override
  String get errorTryAgain =>
      'Không thể hoàn tất yêu cầu lúc này. Vui lòng thử lại.';

  @override
  String get errorOfflineTitle => 'Không có kết nối mạng';

  @override
  String get errorOfflineMessage =>
      'Không có kết nối mạng hoặc mạng không ổn định. Vui lòng kiểm tra kết nối và thử lại.';

  @override
  String get errorServerTitle => 'Lỗi máy chủ';

  @override
  String get errorServerMessage =>
      'Máy chủ đang bận hoặc gặp sự cố tạm thời. Vui lòng thử lại sau.';

  @override
  String get errorUnauthorizedMessage =>
      'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.';

  @override
  String get errorForbiddenMessage =>
      'Bạn không có quyền truy cập chức năng này.';

  @override
  String get errorNotFoundTitle => '404 — Không tìm thấy trang';

  @override
  String get errorNotFoundMessage =>
      'Đường dẫn bạn truy cập không tồn tại hoặc đã được di chuyển.';

  @override
  String get errorVillaNotFoundTitle => 'Không tìm thấy biệt thự';

  @override
  String get errorVillaNotFoundMessage =>
      'Biệt thự bạn tìm kiếm không tồn tại hoặc đã ngừng phục vụ.';

  @override
  String get errorRateLimitMessage =>
      'Bạn đã thao tác quá nhanh. Vui lòng thử lại sau ít phút.';

  @override
  String get errorValidationMessage =>
      'Thông tin gửi lên không hợp lệ. Vui lòng kiểm tra lại.';

  @override
  String get dateBooked => 'Ngày này đã kín';

  @override
  String get checkInDate => 'Nhận phòng';

  @override
  String get checkOutDate => 'Trả phòng';

  @override
  String get guestCount => 'Số khách';

  @override
  String get priceBreakdown => 'Chi tiết giá theo đêm';

  @override
  String get dailyPriceBreakdownTitle => 'Bảng giá theo từng đêm';

  @override
  String get specCapacityLabel => 'Sức chứa';

  @override
  String get specBedroomsLabel => 'Phòng ngủ';

  @override
  String get specBedsLabel => 'Giường';

  @override
  String get specBathroomsLabel => 'Phòng tắm';

  @override
  String get specHighlightsTitle => 'Tiện ích nổi bật & Vị trí';

  @override
  String get specExpandAction => 'Xem thêm thông số chi tiết';

  @override
  String get specCollapseAction => 'Thu gọn thông số';

  @override
  String get specPrivatePool => 'Hồ bơi riêng';

  @override
  String get specNoPool => 'Không có hồ bơi';

  @override
  String get specBbqKitchen => 'Bếp & Lò BBQ đầy đủ';

  @override
  String get specBasicKitchen => 'Bếp cơ bản';

  @override
  String get specParking => 'Chỗ đậu xe ô tô';

  @override
  String get specSelfParking => 'Đậu xe tự túc';

  @override
  String get specNearCenter => 'Gần trung tâm';

  @override
  String get hostDefaultName => 'Chủ nhà VungTauStay';

  @override
  String get hostDefaultBio =>
      'Chủ nhà tại Vũng Tàu, hỗ trợ thông tin lưu trú và nhận phòng.';

  @override
  String get bookingInstantConfirm => 'Đặt phòng xác nhận ngay';

  @override
  String get bookingSupport247 => 'Tư vấn & Đặt phòng 24/7';

  @override
  String get faqTitle => 'Câu hỏi thường gặp';

  @override
  String get rulesAndFaqTitle => 'Quy định & Câu hỏi thường gặp';

  @override
  String get faqCheckInTitle => 'Thời gian nhận và trả villa như thế nào?';

  @override
  String get faqCheckInBody =>
      'Giờ nhận villa tiêu chuẩn từ 14:00 chiều và giờ trả trước 12:00 trưa hôm sau. Quý khách có nhu cầu nhận sớm hoặc trả muộn vui lòng thông báo trước để được hỗ trợ tùy theo tình trạng phòng trống.';

  @override
  String get faqNoiseTitle => 'Quy định về tiếng ồn và sử dụng karaoke?';

  @override
  String get faqNoiseBody =>
      'Theo quy định trật tự đô thị tại Vũng Tàu, dàn karaoke và âm thanh ngoài trời hoạt động đến 22:00 tối. Sau 22:00, quý khách vui lòng sinh hoạt văn minh trong không gian phòng kín để không ảnh hưởng các biệt thự lân cận.';

  @override
  String get faqKitchenTitle =>
      'Biệt thự có trang bị đầy đủ gia vị và đồ dùng nấu ăn không?';

  @override
  String get faqKitchenBody =>
      'Khu vực bếp và lò nướng BBQ được trang bị sẵn chén bát, đũa muỗng, nồi niêu xoong chảo, bếp từ/gas và vỉ nướng. Quý khách chỉ cần chuẩn bị thực phẩm tươi sống và than nướng theo sở thích.';

  @override
  String get faqDepositTitle => 'Chính sách đặt cọc và hủy phòng?';

  @override
  String get faqDepositBody =>
      'Để giữ lịch villa, quý khách vui lòng đặt cọc 50% giá trị hợp đồng. Số tiền còn lại thanh toán khi nhận bàn giao villa. Chính sách dời ngày linh hoạt khi thông báo trước ít nhất 7 ngày.';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get settingsEnvironment => 'Môi trường';

  @override
  String get settingsVersion => 'Phiên bản';

  @override
  String get favoritesEmpty => 'Chưa có villa nào được lưu';

  @override
  String get favoritesEmptyDesc =>
      'Bấm vào biểu tượng trái tim ở góc thẻ villa để lưu vào danh sách yêu thích.';

  @override
  String get bookingStatusPendingPayment => 'Chờ thanh toán';

  @override
  String get bookingStatusPaymentExpired => 'Quá hạn thanh toán';

  @override
  String get bookingStatusPaid => 'Đã thanh toán';

  @override
  String get bookingStatusConfirmed => 'Đã xác nhận';

  @override
  String get bookingStatusCheckedIn => 'Đang lưu trú';

  @override
  String get bookingStatusCheckedOut => 'Đã trả phòng';

  @override
  String get bookingStatusCompleted => 'Đã hoàn thành';

  @override
  String get bookingStatusCancelledByGuest => 'Khách đã hủy';

  @override
  String get bookingStatusCancelledByHost => 'Host đã hủy';

  @override
  String get bookingStatusCancelledByAdmin => 'Admin đã hủy';

  @override
  String get bookingStatusRejected => 'Từ chối';

  @override
  String get bookingStatusRefundPending => 'Đang hoàn tiền';

  @override
  String get bookingStatusRefunded => 'Đã hoàn tiền';

  @override
  String get paymentUnverifiedTitle => 'Chưa xác nhận được giao dịch';

  @override
  String get paymentUnverifiedDesc =>
      'Tạm thời chưa thể xác minh trạng thái giao dịch với máy chủ. Vui lòng kiểm tra kết nối mạng và thử xác minh lại.';

  @override
  String get paymentRecheckStatus => 'Kiểm tra lại trạng thái';

  @override
  String get authLoginTitle => 'Đăng nhập';

  @override
  String get authRegisterTitle => 'Đăng ký tài khoản';

  @override
  String get authForgotPasswordTitle => 'Quên mật khẩu';

  @override
  String get authGoogleSignIn => 'Tiếp tục với Google';

  @override
  String get authLogout => 'Đăng xuất';

  @override
  String get profileVerified => 'Đã xác minh';

  @override
  String get profileUnverified => 'Chưa xác minh';

  @override
  String get hostOnboardingTitle => 'Trở thành Chủ nhà tại Minh Thanh Villa';

  @override
  String get hostKycTitle => 'Đăng ký & Xác minh Hồ sơ Chủ nhà';

  @override
  String get hostKycStatusTitle => 'Trạng thái xét duyệt Hồ sơ Chủ nhà';

  @override
  String get hostTabOverview => 'Tổng quan';

  @override
  String get hostTabProperties => 'Chỗ nghỉ';

  @override
  String get hostTabNewProperty => 'Thêm chỗ nghỉ';

  @override
  String get hostTabBookings => 'Đặt phòng';

  @override
  String get hostTabCalendar => 'Lịch lưu trú';

  @override
  String get hostTabGuests => 'Khách lưu trú';

  @override
  String get hostTabMessages => 'Tin nhắn';

  @override
  String get hostTabPayouts => 'Thanh toán';

  @override
  String get hostTabReviews => 'Đánh giá';

  @override
  String get hostTabReports => 'Báo cáo';

  @override
  String get hostTabSupport => 'Hỗ trợ';

  @override
  String get hostTabSettings => 'Cài đặt';

  @override
  String get hostListingDraft => 'Bản nháp';

  @override
  String get hostListingPendingApproval => 'Chờ duyệt';

  @override
  String get hostListingPublished => 'Đang hiển thị';

  @override
  String get hostListingHidden => 'Đang ẩn';

  @override
  String get hostListingRejected => 'Từ chối duyệt';

  @override
  String get adminTabOverview => 'Tổng quan';

  @override
  String get adminTabUsers => 'Người dùng';

  @override
  String get adminTabModeration => 'Kiểm duyệt bài đăng';

  @override
  String get adminTabHostApplications => 'Duyệt hồ sơ Host';

  @override
  String get adminTabRoles => 'Phân quyền hệ thống';

  @override
  String get adminUserStatusActive => 'Hoạt động';

  @override
  String get adminUserStatusSuspended => 'Đang khóa';

  @override
  String get adminUserStatusInactive => 'Ngừng hoạt động';
}
