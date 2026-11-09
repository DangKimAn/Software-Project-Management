import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/media/app_media_image.dart';
import '../../../../l10n/l10n.dart';

/// Helper to determine if an automatic Messenger-style Time Divider should be
/// shown above the message at [currentDt] given the previous message at [prevDt].
///
/// Messenger inserts a divider:
/// - At the start of a chat ([prevDt] == null).
/// - When crossing to a new calendar day.
/// - When two messages are separated by at least 1 hour (>= 60 minutes).
bool shouldShowChatTimeDivider(DateTime currentDt, DateTime? prevDt) {
  if (prevDt == null) return true;

  final localCurrent = currentDt.toLocal();
  final localPrev = prevDt.toLocal();

  final isNewDay = localCurrent.year != localPrev.year ||
      localCurrent.month != localPrev.month ||
      localCurrent.day != localPrev.day;

  if (isNewDay) return true;

  final diffMinutes = localCurrent.difference(localPrev).inMinutes.abs();
  return diffMinutes >= 60;
}

/// Formats the timestamp for the automatic Messenger-style Time Divider with
/// language support (Vietnamese, English, Korean).
///
/// Rules:
/// - Tin nhắn trong ngày: Chỉ hiện giờ (VD: 14:30).
/// - Tin nhắn trong vòng 7 ngày:
///   - vi: Thứ + Giờ (VD: T3 lúc 14:00, CN lúc 09:15).
///   - en: Weekday + at + Time (VD: Tue at 14:00, Sun at 09:15).
///   - ko: Weekday + Time (VD: 화 14:00, 일 09:15).
/// - Tin nhắn cũ hơn:
///   - vi: Ngày tháng + Giờ (VD: 20 thg 10 lúc 15:30; nếu qua năm cũ: 20 thg 10, 2025 lúc 15:30).
///   - en: Month Day + at + Time (VD: Oct 20 at 15:30; nếu qua năm cũ: Oct 20, 2025 at 15:30).
///   - ko: Month Day + Time (VD: 10월 20일 15:30; nếu qua năm cũ: 2025년 10월 20일 15:30).
String formatChatTimeDivider(
  DateTime dt, {
  DateTime? now,
  String? localeCode,
  BuildContext? context,
}) {
  final currentNow = (now ?? DateTime.now()).toLocal();
  final localDt = dt.toLocal();
  final lang = (localeCode ??
          (context != null
              ? Localizations.maybeLocaleOf(context)?.languageCode
              : null) ??
          'vi')
      .toLowerCase();

  final timeStr = DateFormat('HH:mm').format(localDt);

  // 1. Tin nhắn trong ngày: Chỉ hiện giờ
  final isToday = localDt.year == currentNow.year &&
      localDt.month == currentNow.month &&
      localDt.day == currentNow.day;
  if (isToday) {
    return timeStr;
  }

  // Khoảng cách theo ngày lịch
  final startOfToday =
      DateTime(currentNow.year, currentNow.month, currentNow.day);
  final startOfMsgDay = DateTime(localDt.year, localDt.month, localDt.day);
  final dayDiff = startOfToday.difference(startOfMsgDay).inDays;

  // 2. Tin nhắn trong vòng 7 ngày (1 đến 6 ngày trước): Hiện Thứ + Giờ
  if (dayDiff >= 1 && dayDiff < 7) {
    if (lang.startsWith('en')) {
      const weekdaysEn = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekday = weekdaysEn[localDt.weekday];
      return '$weekday at $timeStr';
    } else if (lang.startsWith('ko')) {
      const weekdaysKo = ['', '월', '화', '수', '목', '금', '토', '일'];
      final weekday = weekdaysKo[localDt.weekday];
      return '$weekday $timeStr';
    } else {
      // Thứ 2 = 1 -> T2, Thứ 3 = 2 -> T3, ..., CN = 7 -> CN
      final weekdayLabel =
          localDt.weekday == DateTime.sunday ? 'CN' : 'T${localDt.weekday + 1}';
      return '$weekdayLabel lúc $timeStr';
    }
  }

  // 3. Tin nhắn cũ hơn: Hiện Ngày tháng + Giờ (nếu khác năm thì thêm năm)
  final isSameYear = localDt.year == currentNow.year;

  if (lang.startsWith('en')) {
    const monthsEn = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final monthStr = monthsEn[localDt.month];
    if (isSameYear) {
      return '$monthStr ${localDt.day} at $timeStr';
    } else {
      return '$monthStr ${localDt.day}, ${localDt.year} at $timeStr';
    }
  } else if (lang.startsWith('ko')) {
    if (isSameYear) {
      return '${localDt.month}월 ${localDt.day}일 $timeStr';
    } else {
      return '${localDt.year}년 ${localDt.month}월 ${localDt.day}일 $timeStr';
    }
  } else {
    // Vietnamese default
    if (isSameYear) {
      return '${localDt.day} thg ${localDt.month} lúc $timeStr';
    } else {
      return '${localDt.day} thg ${localDt.month}, ${localDt.year} lúc $timeStr';
    }
  }
}

