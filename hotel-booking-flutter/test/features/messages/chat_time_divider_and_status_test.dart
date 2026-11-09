import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/messages/presentation/widgets/chat_time_divider.dart';

void main() {
  group('Chat Time Divider & Messenger Status Tests', () {
    test('formatChatTimeDivider formats today correctly (Chỉ hiện giờ)', () {
      final now = DateTime(2026, 11, 5, 16, 45);
      final msgTime = DateTime(2026, 11, 5, 14, 30);

      expect(formatChatTimeDivider(msgTime, now: now), '14:30');
    });

    test('formatChatTimeDivider formats within 7 days correctly (Hiện Thứ + Giờ)', () {
      // 2026-11-05 is Thursday (T5)
      final now = DateTime(2026, 11, 5, 10, 00);

      // Tuesday (T3), 2 days before: 2026-11-03 14:00
      final tuesdayMsg = DateTime(2026, 11, 3, 14, 00);
      expect(formatChatTimeDivider(tuesdayMsg, now: now), 'T3 lúc 14:00');
      expect(formatChatTimeDivider(tuesdayMsg, now: now, localeCode: 'en'), 'Tue at 14:00');
      expect(formatChatTimeDivider(tuesdayMsg, now: now, localeCode: 'ko'), '화 14:00');

      // Sunday (CN), 4 days before: 2026-11-01 09:15
      final sundayMsg = DateTime(2026, 11, 1, 9, 15);
      expect(formatChatTimeDivider(sundayMsg, now: now), 'CN lúc 09:15');
      expect(formatChatTimeDivider(sundayMsg, now: now, localeCode: 'en'), 'Sun at 09:15');
      expect(formatChatTimeDivider(sundayMsg, now: now, localeCode: 'ko'), '일 09:15');
    });

    test('formatChatTimeDivider formats older than 7 days same year (Hiện Ngày tháng + Giờ)', () {
      final now = DateTime(2026, 11, 5, 12, 00);
      final oldMsgSameYear = DateTime(2026, 10, 20, 15, 30);

      expect(
        formatChatTimeDivider(oldMsgSameYear, now: now),
        '20 thg 10 lúc 15:30',
      );
      expect(
        formatChatTimeDivider(oldMsgSameYear, now: now, localeCode: 'en'),
        'Oct 20 at 15:30',
      );
      expect(
        formatChatTimeDivider(oldMsgSameYear, now: now, localeCode: 'ko'),
        '10월 20일 15:30',
      );
    });

    test('formatChatTimeDivider formats past year (Hiện Ngày tháng, Năm + Giờ)', () {
      final now = DateTime(2026, 11, 5, 12, 00);
      final oldMsgPastYear = DateTime(2025, 10, 20, 15, 30);

      expect(
        formatChatTimeDivider(oldMsgPastYear, now: now),
        '20 thg 10, 2025 lúc 15:30',
      );
      expect(
        formatChatTimeDivider(oldMsgPastYear, now: now, localeCode: 'en'),
        'Oct 20, 2025 at 15:30',
      );
      expect(
        formatChatTimeDivider(oldMsgPastYear, now: now, localeCode: 'ko'),
        '2025년 10월 20일 15:30',
      );
    });

    test('localizeChatPreview translates voice and media previews according to locale', () {
      const rawVoice = '🎤 Tin nhắn thoại (00:07)';
      expect(localizeChatPreview(rawVoice, localeCode: 'en'), '🎤 Voice message (00:07)');
      expect(localizeChatPreview(rawVoice, localeCode: 'ko'), '🎤 음성 메시지 (00:07)');
      expect(localizeChatPreview(rawVoice, localeCode: 'vi'), '🎤 Tin nhắn thoại (00:07)');

      const rawVoiceEn = '🎤 Voice message (00:15)';
      expect(localizeChatPreview(rawVoiceEn, localeCode: 'vi'), '🎤 Tin nhắn thoại (00:15)');
      expect(localizeChatPreview(rawVoiceEn, localeCode: 'en'), '🎤 Voice message (00:15)');
    });

    test('shouldShowChatTimeDivider evaluates intervals correctly', () {
      final firstMsg = DateTime(2026, 11, 5, 10, 0);
      // First message has no prevDt -> should show divider
      expect(shouldShowChatTimeDivider(firstMsg, null), isTrue);

      // Same day, 30 minutes later (< 1 hour) -> should NOT show divider
      final closeMsg = DateTime(2026, 11, 5, 10, 30);
      expect(shouldShowChatTimeDivider(closeMsg, firstMsg), isFalse);

      // Same day, 65 minutes later (>= 1 hour) -> should show divider
      final farMsg = DateTime(2026, 11, 5, 11, 05);
      expect(shouldShowChatTimeDivider(farMsg, firstMsg), isTrue);

      // Next day, only 20 minutes apart across midnight (23:50 -> 00:10) -> new day -> should show divider
      final lateNightMsg = DateTime(2026, 11, 5, 23, 50);
      final nextDayMsg = DateTime(2026, 11, 6, 0, 10);
      expect(shouldShowChatTimeDivider(nextDayMsg, lateNightMsg), isTrue);
    });

    testWidgets('MessengerStatusIndicator renders all 4 delivery states correctly', (tester) async {
      // 1. Sending state: Vòng tròn rỗng
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessengerStatusIndicator(
              state: MessengerDeliveryState.sending,
              customLabel: 'Đang gửi...',
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('messenger_status_icon_sending')), findsOneWidget);
      expect(find.text('Đang gửi...'), findsOneWidget);

      // 2. Sent state: Vòng xanh có tick
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessengerStatusIndicator(
              state: MessengerDeliveryState.sent,
              customLabel: 'Đã gửi',
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('messenger_status_icon_sent')), findsOneWidget);
      expect(find.text('Đã gửi'), findsOneWidget);

      // 3. Seen state: Hình đại diện thu nhỏ của người nhận khi họ đã xem
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessengerStatusIndicator(
              state: MessengerDeliveryState.seen,
              recipientName: 'Lê Hoàng Long',
              customLabel: 'Đã xem',
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('messenger_status_icon_seen')), findsOneWidget);
      expect(find.text('Đã xem'), findsOneWidget);

      // 4. Failed state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessengerStatusIndicator(
              state: MessengerDeliveryState.failed,
              customLabel: 'Gửi thất bại',
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('messenger_status_icon_failed')), findsOneWidget);
      expect(find.text('Gửi thất bại'), findsOneWidget);
    });
  });
}
