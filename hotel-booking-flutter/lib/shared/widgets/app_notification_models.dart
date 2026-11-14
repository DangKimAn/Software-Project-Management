// CONFLICT-RESOLVED: Tách mô hình dữ liệu thông báo (AppNotificationItem & NotificationsState) thành tệp độc lập khỏi app_header_footer.dart theo nguyên tắc đơn trách nhiệm và gộp đầy đủ hàm bản địa hóa thông báo + quy đổi tiền tệ từ nhánh develop.
import '../../core/currency/money_display_policy.dart';
import '../../core/currency/money_formatter.dart';

class AppNotificationItem {
  final String id;
  final String notificationLogId;
  final String eventType;
  final String? targetType;
  final String? targetId;
  final String title;
  final String body;
  final String? actionUrl;
  final Map<String, dynamic>? payload;
  final bool isRead;
  final String? readAt;
  final String createdAt;
  final String? updatedAt;

  const AppNotificationItem({
    required this.id,
    String? notificationLogId,
    String? eventType,
    String? type,
    this.targetType,
    this.targetId,
    required this.title,
    String? body,
    String? message,
    this.actionUrl,
    this.payload,
    Map<String, dynamic>? metadata,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    this.updatedAt,
  })  : notificationLogId = notificationLogId ?? id,
        eventType = eventType ?? type ?? 'system',
        body = body ?? message ?? '';

  static final RegExp _legacyVillaBrandPattern =
      RegExp(r'Minh\s*Th(?:ành|anh)\s+Villa', caseSensitive: false);
  static final RegExp _legacyLuxuryBrandPattern =
      RegExp(r'MinhThanh\s+Luxury', caseSensitive: false);

  /// Normalizes legacy brand text from historical DB notification records to The Palm Villa.
  static String normalizeBrandText(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAll(_legacyVillaBrandPattern, 'The Palm Villa')
        .replaceAll(_legacyLuxuryBrandPattern, 'The Palm Luxury');
  }

  /// Backward-compatible getters
  String get type => eventType;
  String get message => body;
  Map<String, dynamic>? get metadata => payload;
  bool get forAdmin =>
      payload?['forAdmin'] == true ||
      payload?['isAdminNotification'] == true ||
      payload?['targetRole'] == 'admin' ||
      title.startsWith('[Admin]') ||
      title.toLowerCase().contains('cần xử lý') ||
      title.toLowerCase().contains('cần duyệt');

  // CONFLICT-RESOLVED: Bổ sung các hàm bản địa hóa tiêu đề/nội dung thông báo theo VI/EN/KO và quy đổi tiền tệ trực tiếp từ nhánh develop vào AppNotificationItem.
  // Giải thuật bản địa hóa và quy đổi tiền tệ trong thông báo thời gian thực:
  // Ánh xạ tiêu đề/mẫu thông báo hệ thống sang ngôn ngữ hiện hành (`vi`/`en`/`ko`) và định dạng lại các mệnh giá `VND` sang ngoại tệ tham chiếu khi người dùng bật chế độ ngoại tệ.
  String titleDisplayFor(String? localeCode, [MoneyFormatter? formatter]) {
    final localized = localizeNotificationTitle(title, eventType, localeCode);
    return convertCurrencyInText(localized, formatter);
  }

  String bodyDisplayFor(String? localeCode, [MoneyFormatter? formatter]) {
    final converted = convertCurrencyInText(body, formatter);
    return localizeNotificationBody(converted, localeCode);
  }

  static String convertCurrencyInText(String text, MoneyFormatter? formatter) {
    if (formatter == null || !formatter.effectiveCurrency.isForeign) {
      return text;
    }
    final moneyRegex = RegExp(
      r'(\d{1,3}(?:[.,]\d{3})+|\d{5,})\s*(?:₫|đ|VND|vnd|VNĐ|vnđ)',
      caseSensitive: false,
    );
    return text.replaceAllMapped(moneyRegex, (match) {
      final rawDigits = match.group(1)!.replaceAll(RegExp(r'[.,]'), '');
      final amount = int.tryParse(rawDigits);
      if (amount == null || amount <= 0) return match.group(0)!;
      final res =
          formatter.format(amount, context: MoneyDisplayContext.breakdown);
      return res.formatted;
    });
  }

