import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/network/socket_service.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/features/admin/data/admin_repository.dart';
import 'package:hotel_booking_flutter/features/admin/presentation/screens/admin_portal_screens.dart';
import 'package:hotel_booking_flutter/features/blog/data/blog_repository.dart';
import 'package:hotel_booking_flutter/features/blog/presentation/screens/blog_detail_screen.dart';
import 'package:hotel_booking_flutter/features/messages/data/conversations_repository.dart';
import 'package:hotel_booking_flutter/shared/animations/animated_heart_button.dart';
import 'package:hotel_booking_flutter/shared/animations/fade_slide_in.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_dialog.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header_footer.dart';

class _FakeSecureStorage extends SecureStorageService {
  String? token;

  @override
  Future<String?> getAuthToken() async => token;

  @override
  Future<void> saveAuthToken(String value) async {
    token = value;
  }

  @override
  Future<void> deleteAuthToken() async {
    token = null;
  }
}

Dio _buildMockDio(
  Future<Response<dynamic>> Function(RequestOptions options) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, interceptorHandler) async {
        try {
          final response = await handler(options);
          interceptorHandler.resolve(response);
        } on DioException catch (e) {
          interceptorHandler.reject(e);
        } catch (e) {
          interceptorHandler.reject(
            DioException(requestOptions: options, error: e),
          );
        }
      },
    ),
  );
  return dio;
}

