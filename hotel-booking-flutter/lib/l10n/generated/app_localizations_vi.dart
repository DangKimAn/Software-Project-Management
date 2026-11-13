// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'The Palm Villa';

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
  String get calendarPrevMonth => 'Tháng trước';

  @override
  String get calendarNextMonth => 'Tháng sau';

  @override
  String calendarDay(int day) {
    return 'Ngày $day';
  }

  @override
  String calendarDayBooked(int day) {
    return 'Ngày $day đã kín';
  }

  @override
  String calendarDayCheckOutOnly(int day) {
    return 'Ngày $day chỉ trả phòng';
  }

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
  String get hostOnboardingTitle => 'Trở thành Chủ nhà tại The Palm';

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

  @override
  String get settingsCurrency => 'Tiền tệ hiển thị';

  @override
  String get currencyFollowLanguage => 'Theo ngôn ngữ';

  @override
  String get currencyFollowLanguageDesc =>
      'Tự động chuyển đổi theo ngôn ngữ giao diện';

  @override
  String get currencyNameVnd => 'Đồng Việt Nam (VND - ₫)';

  @override
  String get currencyNameUsd => 'Đô la Mỹ (USD - \$)';

  @override
  String get currencyNameKrw => 'Won Hàn Quốc (KRW - ₩)';

  @override
  String fxEstimatedPrice(String amount) {
    return 'Giá tham khảo: ≈ $amount';
  }

  @override
  String fxTotalPayableVnd(String amountVnd) {
    return 'Tổng thanh toán thực tế: $amountVnd';
  }

  @override
  String get fxChargedInVndNotice => 'Thanh toán thực tế bằng VND.';

  @override
  String fxReferenceRateLabel(String source) {
    return 'Tỷ giá tham khảo ($source)';
  }

  @override
  String fxRateUpdatedAt(String time) {
    return 'Tỷ giá cập nhật: $time';
  }

  @override
  String get fxRateUnavailableFallback =>
      'Chưa tải được tỷ giá ngoại tệ. Đang hiển thị giá chính thức bằng VND.';

  @override
  String fxRateStaleNotice(String time) {
    return 'Đang sử dụng tỷ giá cập nhật gần nhất ($time).';
  }

  @override
  String get fxBankConversionFeeNotice =>
      'Ngân hàng phát hành thẻ có thể áp dụng tỷ giá và phí chuyển đổi riêng.';

  @override
  String get fxPaymentMethodUnsupported =>
      'Phương thức thanh toán này hiện chưa được hỗ trợ.';

  @override
  String get fxRefundInVndNotice =>
      'Hoàn tiền thực tế bằng VND. Số tiền ngoại tệ trên sao kê có thể khác do tỷ giá ngân hàng tại thời điểm hoàn.';

  @override
  String get fxHistoricalReferenceNote =>
      'Giá quy đổi chỉ để tham khảo, không phải số tiền thực tế trên sao kê thanh toán.';

  @override
  String fxPayButtonVnd(String amountVnd, String method) {
    return 'Thanh toán $amountVnd qua $method';
  }

  @override
  String get fxPriceRangePerNight => 'Khoảng giá mỗi đêm';

  @override
  String get vnpayGatewayTitle => 'VNPay (QR Pay / Thẻ ATM nội địa)';

  @override
  String get vnpayGatewaySubtitle =>
      'Xác nhận thanh toán VND qua cổng bảo mật VNPay';

  @override
  String get momoGatewayTitle => 'Ví điện tử MoMo';

  @override
  String get momoGatewaySubtitle =>
      'Thanh toán VND qua ứng dụng MoMo hoặc quét mã QR MoMo';

  @override
  String get footerSupport => 'Hỗ trợ';

  @override
  String get footerBookingGuide => 'Hướng dẫn đặt phòng';

  @override
  String get footerCancellationPolicy => 'Chính sách hủy phòng';

  @override
  String get footerFeedback => 'Khiếu nại & Góp ý';

  @override
  String get footerFaq => 'Câu hỏi thường gặp (FAQ)';

  @override
  String get footerDiscover => 'Khám phá Vũng Tàu';

  @override
  String get footerAboutUs => 'Về chúng tôi';

  @override
  String get footerTravelGuide => 'Cẩm nang du lịch';

  @override
  String get footerAddonServices => 'Dịch vụ đi kèm';

  @override
  String get footerMemberOffers => 'Ưu đãi thành viên';

  @override
  String get footerContact => 'Liên hệ';

  @override
  String get footerOnlineConsultation => 'Liên hệ tư vấn trực tuyến';

  @override
  String footerHotline(String phone) {
    return 'Hotline: $phone';
  }

  @override
  String get footerAddress => 'Địa chỉ: 28 Thi Sách';

  @override
  String footerEmail(String email) {
    return 'Email: $email';
  }

  @override
  String get footerSocial => 'Mạng xã hội';

  @override
  String get footerCopyright => '© Bản quyền thuộc về Villa Vũng Tàu 2026';

  @override
  String get settingsAvatarUpdateTitle => 'Cập nhật ảnh đại diện';

  @override
  String get settingsAvatarUpdateHint =>
      'Chọn ảnh định dạng JPG, PNG, WebP hoặc GIF từ máy của bạn (dung lượng tối đa 5MB).';

  @override
  String get settingsAvatarPickFromDevice =>
      'Chọn ảnh từ thiết bị (Tối đa 5MB)';

  @override
  String get settingsAvatarUploading => 'Đang tải ảnh lên...';

  @override
  String settingsAvatarSelected(String fileName, String sizeKb) {
    return 'Đã chọn: $fileName ($sizeKb KB)';
  }

  @override
  String get settingsAvatarPickError =>
      'Không thể chọn ảnh từ thiết bị. Vui lòng thử lại.';

  @override
  String get settingsAvatarUpdateSuccess =>
      'Đã cập nhật ảnh đại diện thành công.';

  @override
  String get settingsChangeAvatarTooltip => 'Đổi ảnh';

  @override
  String get settingsEditProfileTooltip => 'Sửa hồ sơ';

  @override
  String get settingsEditProfileTitle => 'Chỉnh sửa hồ sơ cá nhân';

  @override
  String get settingsAvatarSectionTitle => 'Ảnh đại diện';

  @override
  String get settingsAvatarPickFromDeviceShort => 'Chọn ảnh từ máy';

  @override
  String get settingsAvatarUploadingShort => 'Đang tải...';

  @override
  String get settingsAvatarPickHint => 'Chọn ảnh từ thiết bị (tối đa 5MB)';

  @override
  String settingsAvatarSelectedShort(String fileName) {
    return 'Đã chọn: $fileName';
  }

  @override
  String get settingsFullNameLabel => 'Họ và tên *';

  @override
  String get settingsFullNameHint => 'Nhập họ và tên đầy đủ';

  @override
  String get settingsPhoneLabel => 'Số điện thoại';

  @override
  String get settingsPhoneHint => '0912345678 hoặc +84912345678';

  @override
  String get settingsLocationLabel => 'Nơi sinh sống';

  @override
  String get settingsLocationHint => 'Ví dụ: Vũng Tàu, Việt Nam';

  @override
  String get settingsDreamDestinationLabel => 'Nơi tôi luôn muốn đến';

  @override
  String get settingsDreamDestinationHint => 'Nhập điểm đến yêu thích của bạn';

  @override
  String get settingsJobLabel => 'Công việc / Nghề nghiệp';

  @override
  String get settingsJobHint => 'Nhập công việc hiện tại';

  @override
  String get settingsSchoolLabel => 'Trường học';

  @override
  String get settingsSchoolHint => 'Nơi bạn từng theo học';

  @override
  String get settingsLanguagesLabel => 'Ngôn ngữ giao tiếp';

  @override
  String get settingsLanguagesHint =>
      'Tiếng Việt, English (phân cách bằng dấu phẩy)';

  @override
  String get settingsBioLabel => 'Giới thiệu bản thân';

  @override
  String get settingsBioHint => 'Chia sẻ đôi nét về bản thân...';

  @override
  String get settingsSaving => 'Đang lưu...';

  @override
  String get settingsProfileUpdateSuccess => 'Đã cập nhật hồ sơ thành công.';

  @override
  String get settingsUnsavedDraftBanner =>
      'Bạn có bản nháp hồ sơ chưa lưu thành công.';

  @override
  String get settingsResumeEditing => 'Tiếp tục sửa';

  @override
  String get settingsConfirmPhoneTitle => 'Xác nhận thay đổi số điện thoại';

  @override
  String settingsConfirmPhoneRemove(String oldPhone) {
    return 'Bạn sắp xóa số điện thoại liên hệ đã lưu ($oldPhone). Bạn có chắc chắn muốn tiếp tục?';
  }

  @override
  String settingsConfirmPhoneChange(String oldPhone, String newPhone) {
    return 'Bạn sắp thay đổi số điện thoại liên hệ từ $oldPhone sang $newPhone. Bạn có chắc chắn muốn lưu thay đổi này?';
  }

  @override
  String get settingsConfirmPhoneReview => 'Kiểm tra lại';

  @override
  String get settingsConfirmPhoneSave => 'Xác nhận lưu';

  @override
  String get settingsConfirmLogoutTitle => 'Xác nhận đăng xuất';

  @override
  String get settingsConfirmLogoutDraft =>
      'Bạn đang có bản nháp chỉnh sửa hồ sơ chưa lưu. Đăng xuất sẽ xóa dữ liệu nháp tạm thời trên phiên này. Bạn có chắc chắn muốn đăng xuất?';

  @override
  String get settingsConfirmLogout =>
      'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này không?';

  @override
  String get settingsRoleAdmin => 'Quản trị viên (Admin)';

  @override
  String get settingsRoleHost => 'Chủ nhà (Host)';

  @override
  String get settingsRoleHostPending => 'Hồ sơ Chủ nhà đang chờ duyệt';

  @override
  String get settingsRoleGuest => 'Khách lưu trú';

  @override
  String get settingsLoadingAccount => 'Đang tải thông tin tài khoản...';

  @override
  String get settingsNotLoggedIn => 'Chưa đăng nhập';

  @override
  String get settingsLoginPrompt =>
      'Đăng nhập để xem kỳ nghỉ, tin nhắn và đồng bộ yêu thích';

  @override
  String get settingsSignInSignUp => 'Đăng nhập / Đăng ký';

  @override
  String get settingsReLogin => 'Đăng nhập lại';

  @override
  String get settingsContactSupportCenter => 'Trung tâm Liên hệ & Hỗ trợ';

  @override
  String get settingsCallHotline => 'Gọi tổng đài tư vấn';

  @override
  String get settingsZaloSupport => 'Nhắn tin qua Zalo OA';

  @override
  String get settingsZaloInquiryDefaultMessage =>
      'Xin chào The Palm, tôi cần hỗ trợ thông tin ứng dụng.';

  @override
  String get settingsManageProperties => 'Quản lý chỗ nghỉ';

  @override
  String get settingsMyTrips => 'Chuyến đi của tôi';

  @override
  String get settingsMyFavorites => 'Danh sách yêu thích';

  @override
  String get settingsMessagesWithHost => 'Tin nhắn với Chủ nhà';

  @override
  String get settingsStatusOfflineTitle => 'Thiết bị đang ngoại tuyến';

  @override
  String get settingsStatusUnauthorizedTitle =>
      'Phiên đăng nhập hết hạn hoặc bị từ chối';

  @override
  String get settingsStatusServerErrorTitle =>
      'Không thể đồng bộ dữ liệu máy chủ';

  @override
  String get settingsStatusOfflineMessage =>
      'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.';

  @override
  String get settingsStatusUnauthorizedMessage =>
      'Phiên đăng nhập không hợp lệ hoặc bạn không có quyền truy cập (401/403).';

  @override
  String get settingsStatusServerErrorMessage =>
      'Máy chủ đang gặp sự cố tạm thời. Vui lòng thử lại sau.';

  @override
  String villaDetailViewAllPhotos(int count) {
    return 'Xem tất cả $count ảnh';
  }

  @override
  String get villaDetailShareCopied => 'Đã sao chép liên kết vào bộ nhớ tạm';

  @override
  String get villaDetailAboutTitle => 'Giới thiệu biệt thự';

  @override
  String get villaDetailTranslatedBadge => 'Đã dịch sang Tiếng Việt';

  @override
  String get villaDetailShowOriginal => 'Xem bản gốc';

  @override
  String get villaDetailShowTranslation => 'Xem bản dịch';

  @override
  String get villaDetailOriginalBadge => 'Bản gốc (Tiếng Việt)';

  @override
  String get villaDetailAmenitiesTitle => 'Tiện nghi có sẵn';

  @override
  String get villaDetailBookingCalendarTitle => 'Chọn lịch lưu trú & Đặt phòng';

  @override
  String villaDetailStayNightsRange(int min, int max) {
    return 'Tối thiểu $min đêm • Tối đa $max đêm';
  }

  @override
  String villaDetailGuestCapacityInfo(int included, int max) {
    return 'Tiêu chuẩn $included · Tối đa $max khách';
  }

  @override
  String villaDetailGuestCapacityMax(int max) {
    return 'Tối đa $max khách';
  }

  @override
  String get villaDetailPromoCodeHint => 'Mã ưu đãi';

  @override
  String get villaDetailPromoApply => 'Áp dụng';

  @override
  String get villaDetailPromoChecking => 'Đang kiểm tra...';

  @override
  String get villaDetailSpecialRequestsHint => 'Ghi chú cho chủ nhà (tùy chọn)';

  @override
  String villaDetailRoomSubtotal(int nights) {
    return 'Tiền phòng ($nights đêm)';
  }

  @override
  String villaDetailWeekendNights(int count) {
    return ', $count đêm cuối tuần';
  }

  @override
  String get villaDetailExtraGuestFee => 'Phụ thu vượt khách tiêu chuẩn';

  @override
  String get villaDetailCleaningFee => 'Phí vệ sinh';

  @override
  String get villaDetailServiceFee => 'Phí dịch vụ';

  @override
  String villaDetailDiscountLabel(String code) {
    return 'Giảm giá ($code)';
  }

  @override
  String get villaDetailEstimatedTotal => 'Tổng thanh toán tạm tính';

  @override
  String get villaDetailPoliciesTitle =>
      'Nội quy chỗ nghỉ & Chính sách hoàn hủy';

  @override
  String villaDetailCheckInTime(String from, String until) {
    return 'Nhận phòng: $from – $until';
  }

  @override
  String villaDetailCheckOutTime(String time) {
    return 'Trả phòng: Trước $time';
  }

  @override
  String villaDetailQuietHours(String hours) {
    return 'Giờ yên tĩnh: $hours';
  }

  @override
  String get villaDetailPetsAllowed => 'Cho phép mang thú cưng';

  @override
  String get villaDetailPetsNotAllowed => 'Không mang thú cưng';

  @override
  String get villaDetailPolicyFlexible =>
      'Linh hoạt — Hoàn tiền 100% trước 24 giờ nhận phòng';

  @override
  String get villaDetailPolicyModerate =>
      'Trung bình — Hoàn tiền 100% trước 5 ngày nhận phòng';

  @override
  String get villaDetailPolicyStrict =>
      'Nghiêm ngặt — Hoàn tiền 50% trước 7 ngày nhận phòng';

  @override
  String get villaDetailSimilarTitle => 'Gợi ý chỗ nghỉ tương tự gần đây';

  @override
  String get villaDetailMessageHostTooltip => 'Nhắn tin cho Chủ nhà';

  @override
  String villaDetailHostPrefix(String name) {
    return 'Chủ nhà: $name';
  }

  @override
  String villaDetailMinNightsRequired(int min) {
    return 'Chỗ nghỉ này yêu cầu tối thiểu $min đêm.';
  }

  @override
  String villaDetailMaxNightsExceeded(int max) {
    return 'Chỗ nghỉ này giới hạn tối đa $max đêm mỗi lần đặt.';
  }

  @override
  String get villaDetailLoginToBook =>
      'Vui lòng đăng nhập để hoàn tất đặt phòng.';

  @override
  String get villaDetailBookingSuccess =>
      'Đã gửi yêu cầu đặt phòng! Bạn có thể thanh toán ngay hoặc theo dõi tại Chuyến đi.';

  @override
  String get specSaltwaterPool => 'Hồ bơi nước mặn';

  @override
  String specBeachDistance(int meters) {
    return 'Cách biển ${meters}m';
  }

  @override
  String get specBeachfront => 'Sát biển';

  @override
  String specGuestsCount(int count) {
    return '$count khách';
  }

  @override
  String specBedroomsCount(int count) {
    return '$count phòng';
  }

  @override
  String specBedsCount(int count) {
    return '$count giường';
  }

  @override
  String specBathsCount(int count) {
    return '$count WC';
  }

  @override
  String get reviewsTranslate => 'Dịch đánh giá';

  @override
  String get reviewsShowOriginal => 'Xem bản gốc';

  @override
  String get reviewsTranslating => 'Đang dịch...';

  @override
  String get reviewsTranslatedBadge => 'Đã dịch tự động';

  @override
  String get reviewsFilterAll => 'Tất cả';

  @override
  String reviewsFilterStar(int star) {
    return '$star sao';
  }

  @override
  String get reviewsHostReply => 'Phản hồi từ chủ nhà';

  @override
  String get reviewsLoadMore => 'Xem thêm đánh giá';

  @override
  String get reviewsLoadError => 'Không thể tải đánh giá vào lúc này.';

  @override
  String get reviewsEmpty =>
      'Chưa có đánh giá nào cho villa này. Hãy là vị khách đầu tiên trải nghiệm!';

  @override
  String reviewsEmptyRating(int rating) {
    return 'Chưa có đánh giá $rating sao nào cho chỗ nghỉ này.';
  }

  @override
  String get chatBackToList => 'Quay lại danh sách';

  @override
  String get chatShowTimestamps => 'Hiện khung thời gian';

  @override
  String get chatHideTimestamps => 'Ẩn thời gian';

  @override
  String get chatViewListing => 'Xem chỗ nghỉ';

  @override
  String get chatAboutListing => 'Trao đổi về chỗ nghỉ';

  @override
  String get chatSelectConversationPrompt =>
      'Chọn một hội thoại để xem tin nhắn';

  @override
  String get chatInputPlaceholder => 'Nhắn tin';

  @override
  String get chatMoreOptions => 'Tiện ích mở rộng';

  @override
  String get chatCamera => 'Chụp ảnh';

  @override
  String get chatGallery => 'Gửi hình ảnh';

  @override
  String get chatGalleryLabel => 'Thư viện ảnh';

  @override
  String get chatVoiceMessage => 'Tin nhắn thoại';

  @override
  String get chatStopRecording => 'Dừng ghi âm';

  @override
  String get chatEmojiTooltip => 'Biểu tượng cảm xúc';

  @override
  String get chatSendMessage => 'Gửi tin nhắn';

  @override
  String get chatSendQuickEmoji => 'Gửi biểu tượng nhanh';

  @override
  String get chatSendQuickEmojiHint => 'Gửi biểu tượng nhanh (nhấn giữ để đổi)';

  @override
  String get chatSending => 'Đang gửi...';

  @override
  String get chatSent => 'Đã gửi';

  @override
  String get chatSeen => ' • Đã xem';

  @override
  String get chatFailed => 'Gửi thất bại';

  @override
  String get chatRetry => 'Thử lại';

  @override
  String get chatDeleteFailedMessage => 'Xóa tin nhắn lỗi';

  @override
  String get chatEmptyPrompt =>
      'Hãy gửi tin nhắn đầu tiên để bắt đầu trao đổi.';

  @override
  String get chatLoadMoreHistory => 'Tải thêm tin nhắn cũ hơn';

  @override
  String get chatLoadingHistory => 'Đang tải lịch sử...';

  @override
  String chatNewMessagesCount(int count) {
    return 'Tin nhắn mới ($count)';
  }

  @override
  String chatUserTyping(String user) {
    return '$user đang nhập tin nhắn...';
  }

  @override
  String get chatDraftPrefix => 'Nháp: ';

  @override
  String get chatNoMessagesYet => 'Chưa có tin nhắn.';

  @override
  String get chatSearchConversationsPlaceholder => 'Tìm kiếm hội thoại...';

  @override
  String get chatLoginTitle => 'Đăng nhập để xem tin nhắn';

  @override
  String get chatLoginDescription =>
      'Trao đổi trực tiếp với Chủ nhà Vũng Tàu về lịch phòng, tiện nghi và ưu đãi.';

  @override
  String get chatLoginAction => 'Đăng nhập ngay';

  @override
  String get chatEmptyAdminTitle => 'Chưa có cuộc trò chuyện hỗ trợ nào';

  @override
  String get chatEmptyAdminDesc =>
      'Các hội thoại hỗ trợ trực tiếp với Chủ nhà và Khách hàng trên hệ thống sẽ hiển thị tại đây.';

  @override
  String get chatEmptyAdminAction => 'Quản lý người dùng';

  @override
  String get chatEmptyHostTitle => 'Chưa có cuộc trò chuyện nào';

  @override
  String get chatEmptyHostDesc =>
      'Khi khách hàng nhắn tin hỏi phòng hoặc đặt chỗ, hội thoại sẽ hiển thị tại đây.';

  @override
  String get chatEmptyGuestTitle => 'Chưa có cuộc trò chuyện nào';

  @override
  String get chatEmptyGuestDesc =>
      'Hãy chọn một biệt thự và bấm \"Nhắn tin cho Chủ nhà\" để bắt đầu trò chuyện.';

  @override
  String get chatEmptyGuestAction => 'Khám phá biệt thự';

  @override
  String get chatExtensionsAndTemplatesTitle =>
      'Tiện ích mở rộng & Mẫu tin nhanh';

  @override
  String get chatSelectEmojiTitle => 'Chọn biểu tượng cảm xúc';

  @override
  String get chatSelectQuickEmojiTitle => 'Chọn biểu tượng gửi nhanh';

  @override
  String get chatQuickReplyGuest1 => 'Dạ căn còn trống lịch này không ạ?';

  @override
  String get chatQuickReplyGuest2 => 'Cho mình hỏi giờ nhận và trả phòng ạ?';

  @override
  String get chatQuickReplyGuest3 =>
      'Biệt thự có sẵn bếp BBQ và hồ bơi riêng không ạ?';

  @override
  String get chatQuickReplyGuest4 => 'Cảm ơn Chủ nhà nhiều ạ!';

  @override
  String get chatQuickReplyHost1 => 'Dạ vâng, bên em đã nhận thông tin ạ!';

  @override
  String get chatQuickReplyHost2 => 'Quý khách nhận phòng lúc mấy giờ ạ?';

  @override
  String get chatQuickReplyHost3 => 'The Palm Villa xin chào bạn! 🌴';

  @override
  String get chatQuickReplyHost4 =>
      'Vị trí biệt thự em đã cập nhật trên hệ thống ạ.';

  @override
  String get chatQuickReplyAdmin1 =>
      'Chào bạn, Quản trị viên hệ thống hỗ trợ bạn vấn đề gì ạ?';

  @override
  String get chatQuickReplyAdmin2 =>
      'Hệ thống đã tiếp nhận thông tin và đang kiểm tra ạ.';

  @override
  String get chatQuickReplyAdmin3 =>
      'Hồ sơ/bài đăng của bạn đã được cập nhật trạng thái.';

  @override
  String get chatQuickReplyAdmin4 => 'Cảm ơn bạn đã phản hồi cho Ban quản trị!';

  @override
  String get chatTplAdminDocsTitle => 'Yêu cầu bổ sung hồ sơ / giấy tờ';

  @override
  String get chatTplAdminDocsSubtitle =>
      'Nhắc Chủ nhà hoặc Khách cập nhật thông tin xác minh';

  @override
  String get chatTplAdminDocsContent =>
      '📋 Ban quản trị đề nghị bạn kiểm tra và bổ sung giấy tờ xác minh rõ nét để hệ thống hoàn tất phê duyệt.';

  @override
  String get chatTplHostLocationTitle => 'Gửi vị trí chỗ nghỉ';

  @override
  String get chatTplHostLocationSubtitle =>
      'Địa chỉ chi tiết và hướng dẫn di chuyển';

  @override
  String chatTplHostLocationContent(String villaTitle) {
    return '📍 Vị trí $villaTitle: Đường Thùy Vân, TP. Vũng Tàu (gần bãi tắm Bãi Sau).';
  }

  @override
  String get chatTplGuestInquiryTitle => 'Hỏi lịch trống & báo giá';

  @override
  String get chatTplGuestInquirySubtitle =>
      'Kiểm tra tình trạng phòng và phụ thu cuối tuần';

  @override
  String get chatTplGuestInquiryContent =>
      '📅 Chào Chủ nhà, cho mình hỏi căn còn trống lịch cuối tuần này và giá trọn gói cho đoàn mình nhé ạ?';

  @override
  String get chatTplAdminReviewTitle => 'Thông báo kết quả kiểm duyệt';

  @override
  String get chatTplAdminReviewSubtitle =>
      'Cập nhật trạng thái bài đăng hoặc tài khoản';

  @override
  String get chatTplAdminReviewContent =>
      '✅ Quản trị viên đã kiểm tra và cập nhật trạng thái hồ sơ/bài đăng của bạn trên hệ thống.';

  @override
  String get chatTplHostCheckinTitle => 'Giờ nhận & trả phòng';

  @override
  String get chatTplHostCheckinSubtitle => 'Check-in: 14:00 • Check-out: 12:00';

  @override
  String get chatTplHostCheckinContent =>
      '⏰ Thời gian nhận phòng: từ 14:00 | Thời gian trả phòng: trước 12:00 ngày hôm sau.';

  @override
  String get chatTplGuestCheckinTitle => 'Xin nhận phòng sớm / trả phòng muộn';

  @override
  String get chatTplGuestCheckinSubtitle =>
      'Hỏi hỗ trợ linh hoạt giờ check-in / check-out';

  @override
  String get chatTplGuestCheckinContent =>
      '⏰ Đoàn mình dự kiến đến sớm hơn 14:00 một chút, Chủ nhà có thể hỗ trợ gửi hành lý hoặc nhận phòng sớm không ạ?';

  @override
  String get chatTplAdminPolicyTitle => 'Hướng dẫn chính sách nền tảng';

  @override
  String get chatTplAdminPolicySubtitle =>
      'Giải đáp quy định đặt phòng & phí dịch vụ';

  @override
  String get chatTplAdminPolicyContent =>
      'ℹ️ Mọi giao dịch trên hệ thống đều được bảo vệ theo chính sách đặt phòng và hoàn hủy minh bạch của The Palm Villa.';

  @override
  String get chatTplHostHouseRulesTitle => 'Gửi nội quy lưu trú';

  @override
  String get chatTplHostHouseRulesSubtitle =>
      'Giữ gìn vệ sinh, yên tĩnh sau 22:00';

  @override
  String get chatTplHostHouseRulesContent =>
      '📋 Nội quy lưu trú: Vui lòng giữ gìn tài sản chung và hạn chế tiếng ồn lớn sau 22:00. Chúc quý khách kỳ nghỉ tuyệt vời!';

  @override
  String get chatTplGuestAmenitiesTitle => 'Hỏi tiện ích BBQ & hồ bơi';

  @override
  String get chatTplGuestAmenitiesSubtitle =>
      'Bếp nướng, than, phao bơi và chỗ đậu xe';

  @override
  String get chatTplGuestAmenitiesContent =>
      '🔥 Biệt thự có sẵn lò nướng BBQ, dụng cụ bếp, hồ bơi riêng và chỗ đậu ô tô trong sân không ạ?';

  @override
  String get chatToastUploadingPhoto => 'Đang tải ảnh lên Cloudflare R2...';

  @override
  String get chatToastUploadPhotoFailed => 'Tải ảnh lên R2 thất bại';

  @override
  String get chatToastUploadingVoice =>
      'Đang tải tin nhắn thoại lên Cloudflare R2...';

  @override
  String get chatToastUploadVoiceFailed => 'Tải âm thanh lên R2 thất bại';

  @override
  String get chatToastMicNoAudio =>
      'Không ghi nhận được âm thanh từ Micro. Vui lòng cấp quyền Microphone hoặc nói to hơn.';

  @override
  String get chatToastMicAccessError =>
      'Không thể truy cập Micro. Vui lòng cấp quyền Microphone trên trình duyệt / thiết bị.';

  @override
  String get chatErrorNetwork => 'Mất kết nối mạng';

  @override
  String get chatErrorForbidden => 'Không có quyền truy cập';

  @override
  String get chatErrorUnauthorized => 'Phiên đăng nhập hết hạn';

  @override
  String get chatErrorNotFound => 'Không tìm thấy cuộc trò chuyện';

  @override
  String get chatErrorRateLimit => 'Thao tác quá nhanh';

  @override
  String get chatErrorServer => 'Lỗi máy chủ';

  @override
  String get chatErrorValidation => 'Dữ liệu không hợp lệ';

  @override
  String get chatErrorGeneric => 'Đã có lỗi xảy ra';

  @override
  String get hostMsgBackToVilla => 'Quay lại trang biệt thự';

  @override
  String get hostMsgContactTitle => 'Liên hệ Chủ nhà';

  @override
  String hostMsgHostLabel(String name) {
    return 'Chủ nhà: $name';
  }

  @override
  String get hostMsgDefaultHost => 'Chủ nhà The Palm Villa';

  @override
  String get hostMsgFaqTitle => 'Câu hỏi thường gặp cho Chủ nhà:';

  @override
  String get hostMsgInputLabel => 'Nội dung tin nhắn gửi Chủ nhà ';

  @override
  String get hostMsgInputPlaceholder =>
      'Nhập câu hỏi của bạn về lịch trống, tiện nghi hoặc yêu cầu đặc biệt...';

  @override
  String get hostMsgSendAction => 'Gửi tin nhắn & Mở phòng chat';

  @override
  String get hostMsgSendingAction => 'Đang gửi tin nhắn...';

  @override
  String get hostMsgQuestion1 =>
      'Chào Chủ nhà, biệt thự còn trống lịch cuối tuần này không ạ?';

  @override
  String get hostMsgQuestion2 =>
      'Hồ bơi của biệt thự là nước ngọt hay nước mặn và có phao bơi không ạ?';

  @override
  String get hostMsgQuestion3 =>
      'Biệt thự có sẵn lò nướng BBQ, than và dụng cụ bếp đầy đủ không ạ?';

  @override
  String get hostMsgQuestion4 =>
      'Đoàn mình muốn nhận phòng sớm hơn 14:00 có được hỗ trợ không ạ?';

  @override
  String galleryPhotoCount(int count) {
    return '$count ảnh';
  }

  @override
  String get galleryViewAllPhotosSemantic => 'Xem toàn bộ ảnh';

  @override
  String gallerySpacePrefix(String type) {
    return 'Không gian: $type';
  }

  @override
  String get spaceBedroom => 'Phòng ngủ';

  @override
  String get spaceLivingRoom => 'Phòng khách';

  @override
  String get spaceKitchen => 'Phòng bếp';

  @override
  String get spaceBathroom => 'Phòng tắm';

  @override
  String get spacePool => 'Hồ bơi';

  @override
  String get spaceExterior => 'Ngoại thất';

  @override
  String get spaceView => 'Tầm nhìn';

  @override
  String get spaceDining => 'Phòng ăn';

  @override
  String get spaceOther => 'Không gian khác';
}