  static String localizeNotificationTitle(
    String rawTitle,
    String? eventType,
    String? localeCode,
  ) {
    if (rawTitle.isEmpty) return rawTitle;
    final isEn = localeCode == 'en' ||
        (localeCode != null && localeCode.startsWith('en'));
    final isKo = localeCode == 'ko' ||
        (localeCode != null && localeCode.startsWith('ko'));
    if (!isEn && !isKo) return rawTitle;

    final trimmed = rawTitle.trim();
    final lower = trimmed.toLowerCase();
    final eType = (eventType ?? '').toUpperCase();

    if (lower == 'thanh toán thành công' || eType == 'PAYMENT_SUCCESS') {
      return isEn ? 'Payment successful' : '결제 완료';
    }
    if (lower == 'thanh toán đang chờ xử lý' || eType == 'PAYMENT_PENDING') {
      return isEn ? 'Payment pending' : '결제 대기 중';
    }
    if (lower == 'booking đã được tạo' ||
        lower == 'đặt phòng đã được tạo' ||
        eType == 'BOOKING_CREATED') {
      return isEn ? 'Booking created' : '예약 생성 완료';
    }
    if (lower == 'phiên thanh toán đã hết hạn' ||
        lower == 'booking đã hết hạn thanh toán' ||
        eType == 'PAYMENT_EXPIRED') {
      return isEn ? 'Payment session expired' : '결제 세션 만료';
    }
    if (lower.startsWith('đặt phòng đã được xác nhận') ||
        lower.startsWith('booking đã được xác nhận') ||
        eType == 'BOOKING_CONFIRMED') {
      return isEn ? 'Booking confirmed' : '예약 확정';
    }
    if (lower == 'bạn đã xác nhận booking') {
      return isEn ? 'Booking confirmed by you' : '예약 확정 완료';
    }
    if (lower == 'booking đã thanh toán') {
      return isEn ? 'Booking paid' : '예약 결제 완료';
    }
    if (lower == 'có booking mới') {
      return isEn ? 'New booking received' : '새 예약 접수';
    }
    if (lower == 'booking đã bị hủy' ||
        lower == 'đặt phòng đã bị hủy' ||
        eType == 'BOOKING_CANCELLED') {
      return isEn ? 'Booking cancelled' : '예약 취소';
    }
    if (lower == 'có refund mới cần xử lý' ||
        lower.contains('refund mới cần xử lý')) {
      return isEn ? 'New refund request pending review' : '새 환불 요청 대기 중';
    }
    if (lower == 'có yêu cầu rút tiền host cần duyệt') {
      return isEn ? 'Host payout request pending review' : '호스트 정산 승인 대기 중';
    }
    if (lower == 'yêu cầu hoàn tiền đã được tạo' || eType == 'REFUND_CREATED') {
      return isEn ? 'Refund request created' : '환불 요청 생성';
    }
    if (lower == 'hoàn tiền thành công' || eType == 'REFUND_SUCCESS') {
      return isEn ? 'Refund successful' : '환불 완료';
    }
    if (lower == 'payout đã được tạo' || eType == 'PAYOUT_CREATED') {
      return isEn ? 'Payout created' : '정산 내역 생성';
    }
    if (lower == 'có đánh giá mới' || eType == 'REVIEW_CREATED') {
      return isEn ? 'New review received' : '새 후기 등록';
    }
    if (lower.contains('hồ sơ đối tác đã được duyệt') ||
        lower.contains('hồ sơ host đã được duyệt') ||
        eType == 'HOST_APPLICATION_APPROVED') {
      return isEn ? 'Host application approved' : '호스트 신청 승인';
    }
    if (lower.contains('hồ sơ đăng ký host bị từ chối') ||
        lower.contains('hồ sơ host bị từ chối') ||
        eType == 'HOST_APPLICATION_REJECTED') {
      return isEn ? 'Host application rejected' : '호스트 신청 거절';
    }
    if (lower == 'listing đã được duyệt' || eType == 'LISTING_APPROVED') {
      return isEn ? 'Listing approved' : '숙소 등록 승인';
    }
    if (lower == 'listing bị từ chối' || eType == 'LISTING_REJECTED') {
      return isEn ? 'Listing rejected' : '숙소 등록 거절';
    }
    if (lower == 'tin đăng đã gửi kiểm duyệt' || eType == 'LISTING_SUBMITTED') {
      return isEn ? 'Listing submitted for review' : '숙소 검토 요청 제출';
    }
    if (lower.contains('có hồ sơ host mới chờ duyệt')) {
      return isEn
          ? '[Admin] New host application awaiting review'
          : '[Admin] 새 호스트 승인 대기 중';
    }
    if (lower.contains('có listing mới chờ duyệt')) {
      return isEn
          ? '[Admin] New listing awaiting review'
          : '[Admin] 새 숙소 승인 대기 중';
    }
    if (lower.contains('xin chào đến với the palm villa')) {
      return isEn ? 'Welcome to The Palm Villa' : 'The Palm Villa에 오신 것을 환영합니다';
    }
    if (lower.contains('thông báo điều chỉnh mức phí nền tảng')) {
      return isEn ? 'Platform fee adjustment notice' : '플랫폼 수수료 조정 안내';
    }
    if (lower == 'thông báo mới') {
      return isEn ? 'New notification' : '새 알림';
    }
    if (lower == 'thông báo') {
      return isEn ? 'Notification' : '알림';
    }

    return rawTitle;
  }

