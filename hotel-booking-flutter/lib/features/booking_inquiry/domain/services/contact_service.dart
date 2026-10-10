import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/date/booking_date.dart';
import '../../../../core/logging/app_logger.dart';

abstract final class ContactService {
  /// Builds a structured, respectful inquiry message for Zalo.
  static String buildZaloInquiryMessage({
    required String villaName,
    required String villaCode,
    BookingDate? checkIn,
    BookingDate? checkOut,
    int? guestCount,
    String? additionalNotes,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Xin chào Minh Thanh Villa, tôi muốn tư vấn đặt biệt thự:');
    buffer.writeln('• Biệt thự: $villaName (Mã: $villaCode)');

    if (checkIn != null && checkOut != null) {
      final nights = checkIn.differenceInNights(checkOut);
      buffer.writeln(
          '• Lịch ở: ${checkIn.toDisplayString()} - ${checkOut.toDisplayString()} ($nights đêm)');
    }
    if (guestCount != null && guestCount > 0) {
      buffer.writeln('• Số khách dự kiến: $guestCount người');
    }
    if (additionalNotes != null && additionalNotes.trim().isNotEmpty) {
      buffer.writeln('• Yêu cầu thêm: ${additionalNotes.trim()}');
    }
    buffer.writeln(
        'Nhờ anh/chị kiểm tra tình trạng trống và báo giá giúp tôi. Xin cảm ơn!');
    return buffer.toString();
  }

  /// Initiates a telephone call using `tel:` scheme.
  ///
  /// If device cannot launch dialer (e.g. simulator, tablet without telephony),
  /// falls back to copying phone number to clipboard.
  static Future<bool> callHotline({String? customNumber}) async {
    final number = customNumber ?? AppConfig.hotlineNumber;
    final cleanNumber = number.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      AppLogger.w('Failed to launch hotline dialer: $e');
    }

    // Fallback: copy to clipboard
    await Clipboard.setData(ClipboardData(text: cleanNumber));
    return false;
  }

  /// Opens Zalo with pre-copied inquiry text.
  ///
  /// Follows strict production rule:
  /// - Copies message text to clipboard.
  /// - Launches official Zalo link or custom OA URL.
  static Future<bool> openZaloInquiry({
    required String messageText,
    String? customZaloUrl,
  }) async {
    // 1. Copy inquiry message to clipboard for seamless pasting
    await Clipboard.setData(ClipboardData(text: messageText));

    // 2. Launch Zalo OA or personal chat link
    final urlString = customZaloUrl ?? AppConfig.zaloOaUrl;
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.w('Failed to launch Zalo URL: $e');
    }

    return false;
  }
}
