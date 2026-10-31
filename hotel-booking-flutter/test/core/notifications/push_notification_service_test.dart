import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/network/socket_service.dart';
import 'package:hotel_booking_flutter/core/notifications/device_token_repository.dart';
import 'package:hotel_booking_flutter/core/notifications/push_notification_service.dart';

class _FakeDeviceTokenRepository implements DeviceTokenRepository {
  final List<Map<String, String?>> registeredCalls = <Map<String, String?>>[];
  final List<String> unregisteredTokens = <String>[];

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
    String? appFlavor,
  }) async {
    registeredCalls.add(<String, String?>{
      'token': token,
      'platform': platform,
      'appFlavor': appFlavor,
    });
  }

  @override
  Future<void> unregisterToken({required String token}) async {
    unregisteredTokens.add(token);
  }
}

void main() {
  group('PushNotificationService', () {
    late _FakeDeviceTokenRepository fakeRepo;
    late SocketService socketService;
    late List<Map<String, Object?>> shownBanners;
    late PushNotificationService service;
    String? currentMockFcmToken;

    setUp(() {
      fakeRepo = _FakeDeviceTokenRepository();
      socketService = SocketService();
      shownBanners = <Map<String, Object?>>[];
      currentMockFcmToken = 'mock_android_fcm_token_abcdef_1234567890';

      service = PushNotificationService(
        deviceTokenRepository: fakeRepo,
        socketService: socketService,
        enableNativePlugins: false,
        tokenProviderOverride: () async => currentMockFcmToken,
        localBannerOverride: ({
          required int id,
          required String title,
          required String body,
          String? payload,
        }) async {
          shownBanners.add(<String, Object?>{
            'id': id,
            'title': title,
            'body': body,
            'payload': payload,
          });
        },
      );
    });

    tearDown(() {
      service.dispose();
      socketService.dispose();
    });

    test(
      'syncAuthenticatedUser registers FCM token once per user and unregisterCurrentDevice deactivates on logout',
      () async {
        await service.initialize();
        await service.syncAuthenticatedUser('201');
        // Duplicate call for same user + token should be idempotent
        await service.syncAuthenticatedUser('201');

        expect(fakeRepo.registeredCalls.length, equals(1));
        expect(
          fakeRepo.registeredCalls.first['token'],
          equals('mock_android_fcm_token_abcdef_1234567890'),
        );

        await service.unregisterCurrentDevice();
        expect(
          fakeRepo.unregisteredTokens,
          equals(<String>['mock_android_fcm_token_abcdef_1234567890']),
        );
      },
    );

    test(
      'deduplicates identical notification received across FCM and Socket.IO',
      () async {
        await service.initialize();
        await service.syncAuthenticatedUser('201');

        await service.handleFcmDataForTesting(
          title: 'Đặt phòng đã được xác nhận',
          body: 'Host đã xác nhận booking #9001.',
          data: <String, dynamic>{
            'notificationLogId': '555',
            'eventType': 'BOOKING_CONFIRMED',
            'targetType': 'booking',
            'targetId': '9001',
            'actionUrl': '/account/trips',
          },
        );

        // Simulate Socket.IO delivering the same notificationLogId milliseconds later
        socketService.handleRawPacketForTesting('40{"sid":"s1"}');
        socketService.handleRawPacketForTesting(
          '42["notification:new",{"id":555,"notificationLogId":555,"eventType":"BOOKING_CONFIRMED","title":"Đặt phòng đã được xác nhận","body":"Host đã xác nhận booking #9001.","actionUrl":"/account/trips"}]',
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(shownBanners.length, equals(1));
        expect(
            shownBanners.first['title'], equals('Đặt phòng đã được xác nhận'));
      },
    );

    test(
      'resolveRouteFromPushData maps safe internal routes and blocks external URLs',
      () {
        expect(
          PushNotificationService.resolveRouteFromPushData(<String, dynamic>{
            'actionUrl': '/account/trips',
            'eventType': 'BOOKING_CONFIRMED',
          }),
          equals('/account/trips'),
        );

        expect(
          PushNotificationService.resolveRouteFromPushData(<String, dynamic>{
            'actionUrl': 'https://evil.example.com/phish',
            'eventType': 'PAYMENT_PENDING',
            'targetType': 'payment',
            'payloadJson': '{"bookingId":42}',
          }),
          equals('/thanh-toan/42'),
        );

        expect(
          PushNotificationService.resolveRouteFromPushData(<String, dynamic>{
            'eventType': 'MESSAGE_NEW',
            'targetType': 'conversation',
            'targetId': '88',
          }),
          equals('/messages?conversationId=88'),
        );
      },
    );
  });
}