/// Localizes conversation preview text (such as voice messages, images, etc.)
/// based on [AppLocalizations] or [localeCode].
String localizeChatPreview(
  String? raw, {
  AppLocalizations? loc,
  String? localeCode,
}) {
  if (raw == null || raw.trim().isEmpty) {
    return loc?.chatNoMessagesYet ??
        ((localeCode ?? 'vi').startsWith('en')
            ? 'No messages yet'
            : (localeCode ?? 'vi').startsWith('ko')
                ? '메시지가 없습니다'
                : 'Chưa có tin nhắn.');
  }
  final trimmed = raw.trim();

  // Match voice message pattern in any language:
  // e.g. "🎤 Tin nhắn thoại (00:07)", "🎤 Voice message (00:07)", "🎤 음성 메시지 (00:07)"
  if (trimmed.startsWith('🎤')) {
    final match = RegExp(r'\(([0-9:]+)\)').firstMatch(trimmed);
    final duration = match != null ? ' (${match.group(1)})' : '';
    final voiceLabel = loc?.chatVoiceMessage ??
        ((localeCode ?? 'vi').startsWith('en')
            ? 'Voice message'
            : (localeCode ?? 'vi').startsWith('ko')
                ? '음성 메시지'
                : 'Tin nhắn thoại');
    return '🎤 $voiceLabel$duration';
  }

  // Match image message pattern:
  if (trimmed.startsWith('📷') ||
      trimmed.startsWith('🖼️') ||
      trimmed == '[image]' ||
      trimmed == 'image' ||
      trimmed == '[Hình ảnh]' ||
      trimmed == '📷 [Hình ảnh]') {
    final galleryLabel = loc?.chatGalleryLabel ??
        ((localeCode ?? 'vi').startsWith('en')
            ? 'Photo'
            : (localeCode ?? 'vi').startsWith('ko')
                ? '사진'
                : 'Hình ảnh');
    return '📷 $galleryLabel';
  }

  return trimmed;
}

/// A centered gray Messenger-style Time Divider widget.
class ChatTimeDivider extends StatelessWidget {
  final String label;

  const ChatTimeDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Delivery states for the Messenger-style status indicator.
enum MessengerDeliveryState {
  /// Vòng tròn rỗng (đang gửi)
  sending,

  /// Vòng xanh có tick (đã gửi đến máy chủ)
  sent,

  /// Hình đại diện thu nhỏ của người nhận khi họ đã xem
  seen,

  /// Lỗi gửi tin nhắn
  failed,
}

/// Messenger status indicator shown at the bottom-right corner of the user's
/// last message cluster.
///
/// Transitions:
/// Vòng tròn rỗng -> Vòng xanh có tick -> Hình đại diện thu nhỏ của người nhận khi họ đã xem.
class MessengerStatusIndicator extends StatelessWidget {
  final MessengerDeliveryState state;
  final String? recipientName;
  final String? recipientAvatar;
  final String? customLabel;
  final Key? statusKey;

  const MessengerStatusIndicator({
    super.key,
    required this.state,
    this.recipientName,
    this.recipientAvatar,
    this.customLabel,
    this.statusKey,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;
    String defaultText;
    Color textColor = AppColors.textMuted;

    switch (state) {
      case MessengerDeliveryState.sending:
        defaultText = 'Đang gửi...';
        iconWidget = Container(
          key: const Key('messenger_status_icon_sending'),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
        );
        break;

      case MessengerDeliveryState.sent:
        defaultText = 'Đã gửi';
        iconWidget = Container(
          key: const Key('messenger_status_icon_sent'),
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
          ),
          child: const Center(
            child: Icon(
              LucideIcons.check,
              size: 9,
              color: Colors.white,
            ),
          ),
        );
        break;

      case MessengerDeliveryState.seen:
        defaultText = 'Đã xem';
        iconWidget = Container(
          key: const Key('messenger_status_icon_seen'),
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipOval(
            child: (recipientAvatar != null && recipientAvatar!.isNotEmpty)
                ? AppMediaImage(
                    imageUrl: recipientAvatar!,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: AppColors.brandSoft,
                    alignment: Alignment.center,
                    child: Text(
                      (recipientName != null && recipientName!.isNotEmpty)
                          ? recipientName![0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
          ),
        );
        break;

      case MessengerDeliveryState.failed:
        defaultText = 'Gửi thất bại';
        textColor = AppColors.error;
        iconWidget = const Icon(
          LucideIcons.alertCircle,
          key: Key('messenger_status_icon_failed'),
          size: 13,
          color: AppColors.error,
        );
        break;
    }

    final displayText = customLabel ?? defaultText;

    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(width: 4),
          Text(
            displayText,
            key: statusKey,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: state == MessengerDeliveryState.failed
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
