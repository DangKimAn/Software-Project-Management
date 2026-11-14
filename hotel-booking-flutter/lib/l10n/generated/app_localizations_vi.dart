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
  String get loadingTrips => 'Đang tải lịch trình...';

  @override
  String get loadingPaymentInfo => 'Đang tải thông tin thanh toán đặt phòng...';

  @override
  String get guestPaymentConnectingGateway => 'Đang kết nối cổng thanh toán...';

  @override
  String get guestPaymentBookingNotFoundTitle => 'Không tìm thấy đơn đặt phòng';

  @override
  String get guestPaymentBookingNotFoundMessage =>
      'Đơn đặt phòng không tồn tại hoặc đã hết hạn.';

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
  String get footerCopyright =>
      '© 2026 The Palm Villa Vũng Tàu. Bảo lưu mọi quyền.';

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

  @override
  String get blogAllArticles => 'Tất cả bài viết';

  @override
  String get blogShareTooltip => 'Chia sẻ bài viết';

  @override
  String get blogShareInvalidLink =>
      'Liên kết bài viết không hợp lệ để chia sẻ.';

  @override
  String get blogShareSuccess => 'Đã sao chép liên kết bài viết vào bộ nhớ tạm';

  @override
  String get blogShareFailure =>
      'Không thể sao chép liên kết bài viết trên thiết bị này.';

  @override
  String get blogNotFoundTitle => 'Không tìm thấy bài viết';

  @override
  String get blogNotFoundDescription =>
      'Bài viết có thể đã được gỡ hoặc đường dẫn không chính xác.';

  @override
  String get blogBackToBlog => 'Quay lại Cẩm nang';

  @override
  String get blogLoadingArticle => 'Đang tải bài viết...';

  @override
  String get blogRelatedArticlesBadge => 'BÀI VIẾT LIÊN QUAN';

  @override
  String get blogRelatedArticlesTitle => 'Gợi ý đọc tiếp';

  @override
  String get blogViewAllArticles => 'Xem tất cả bài viết';

  @override
  String blogReadMinutes(int minutes) {
    return '$minutes phút đọc';
  }

  @override
  String get blogDefaultAuthor => 'Ban biên tập The Palm';

  @override
  String get blogListBadge => 'CẨM NANG LƯU TRÚ VŨNG TÀU';

  @override
  String get blogListHeroTitle =>
      'Kinh nghiệm lưu trú, lịch trình & bí quyết đặt Villa biển Vũng Tàu';

  @override
  String get blogSearchHint => 'Tìm bài viết cẩm nang Vũng Tàu...';

  @override
  String get blogClearSearchTooltip => 'Xóa từ khóa tìm kiếm';

  @override
  String get blogCategoryAll => 'Tất cả';

  @override
  String get blogCategoryTravelGuide => 'Cẩm nang du lịch';

  @override
  String get blogCategoryReviews => 'Đánh giá Villa & Homestay';

  @override
  String get blogCategoryTripGuide => 'Cẩm nang chuyến đi';

  @override
  String get blogCategoryBookingTips => 'Kinh nghiệm đặt phòng';

  @override
  String get blogCategoryLocalDiscovery => 'Khám phá địa phương';

  @override
  String get blogCategoryStayTips => 'Mẹo lưu trú';

  @override
  String get blogCategoryNearBeach => 'Villa gần biển';

  @override
  String get blogCategoryBookingChecklist => 'Checklist đặt phòng';

  @override
  String get blogEmptyTitle => 'Chưa có bài viết phù hợp';

  @override
  String get blogEmptyDescription =>
      'Hãy thử chọn chuyên mục khác hoặc từ khóa khác.';

  @override
  String get blogClearFilters => 'Xóa bộ lọc';

  @override
  String get blogLoadingList => 'Đang tải danh sách bài viết...';

  @override
  String get blogPaginationPrev => 'Trang trước';

  @override
  String get blogPaginationNext => 'Trang sau';

  @override
  String blogPaginationPage(int page) {
    return 'Trang $page';
  }

  @override
  String get footerSupportTitle => 'Hỗ trợ';

  @override
  String get footerLinkBookingGuide => 'Hướng dẫn đặt phòng';

  @override
  String get footerLinkCancellationPolicy => 'Chính sách hủy phòng';

  @override
  String get footerLinkComplaintsFeedback => 'Khiếu nại & Góp ý';

  @override
  String get footerLinkFaq => 'Câu hỏi thường gặp (FAQ)';

  @override
  String get footerExploreTitle => 'Khám phá & Dịch vụ';

  @override
  String get footerLinkAboutUs => 'Về chúng tôi';

  @override
  String get footerLinkExploreVungTau => 'Khám phá Vũng Tàu';

  @override
  String get footerLinkTravelGuide => 'Cẩm nang du lịch';

  @override
  String get footerLinkAddonServices => 'Dịch vụ đi kèm';

  @override
  String get footerLinkMemberOffers => 'Ưu đãi thành viên';

  @override
  String get footerContactTitle => 'Liên hệ';

  @override
  String footerHotlineLabel(String phone) {
    return 'Hotline: $phone';
  }

  @override
  String get footerOnlineConsultLink => 'Liên hệ tư vấn trực tuyến';

  @override
  String footerAddressLabel(String address) {
    return 'Địa chỉ: $address';
  }

  @override
  String footerEmailLabel(String email) {
    return 'Email: $email';
  }

  @override
  String get footerEmailSubject => 'Liên hệ đặt phòng The Palm Villa Vũng Tàu';

  @override
  String get footerSocialTitle => 'Social';

  @override
  String get supportGuideStep1Title =>
      'Tìm kiếm theo phân khu & lịch trống thực tế';

  @override
  String get supportGuideStep1Desc =>
      'Chọn phân khu biển tại Vũng Tàu (Bãi Sau, Bãi Trước, Chí Linh, Long Cung), khoảng ngày lưu trú [Nhận phòng, Trả phòng) và tổng số khách đoàn để lọc đúng các căn biệt thự đang mở lịch.';

  @override
  String get supportGuideStep2Title =>
      'Kiểm tra bảng giá theo đêm & áp dụng mã ưu đãi';

  @override
  String get supportGuideStep2Desc =>
      'Xem chi tiết thông số biệt thự (phòng ngủ, giường, WC, khoảng cách biển), bảng giá từng đêm ngày thường / cuối tuần, phụ thu khách vượt tiêu chuẩn (nếu có) và nhập mã ưu đãi hợp lệ.';

  @override
  String get supportGuideStep3Title => 'Khóa lịch giữ chỗ tạm thời 15 phút';

  @override
  String get supportGuideStep3Desc =>
      'Ngay khi tạo đơn đặt phòng, hệ thống tự động khóa khoảng ngày lưu trú trong 15 phút (trạng thái Chờ thanh toán) để bảo vệ bạn khỏi tình trạng trùng lịch với đoàn khách khác.';

  @override
  String get supportGuideStep4Title =>
      'Thanh toán trực tuyến & nhận xác nhận lưu trú';

  @override
  String get supportGuideStep4Desc =>
      'Hoàn tất thanh toán qua cổng thanh toán được hỗ trợ (VNPay, MoMo hoặc VietQR) trong thời gian giữ chỗ. Theo dõi trạng thái đơn và nhắn tin trực tiếp với Chủ nhà ngay tại mục Chuyến đi.';

  @override
  String get supportCancelFlexName => 'Chính sách Linh hoạt (Flexible)';

  @override
  String get supportCancelFlexBadge => 'Hoàn 100% trước 24 giờ';

  @override
  String get supportCancelFlexRule1 =>
      'Hủy trước thời điểm nhận phòng từ đủ 24 giờ trở lên: hoàn 100% tổng số tiền đã thanh toán.';

  @override
  String get supportCancelFlexRule2 =>
      'Hủy trong vòng dưới 24 giờ trước giờ nhận phòng: không áp dụng hoàn tiền.';

  @override
  String get supportCancelModName => 'Chính sách Trung bình (Moderate)';

  @override
  String get supportCancelModBadge => 'Hoàn 100% trước 5 ngày';

  @override
  String get supportCancelModRule1 =>
      'Hủy trước thời điểm nhận phòng từ đủ 5 ngày (120 giờ) trở lên: hoàn 100% tổng số tiền đã thanh toán.';

  @override
  String get supportCancelModRule2 =>
      'Hủy trong khoảng từ đủ 24 giờ đến dưới 5 ngày (120 giờ): hoàn 50% tổng số tiền đã thanh toán.';

  @override
  String get supportCancelModRule3 =>
      'Hủy trong vòng dưới 24 giờ trước giờ nhận phòng: không áp dụng hoàn tiền.';

  @override
  String get supportCancelStrictName => 'Chính sách Nghiêm ngặt (Strict)';

  @override
  String get supportCancelStrictBadge => 'Hoàn 50% trước 7 ngày';

  @override
  String get supportCancelStrictRule1 =>
      'Hủy trước thời điểm nhận phòng từ đủ 7 ngày (168 giờ) trở lên: hoàn 50% tổng số tiền đã thanh toán.';

  @override
  String get supportCancelStrictRule2 =>
      'Hủy trong vòng dưới 7 ngày (168 giờ) trước giờ nhận phòng: không áp dụng hoàn tiền.';

  @override
  String get supportComplaintStep1Title =>
      'Gửi phản ánh kèm mã đơn hoặc mã chỗ nghỉ';

  @override
  String get supportComplaintStep1Desc =>
      'Đăng nhập tài khoản và gửi báo cáo trực tuyến kèm mã đơn đặt phòng (Booking ID) hoặc mã biệt thự (Listing ID), nêu rõ vấn đề thực tế cần đối soát.';

  @override
  String get supportComplaintStep2Title =>
      'Đối soát lịch sử lưu trú & luồng thanh toán';

  @override
  String get supportComplaintStep2Desc =>
      'Bộ phận Kiểm duyệt & An toàn (Trust & Safety) kiểm tra nhật ký trạng thái đơn, lịch sử trao đổi tin nhắn trên ứng dụng và chứng từ thanh toán độc lập.';

  @override
  String get supportComplaintStep3Title =>
      'Phản hồi kết quả & bảo vệ quyền lợi khách hàng';

  @override
  String get supportComplaintStep3Desc =>
      'Kết quả xử lý được cập nhật minh bạch vào trạng thái báo cáo (Đã giải quyết / Từ chối kèm lý do) và kích hoạt quy trình hoàn tiền nếu Chủ nhà vi phạm cam kết.';

  @override
  String get supportFaqCatAll => 'Tất cả';

  @override
  String get supportFaqCatBooking => 'Đặt phòng & Lịch trống';

  @override
  String get supportFaqCatPayment => 'Thanh toán & Hoàn tiền';

  @override
  String get supportFaqCatAmenities => 'Tiện ích & Nội quy';

  @override
  String get supportFaqCatHost => 'Đối tác Chủ nhà';

  @override
  String get supportFaq1Q => 'Số đêm lưu trú được hệ thống tính như thế nào?';

  @override
  String get supportFaq1A =>
      'Hệ thống áp dụng mô hình đêm lưu trú nửa mở [Nhận phòng, Trả phòng) theo múi giờ Việt Nam (Asia/Ho_Chi_Minh). Ví dụ chọn nhận phòng ngày 15 và trả phòng ngày 17 sẽ gồm 2 đêm ở (đêm 15 và đêm 16); ngày 17 là ngày trả phòng.';

  @override
  String get supportFaq2Q =>
      'Tại sao đơn đặt phòng có thời gian giữ chỗ 15 phút?';

  @override
  String get supportFaq2A =>
      'Mỗi căn biệt thự nguyên căn là tài sản đơn chiếc. Khi bạn tạo đơn, hệ thống khóa ngày lưu trú trong 15 phút để không ai khác đặt trùng trong lúc bạn thao tác thanh toán. Quá 15 phút chưa thanh toán, khóa ngày sẽ tự động giải phóng.';

  @override
  String get supportFaq3Q =>
      'Giá cuối tuần và phụ thu đoàn đông được tính ra sao?';

  @override
  String get supportFaq3A =>
      'Bảng giá từng đêm (ngày thường, thứ Bảy/cuối tuần), phí dọn dẹp và phụ thu khách vượt mức tiêu chuẩn đều lấy trực tiếp từ cấu hình đã kiểm duyệt của từng căn biệt thự và hiển thị minh bạch trước khi bạn xác nhận đặt phòng.';

  @override
  String get supportFaq4Q =>
      'Tôi có thể thanh toán bằng những phương thức nào?';

  @override
  String get supportFaq4A =>
      'Hệ thống hỗ trợ thanh toán trực tuyến qua cổng VNPay, ví MoMo và chuyển khoản mã VietQR. Mọi giao dịch đều được đối soát tự động và cập nhật tức thời vào mục Chuyến đi.';

  @override
  String get supportFaq5Q =>
      'Khi hủy phòng hợp lệ hoặc Chủ nhà từ chối đơn, tôi nhận lại tiền bằng cách nào?';

  @override
  String get supportFaq5A =>
      'Nếu đơn đã thanh toán được hủy trong khung giờ hoàn tiền của căn biệt thự (hoặc bị Chủ nhà hủy/từ chối — hoàn 100%), hệ thống tự động khởi tạo yêu cầu hoàn tiền riêng biệt để bộ phận tài chính đối soát hoàn trả về tài khoản/kênh thanh toán của bạn.';

  @override
  String get supportFaq6Q =>
      'Tôi có thể trao đổi trực tiếp với Chủ nhà trước khi đặt không?';

  @override
  String get supportFaq6A =>
      'Có. Tại trang chi tiết từng biệt thự, bạn có thể bấm Nhắn tin cho Host hoặc kết nối qua kênh tư vấn Zalo OA / Hotline tại trang Liên hệ để hỏi rõ về hồ bơi, bếp BBQ hoặc chỗ đậu xe đoàn.';

  @override
  String get supportFaq7Q =>
      'Làm thế nào để đăng ký cho thuê biệt thự trên The Palm Villa?';

  @override
  String get supportFaq7A =>
      'Bạn truy cập mục Trở thành Host trên thanh điều hướng hoặc chân trang, hoàn tất hồ sơ xác thực danh tính (KYC CCCD) và thông tin chỗ nghỉ. Sau khi Quản trị viên phê duyệt, bạn có thể quản lý lịch 30 ngày và đồng bộ hai chiều với Google Sheets.';

  @override
  String get supportZoneBaiSauName => 'Phân khu Bãi Sau (Thùy Vân – Thi Sách)';

  @override
  String get supportZoneBaiSauHint =>
      'Bờ biển dài, sôi động, thuận tiện đi bộ ra bãi tắm';

  @override
  String get supportZoneBaiSauHighlight =>
      'Tập trung nhiều biệt thự hồ bơi riêng diện tích lớn cho nhóm bạn và gia đình, gần trục đường Thùy Vân, Thi Sách, Võ Thị Sáu.';

  @override
  String get supportZoneBaiTruocName =>
      'Phân khu Bãi Trước (Trần Phú – Quang Trung)';

  @override
  String get supportZoneBaiTruocHint =>
      'Ngắm hoàng hôn biển trực diện, gần trung tâm ẩm thực';

  @override
  String get supportZoneBaiTruocHighlight =>
      'Không gian biệt thự nghỉ dưỡng hướng biển Trần Phú yên tĩnh, tầm nhìn hoàng hôn thoáng đãng và di chuyển thuận tiện tới công viên Bãi Trước.';

  @override
  String get supportZoneChiLinhName => 'Phân khu Chí Linh';

  @override
  String get supportZoneChiLinhHint =>
      'Khu nghỉ dưỡng biệt lập, an ninh, bãi tắm riêng tư';

  @override
  String get supportZoneChiLinhHighlight =>
      'Phù hợp đoàn gia đình nhiều thế hệ hoặc nhóm công ty yêu thích không gian xanh mát, yên tĩnh và bãi biển sạch thoáng.';

  @override
  String get supportZoneLongCungName => 'Phân khu Long Cung – Thủy Tiên';

  @override
  String get supportZoneLongCungHint =>
      'Quần thể biệt thự nghỉ dưỡng sát biển cho đoàn đông';

  @override
  String get supportZoneLongCungHighlight =>
      'Nổi bật với các căn biệt thự sân vườn rộng, hồ bơi riêng và khu tổ chức tiệc nướng BBQ ngoài trời gần bãi tắm Long Cung.';

  @override
  String get supportAddonPoolTitle => 'Hồ bơi riêng tại biệt thự';

  @override
  String get supportAddonPoolDesc =>
      'Không gian hồ bơi riêng tư ngay trong khuôn viên căn biệt thự, phù hợp thư giãn cùng gia đình và nhóm bạn.';

  @override
  String get supportAddonPoolNote =>
      'Có sẵn theo thông số công bố của từng căn biệt thự.';

  @override
  String get supportAddonBbqTitle => 'Khu vực bếp nướng BBQ sân vườn';

  @override
  String get supportAddonBbqDesc =>
      'Trang bị khu vực nướng ngoài trời, bàn ghế sân vườn và dụng cụ bếp cơ bản phục vụ tiệc tối ấm cúng.';

  @override
  String get supportAddonBbqNote =>
      'Trao đổi trước với Chủ nhà về than nướng hoặc hỗ trợ dọn rửa.';

  @override
  String get supportAddonKitchenTitle => 'Bếp nấu tiêu chuẩn gia đình';

  @override
  String get supportAddonKitchenDesc =>
      'Đầy đủ tủ lạnh, bếp nấu, nồi chảo và bát đĩa để đoàn tự chuẩn bị hải sản tươi sống mua tại chợ địa phương.';

  @override
  String get supportAddonKitchenNote =>
      'Vui lòng giữ vệ sinh khu bếp theo nội quy từng chỗ nghỉ.';

  @override
  String get supportAddonKaraokeTitle => 'Phòng giải trí & Âm thanh Karaoke';

  @override
  String get supportAddonKaraokeDesc =>
      'Hệ thống loa giải trí hoặc phòng sinh hoạt chung tại các căn biệt thự có gắn nhãn tiện nghi Karaoke.';

  @override
  String get supportAddonKaraokeNote =>
      'Tuân thủ khung giờ yên tĩnh khu dân cư (trước 22:00).';

  @override
  String get supportAddonParkingTitle => 'Chỗ đậu xe ô tô & xe đoàn an toàn';

  @override
  String get supportAddonParkingDesc =>
      'Sân đậu xe trong khuôn viên hoặc đường nội khu rộng rãi thuận tiện cho ô tô cá nhân và xe du lịch 7–29 chỗ.';

  @override
  String get supportAddonParkingNote =>
      'Kiểm tra sức chứa xe cụ thể trong phần mô tả chi tiết villa.';

  @override
  String get supportAddonBeachTitle => 'Vị trí gần bãi tắm biển';

  @override
  String get supportAddonBeachDesc =>
      'Các căn biệt thự có khoảng cách thực tế tới bãi tắm được công bố rõ ràng bằng đơn vị mét ngay trên thẻ thông tin.';

  @override
  String get supportAddonBeachNote =>
      'Lọc nhanh các căn sát biển chỉ với một chạm bên dưới.';

  @override
  String get supportExploreZoneAction => 'Xem biệt thự khu vực này';

  @override
  String supportServiceNotePrefix(String note) {
    return 'Lưu ý: $note';
  }

  @override
  String get supportFilterByAmenityAction => 'Lọc villa có tiện ích này';

  @override
  String get supportFaqSearchHint =>
      'Tìm câu hỏi theo từ khóa (ví dụ: giữ chỗ, hoàn tiền)...';

  @override
  String get supportFaqClearSearchTooltip => 'Xóa từ khóa';

  @override
  String get supportFaqEmptyResult =>
      'Không tìm thấy câu hỏi phù hợp với từ khóa hiện tại. Vui lòng thử từ khóa khác hoặc liên hệ trực tiếp đội ngũ tư vấn.';

  @override
  String get supportBookingGuideEyebrow => 'Hỗ trợ đặt phòng';

  @override
  String get supportBookingGuideTitle => 'Hướng dẫn đặt biệt thự nguyên căn';

  @override
  String get supportBookingGuideSubtitle =>
      'Quy trình đặt chỗ 4 bước minh bạch với cơ chế khóa lịch 15 phút chống trùng phòng và đối soát thanh toán trực tuyến tức thời.';

  @override
  String get supportBookingGuideNoteTitle => 'Lưu ý khi nhận và trả phòng';

  @override
  String get supportBookingGuideNoteBody =>
      'Mọi đơn đặt đều tính theo đêm lưu trú [Nhận phòng, Trả phòng) theo múi giờ Việt Nam. Trước khi khởi hành, bạn có thể nhắn tin trực tiếp với Chủ nhà trong mục Tin nhắn để thống nhất giờ đón đoàn và danh sách xe.';

  @override
  String get supportBookingGuideCtaTitle =>
      'Sẵn sàng tìm căn biệt thự phù hợp cho đoàn của bạn?';

  @override
  String get supportBookingGuideCtaDesc =>
      'Tra cứu ngay danh sách biệt thự đang mở lịch trống kèm giá niêm yết theo đêm tại Vũng Tàu.';

  @override
  String get supportBookingGuidePrimaryAction => 'Tìm biệt thự ngay';

  @override
  String get supportBookingGuideSecondaryAction => 'Liên hệ tư vấn';

  @override
  String get supportCancelEyebrow => 'Chính sách lưu trú & hoàn tiền';

  @override
  String get supportCancelTitle => 'Chính sách hủy phòng & Hoàn tiền';

  @override
  String get supportCancelSubtitle =>
      'Tỷ lệ hoàn tiền được hệ thống tính tự động dựa trên loại chính sách công bố của từng căn biệt thự và số giờ còn lại trước ngày nhận phòng.';

  @override
  String get supportCancelHostProtectTitle =>
      'Bảo vệ khách lưu trú 100% khi Chủ nhà hủy đơn';

  @override
  String get supportCancelHostProtectBody =>
      'Trong trường hợp đơn đã thanh toán bị Chủ nhà từ chối hoặc chủ động hủy, hệ thống tự động tạo lệnh hoàn 100% giá trị thanh toán không phụ thuộc bậc chính sách. Các đơn giữ chỗ chưa thanh toán sẽ tự hủy miễn phí sau 15 phút.';

  @override
  String get supportCancelCtaTitle =>
      'Kiểm tra trạng thái đơn hoặc yêu cầu hủy phòng';

  @override
  String get supportCancelCtaDesc =>
      'Truy cập mục Chuyến đi để xem chính sách áp dụng riêng cho đơn đặt phòng của bạn hoặc liên hệ bộ phận hỗ trợ.';

  @override
  String get supportCancelPrimaryAction => 'Xem Chuyến đi của tôi';

  @override
  String get supportCancelSecondaryAction => 'Câu hỏi thường gặp';

  @override
  String get supportComplaintsEyebrow => 'An toàn & Minh bạch';

  @override
  String get supportComplaintsTitle => 'Khiếu nại, Báo cáo & Góp ý dịch vụ';

  @override
  String get supportComplaintsSubtitle =>
      'Mọi phản ánh về chất lượng biệt thự, sai lệch thông tin tin đăng hoặc thái độ phục vụ đều được ghi vết và đối soát độc lập.';

  @override
  String get supportComplaintsCtaTitle =>
      'Cần hỗ trợ khẩn cấp trong thời gian đang lưu trú?';

  @override
  String get supportComplaintsCtaDesc =>
      'Kết nối trực tiếp qua Hotline hoặc Zalo OA tại văn phòng Vũng Tàu (08:00 – 22:00) để được hỗ trợ ngay.';

  @override
  String get supportComplaintsPrimaryAction => 'Mở trang Liên hệ';

  @override
  String get supportComplaintsSecondaryAction => 'Tin nhắn với Host';

  @override
  String get supportFaqEyebrow => 'Trung tâm giải đáp';

  @override
  String get supportFaqPageTitle => 'Câu hỏi thường gặp (FAQ)';

  @override
  String get supportFaqSubtitle =>
      'Giải đáp nhanh các thắc mắc về cách tính đêm lưu trú, khóa lịch 15 phút, phương thức thanh toán, hoàn tiền và đăng ký đối tác Chủ nhà.';

  @override
  String get supportFaqCtaTitle => 'Chưa tìm thấy câu trả lời bạn cần?';

  @override
  String get supportFaqCtaDesc =>
      'Đội ngũ tư vấn tại 28 Thi Sách, TP. Vũng Tàu luôn sẵn sàng giải đáp chi tiết theo nhu cầu riêng của đoàn.';

  @override
  String get supportFaqPrimaryAction => 'Liên hệ tư vấn trực tuyến';

  @override
  String get supportFaqSecondaryAction => 'Xem hướng dẫn đặt phòng';

  @override
  String get supportAboutEyebrow => 'Về The Palm Villa';

  @override
  String get supportAboutTitle =>
      'Nền tảng đặt biệt thự nghỉ dưỡng nguyên căn tại Vũng Tàu';

  @override
  String get supportAboutSubtitle =>
      'Kết nối trực tiếp du khách với hệ thống biệt thự nghỉ dưỡng đã qua kiểm duyệt thực tế và xác thực danh tính Chủ nhà (KYC) tại TP. Vũng Tàu.';

  @override
  String get supportAboutPillar1Title =>
      'Chỗ nghỉ kiểm duyệt & Host xác thực KYC';

  @override
  String get supportAboutPillar1Body =>
      'Mọi hồ sơ đối tác Chủ nhà đều trải qua bước xác minh danh tính và kiểm duyệt thông tin, hình ảnh thực tế trước khi mở lịch đón khách.';

  @override
  String get supportAboutPillar2Title =>
      'Khóa lịch chống đặt trùng (Zero Double-Booking)';

  @override
  String get supportAboutPillar2Body =>
      'Cơ chế khóa ngày mức giao dịch ngay khi tạo đơn giúp bảo vệ tuyệt đối lịch lưu trú của đoàn trong suốt thời gian thanh toán.';

  @override
  String get supportAboutPillar3Title => 'Giá niêm yết minh bạch theo từng đêm';

  @override
  String get supportAboutPillar3Body =>
      'Hiển thị rõ giá ngày thường, giá cuối tuần, phí vệ sinh và phụ thu khách vượt tiêu chuẩn từ dữ liệu máy chủ trước khi thanh toán.';

  @override
  String get supportAboutCtaTitle => 'Đồng hành cùng The Palm Villa';

  @override
  String get supportAboutCtaDesc =>
      'Khám phá các căn biệt thự đang mở lịch hoặc đăng ký trở thành đối tác Chủ nhà để quản lý lịch và doanh thu minh bạch.';

  @override
  String get supportAboutPrimaryAction => 'Khám phá nơi lưu trú';

  @override
  String get supportAboutSecondaryAction => 'Trở thành Host';

  @override
  String get supportExploreVtEyebrow => 'Bản đồ phân khu nghỉ dưỡng';

  @override
  String get supportExploreVtTitle =>
      'Khám phá Vũng Tàu theo từng phân khu biển';

  @override
  String get supportExploreVtSubtitle =>
      'Mỗi phân khu tại Vũng Tàu mang một nét trải nghiệm riêng. Chọn khu vực phù hợp với lịch trình của đoàn để lọc ngay các căn biệt thự thực tế.';

  @override
  String get supportExploreVtCtaTitle =>
      'Kết hợp lịch trình ăn chơi & kinh nghiệm đi biển';

  @override
  String get supportExploreVtCtaDesc =>
      'Tham khảo thêm các bài viết cẩm nang du lịch địa phương để lên kế hoạch trọn vẹn cho kỳ nghỉ tại Vũng Tàu.';

  @override
  String get supportExploreVtPrimaryAction => 'Đọc Cẩm nang du lịch';

  @override
  String get supportExploreVtSecondaryAction => 'Mở bản đồ tìm kiếm';

  @override
  String get supportAddonEyebrow => 'Tiện nghi & Trải nghiệm';

  @override
  String get supportAddonTitle => 'Tiện ích biệt thự & Dịch vụ lưu trú đi kèm';

  @override
  String get supportAddonSubtitle =>
      'Tổng hợp các nhóm tiện nghi đặc trưng của biệt thự nguyên căn và cách trao đổi nhu cầu chuẩn bị tiệc BBQ, đậu xe đoàn cùng Chủ nhà.';

  @override
  String get supportAddonNoteTitle =>
      'Cách đặt dịch vụ hoặc yêu cầu chuẩn bị trước giờ nhận phòng';

  @override
  String get supportAddonNoteBody =>
      'Mỗi căn biệt thự có cấu hình tiện nghi và quy định phụ thu khách đoàn riêng được niêm yết công khai. Sau khi chọn căn ưng ý, bạn có thể nhấn Nhắn tin cho Host ngay trên trang chi tiết để xác nhận các nhu cầu riêng.';

  @override
  String get supportAddonCtaTitle =>
      'Tìm biệt thự có đầy đủ hồ bơi riêng & sân BBQ?';

  @override
  String get supportAddonCtaDesc =>
      'Sử dụng bộ lọc đa tiêu chí trên trang Tìm kiếm để chọn chính xác các tiện ích đoàn của bạn mong muốn.';

  @override
  String get supportAddonPrimaryAction => 'Mở bộ lọc nơi lưu trú';

  @override
  String get supportAddonSecondaryAction => 'Liên hệ tư vấn đoàn';

  @override
  String get supportMemberEyebrow => 'Quyền lợi tài khoản';

  @override
  String get supportMemberTitle => 'Ưu đãi thành viên & Mã giảm giá đặt phòng';

  @override
  String get supportMemberSubtitle =>
      'Đăng ký tài khoản thành viên miễn phí để áp dụng mã ưu đãi trực tiếp khi đặt biệt thự, đồng bộ danh sách yêu thích và quản lý lịch sử chuyến đi.';

  @override
  String get supportMemberNote1Title =>
      'Sử dụng Mã giảm giá (Coupon) trực tiếp khi đặt phòng';

  @override
  String get supportMemberNote1Body =>
      'Thành viên đã đăng nhập có thể áp dụng mã ưu đãi theo phần trăm (%) hoặc số tiền cố định trên trang chi tiết biệt thự. Hệ thống tự động kiểm tra hạn dùng, giá trị đơn tối thiểu và số lượt sử dụng của từng tài khoản.';

  @override
  String get supportMemberNote2Title =>
      'Đồng bộ Danh sách yêu thích & Theo dõi Chuyến đi thời gian thực';

  @override
  String get supportMemberNote2Body =>
      'Lưu lại các căn biệt thự ưng ý trên mọi thiết bị, nhận thông báo trạng thái đơn tức thời và nhắn tin trực tiếp với Chủ nhà không qua trung gian.';

  @override
  String get supportMemberCtaTitle =>
      'Áp dụng ưu đãi cho kỳ nghỉ sắp tới tại Vũng Tàu';

  @override
  String get supportMemberCtaDesc =>
      'Chọn căn biệt thự yêu thích, kiểm tra giá niêm yết theo đêm và nhập mã giảm giá ngay tại bước xác nhận đặt phòng.';

  @override
  String get supportMemberPrimaryAction => 'Tìm biệt thự đang mở lịch';

  @override
  String get supportMemberSecondaryAction => 'Danh sách yêu thích';

  @override
  String get supportReportTargetBooking => 'Đơn đặt phòng (Mã Booking)';

  @override
  String get supportReportTargetListing => 'Chỗ nghỉ / Biệt thự (Mã Villa)';

  @override
  String get supportReportTargetReview => 'Đánh giá lưu trú (Mã Review)';

  @override
  String get supportReportTargetUser => 'Tài khoản người dùng (Mã User)';

  @override
  String get supportReportSuccessMessage =>
      'Đã ghi nhận phản ánh thành công. Bộ phận Kiểm duyệt & An toàn sẽ đối soát và phản hồi sớm nhất.';

  @override
  String get supportReportErrorFallback =>
      'Không thể gửi phản ánh lúc này. Vui lòng thử lại.';

  @override
  String get supportReportStatusResolved => 'Đã giải quyết';

  @override
  String get supportReportStatusRejected => 'Đã từ chối';

  @override
  String get supportReportStatusOpen => 'Đang xử lý';

  @override
  String get supportReportGuestCardTitle =>
      'Gửi báo cáo & khiếu nại trực tuyến';

  @override
  String get supportReportGuestCardBody =>
      'Để đảm bảo tính xác thực và đối soát đúng mã đơn đặt phòng, vui lòng đăng nhập tài khoản trước khi gửi phản ánh trực tuyến hoặc kết nối nhanh qua trang Liên hệ.';

  @override
  String get supportReportLoginAction => 'Đăng nhập để gửi phản ánh';

  @override
  String get supportReportDirectContactAction => 'Mở kênh Liên hệ trực tiếp';

  @override
  String get supportReportAuthCardTitle =>
      'Gửi phản ánh / báo cáo tới bộ phận Kiểm duyệt';

  @override
  String get supportReportAuthCardSubtitle =>
      'Thông tin phản ánh được lưu vết trực tiếp để Quản trị viên kiểm tra và phản hồi minh bạch.';

  @override
  String get supportReportTargetGroupLabel => 'Nhóm đối tượng phản ánh';

  @override
  String get supportReportTargetIdLabel =>
      'Mã định danh số (ví dụ: mã đơn 102 hoặc mã villa 15)';

  @override
  String get supportReportTargetIdError =>
      'Vui lòng nhập mã số nguyên dương hợp lệ';

  @override
  String get supportReportReasonLabel => 'Tiêu đề khiếu nại / góp ý';

  @override
  String get supportReportReasonEmptyError => 'Vui lòng nhập tiêu đề phản ánh';

  @override
  String get supportReportReasonMaxError => 'Tối đa 255 ký tự';

  @override
  String get supportReportDescLabel => 'Mô tả chi tiết sự việc (tùy chọn)';

  @override
  String get supportReportSubmittingLabel => 'Đang gửi phản ánh...';

  @override
  String get supportReportSubmitAction => 'Gửi phản ánh';

  @override
  String supportReportRecentTitle(int count) {
    return 'Phản ánh gần đây của bạn ($count)';
  }

  @override
  String get supportCouponEmptyError => 'Vui lòng nhập mã ưu đãi cần kiểm tra.';

  @override
  String supportCouponValidStatus(String code, String discount) {
    return 'Mã $code hợp lệ — ước tính giảm $discount cho đơn tạm tính.';
  }

  @override
  String get supportCouponInvalidFallback =>
      'Mã ưu đãi chưa đủ điều kiện hoặc đã hết hạn.';

  @override
  String get supportCouponCheckError => 'Không thể kiểm tra mã ưu đãi lúc này.';

  @override
  String get supportCouponCardTitle => 'Tra cứu hiệu lực Mã ưu đãi (Coupon)';

  @override
  String get supportCouponGuestHint =>
      'Đăng nhập tài khoản thành viên để kiểm tra trực tiếp hiệu lực mã giảm giá theo giá trị đơn dự kiến hoặc áp dụng ngay tại bước đặt biệt thự.';

  @override
  String get supportCouponAuthHint =>
      'Nhập mã ưu đãi bạn đang có và giá trị đơn lưu trú dự kiến (VNĐ) để kiểm tra điều kiện áp dụng trực tiếp từ hệ thống.';

  @override
  String get supportCouponLoginAction => 'Đăng nhập thành viên';

  @override
  String get supportCouponRegisterAction => 'Tạo tài khoản miễn phí';

  @override
  String get supportCouponCodeInputLabel => 'Mã ưu đãi (ví dụ: PALM2026)';

  @override
  String get supportCouponAmountInputLabel => 'Giá trị đơn tạm tính (VNĐ)';

  @override
  String get supportCouponCheckingLabel => 'Đang kiểm tra...';

  @override
  String get supportCouponCheckAction => 'Kiểm tra mã ưu đãi';

  @override
  String get homeEmptyApprovedVillas =>
      'Hiện chưa có căn biệt thự nào đã được phê duyệt trên hệ thống.';

  @override
  String homeApprovedVillasCountTitle(int count) {
    return 'Danh sách chỗ nghỉ đã duyệt ($count)';
  }

  @override
  String get homePrevVillaTooltip => 'Căn trước';

  @override
  String get homeNextVillaTooltip => 'Căn tiếp theo';

  @override
  String get homeFavoriteAdd => 'Lưu vào yêu thích';

  @override
  String get homeFavoriteRemove => 'Bỏ khỏi yêu thích';

  @override
  String homeCardSpecsSummary(int bedrooms, int guests) {
    return '$bedrooms PN · Tối đa $guests khách';
  }

  @override
  String get searchFilterBtn => 'Bộ lọc';

  @override
  String searchFilterActiveBtn(int count) {
    return 'Bộ lọc ($count)';
  }

  @override
  String get searchShowMapBtn => 'Hiện bản đồ';

  @override
  String get searchHideMapBtn => 'Ẩn bản đồ';

  @override
  String get searchClearAllBtn => 'Xóa tất cả';

  @override
  String searchFoundStaysCount(int count) {
    return 'Tìm thấy $count chỗ nghỉ tại Vũng Tàu';
  }

  @override
  String favoritesSavedCountSubtitle(int count) {
    return '$count căn biệt thự đã lưu';
  }

  @override
  String get favoritesSyncOfflineNotice =>
      'Không thể đồng bộ máy chủ — đang hiển thị danh sách lưu trên thiết bị.';

  @override
  String favoritesInvalidCountNotice(int count) {
    return 'Có $count chỗ nghỉ không còn mở lịch nhận khách.';
  }

  @override
  String get favoritesExploreAction => 'Khám phá biệt thự';

  @override
  String get contactEyebrow => 'HỖ TRỢ TRỰC TIẾP VŨNG TÀU';

  @override
  String get contactBrowseVillas => 'Xem danh sách Villa';

  @override
  String get contactHeroTitle => 'Liên hệ đội ngũ tư vấn & vận hành lưu trú';

  @override
  String get contactHeroSubtitle =>
      'Hỗ trợ kiểm tra lịch trống, tư vấn chọn căn theo đoàn và giải đáp thông tin lưu trú tại TP. Vũng Tàu.';

  @override
  String get contactHotlineTitle => 'Hotline & Zalo tư vấn';

  @override
  String get contactVerifiedBadge => 'Xác thực';

  @override
  String get contactCallNow => 'Gọi ngay';

  @override
  String get contactCopyHotlineTooltip => 'Sao chép số Hotline';

  @override
  String get contactCopiedHotline => 'Đã sao chép số Hotline vào bộ nhớ tạm';

  @override
  String get contactOpenZalo => 'Nhắn Zalo OA';

  @override
  String get contactOfficeTitle => 'Văn phòng đón tiếp tại Vũng Tàu';

  @override
  String get contactMapAction => 'Xem bản đồ đường đi';

  @override
  String get contactEmailTitle => 'Hòm thư hỗ trợ & đối soát';

  @override
  String get contactSameDayReply => 'Phản hồi trong ngày';

  @override
  String get contactSendEmail => 'Gửi Email hỗ trợ';

  @override
  String get contactCopyEmailTooltip => 'Sao chép địa chỉ Email';

  @override
  String get contactCopiedEmail => 'Đã sao chép địa chỉ Email vào bộ nhớ tạm';

  @override
  String get authWelcomeBack => 'Chào mừng trở lại';

  @override
  String get authLoginSubtitle =>
      'Đăng nhập để xem kỳ nghỉ và quản lý chuyến đi của bạn tại The Palm Villa.';

  @override
  String get authIdentifierLabel => 'Email hoặc số điện thoại';

  @override
  String get authIdentifierHint => 'Nhập email hoặc số điện thoại Việt Nam';

  @override
  String get authPasswordLabel => 'Mật khẩu';

  @override
  String get authPasswordHint => 'Nhập mật khẩu';

  @override
  String get authShowPasswordTooltip => 'Hiện mật khẩu';

  @override
  String get authHidePasswordTooltip => 'Ẩn mật khẩu';

  @override
  String get authRememberMe => 'Ghi nhớ đăng nhập';

  @override
  String get authSigningIn => 'Đang đăng nhập...';

  @override
  String get authOrDivider => 'HOẶC';

  @override
  String get authGoogleLoginBtn => 'Đăng nhập với Google';

  @override
  String get authNoAccountYet => 'Chưa có tài khoản?';

  @override
  String get authRegisterBtn => 'Đăng ký';

  @override
  String get authCreateAccountTitle => 'Tạo tài khoản mới';

  @override
  String get authRegisterSubtitle =>
      'Trải nghiệm đặt phòng villa nghỉ dưỡng đẳng cấp và nhận ưu đãi độc quyền.';

  @override
  String get authFullNameLabel => 'Họ và tên';

  @override
  String get authFullNameHint => 'Nhập họ và tên';

  @override
  String get authPhoneRequiredLabel => 'Số điện thoại *';

  @override
  String get authPhoneHint => 'Nhập số điện thoại Việt Nam (vd: 0901234567)';

  @override
  String get authEmailRequiredLabel => 'Email *';

  @override
  String get authEmailHint => 'Nhập địa chỉ email';

  @override
  String get authPasswordCreateHint =>
      'Tạo mật khẩu (tối thiểu 8 ký tự, gồm chữ và số)';

  @override
  String get authConfirmPasswordLabel => 'Xác nhận mật khẩu *';

  @override
  String get authConfirmPasswordHint => 'Nhập lại mật khẩu vừa tạo';

  @override
  String authPasswordStrengthLabel(String level) {
    return 'Độ mạnh mật khẩu: $level';
  }

  @override
  String get authStrengthWeak => 'Yếu';

  @override
  String get authStrengthFair => 'Trung bình';

  @override
  String get authStrengthGood => 'Khá';

  @override
  String get authStrengthStrong => 'Mạnh';

  @override
  String get authTermsAgreement =>
      'Tôi đồng ý với Điều khoản dịch vụ và Chính sách bảo mật của The Palm Villa';

  @override
  String get authTermsRequiredError =>
      'Vui lòng đồng ý với Điều khoản dịch vụ và Chính sách bảo mật';

  @override
  String get authCreatingAccount => 'Đang tạo tài khoản...';

  @override
  String get authAlreadyHaveAccount => 'Bạn đã có tài khoản?';

  @override
  String get authForgotQuestionTitle => 'Quên mật khẩu?';

  @override
  String get authOtpVerifyTitle => 'Xác thực mã OTP';

  @override
  String get authPasswordChangedTitle => 'Đổi mật khẩu thành công';

  @override
  String get authForgotRequestSubtitle =>
      'Nhập email hoặc số điện thoại đã đăng ký để nhận mã xác thực khôi phục mật khẩu.';

  @override
  String get authForgotOtpSubtitle =>
      'Nhập 6 chữ số OTP và thiết lập mật khẩu mới.';

  @override
  String get authForgotSuccessSubtitle =>
      'Mật khẩu của bạn đã được cập nhật an toàn.';

  @override
  String get authSendOtpButton => 'Gửi mã xác thực';

  @override
  String authOtpSentTo(String target) {
    return 'Mã OTP đã gửi tới: $target';
  }

  @override
  String get authOtpSixDigitsLabel => 'Mã OTP gồm 6 chữ số';

  @override
  String get authNewPasswordLabel => 'Mật khẩu mới';

  @override
  String authResendOtpCountdown(String seconds) {
    return 'Gửi lại sau 00:$seconds';
  }

  @override
  String get authResendOtpButton => 'Gửi lại mã OTP';

  @override
  String get authConfirmOtpButton => 'Xác nhận mã OTP';

  @override
  String get authOtpSuccessBanner =>
      'Mã OTP đã được xác thực và mật khẩu mới đã sẵn sàng sử dụng.';

  @override
  String get authBackToLoginButton => 'Quay lại đăng nhập';

  @override
  String get adminTabFinance => 'Tài chính & Chi trả';

  @override
  String get adminTabBlog => 'Cẩm nang Blog';

  @override
  String get adminTabTrustSafety => 'Báo cáo & Khiếu nại';
}
