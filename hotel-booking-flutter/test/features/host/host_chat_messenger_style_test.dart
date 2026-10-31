import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/host/data/host_repository.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/host_portal_screens.dart';

class _FakeDioClient {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
}

class _ChatRecordingAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) responder;

  _ChatRecordingAdapter({required this.responder});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(dynamic data, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  testWidgets(
    'Host chat displays Messenger-style bubbles (no sender name, hidden timestamp until drag or toggle)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = _FakeDioClient();
      client.dio.httpClientAdapter = _ChatRecordingAdapter(
        responder: (options) {
          if (options.path == '/api/conversations') {
            return _jsonResponse({
              'items': [
                {
                  'id': 'conv-101',
                  'conversationId': 'conv-101',
                  'listingTitle': 'The Palm Villa',
                  'guestName': 'ĐẶNG KIM AN',
                  'otherParticipant': {
                    'fullName': 'ĐẶNG KIM AN',
                  },
                  'lastMessage': {
                    'body': 'xin chao',
                    'createdAt': '2026-10-31T18:26:00.000Z',
                  },
                },
              ],
            });
          }
          if (options.path.contains('/api/conversations/conv-101/messages')) {
            return _jsonResponse({
              'items': [
                {
                  'messageId': 'm1',
                  'content': 'xin chao',
                  'senderRole': 'guest',
                  'senderName': 'ĐẶNG KIM AN',
                  'isMe': false,
                  'createdAt': '2026-10-31T18:26:00.000Z',
                },
                {
                  'messageId': 'm2',
                  'content': 'xin chao, ban can ho tro gi nhi',
                  'senderRole': 'host',
                  'senderName': 'The Palm Villa',
                  'isMe': true,
                  'createdAt': '2026-10-31T18:27:00.000Z',
                },
              ],
            });
          }
          return _jsonResponse({'items': <dynamic>[]});
        },
      );

      final repo = HostRepository(
        client as dynamic,
        roleResolver: () => 'host',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: const MaterialApp(
            home: HostPortalScreen(
              initialSection: HostPortalSection.messages,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on conversation item to enter chat detail view
      expect(find.text('ĐẶNG KIM AN'), findsWidgets);
      await tester.tap(find.text('ĐẶNG KIM AN').first);
      await tester.pumpAndSettle();

      // 1. Verify messages content exists
      expect(find.text('xin chao'), findsOneWidget);
      expect(find.text('xin chao, ban can ho tro gi nhi'), findsOneWidget);

      // 2. Sender name should NOT be rendered above each message bubble (Messenger style)
      // The header title has "ĐẶNG KIM AN" exactly once, NOT duplicated above the bubble
      expect(find.text('ĐẶNG KIM AN'), findsOneWidget);

      // 3. Small Avatar should appear on the left of the guest message ('Đ')
      expect(find.text('Đ'), findsOneWidget);

      // 4. Timestamps 18:26 and 18:27 should initially NOT be visible in the tree (progress = 0)
      expect(find.text('18:26'), findsNothing);
      expect(find.text('18:27'), findsNothing);

      // 5. Tap the clock toggle button to reveal timestamps
      final toggleBtn =
          find.byKey(const Key('host_chat_toggle_timestamps_btn'));
      expect(toggleBtn, findsOneWidget);
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // All timestamps in the conversation are now revealed simultaneously
      expect(find.text('18:26'), findsOneWidget);
      expect(find.text('18:27'), findsOneWidget);

      // 6. Tap again to hide timestamps
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();
      expect(find.text('18:26'), findsNothing);
      expect(find.text('18:27'), findsNothing);

      // 7. Long press (đè vào tin nhắn) to reveal 6 basic reaction icons
      await tester.longPress(find.text('xin chao'));
      await tester.pumpAndSettle();

      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('😆'), findsOneWidget);
      expect(find.text('😮'), findsOneWidget);
      expect(find.text('😢'), findsOneWidget);
      expect(find.text('😡'), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);

      // Tap ❤️ to react
      await tester.tap(find.text('❤️'));
      await tester.pumpAndSettle();

      // Reaction badge ❤️ is now attached to the bubble
      expect(find.text('❤️'), findsOneWidget);

      // 8. Test quick reply chips filling input
      final quickChip = find.text('Dạ vâng, bên em đã nhận thông tin ạ!');
      expect(quickChip, findsOneWidget);
      await tester.tap(quickChip);
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('host_message_input'));
      final inputWidget = tester.widget<TextField>(inputFinder);
      expect(
          inputWidget.controller?.text, 'Dạ vâng, bên em đã nhận thông tin ạ!');

      // When text is non-empty, send button appears
      expect(find.byKey(const Key('host_message_send_btn')), findsOneWidget);

      // 9. Verify Messenger toolbar buttons (Plus, Camera, Gallery, Mic, Quick Emoji 😤)
      inputWidget.controller?.clear();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat_more_features_btn')), findsOneWidget);
      expect(find.byKey(const Key('chat_camera_btn')), findsOneWidget);
      expect(find.byKey(const Key('chat_gallery_btn')), findsOneWidget);
      expect(find.byKey(const Key('chat_mic_btn')), findsOneWidget);
      expect(find.byKey(const Key('chat_input_smile_btn')), findsOneWidget);
      expect(find.byKey(const Key('chat_quick_emoji_btn')), findsOneWidget);
      expect(find.text('😤'), findsOneWidget);
      expect(find.text('Nhắn tin'), findsOneWidget);
    },
  );
}
