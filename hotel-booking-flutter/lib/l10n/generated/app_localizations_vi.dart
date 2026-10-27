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
  String get searchPlaceholder => 'Bắt đầu tìm kiếm...';

  @override
  String get navDiscover => 'Khám phá';

  @override
  String get navZalo => 'Zalo';

  @override
  String get navHotline => 'Hotline';

  @override
  String get navFavorites => 'Yêu thích';

  @override
  String get navSettings => 'Cài đặt';

  @override
  String bedroomsCount(int count) {
    return '$count phòng';
  }

  @override
  String bedsCount(int count) {
    return '$count giường';
  }

  @override
  String guestsCapacity(int count) {
    return '$count khách';
  }

  @override
  String bathroomsCount(int count) {
    return '$count WC';
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
  String saturdayPrice(String price) {
    return 'Thứ 7: $price';
  }

  @override
  String get contactForPrice => 'Liên hệ báo giá';

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
  String get ctaViewDetail => 'Xem chi tiết';

  @override
  String get ctaCopyLink => 'Sao chép liên kết';

  @override
  String get ctaCopied => 'Đã sao chép liên kết vào bộ nhớ tạm';

  @override
  String get ctaRetry => 'Thử lại';

  @override
  String get ctaResetFilter => 'Đặt lại bộ lọc';

  @override
  String get loadingText => 'Đang tải dữ liệu...';

  @override
  String get emptyList => 'Không tìm thấy villa nào phù hợp';

  @override
  String get emptyListDesc =>
      'Hãy thử thay đổi tiêu chí tìm kiếm hoặc khoảng thời gian lưu trú.';

  @override
  String get errorOccurred => 'Đã có lỗi xảy ra';

  @override
  String get errorTryAgain => 'Vui lòng kiểm tra kết nối mạng và thử lại.';

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
  String get faqTitle => 'Câu hỏi thường gặp';

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
}
