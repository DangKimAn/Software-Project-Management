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
  String get footerCopyright =>
      '© 2026 The Palm Villa Vũng Tàu. Bảo lưu mọi quyền.';

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
}