void main() {
  group('BUG-05 — Socket Message Payload & Deduplication', () {
    test(
      '1. message:new envelope { conversationId, message, conversation } parses nested message accurately',
      () {
        final rawPayload = <String, dynamic>{
          'conversationId': 42,
          'message': <String, dynamic>{
            'messageId': 9001,
            'conversationId': 42,
            'senderUserId': 15,
            'content': 'Xin chào, căn villa còn trống cuối tuần không ạ?',
            'messageType': 'text',
            'attachments': [
              {'url': 'https://example.com/photo.jpg'},
            ],
            'createdAt': '2026-10-15T08:30:00.000Z',
            'updatedAt': '2026-10-15T08:30:00.000Z',
          },
          'conversation': <String, dynamic>{
            'conversationId': 42,
            'guestUserId': 15,
            'hostUserId': 7,
            'lastMessagePreview':
                'Xin chào, căn villa còn trống cuối tuần không ạ?',
            'lastMessageAt': '2026-10-15T08:30:00.000Z',
            'unreadCount': 2,
          },
        };

        final envelope = SocketMessageEnvelope.fromJson(rawPayload);
        expect(envelope.conversationId, '42');
        expect(envelope.message, isNotNull);
        expect(envelope.message!.id, '9001');
        expect(envelope.message!.conversationId, '42');
        expect(envelope.message!.senderId, '15');
        expect(
          envelope.message!.content,
          'Xin chào, căn villa còn trống cuối tuần không ạ?',
        );
        expect(
            envelope.message!.attachments, ['https://example.com/photo.jpg']);
        expect(envelope.conversation?.unreadCount, 2);

        // ChatMessageItem.fromJson also unwraps envelope directly if passed raw
        final directParsed = ChatMessageItem.fromJson(rawPayload);
        expect(directParsed.id, '9001');
        expect(directParsed.conversationId, '42');
        expect(directParsed.senderId, '15');
      },
    );

    test(
      '2. Messages from another conversation are never merged into the active conversation',
      () {
        const existing = [
          ChatMessageItem(
            id: '101',
            conversationId: 'conv-A',
            senderId: '1',
            content: 'Hello from A',
            createdAt: '2026-10-15T08:00:00Z',
          ),
        ];
        const foreignMessage = ChatMessageItem(
          id: '202',
          conversationId: 'conv-B',
          senderId: '2',
          content: 'Secret message in B',
          createdAt: '2026-10-15T08:05:00Z',
        );

        final merged = ChatMessageItem.mergeAndSortMessages(
          existing,
          const [foreignMessage],
          conversationId: 'conv-A',
        );

        expect(merged.length, 1);
        expect(merged.first.id, '101');
        expect(merged.any((m) => m.id == '202'), isFalse);
      },
    );

    test(
      '3. Duplicate message IDs after reconnect are deduplicated and late messages are sorted chronologically',
      () {
        const msg1 = ChatMessageItem(
          id: '10',
          conversationId: '42',
          senderId: '1',
          content: 'First',
          createdAt: '2026-10-15T08:00:00Z',
        );
        const msg3 = ChatMessageItem(
          id: '12',
          conversationId: '42',
          senderId: '1',
          content: 'Third',
          createdAt: '2026-10-15T08:02:00Z',
        );
        const msg2Late = ChatMessageItem(
          id: '11',
          conversationId: '42',
          senderId: '2',
          content: 'Second (arrived late)',
          createdAt: '2026-10-15T08:01:00Z',
        );
        const msg1Duplicate = ChatMessageItem(
          id: '10',
          conversationId: '42',
          senderId: '1',
          content: 'First',
          createdAt: '2026-10-15T08:00:00Z',
        );

        final merged = ChatMessageItem.mergeAndSortMessages(
          const [msg1, msg3],
          const [msg2Late, msg1Duplicate],
          conversationId: '42',
        );

        expect(merged.map((m) => m.id).toList(), ['10', '11', '12']);
      },
    );
  });

  group('BUG-06 — Conversation Participants & Mark Read', () {
    test(
      '4. ConversationItem.fromJson maps otherParticipant, guestUserId, hostUserId without blind Chủ nhà fallback',
      () {
        final json = <String, dynamic>{
          'conversationId': 88,
          'guestUserId': 101,
          'hostUserId': 202,
          'listingId': 55,
          'listingTitle': 'Villa Bãi Sau',
          'lastMessagePreview': 'Hẹn gặp bạn lúc 14:00 nhé',
          'lastMessageAt': '2026-10-15T09:15:00.000Z',
          'unreadCount': 3,
          'otherParticipant': <String, dynamic>{
            'userId': 101,
            'fullName': 'Trần Minh Khách',
            'avatarUrl': 'https://example.com/guest-avatar.png',
          },
        };

        final conv = ConversationItem.fromJson(json);
        expect(conv.id, '88');
        expect(conv.guestId, '101');
        expect(conv.hostId, '202');
        expect(conv.otherParticipantId, '101');
        expect(conv.otherParticipantName, 'Trần Minh Khách');
        expect(
          conv.otherParticipantAvatar,
          'https://example.com/guest-avatar.png',
        );
        expect(conv.unreadCount, 3);
        expect(conv.displayNameFor('202'), 'Trần Minh Khách');
        expect(conv.avatarFor('202'), 'https://example.com/guest-avatar.png');
      },
    );

    test(
      '5. markConversationRead calls PATCH /api/conversations/:id/read and returns unreadCount',
      () async {
        String? calledMethod;
        String? calledPath;
        final fakeStorage = _FakeSecureStorage();
        final dio = _buildMockDio((options) async {
          calledMethod = options.method;
          calledPath = options.path;
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'conversationId': '88', 'unreadCount': 0},
            },
          );
        });

        final repo = ConversationsRepository(
          DioClient(dio: dio, secureStorage: fakeStorage),
        );
        final res = await repo.markConversationRead('88');
        expect(calledMethod, 'PATCH');
        expect(calledPath, '/api/conversations/88/read');
        expect(res.unreadCount, 0);
      },
    );
  });

  group('BUG-28 — Socket Security & Handshake Auth', () {
    test(
      '6. SocketService.buildSocketUri never puts JWT in URL query string and uses Socket.IO handshake payload',
      () {
        const fakeJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.secret.signature';
        final fakeStorage = _FakeSecureStorage()..token = fakeJwt;
        final socketService = SocketService(secureStorage: fakeStorage);
        final uri = socketService.buildSocketUri('https://api.vungtaustay.com');

        expect(uri.toString().contains(fakeJwt), isFalse);
        expect(uri.queryParameters.containsKey('token'), isFalse);
        expect(uri.queryParameters['EIO'], '4');
        expect(uri.queryParameters['transport'], 'websocket');

        final handshake = SocketService.buildConnectHandshakePacket(fakeJwt);
        expect(handshake, '40{"token":"$fakeJwt"}');
      },
    );

    test(
      '7. Logout disconnects SocketService and clears NotificationsNotifier state',
      () async {
        final fakeStorage = _FakeSecureStorage()..token = 'jwt-user-A';
        final socketService = SocketService(secureStorage: fakeStorage);
        final dio = _buildMockDio((options) async {
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'items': [
                  {
                    'notificationLogId': 1,
                    'title': 'Thông báo tài khoản A',
                    'body': 'Nội dung riêng của A',
                    'eventType': 'booking_created',
                    'isRead': false,
                    'createdAt': '2026-10-15T10:00:00Z',
                  },
                ],
                'unreadCount': 1,
              },
            },
          );
        });

        final notifier = NotificationsNotifier(
          DioClient(dio: dio, secureStorage: fakeStorage),
          true,
          socketService.onNotificationNew,
          socketService: socketService,
          enablePolling: false,
          autoConnectSocket: false,
        );
        await notifier.fetchNotifications();
        expect(notifier.state.items.length, 1);
        expect(notifier.state.unreadCount, 1);

        notifier.clearForLogout();
        expect(notifier.state.items, isEmpty);
        expect(notifier.state.unreadCount, 0);
        expect(socketService.isConnected, isFalse);
        notifier.dispose();
      },
    );
  });

  group('BUG-21 — Realtime Notifications Parsing & Mark Read', () {
    test(
      '8. notification:new parses body, eventType, actionUrl, targetType, targetId and blocks external URLs',
      () {
        final item = AppNotificationItem.fromJson({
          'notificationLogId': 501,
          'eventType': 'message_received',
          'targetType': 'conversation',
          'targetId': 42,
          'title': 'Tin nhắn mới',
          'body': 'Chủ nhà vừa phản hồi bạn.',
          'actionUrl': '/messages?conversationId=42',
          'isRead': false,
          'createdAt': '2026-10-15T11:00:00.000Z',
        });

        expect(item.id, '501');
        expect(item.body, 'Chủ nhà vừa phản hồi bạn.');
        expect(item.message, 'Chủ nhà vừa phản hồi bạn.');
        expect(item.eventType, 'message_received');
        expect(item.targetType, 'conversation');
        expect(item.targetId, '42');
        expect(item.resolveInternalRoute(), '/messages?conversationId=42');

        final malicious = AppNotificationItem.fromJson({
          'id': 502,
          'title': 'Phishing',
          'body': 'Click here',
          'actionUrl': 'https://evil.example.com/phish',
          'targetType': 'booking',
          'targetId': 99,
        });
        // Rejects external URL and falls back to safe internal target route
        expect(
          AppNotificationItem.isSafeInternalRoute(
            'https://evil.example.com/phish',
          ),
          isFalse,
        );
        expect(malicious.resolveInternalRoute(), '/account/trips');
      },
    );

    test(
      '9. NotificationsNotifier markAsRead, markAllAsRead, and realtime notification:new update unreadCount accurately',
      () async {
        final fakeStorage = _FakeSecureStorage()..token = 'jwt-token';
        final socketService = SocketService(secureStorage: fakeStorage);
        final patchedPaths = <String>[];

        final dio = _buildMockDio((options) async {
          if (options.method == 'PATCH') {
            patchedPaths.add(options.path);
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true},
            );
          }
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'items': [
                  {
                    'notificationLogId': 10,
                    'title': 'Đơn đặt mới',
                    'body': 'Bạn có đơn đặt mới #10',
                    'eventType': 'booking_created',
                    'isRead': false,
                    'createdAt': '2026-10-15T10:00:00Z',
                  },
                ],
                'unreadCount': 1,
              },
            },
          );
        });

        final notifier = NotificationsNotifier(
          DioClient(dio: dio, secureStorage: fakeStorage),
          true,
          socketService.onNotificationNew,
          socketService: socketService,
          enablePolling: false,
          autoConnectSocket: false,
        );
        await notifier.fetchNotifications();
        expect(notifier.state.unreadCount, 1);

        // Simulate incoming Socket.IO 42["notification:new", {...}]
        socketService.handleRawPacketForTesting(
          '42["notification:new",{"notificationLogId":11,"title":"Tin nhắn","body":"Xin chào","eventType":"message_received","isRead":false,"createdAt":"2026-10-15T10:05:00Z"}]',
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(notifier.state.items.length, 2);
        expect(notifier.state.unreadCount, 2);

        await notifier.markAsRead('10');
        expect(patchedPaths, contains('/api/notifications/10/read'));
        expect(notifier.state.unreadCount, 1);

        await notifier.markAllAsRead();
        expect(patchedPaths, contains('/api/notifications/read-all'));
        expect(notifier.state.unreadCount, 0);
        notifier.dispose();
      },
    );
  });

  group('BUG-14 & BUG-30 — Admin Repository & Portal Parity', () {
    test(
      '10. getAdminUsers clamps limit to max 100 even when caller requests > 100',
      () async {
        int? sentLimit;
        final dio = _buildMockDio((options) async {
          sentLimit = options.queryParameters['limit'] as int?;
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'items': [
                  {'userId': 1, 'fullName': 'Admin', 'status': 'active'},
                ],
                'pagination': {
                  'page': 1,
                  'limit': 100,
                  'total': 1,
                  'totalPages': 1,
                },
              },
            },
          );
        });

        final repo = AdminRepository(dio);
        await repo.getAdminUsers(page: 1, limit: 500);
        expect(sentLimit, 100);
      },
    );

    test(
      '11. updateAdminUserStatus sends backend schema enum suspended instead of blocked',
      () async {
        String? sentStatus;
        final dio = _buildMockDio((options) async {
          final body = options.data as Map<String, dynamic>;
          sentStatus = body['status'] as String?;
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {'userId': 9, 'status': sentStatus},
            },
          );
        });

        final repo = AdminRepository(dio);
        await repo.updateAdminUserStatus('9', 'blocked');
        expect(sentStatus, 'suspended');

        await repo.updateAdminUserStatus('9', 'suspended');
        expect(sentStatus, 'suspended');
      },
    );

    test(
      '12. AdminOverviewStats reads hostsCreated / activeHosts from backend report and parses revenueSeries',
      () async {
        final dio = _buildMockDio((options) async {
          if (options.path == '/api/admin/reports/hosts') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'totals': {
                    'hostsCreated': 14,
                    'activeHosts': 12,
                    'verifiedHosts': 10,
                  },
                },
              },
            );
          }
          if (options.path == '/api/admin/reports/revenue') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'totals': {
                    'grossRevenue': 45000000,
                    'platformRevenue': 4500000,
                    'hostRevenue': 40500000,
                  },
                  'series': [
                    {
                      'period': '2026-10-14',
                      'grossRevenue': 20000000,
                      'bookingCount': 2,
                    },
                    {
                      'period': '2026-10-15',
                      'grossRevenue': 25000000,
                      'bookingCount': 3,
                    },
                  ],
                },
              },
            );
          }
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'totals': {'totalBookings': 5, 'activeListings': 18},
                'pagination': {'total': 50},
              },
            },
          );
        });

        final repo = AdminRepository(dio);
        final stats = await repo.getOverviewStats(days: 30);
        expect(stats.hosts, 14);
        expect(stats.activeHosts, 12);
        expect(stats.verifiedHosts, 10);
        expect(stats.grossRevenue, 45000000);
        expect(stats.revenueSeries.length, 2);
      },
    );

    test(
      '13. Listing moderation AI image reanalyze endpoints call POST /api/admin/images/:id/reanalyze and /api/ai/listings/:id/analyze-images',
      () async {
        final calledPaths = <String>[];
        final dio = _buildMockDio((options) async {
          calledPaths.add('${options.method} ${options.path}');
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {'aiAnalysisStatus': 'completed', 'aiConfidence': 0.96},
            },
          );
        });

        final repo = AdminRepository(dio);
        await repo.reanalyzeListingImage('77');
        await repo.analyzeAllListingImages('12', force: true);

        expect(calledPaths, contains('POST /api/admin/images/77/reanalyze'));
        expect(
          calledPaths,
          contains('POST /api/ai/listings/12/analyze-images'),
        );
      },
    );

    testWidgets(
      '14 & 15. Admin Host Applications & Legacy Verifications and Role Management (with moderator) render and mutate via real repository',
      (tester) async {
        final updatedRoles = <String, dynamic>{};
        final approvedVerifications = <String>[];

        final dio = _buildMockDio((options) async {
          if (options.path == '/api/admin/host-applications') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'items': [
                    {
                      'applicationId': 301,
                      'contactName': 'Chủ nhà Minh',
                      'phone': '0909123456',
                      'status': 'pending',
                      'documentCount': 2,
                    },
                  ],
                },
              },
            );
          }
          if (options.path == '/api/admin/verifications') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'items': [
                    {
                      'verificationId': 701,
                      'fullName': 'Nguyễn Văn Host',
                      'verificationType': 'cccd',
                      'status': 'pending',
                    },
                  ],
                },
              },
            );
          }
          if (options.path == '/api/admin/verifications/701/approve') {
            approvedVerifications.add('701');
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true},
            );
          }
          if (options.path == '/api/users' && options.method == 'GET') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'items': [
                    {
                      'userId': 55,
                      'fullName': 'Lê Kiểm Duyệt',
                      'email': 'mod@vungtaustay.com',
                      'role': 'guest',
                      'status': 'active',
                    },
                  ],
                  'pagination': {
                    'page': 1,
                    'limit': 100,
                    'total': 1,
                    'totalPages': 1,
                  },
                },
              },
            );
          }
          if (options.path == '/api/users/55' && options.method == 'PATCH') {
            updatedRoles.addAll(options.data as Map<String, dynamic>);
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {'userId': 55, 'role': updatedRoles['role']},
              },
            );
          }
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {'data': <String, dynamic>{}},
          );
        });

        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 14. Host Applications + Legacy Verifications
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminRepositoryProvider.overrideWithValue(AdminRepository(dio)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const AdminPortalScreen(activeTab: 'ho-so-host'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Chủ nhà Minh'), findsOneWidget);
        expect(find.text('Bảng Legacy Verifications'), findsOneWidget);
        expect(find.text('Nguyễn Văn Host (#701)'), findsOneWidget);

        await tester.tap(find.text('Duyệt xác minh'));
        await tester.pumpAndSettle();
        expect(approvedVerifications, contains('701'));

        // 15. Role Management with 'moderator'
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminRepositoryProvider.overrideWithValue(AdminRepository(dio)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const AdminPortalScreen(activeTab: 'phan-quyen'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lê Kiểm Duyệt'), findsOneWidget);
        await tester.tap(find.byType(DropdownButton<String>).first);
        await tester.pumpAndSettle();
        expect(find.text('Moderator'), findsWidgets);

        await tester.tap(find.text('Moderator').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();
        expect(updatedRoles['role'], 'moderator');
      },
    );
  });

  group(
      'BUG-25, BUG-26, BUG-34 & BUG-40 — Design System, Icons, Animations & Blog',
      () {
    test(
      '16. Semantic theme tokens are restored and no longer overwritten with #FFFFFF',
      () {
        expect(AppColors.brandSoft, const Color(0xFFFFF1F3));
        expect(AppColors.rangeBackground, const Color(0xFFFFF1F3));
        expect(AppColors.surfaceMuted, const Color(0xFFF1F5F9));
        expect(AppColors.surfaceWarmSand, const Color(0xFFF7F6F3));
        expect(AppColors.successSoft, const Color(0xFFECFDF5));
        expect(AppColors.warningSoft, const Color(0xFFFFFBEB));
        expect(AppColors.errorSoft, const Color(0xFFFFF1F2));

        expect(AppColors.brandSoft, isNot(const Color(0xFFFFFFFF)));
        expect(AppColors.surfaceMuted, isNot(const Color(0xFFFFFFFF)));
        expect(AppColors.surfaceWarmSand, isNot(const Color(0xFFFFFFFF)));
      },
    );

    testWidgets(
      '17. AnimatedHeartButton and NavigationBar enforce monochrome neutral icons and >= 48x48 touch target',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Center(
                child: AnimatedHeartButton(
                  isFavorite: true,
                  onToggle: () {},
                ),
              ),
            ),
          ),
        );

        final size = tester.getSize(find.byType(AnimatedHeartButton));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, AppColors.iconStrong);
      },
    );

    testWidgets(
      '18. AppModal, AppToast, and FadeSlideIn work and respect reduce motion (disableAnimations)',
      (tester) async {
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    FadeSlideIn(child: Text('Reduced Motion Content')),
                    AppModal(
                      title: 'Tiêu đề Modal',
                      child: Text('Nội dung Modal'),
                    ),
                    AppToast(
                      message: 'Lưu thành công',
                      type: AppToastType.success,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Reduced Motion Content'), findsOneWidget);
        expect(find.text('Tiêu đề Modal'), findsOneWidget);
        expect(find.text('Lưu thành công'), findsOneWidget);
      },
    );

    testWidgets(
      '19. BlogDetailScreen selects and renders Related Posts excluding current post and prioritizing same category',
      (tester) async {
        const currentPost = BlogPost(
          id: '1',
          slug: 'kinh-nghiem-thue-villa-bai-sau',
          title: 'Kinh nghiệm thuê villa Bãi Sau',
          excerpt: 'Tổng hợp kinh nghiệm thuê villa gần biển.',
          content: 'Nội dung chi tiết bài viết số 1.',
          coverImage: 'assets/images/lacase.jpg',
          category: 'Kinh nghiệm đặt villa',
          authorName: 'Ban biên tập',
          publishedAt: '2026-10-10',
        );
        const sameCategoryPost = BlogPost(
          id: '2',
          slug: 'luu-y-khi-nhan-phong-villa',
          title: 'Lưu ý khi nhận phòng villa cho nhóm đông người',
          excerpt: 'Checklist nhận phòng nhanh gọn.',
          content: 'Nội dung bài viết số 2.',
          coverImage: 'assets/images/lacase.jpg',
          category: 'Kinh nghiệm đặt villa',
          authorName: 'Ban biên tập',
          publishedAt: '2026-10-11',
        );
        const otherCategoryPost = BlogPost(
          id: '3',
          slug: 'quan-hai-san-ngon-vung-tau',
          title: 'Top quán hải sản ngon Vũng Tàu',
          excerpt: 'Danh sách quán ăn địa phương.',
          content: 'Nội dung bài viết số 3.',
          coverImage: 'assets/images/lacase.jpg',
          category: 'Ẩm thực địa phương',
          authorName: 'Ban biên tập',
          publishedAt: '2026-10-12',
        );

        final selected = BlogDetailScreen.selectRelatedPosts(
          currentPost,
          const [currentPost, otherCategoryPost, sameCategoryPost],
        );
        expect(selected.length, 2);
        expect(selected.first.slug, 'luu-y-khi-nhan-phong-villa');
        expect(selected.last.slug, 'quan-hai-san-ngon-vung-tau');
        expect(selected.any((p) => p.slug == currentPost.slug), isFalse);

        final fakeStorage = _FakeSecureStorage();
        final dio = _buildMockDio((options) async {
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {'items': const <dynamic>[], 'unreadCount': 0}
            },
          );
        });

        await tester.binding.setSurfaceSize(const Size(1200, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              secureStorageProvider.overrideWithValue(fakeStorage),
              dioClientProvider.overrideWithValue(
                DioClient(dio: dio, secureStorage: fakeStorage),
              ),
              blogDetailProvider('kinh-nghiem-thue-villa-bai-sau')
                  .overrideWith((ref) async => currentPost),
              blogListProvider(null).overrideWith(
                (ref) async => const [
                  currentPost,
                  sameCategoryPost,
                  otherCategoryPost,
                ],
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const BlogDetailScreen(
                slug: 'kinh-nghiem-thue-villa-bai-sau',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gợi ý đọc tiếp'), findsOneWidget);
        expect(
          find.text('Lưu ý khi nhận phòng villa cho nhóm đông người'),
          findsOneWidget,
        );
        expect(find.text('Top quán hải sản ngon Vũng Tàu'), findsOneWidget);
      },
    );
  });
}
