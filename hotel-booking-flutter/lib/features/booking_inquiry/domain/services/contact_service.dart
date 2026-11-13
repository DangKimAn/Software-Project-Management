import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/date/booking_date.dart';
import '../../../../core/logging/app_logger.dart';

/// Status of a contact/external launcher action.
enum ContactActionStatus {
  /// External application/dialer was successfully launched.
  launched,

  /// External launcher was unavailable or failed; target/draft was copied to clipboard.
  copiedFallback,

  /// Draft text was copied to clipboard with user consent without launching an external app.
  copiedDraftOnly,

  /// Configured hotline or Zalo URL is a placeholder/example and not verified for production.
  unverifiedConfig,

  /// Input phone number, URL, or consent state is invalid.
  invalidInput,

  /// Both external launch and clipboard fallback failed.
  failed,
}

/// Detailed result returned by [ContactService] operations so UI can render
/// accurate, non-deceptive feedback (never faking success).
class ContactActionResult {
  final ContactActionStatus status;
  final bool launched;
  final bool copiedToClipboard;
  final String message;
  final String? targetValue;

  const ContactActionResult({
    required this.status,
    required this.launched,
    required this.copiedToClipboard,
    required this.message,
    this.targetValue,
  });
}

abstract final class ContactService {
  /// Official Zalo domains permitted for OA / chat redirection.
  static const Set<String> allowedZaloHosts = {
    'zalo.me',
    'www.zalo.me',
    'oa.zalo.me',
    'chat.zalo.me',
  };

  /// Known sample/placeholder phone numbers used in sample configs (`config/*.json`).
  static const Set<String> _knownPlaceholderPhones = {
    '0901234567',
    '0123456789',
    '0987654321',
    '0912345678',
    '0900000000',
    '0000000000',
    '1234567890',
    '0999999999',
  };

  /// Injectable overrides for deterministic unit & widget testing.
  static Future<bool> Function(Uri uri)? canLaunchUrlOverride;
  static Future<bool> Function(Uri uri, LaunchMode mode)? launchUrlOverride;
  static Future<void> Function(String text)? clipboardSetDataOverride;

  /// Resets all test overrides to default platform implementations.
  static void resetTestOverrides() {
    canLaunchUrlOverride = null;
    launchUrlOverride = null;
    clipboardSetDataOverride = null;
  }