  static String localizeNotificationBody(
    String rawBody,
    String? localeCode,
  ) {
    if (rawBody.isEmpty) return rawBody;
    final isEn = localeCode == 'en' ||
        (localeCode != null && localeCode.startsWith('en'));
    final isKo = localeCode == 'ko' ||
        (localeCode != null && localeCode.startsWith('ko'));
    if (!isEn && !isKo) return rawBody;

    final trimmed = rawBody.trim();

    if (trimmed == 'Vui lòng hoàn tất thanh toán để giữ chỗ.') {
      return isEn
          ? 'Please complete payment to secure your reservation.'
          : '예약을 유지하려면 결제를 완료해 주세요.';
    }

    final mSuccess = RegExp(
      r'^(?:Booking|Báo cáo)\s*#(\d+)\s+đã thanh toán thành công\.?\s*(?:Host sẽ.*)?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mSuccess != null) {
      final id = mSuccess.group(1);
      return isEn
          ? 'Booking #$id paid successfully. Host will confirm your booking.'
          : '예약 #$id 결제가 완료되었습니다. 호스트가 확정할 예정입니다.';
    }

    final mPaidWait = RegExp(
      r'^Booking\s*#(\d+)\s+đã thanh toán và đang chờ xác nhận\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mPaidWait != null) {
      final id = mPaidWait.group(1);
      return isEn
          ? 'Booking #$id paid and awaiting host confirmation.'
          : '예약 #$id 결제가 완료되어 호스트 확정 대기 중입니다.';
    }

    final mPending = RegExp(
      r'^Thanh toán\s*#(\d+)\s+cho booking\s*#(\d+)\s+đang chờ (?:hoàn tất|xử lý)\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mPending != null) {
      final pId = mPending.group(1);
      final bId = mPending.group(2);
      return isEn
          ? 'Payment #$pId for booking #$bId is pending completion.'
          : '예약 #$bId의 결제 #$pId 처리가 대기 중입니다.';
    }

    final mExpired = RegExp(
      r'^Booking\s*#(\d+)\s+đã hết hạn thanh toán\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mExpired != null) {
      final id = mExpired.group(1);
      return isEn
          ? 'Booking #$id payment session has expired.'
          : '예약 #$id의 결제 유효 시간이 만료되었습니다.';
    }

    final mUnpaid = RegExp(
      r'^Booking\s*#(\d+)\s+không được thanh toán đúng hạn\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mUnpaid != null) {
      final id = mUnpaid.group(1);
      return isEn
          ? 'Booking #$id was not paid on time.'
          : '예약 #$id이(가) 제시간에 결제되지 않았습니다.';
    }

    final mHostConf = RegExp(
      r'^Host đã xác nhận booking\s*#(\d+)\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mHostConf != null) {
      final id = mHostConf.group(1);
      return isEn
          ? 'Host has confirmed booking #$id.'
          : '호스트가 예약 #$id을(를) 확정했습니다.';
    }

    final mWaitGuest = RegExp(
      r'^Booking\s*#(\d+)\s+đang chờ khách thanh toán\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mWaitGuest != null) {
      final id = mWaitGuest.group(1);
      return isEn
          ? 'Booking #$id is awaiting guest payment.'
          : '예약 #$id이(가) 게스트 결제 대기 중입니다.';
    }

    final mConf = RegExp(
      r'^Booking\s*#(\d+)\s+đã được xác nhận\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mConf != null) {
      final id = mConf.group(1);
      return isEn ? 'Booking #$id has been confirmed.' : '예약 #$id이(가) 확정되었습니다.';
    }

    final mCancel = RegExp(
      r'^Booking\s*#(\d+)\s+đã bị hủy\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mCancel != null) {
      final id = mCancel.group(1);
      return isEn ? 'Booking #$id has been cancelled.' : '예약 #$id이(가) 취소되었습니다.';
    }

    final mRefund = RegExp(
      r'^Hoàn tiền\s+(.+?)\s+cho booking\s*#(\d+)\s+đang chờ xử lý\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mRefund != null) {
      final amt = mRefund.group(1);
      final id = mRefund.group(2);
      return isEn
          ? 'Refund of $amt for booking #$id is pending processing.'
          : '예약 #$id의 환불금 $amt 처리가 대기 중입니다.';
    }

    final mPayout = RegExp(
      r'^Payout\s*#(\d+)\s+trị giá\s+(.+?)\s+đang chờ xử lý\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mPayout != null) {
      final id = mPayout.group(1);
      final amt = mPayout.group(2);
      return isEn
          ? 'Payout #$id for $amt is pending processing.'
          : '정산 #$id($amt) 처리가 대기 중입니다.';
    }

    final mReview = RegExp(
      r'^(.+?)\s+đã đánh giá\s+(\d+(?:\.\d+)?)/5\s+cho\s+(.+)\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mReview != null) {
      final user = mReview.group(1);
      final rating = mReview.group(2);
      final listing = mReview.group(3);
      return isEn
          ? '$user left a $rating/5 rating for $listing.'
          : '$user님이 $listing에 $rating/5점 후기를 남겼습니다.';
    }

    if (trimmed.contains('Chào mừng bạn đến với The Palm Villa!')) {
      return isEn
          ? 'Welcome to The Palm Villa! Your account has been created successfully.'
          : 'The Palm Villa에 오신 것을 환영합니다! 계정이 성공적으로 생성되었습니다.';
    }
    if (trimmed.contains('Chúc mừng bạn đã trở thành Host!')) {
      return isEn
          ? 'Congratulations on becoming a Host! You can now list properties and manage bookings.'
          : '호스트가 되신 것을 축하합니다! 이제 숙소를 등록하고 예약을 관리할 수 있습니다.';
    }

    final mListingApproved = RegExp(
      r'^(.+?)\s+đã được duyệt và hiển thị trên hệ thống\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mListingApproved != null) {
      final listing = mListingApproved.group(1);
      return isEn
          ? '$listing has been approved and is now active.'
          : '$listing이(가) 승인되어 시스템에 게시되었습니다.';
    }

    final mListingWait = RegExp(
      r'^(.+?)\s+đang chờ đội ngũ kiểm duyệt\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mListingWait != null) {
      final listing = mListingWait.group(1);
      return isEn
          ? '$listing is awaiting review by our team.'
          : '$listing이(가) 검토 대기 중입니다.';
    }

    final mListingNeed = RegExp(
      r'^(.+?)\s+cần được kiểm duyệt\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mListingNeed != null) {
      final listing = mListingNeed.group(1);
      return isEn ? '$listing requires review.' : '$listing 검토가 필요합니다.';
    }

    final mPalmConfirm = RegExp(
      r'Chủ biệt thự The Palm Villa đã xác nhận kỳ nghỉ\s*#(\d+)\s+của bạn tại\s+(.+?)\s+từ ngày\s+(\S+)\s+đến\s+(\S+)\.?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mPalmConfirm != null) {
      final id = mPalmConfirm.group(1);
      final place = mPalmConfirm.group(2);
      final from = mPalmConfirm.group(3);
      final to = mPalmConfirm.group(4);
      return isEn
          ? 'The Palm Villa host confirmed your stay #$id at $place from $from to $to.'
          : 'The Palm Villa 호스트가 $place에서의 예약 #$id($from ~ $to)을 확정했습니다.';
    }

    return rawBody;
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> rawJson) {
    final json = rawJson['notification'] is Map
        ? Map<String, dynamic>.from(rawJson['notification'] as Map)
        : rawJson;

    final resolvedId = (json['notificationLogId'] ??
            json['notificationId'] ??
            json['id'] ??
            '')
        .toString();

    Map<String, dynamic>? parsedPayload;
    if (json['payload'] is Map) {
      parsedPayload = Map<String, dynamic>.from(json['payload'] as Map);
    } else if (json['metadata'] is Map) {
      parsedPayload = Map<String, dynamic>.from(json['metadata'] as Map);
    }

    final rawActionUrl = json['actionUrl']?.toString().trim();
    final rawTargetType = json['targetType']?.toString().trim();
    final rawTargetId = json['targetId']?.toString().trim();

    return AppNotificationItem(
      id: resolvedId,
      notificationLogId: (json['notificationLogId'] ?? resolvedId).toString(),
      eventType: (json['eventType'] ?? json['type'] ?? 'system').toString(),
      targetType: (rawTargetType != null && rawTargetType.isNotEmpty)
          ? rawTargetType
          : null,
      targetId:
          (rawTargetId != null && rawTargetId.isNotEmpty) ? rawTargetId : null,
      title: normalizeBrandText((json['title'] ?? 'Thông báo').toString()),
      body: normalizeBrandText(
          (json['body'] ?? json['message'] ?? json['content'] ?? '')
              .toString()),
      actionUrl: (rawActionUrl != null && rawActionUrl.isNotEmpty)
          ? rawActionUrl
          : null,
      payload: parsedPayload,
      isRead: json['isRead'] == true || json['readAt'] != null,
      readAt: json['readAt']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  // Giải thuật phân giải đường dẫn nội bộ an toàn cho thông báo (Safe Internal Route Resolution):
  // Kiểm tra tính hợp lệ của `actionUrl` chống Open Redirect / XSS và ánh xạ thông báo hoàn tiền / rút tiền / phí nền tảng / đặt phòng theo đúng vai trò.
  // CONFLICT-RESOLVED: Hợp nhất luồng điều hướng thông báo Refund (`/admin/chi-tra`, `/account/trips`) và Payout (`/admin/chi-tra`, `/chu-nha/thanh-toan`) từ nhánh develop cùng luồng chuẩn hóa route `/host/...` -> `/chu-nha/...`.
  String? resolveInternalRoute() {
    final candidate = actionUrl?.trim() ?? '';
    final tType = (targetType ?? '').toLowerCase();
    final eType = eventType.toLowerCase();

    if (tType == 'refund' ||
        eType == 'refund_created' ||
        eType == 'refund_success' ||
        eType == 'refund_rejected' ||
        eType.contains('refund') ||
        title.toLowerCase().contains('refund') ||
        title.toLowerCase().contains('hoàn tiền')) {
      if (forAdmin ||
          candidate == '/admin' ||
          candidate == '/admin/chi-tra' ||
          candidate.startsWith('/admin') ||
          title.toLowerCase().contains('cần xử lý')) {
        return '/admin/chi-tra';
      }
      return '/account/trips';
    }

    if (tType == 'payout' ||
        eType == 'payout_created' ||
        eType == 'payout_paid' ||
        eType == 'payout_rejected' ||
        eType.contains('payout') ||
        title.toLowerCase().contains('payout') ||
        title.toLowerCase().contains('rút tiền')) {
      if (forAdmin ||
          candidate == '/admin' ||
          candidate == '/admin/chi-tra' ||
          candidate.startsWith('/admin') ||
          title.toLowerCase().contains('cần duyệt')) {
        return '/admin/chi-tra';
      }
      return '/chu-nha/thanh-toan';
    }

    if (candidate.isNotEmpty && isSafeInternalRoute(candidate)) {
      return _normalizeInternalRoute(candidate);
    }

    if (tType == 'booking' || eType.startsWith('booking.')) {
      if (eType == 'booking.created') {
        return '/chu-nha/dat-phong';
      }
      return '/account/trips';
    }

    if (tType == 'payment' || eType.startsWith('payment.')) {
      final bookingId = payload?['bookingId']?.toString() ?? '';
      if (bookingId.isNotEmpty) {
        return '/thanh-toan/$bookingId';
      }
      return '/account/trips';
    }

    if (tType == 'listing' ||
        eType.startsWith('listing.') ||
        eType.startsWith('listing_')) {
      if (forAdmin ||
          eType == 'listing.submitted_for_review' ||
          eType == 'listing_submitted' ||
          eType == 'listing.submitted') {
        return '/admin/kiem-duyet';
      }
      return '/chu-nha/cho-nghi';
    }

    if (tType == 'host_application' ||
        eType.startsWith('host_application.') ||
        eType.startsWith('host_application_')) {
      if (forAdmin ||
          eType == 'host_application.submitted' ||
          eType == 'host_application_submitted') {
        return '/admin/ho-so-host';
      }
      return '/tro-thanh-host/trang-thai';
    }

    if (tType == 'conversation' ||
        eType.contains('message') ||
        eType.contains('chat')) {
      final convId = targetId ?? payload?['conversationId']?.toString() ?? '';
      if (forAdmin) {
        return convId.isNotEmpty
            ? '/admin/tin-nhan?conversationId=$convId'
            : '/admin/tin-nhan';
      }
      if (convId.isNotEmpty) {
        return '/messages?conversationId=$convId';
      }
      return '/messages';
    }

    if (tType.contains('platform_fee') ||
        eType.contains('platform_fee') ||
        tType == 'payout' ||
        eType.startsWith('payout.')) {
      return forAdmin ? '/admin/tai-chinh' : '/chu-nha/bao-cao';
    }

    return null;
  }

  static bool isSafeInternalRoute(String url) {
    final trimmed = url.trim();
    if (!trimmed.startsWith('/') || trimmed.startsWith('//')) {
      return false;
    }
    if (RegExp(r'[\x00-\x1F\x7F\\]').hasMatch(trimmed)) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    if (lower.contains('://') ||
        lower.contains('..') ||
        lower.contains('%2f') ||
        lower.contains('%5c') ||
        lower.contains('%2e') ||
        lower.startsWith('/javascript:') ||
        lower.startsWith('/data:') ||
        lower.startsWith('/vbscript:')) {
      return false;
    }
    return true;
  }

  // Giải thuật ánh xạ chuẩn hóa đường dẫn thông báo nội bộ (`/host/...` -> `/chu-nha/...`):
  // Tách bảo toàn query string, ánh xạ tường minh `/host/bao-cao` -> `/chu-nha/bao-cao`
  // và tổng quát hóa mọi đường dẫn `/host/...` sang `/chu-nha/...` để thông báo Host (`PLATFORM_FEE_SCHEDULED`, v.v.) không bị lỗi 404.
  // CONFLICT-RESOLVED: Đồng bộ tiền tố route `/host/...` từ thông báo backend sang cây điều hướng `/chu-nha/...` trên GoRouter.
  static String _normalizeInternalRoute(String route) {
    final trimmed = route.trim();
    final qIndex = trimmed.indexOf('?');
    final pathPart = qIndex >= 0 ? trimmed.substring(0, qIndex) : trimmed;
    final querySuffix = qIndex >= 0 ? trimmed.substring(qIndex) : '';

    String mappedPath = pathPart;
    if (pathPart == '/host' || pathPart == '/host/') {
      mappedPath = '/chu-nha/tong-quan';
    } else if (pathPart == '/host/bookings') {
      mappedPath = '/chu-nha/dat-phong';
    } else if (pathPart == '/host/listings') {
      mappedPath = '/chu-nha/cho-nghi';
    } else if (pathPart == '/host/bao-cao' ||
        pathPart == '/host/reports' ||
        pathPart == '/host/earnings' ||
        pathPart == '/host/platform-fees') {
      mappedPath = '/chu-nha/bao-cao';
    } else if (pathPart == '/host/messages') {
      mappedPath = '/chu-nha/tin-nhan';
    } else if (pathPart == '/host/calendar') {
      mappedPath = '/chu-nha/lich';
    } else if (pathPart.startsWith('/host/')) {
      mappedPath = '/chu-nha/${pathPart.substring('/host/'.length)}';
    } else if (pathPart == '/admin/moderation') {
      mappedPath = '/admin/kiem-duyet';
    } else if (pathPart == '/admin/host-applications') {
      mappedPath = '/admin/ho-so-host';
    } else if (pathPart == '/admin/messages') {
      mappedPath = '/admin/tin-nhan';
    }

    return '$mappedPath$querySuffix';
  }

  AppNotificationItem copyWith({
    bool? isRead,
    String? readAt,
  }) {
    return AppNotificationItem(
      id: id,
      notificationLogId: notificationLogId,
      eventType: eventType,
      targetType: targetType,
      targetId: targetId,
      title: title,
      body: body,
      actionUrl: actionUrl,
      payload: payload,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class NotificationsState {
  final List<AppNotificationItem> items;
  final int unreadCount;
  final bool isLoading;

  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationsState copyWith({
    List<AppNotificationItem>? items,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