  /// Strips formatting separators (spaces, dots, dashes, parentheses) from a phone string.
  static String normalizePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll(RegExp(r'[\s\.\-\(\)]+'), '');
  }

  /// Converts a normalized phone number (`+84...` or `84...`) to canonical local `0...` form for comparison.
  static String _toLocalDigits(String normalized) {
    if (normalized.startsWith('+84')) {
      return '0${normalized.substring(3)}';
    }
    if (normalized.startsWith('84') && normalized.length >= 10) {
      return '0${normalized.substring(2)}';
    }
    return normalized;
  }

  /// Validates whether [raw] is a well-formed Vietnam phone or hotline number.
  ///
  /// Rejects empty strings, URI schemes, HTML characters, or non-numeric garbage.
  static bool isValidPhoneFormat(String? raw) {
    if (raw == null) return false;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains(':') ||
        trimmed.contains('/') ||
        trimmed.contains('<') ||
        trimmed.contains('>')) {
      return false;
    }

    final clean = normalizePhone(trimmed);
    final mobileOrLandline = RegExp(r'^(\+84|84|0)[1-9][0-9]{7,9}$');
    final tollFreeOrHotline = RegExp(r'^1[89]00[0-9]{4,6}$');
    return mobileOrLandline.hasMatch(clean) ||
        tollFreeOrHotline.hasMatch(clean);
  }

  /// Detects if [raw] is a sample/example phone number from config (such as `0901234567`)
  /// rather than a verified production hotline.
  static bool isPlaceholderPhone(String? raw) {
    if (raw == null) return true;
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return true;
    if (trimmed.contains('placeholder') ||
        trimmed.contains('example') ||
        trimmed.contains('your_') ||
        trimmed.contains('changeme') ||
        trimmed.contains('xxx')) {
      return true;
    }

    if (!isValidPhoneFormat(trimmed)) return true;

    final local = _toLocalDigits(normalizePhone(trimmed));
    if (_knownPlaceholderPhones.contains(local)) {
      return true;
    }

    // Reject numbers with 7+ identical trailing digits (e.g. 0911111111, 0900000000).
    if (local.length >= 8) {
      final tail = local.substring(local.length - 7);
      if (RegExp(r'^(\d)\1{6}$').hasMatch(tail)) {
        return true;
      }
    }

    return false;
  }

  /// Returns `true` only when [raw] is both valid in format and not a sample/placeholder number.
  static bool isVerifiedHotline(String? raw) {
    return isValidPhoneFormat(raw) && !isPlaceholderPhone(raw);
  }

  /// Formats a phone number for human-readable display (e.g. `0901 234 567`).
  static String formatDisplayPhone(String raw) {
    final clean = normalizePhone(raw);
    if (!isValidPhoneFormat(clean)) return raw.trim();
    final local = _toLocalDigits(clean);
    if (local.length == 10) {
      return '${local.substring(0, 4)} ${local.substring(4, 7)} ${local.substring(7)}';
    }
    if (local.length == 11) {
      return '${local.substring(0, 4)} ${local.substring(4, 7)} ${local.substring(7)}';
    }
    return clean;
  }

  /// Validates and normalizes an official Zalo OA / chat URL.
  ///
  /// Rules enforced:
  /// - Strictly `https` scheme.
  /// - Host must belong to [allowedZaloHosts] (`zalo.me`, `oa.zalo.me`, etc.).
  /// - Must contain a valid single path identifier (`^[a-zA-Z0-9._-]+$`).
  /// - Strips query parameters & fragments so the app never pretends Zalo supports
  ///   auto-filling message text via URL query parameters.
  static Uri? parseAndValidateZaloUri(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'[\s<>"\x00-\x1F\\]').hasMatch(trimmed)) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != 'https') return null;
    if (uri.userInfo.isNotEmpty) return null;

    final host = uri.host.toLowerCase();
    if (!allowedZaloHosts.contains(host)) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;

    final oaIdentifier = segments.first.trim();
    if (oaIdentifier.isEmpty ||
        oaIdentifier == '.' ||
        oaIdentifier == '..' ||
        !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(oaIdentifier)) {
      return null;
    }

    return Uri(
      scheme: 'https',
      host: host,
      pathSegments: [oaIdentifier],
    );
  }

  /// Returns `true` if [rawUrl] is a structurally valid HTTPS Zalo URL.
  static bool isValidZaloUrl(String? rawUrl) {
    return parseAndValidateZaloUri(rawUrl) != null;
  }

  /// Detects if [rawUrl] points to an example/placeholder Zalo OA (such as `https://zalo.me/0901234567`).
  static bool isPlaceholderZaloUrl(String? rawUrl) {
    final uri = parseAndValidateZaloUri(rawUrl);
    if (uri == null) return true;

    final identifier = uri.pathSegments.first.toLowerCase();
    if (identifier.contains('placeholder') ||
        identifier.contains('example') ||
        identifier.contains('your_') ||
        identifier.contains('sample') ||
        identifier.contains('changeme') ||
        identifier == 'test' ||
        identifier == 'demo') {
      return true;
    }

    // If the Zalo path is a phone number, check if that phone number is a placeholder.
    if (RegExp(r'^\+?\d+$').hasMatch(identifier)) {
      return isPlaceholderPhone(identifier);
    }

    return false;
  }

  /// Returns `true` only when [rawUrl] is a valid official Zalo URL and not a sample placeholder.
  static bool isVerifiedZaloUrl(String? rawUrl) {
    return isValidZaloUrl(rawUrl) && !isPlaceholderZaloUrl(rawUrl);
  }

  /// Validates an email address format for consultation draft / contact validation.
  static bool isValidEmail(String? rawEmail) {
    if (rawEmail == null) return false;
    final trimmed = rawEmail.trim();
    if (trimmed.isEmpty || trimmed.length > 254) return false;
    if (trimmed.contains('..') ||
        trimmed.contains(' ') ||
        trimmed.contains('<') ||
        trimmed.contains('>')) {
      return false;
    }
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$',
    ).hasMatch(trimmed);
  }

  /// Parses and validates a safe external `https://` URL (blocking `javascript:`, `data:`, `http:`, malformed URLs).
  static Uri? parseSafeExternalHttpsUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'[\s<>"\x00-\x1F]').hasMatch(trimmed)) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != 'https') return null;
    if (uri.userInfo.isNotEmpty) return null;

    final host = uri.host.toLowerCase();
    if (host.isEmpty ||
        !host.contains('.') ||
        host.startsWith('.') ||
        host.endsWith('.')) {
      return null;
    }
    return uri;
  }

  /// Sanitizes single-line user input before embedding into inquiry/consultation drafts.
  static String _sanitizeLine(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Builds a structured, respectful inquiry message for Zalo.
  static String buildZaloInquiryMessage({
    required String villaName,
    required String villaCode,
    BookingDate? checkIn,
    BookingDate? checkOut,
    int? guestCount,
    String? additionalNotes,
  }) {
    final safeVillaName = _sanitizeLine(villaName);
    final safeVillaCode = _sanitizeLine(villaCode);
    final buffer = StringBuffer();
    buffer.writeln('Xin chào The Palm Villa, tôi muốn tư vấn đặt biệt thự:');
    buffer.writeln('• Biệt thự: $safeVillaName (Mã: $safeVillaCode)');

    if (checkIn != null && checkOut != null) {
      final nights = checkIn.differenceInNights(checkOut);
      buffer.writeln(
        '• Lịch ở: ${checkIn.toDisplayString()} - ${checkOut.toDisplayString()} ($nights đêm)',
      );
    }
    if (guestCount != null && guestCount > 0) {
      buffer.writeln('• Số khách dự kiến: $guestCount người');
    }
    if (additionalNotes != null && additionalNotes.trim().isNotEmpty) {
      buffer.writeln('• Yêu cầu thêm: ${_sanitizeLine(additionalNotes)}');
    }
    buffer.writeln(
      'Nhờ anh/chị kiểm tra tình trạng trống và báo giá giúp tôi. Xin cảm ơn!',
    );
    return buffer.toString();
  }

  /// Builds a structured consultation draft when the user wants to prepare inquiry content
  /// on the Contact screen to copy/paste with explicit consent.
  static String buildConsultationDraftMessage({
    required String fullName,
    required String phone,
    String? email,
    String? topic,
    required String messageContent,
  }) {
    final safeName = _sanitizeLine(fullName);
    final safePhone = normalizePhone(phone);
    final safeEmail = email != null ? _sanitizeLine(email) : '';
    final safeTopic = topic != null ? _sanitizeLine(topic) : '';
    final safeMessage = messageContent
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]+'), '')
        .trim();

    final buffer = StringBuffer();
    buffer.writeln('Xin chào The Palm, tôi cần tư vấn lưu trú:');
    if (safeName.isNotEmpty) {
      buffer.writeln('• Họ và tên: $safeName');
    }
    if (safePhone.isNotEmpty) {
      buffer.writeln('• Số điện thoại: $safePhone');
    }
    if (safeEmail.isNotEmpty) {
      buffer.writeln('• Email: $safeEmail');
    }
    if (safeTopic.isNotEmpty) {
      buffer.writeln('• Chủ đề: $safeTopic');
    }
    if (safeMessage.isNotEmpty) {
      buffer.writeln('• Nội dung: $safeMessage');
    }
    buffer.writeln('Mong nhận được phản hồi từ đội ngũ tư vấn. Xin cảm ơn!');
    return buffer.toString();
  }

  /// Copies [text] to the system clipboard, returning `true` only if the copy succeeded.
  static Future<bool> copyTextToClipboard(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    try {
      if (clipboardSetDataOverride != null) {
        await clipboardSetDataOverride!(trimmed);
      } else {
        await Clipboard.setData(ClipboardData(text: trimmed));
      }
      return true;
    } catch (e) {
      AppLogger.w('Failed to copy text to clipboard');
      return false;
    }
  }

  static Future<bool> _canLaunch(Uri uri) async {
    if (canLaunchUrlOverride != null) {
      return canLaunchUrlOverride!(uri);
    }
    return canLaunchUrl(uri);
  }

  static Future<bool> _launch(Uri uri, LaunchMode mode) async {
    if (launchUrlOverride != null) {
      return launchUrlOverride!(uri, mode);
    }
    return launchUrl(uri, mode: mode);
  }

  /// Detailed hotline action with config validation and clipboard fallback.
  static Future<ContactActionResult> callHotlineDetailed({
    String? customNumber,
    bool rejectPlaceholder = true,
    bool copyOnPlaceholder = false,
  }) async {
    final raw = (customNumber ?? AppConfig.hotlineNumber).trim();
    if (!isValidPhoneFormat(raw)) {
      return const ContactActionResult(
        status: ContactActionStatus.invalidInput,
        launched: false,
        copiedToClipboard: false,
        message: 'Số điện thoại hotline không hợp lệ.',
      );
    }

    final cleanNumber = normalizePhone(raw);
    if (rejectPlaceholder && isPlaceholderPhone(cleanNumber)) {
      final copied =
          copyOnPlaceholder ? await copyTextToClipboard(cleanNumber) : false;
      return ContactActionResult(
        status: ContactActionStatus.unverifiedConfig,
        launched: false,
        copiedToClipboard: copied,
        targetValue: cleanNumber,
        message:
            'Số hotline trong cấu hình ($cleanNumber) đang là số mẫu chưa được xác minh thực tế.',
      );
    }

    final uri = Uri(scheme: 'tel', path: cleanNumber);
    try {
      if (await _canLaunch(uri)) {
        final launched = await _launch(uri, LaunchMode.platformDefault);
        if (launched) {
          return ContactActionResult(
            status: ContactActionStatus.launched,
            launched: true,
            copiedToClipboard: false,
            targetValue: cleanNumber,
            message:
                'Đang mở trình gọi điện tới ${formatDisplayPhone(cleanNumber)}.',
          );
        }
      }
    } catch (e) {
      AppLogger.w('Failed to launch hotline dialer');
    }

    // Fallback: copy phone number to clipboard
    final copied = await copyTextToClipboard(cleanNumber);
    return ContactActionResult(
      status: copied
          ? ContactActionStatus.copiedFallback
          : ContactActionStatus.failed,
      launched: false,
      copiedToClipboard: copied,
      targetValue: cleanNumber,
      message: copied
          ? 'Thiết bị không hỗ trợ gọi trực tiếp. Đã sao chép số ${formatDisplayPhone(cleanNumber)} vào bộ nhớ tạm.'
          : 'Không thể mở trình gọi điện trên thiết bị này.',
    );
  }

  /// Initiates a telephone call using `tel:` scheme.
  ///
  /// Validates phone format first. If device cannot launch dialer (e.g. simulator, tablet),
  /// falls back to copying phone number to clipboard and returns `false`.
  static Future<bool> callHotline({
    String? customNumber,
    bool rejectPlaceholder = false,
  }) async {
    final result = await callHotlineDetailed(
      customNumber: customNumber,
      rejectPlaceholder: rejectPlaceholder,
      copyOnPlaceholder: false,
    );
    return result.launched;
  }

  /// Detailed Zalo OA inquiry launcher:
  /// - Validates that the Zalo URL is an official `https://zalo.me/...` or `https://oa.zalo.me/...` link.
  /// - Never appends fake message auto-fill query params to the URL.
  /// - Copies [messageText] to clipboard only when [userConsentedToCopyDraft] is `true` and [messageText] is non-empty.
  static Future<ContactActionResult> openZaloInquiryDetailed({
    String? messageText,
    String? customZaloUrl,
    bool userConsentedToCopyDraft = true,
    bool rejectPlaceholder = true,
  }) async {
    final rawUrl = (customZaloUrl ?? AppConfig.zaloOaUrl).trim();
    final uri = parseAndValidateZaloUri(rawUrl);

    final hasDraft = messageText != null && messageText.trim().isNotEmpty;
    final copiedDraft = (userConsentedToCopyDraft && hasDraft)
        ? await copyTextToClipboard(messageText.trim())
        : false;

    if (uri == null) {
      return ContactActionResult(
        status: ContactActionStatus.invalidInput,
        launched: false,
        copiedToClipboard: copiedDraft,
        message: copiedDraft
            ? 'Liên kết Zalo không hợp lệ. Đã sao chép bản nháp nội dung vào bộ nhớ tạm.'
            : 'Liên kết Zalo OA không hợp lệ hoặc chưa được cấu hình đúng chuẩn HTTPS.',
      );
    }

    if (rejectPlaceholder && isPlaceholderZaloUrl(rawUrl)) {
      return ContactActionResult(
        status: ContactActionStatus.unverifiedConfig,
        launched: false,
        copiedToClipboard: copiedDraft,
        targetValue: uri.toString(),
        message: copiedDraft
            ? 'Zalo OA trong cấu hình đang là địa chỉ mẫu chưa xác minh. Đã sao chép bản nháp để bạn chủ động dán khi liên hệ.'
            : 'Địa chỉ Zalo OA trong cấu hình đang là dữ liệu mẫu chưa xác minh thực tế.',
      );
    }

    try {
      if (await _canLaunch(uri)) {
        final launched = await _launch(uri, LaunchMode.externalApplication);
        if (launched) {
          return ContactActionResult(
            status: ContactActionStatus.launched,
            launched: true,
            copiedToClipboard: copiedDraft,
            targetValue: uri.toString(),
            message: copiedDraft
                ? 'Đã sao chép bản nháp và mở Zalo OA. Vui lòng dán (Paste) nội dung vào khung trò chuyện.'
                : 'Đang mở trang Zalo OA chính thức.',
          );
        }
      }
    } catch (e) {
      AppLogger.w('Failed to launch Zalo URL');
    }

    return ContactActionResult(
      status: copiedDraft
          ? ContactActionStatus.copiedFallback
          : ContactActionStatus.failed,
      launched: false,
      copiedToClipboard: copiedDraft,
      targetValue: uri.toString(),
      message: copiedDraft
          ? 'Không mở được ứng dụng Zalo. Đã sao chép sẵn bản nháp nội dung vào bộ nhớ tạm.'
          : 'Không thể mở liên kết Zalo OA trên thiết bị này.',
    );
  }

  /// Opens verified Zalo link and optionally copies inquiry draft text to clipboard.
  static Future<bool> openZaloInquiry({
    required String messageText,
    String? customZaloUrl,
    bool userConsentedToCopyDraft = true,
    bool rejectPlaceholder = false,
  }) async {
    final result = await openZaloInquiryDetailed(
      messageText: messageText,
      customZaloUrl: customZaloUrl,
      userConsentedToCopyDraft: userConsentedToCopyDraft,
      rejectPlaceholder: rejectPlaceholder,
    );
    return result.launched;
  }

  /// Launches a validated external `https://` URL, falling back to copying [fallbackCopyText] if launcher fails.
  static Future<ContactActionResult> openExternalHttpsUrl(
    String rawUrl, {
    String? fallbackCopyText,
  }) async {
    final uri = parseSafeExternalHttpsUrl(rawUrl);
    if (uri == null) {
      return const ContactActionResult(
        status: ContactActionStatus.invalidInput,
        launched: false,
        copiedToClipboard: false,
        message: 'Liên kết ngoài không hợp lệ hoặc không an toàn.',
      );
    }

    try {
      if (await _canLaunch(uri)) {
        final launched = await _launch(uri, LaunchMode.externalApplication);
        if (launched) {
          return ContactActionResult(
            status: ContactActionStatus.launched,
            launched: true,
            copiedToClipboard: false,
            targetValue: uri.toString(),
            message: 'Đang mở liên kết ngoài...',
          );
        }
      }
    } catch (e) {
      AppLogger.w('Failed to launch external HTTPS URL');
    }

    final copyCandidate = fallbackCopyText?.trim() ?? uri.toString();
    final copied = await copyTextToClipboard(copyCandidate);
    return ContactActionResult(
      status: copied
          ? ContactActionStatus.copiedFallback
          : ContactActionStatus.failed,
      launched: false,
      copiedToClipboard: copied,
      targetValue: uri.toString(),
      message: copied
          ? 'Không thể mở trình duyệt ngoài. Đã sao chép thông tin vào bộ nhớ tạm.'
          : 'Không thể mở liên kết ngoài trên thiết bị này.',
    );
  }
}
