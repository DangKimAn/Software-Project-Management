import 'dart:async';
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
import 'package:hotel_booking_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/messages/data/conversations_repository.dart';
import 'package:hotel_booking_flutter/features/messages/presentation/screens/messages_screen.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';

class _FakeSecureStorage extends SecureStorageService {
  String? token;

  _FakeSecureStorage([this.token = 'jwt-guest-10']);

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

class _FakeAuthRepository implements AuthRepository {
  User? currentUser;

  _FakeAuthRepository(this.currentUser);

  @override
  Future<User?> getCurrentUser() async => currentUser;

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> loginWithGoogle({required String idToken}) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> forgotPassword({required String identifier}) async {}

  @override
  Future<void> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {}

  @override
  Future<User> updateProfile({
    String? fullName,
    String? phone,
    String? bio,
    String? location,
    String? job,
    String? dreamDestination,
    String? school,
    List<String>? languages,
    String? avatarUrl,
  }) =>
      throw UnimplementedError();

  @override
  Future<User> updateAvatar({required String url, String? key}) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {
    currentUser = null;
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

const _guestUser = User(
  id: '10',
  email: 'guest10@example.com',
  firstName: 'Minh',
  lastName: 'Khách',
  role: 'guest',
);

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
}

Map<String, dynamic> _buildConvJson({
  required int id,
  int guestUserId = 10,
  int hostUserId = 20,
  int listingId = 101,
  String listingTitle = 'Villa Bãi Sau Minh Thanh',
  String otherName = 'Chủ nhà Hải Đăng',
  String lastMessage = 'Xin chào quý khách!',
  String lastMessageAt = '2026-10-20T09:00:00.000Z',
  int unreadCount = 0,
}) {
  return <String, dynamic>{
    'id': id,
    'conversationId': id,
    'listingId': listingId,
    'listingTitle': listingTitle,
    'guestUserId': guestUserId,
    'hostUserId': hostUserId,
    'lastMessage': lastMessage,
    'lastMessageAt': lastMessageAt,
    'unreadCount': unreadCount,
    'otherParticipant': <String, dynamic>{
      'userId': hostUserId,
      'fullName': otherName,
    },
  };
}

Map<String, dynamic> _buildMsgJson({
  required int id,
  required int conversationId,
  required int senderId,
  required String content,
  required String createdAt,
}) {
  return <String, dynamic>{
    'id': id,
    'messageId': id,
    'conversationId': conversationId,
    'senderUserId': senderId,
    'senderId': senderId,
    'content': content,
    'messageType': 'text',
    'attachments': const <dynamic>[],
    'createdAt': createdAt,
  };
}

void main() {
  group('1. REST Contract, Pagination, Validation & Room Authorization', () {
    test(
      'ConversationsRepository clamps pagination limits, validates message length, and parses pagination metadata',
      () async {
        Map<String, dynamic>? lastQuery;
        final dio = _buildMockDio((options) async {
          lastQuery = options.queryParameters;
          if (options.path == '/api/conversations') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [
                    _buildConvJson(id: 1),
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
          if (options.path == '/api/conversations/1/messages' &&
              options.method == 'GET') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [
                    _buildMsgJson(
                      id: 501,
                      conversationId: 1,
                      senderId: 20,
                      content: 'Chào bạn',
                      createdAt: '2026-10-20T09:00:00.000Z',
                    ),
                  ],
                  'pagination': {
                    'page': 1,
                    'limit': 100,
                    'total': 120,
                    'totalPages': 2,
                  },
                },
              },
            );
          }
          return Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              'success': true,
              'data': {
                'message': _buildMsgJson(
                  id: 502,
                  conversationId: 1,
                  senderId: 10,
                  content: (options.data as Map)['content'] as String,
                  createdAt: '2026-10-20T09:01:00.000Z',
                ),
              },
            },
          );
        });

        final repo = ConversationsRepository(
          DioClient(dio: dio, secureStorage: _FakeSecureStorage()),
        );

        final convPage = await repo.getConversationsPaginated(
          page: 0,
          limit: 500,
          scope: 'guest',
          unreadOnly: true,
        );
        expect(lastQuery?['page'], 1);
        expect(lastQuery?['limit'], 100);
        expect(lastQuery?['scope'], 'guest');
        expect(lastQuery?['unreadOnly'], isTrue);
        expect(convPage.items.length, 1);

        final msgPage =
            await repo.getMessagesPaginated('1', page: 1, limit: 250);
        expect(lastQuery?['limit'], 100);
        expect(msgPage.pagination.totalPages, 2);
        expect(msgPage.pagination.hasNext, isTrue);

        // Rejects empty or > 2000 character messages before hitting network
        await expectLater(
          repo.sendMessage(conversationId: '1', content: '   '),
          throwsA(isA<Object>()),
        );
        await expectLater(
          repo.sendMessage(conversationId: '1', content: 'a' * 2001),
          throwsA(isA<Object>()),
        );

        final sent = await repo.sendMessage(
          conversationId: '1',
          content: '  Tin nhắn hợp lệ  ',
        );
        expect(sent.id, '502');
        expect(sent.content, 'Tin nhắn hợp lệ');
        expect(sent.isSent, isTrue);
      },
    );

    test(
      'ConversationItem.canAccess blocks guest from reading threads belonging to another guest/host pair',
      () {
        final ownThread = ConversationItem.fromJson(
          _buildConvJson(id: 1, guestUserId: 10, hostUserId: 20),
        );
        final otherHostThread = ConversationItem.fromJson(
          _buildConvJson(id: 999, guestUserId: 77, hostUserId: 88),
        );

        expect(ownThread.canAccess('10', isHostPortal: false), isTrue);
        expect(ownThread.canAccess('10', isHostPortal: true), isFalse);
        expect(ownThread.canAccess('20', isHostPortal: true), isTrue);

        // Guest 10 must NEVER be allowed to access thread 999 between guest 77 and host 88
        expect(otherHostThread.canAccess('10', isHostPortal: false), isFalse);
        expect(otherHostThread.canAccess('10', isHostPortal: true), isFalse);
      },
    );
  });

  group('2. Duplicate POST vs Socket message:new, Pending/Sent/Failed & Retry',
      () {
    testWidgets(
      'Sending message shows Đang gửi..., deduplicates with Socket message:new, and shows Đã gửi only after server confirmation',
      (tester) async {
        final postCompleter = Completer<Response<dynamic>>();
        final storage = _FakeSecureStorage('jwt-guest-10');
        final socketService = SocketService(secureStorage: storage);

        final dio = _buildMockDio((options) async {
          if (options.path == '/api/conversations') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [_buildConvJson(id: 42)],
                },
              },
            );
          }
          if (options.path == '/api/conversations/42/messages' &&
              options.method == 'GET') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'items': const <dynamic>[]},
              },
            );
          }
          if (options.path == '/api/conversations/42/messages' &&
              options.method == 'POST') {
            return postCompleter.future;
          }
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': <String, dynamic>{}},
          );
        });

        final client = DioClient(dio: dio, secureStorage: storage);
        final authNotifier = AuthNotifier(
          _FakeAuthRepository(_guestUser),
          socket: socketService,
          dioClient: client,
        );

        await _setViewport(tester, const Size(1280, 800));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioClientProvider.overrideWithValue(client),
              socketServiceProvider.overrideWithValue(socketService),
              authNotifierProvider.overrideWith((_) => authNotifier),
              conversationsRepositoryProvider.overrideWithValue(
                ConversationsRepository(client),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MessagesScreen(initialConversationId: '42'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter text and press Send
        await tester.enterText(
          find.byKey(const Key('chat_message_input')),
          'Cho mình hỏi giá cuối tuần nhé',
        );
        await tester.tap(find.byKey(const Key('chat_send_button')));
        await tester.pump();

        // Before server confirms: must show 'Đang gửi...' and NEVER 'Đã gửi'
        expect(find.text('Cho mình hỏi giá cuối tuần nhé'), findsOneWidget);
        expect(find.text('Đang gửi...'), findsOneWidget);
        expect(find.text('Đã gửi'), findsNothing);

        // Simulate Socket `message:new` arriving BEFORE POST response finishes
        socketService.handleRawPacketForTesting(
          '42["message:new",{"conversationId":42,"message":{"id":901,"messageId":901,"conversationId":42,"senderUserId":10,"content":"Cho mình hỏi giá cuối tuần nhé","createdAt":"2026-10-20T09:05:00.000Z"}}]',
        );
        await tester.pump();

        // Now complete POST response with the same message ID 901
        postCompleter.complete(
          Response(
            requestOptions: RequestOptions(
              path: '/api/conversations/42/messages',
            ),
            statusCode: 201,
            data: {
              'success': true,
              'data': {
                'message': _buildMsgJson(
                  id: 901,
                  conversationId: 42,
                  senderId: 10,
                  content: 'Cho mình hỏi giá cuối tuần nhé',
                  createdAt: '2026-10-20T09:05:00.000Z',
                ),
              },
            },
          ),
        );
        await tester.pumpAndSettle();

        // Message must NOT be duplicated in chat pane (1 bubble + 1 preview in sidebar = 2 max, only 1 in message list)
        final listFinder = find.byKey(const Key('chat_message_list_42'));
        expect(
          find.descendant(
            of: listFinder,
            matching: find.text('Cho mình hỏi giá cuối tuần nhé'),
          ),
          findsOneWidget,
        );
        expect(find.text('Đang gửi...'), findsNothing);
        expect(find.text('Đã gửi'), findsOneWidget);

        socketService.dispose();
      },
    );

    testWidgets(
      'Failed POST shows Gửi thất bại + Thử lại button, and retrying succeeds',
      (tester) async {
        var sendAttempts = 0;
        final storage = _FakeSecureStorage('jwt-guest-10');
        final socketService = SocketService(secureStorage: storage);

        final dio = _buildMockDio((options) async {
          if (options.path == '/api/conversations') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [_buildConvJson(id: 42)],
                },
              },
            );
          }
          if (options.path == '/api/conversations/42/messages' &&
              options.method == 'GET') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'items': const <dynamic>[]},
              },
            );
          }
          if (options.path == '/api/conversations/42/messages' &&
              options.method == 'POST') {
            sendAttempts++;
            if (sendAttempts == 1) {
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Network dropped',
              );
            }
            return Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'success': true,
                'data': {
                  'message': _buildMsgJson(
                    id: 902,
                    conversationId: 42,
                    senderId: 10,
                    content: 'Tin nhắn gửi lại khi có mạng',
                    createdAt: '2026-10-20T09:10:00.000Z',
                  ),
                },
              },
            );
          }
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': <String, dynamic>{}},
          );
        });

        final client = DioClient(dio: dio, secureStorage: storage);
        final authNotifier = AuthNotifier(
          _FakeAuthRepository(_guestUser),
          socket: socketService,
          dioClient: client,
        );

        await _setViewport(tester, const Size(1280, 800));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioClientProvider.overrideWithValue(client),
              socketServiceProvider.overrideWithValue(socketService),
              authNotifierProvider.overrideWith((_) => authNotifier),
              conversationsRepositoryProvider.overrideWithValue(
                ConversationsRepository(client),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MessagesScreen(initialConversationId: '42'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('chat_message_input')),
          'Tin nhắn gửi lại khi có mạng',
        );
        await tester.tap(find.byKey(const Key('chat_send_button')));
        await tester.pumpAndSettle();

        expect(find.text('Gửi thất bại'), findsOneWidget);
        expect(find.text('Thử lại'), findsOneWidget);
        expect(find.text('Đã gửi'), findsNothing);

        // Tap Retry
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();

        expect(sendAttempts, 2);
        expect(find.text('Gửi thất bại'), findsNothing);
        expect(find.text('Đã gửi'), findsOneWidget);

        socketService.dispose();
      },
    );
  });

  group('3. Draft Saving When Switching Conversations & Unread Badge', () {
    testWidgets(
      'Draft is preserved per conversation when switching chats and unread badge updates on message:new',
      (tester) async {
        final storage = _FakeSecureStorage('jwt-guest-10');
        final socketService = SocketService(secureStorage: storage);

        final dio = _buildMockDio((options) async {
          if (options.path == '/api/conversations') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [
                    _buildConvJson(
                      id: 1,
                      otherName: 'Chủ nhà Căn 1',
                      listingTitle: 'Villa Căn 1',
                      lastMessageAt: '2026-10-20T09:05:00.000Z',
                    ),
                    _buildConvJson(
                      id: 2,
                      otherName: 'Chủ nhà Căn 2',
                      listingTitle: 'Villa Căn 2',
                      lastMessageAt: '2026-10-20T09:00:00.000Z',
                    ),
                  ],
                },
              },
            );
          }
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'items': const <dynamic>[]},
            },
          );
        });

        final client = DioClient(dio: dio, secureStorage: storage);
        final authNotifier = AuthNotifier(
          _FakeAuthRepository(_guestUser),
          socket: socketService,
          dioClient: client,
        );

        await _setViewport(tester, const Size(1280, 800));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioClientProvider.overrideWithValue(client),
              socketServiceProvider.overrideWithValue(socketService),
              authNotifierProvider.overrideWith((_) => authNotifier),
              conversationsRepositoryProvider.overrideWithValue(
                ConversationsRepository(client),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MessagesScreen(initialConversationId: '1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Type draft in Conversation 1
        await tester.enterText(
          find.byKey(const Key('chat_message_input')),
          'Bản nháp cho căn số 1',
        );
        await tester.pump();

        // Switch to Conversation 2
        await tester.tap(find.byKey(const Key('conv_tile_2')));
        await tester.pumpAndSettle();

        // Input for Conversation 2 must be empty, and Conversation 1 tile shows draft preview
        final inputField = tester.widget<TextField>(
          find.byKey(const Key('chat_message_input')),
        );
        expect(inputField.controller?.text, isEmpty);
        expect(
            find.textContaining('Nháp: Bản nháp cho căn số 1'), findsOneWidget);

        // Simulate incoming message:new for inactive Conversation 1 -> unread badge appears
        socketService.handleRawPacketForTesting(
          '42["message:new",{"conversationId":1,"message":{"id":777,"conversationId":1,"senderUserId":20,"content":"Căn 1 vẫn còn trống nhé","createdAt":"2026-10-20T09:20:00.000Z"}}]',
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('unread_badge_1')), findsOneWidget);

        // Switch back to Conversation 1 -> draft is restored and unread badge is cleared
        await tester.tap(find.byKey(const Key('conv_tile_1')));
        await tester.pumpAndSettle();

        final restoredInput = tester.widget<TextField>(
          find.byKey(const Key('chat_message_input')),
        );
        expect(restoredInput.controller?.text, 'Bản nháp cho căn số 1');
        expect(find.byKey(const Key('unread_badge_1')), findsNothing);

        socketService.dispose();
      },
    );
  });

  group(
      '4. 403 Forbidden Thread Protection, 500 Server Error & Pagination History',
      () {
    testWidgets(
      'Guest cannot read another host thread (403 Forbidden) and 500 ServerError is not mislabeled as offline',
      (tester) async {
        final storage = _FakeSecureStorage('jwt-guest-10');
        final socketService = SocketService(secureStorage: storage);

        final dio = _buildMockDio((options) async {
          if (options.path == '/api/conversations') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [
                    // Foreign thread between guest 77 and host 88
                    _buildConvJson(id: 999, guestUserId: 77, hostUserId: 88),
                  ],
                },
              },
            );
          }
          if (options.path == '/api/conversations/999/messages') {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 403,
                data: {
                  'success': false,
                  'message': 'Bạn không có quyền truy cập cuộc trò chuyện này.',
                },
              ),
            );
          }
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': <String, dynamic>{}},
          );
        });

        final client = DioClient(dio: dio, secureStorage: storage);
        final authNotifier = AuthNotifier(
          _FakeAuthRepository(_guestUser),
          socket: socketService,
          dioClient: client,
        );

        await _setViewport(tester, const Size(390, 844));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioClientProvider.overrideWithValue(client),
              socketServiceProvider.overrideWithValue(socketService),
              authNotifierProvider.overrideWith((_) => authNotifier),
              conversationsRepositoryProvider.overrideWithValue(
                ConversationsRepository(client),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MessagesScreen(initialConversationId: '999'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Không có quyền truy cập'), findsOneWidget);
        expect(
          find.text('Bạn không có quyền truy cập cuộc trò chuyện này.'),
          findsOneWidget,
        );
        // Composer input must be hidden for forbidden threads
        expect(find.byKey(const Key('chat_message_input')), findsNothing);
        expect(
          socketService.joinedConversationsForTesting,
          isNot(contains('999')),
        );

        socketService.dispose();
      },
    );

    testWidgets(
      '500 Server Error is not mislabeled as offline, Retry succeeds, History Pagination loads page 2, and Typing indicator displays',
      (tester) async {
        final storage = _FakeSecureStorage('jwt-guest-10');
        final socketService = SocketService(secureStorage: storage);
        var failConversations = true;

        final dio = _buildMockDio((options) async {
          if (options.path == '/api/conversations') {
            if (failConversations) {
              throw DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 500,
                  data: {
                    'success': false,
                    'message': 'Lỗi máy chủ nội bộ 500',
                  },
                ),
              );
            }
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [_buildConvJson(id: 42)],
                },
              },
            );
          }
          if (options.path == '/api/conversations/42/messages') {
            final page = (options.queryParameters['page'] as int?) ?? 1;
            if (page == 1) {
              return Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'items': [
                      _buildMsgJson(
                        id: 102,
                        conversationId: 42,
                        senderId: 20,
                        content: 'Tin nhắn trang 1 mới hơn',
                        createdAt: '2026-10-20T09:10:00.000Z',
                      ),
                    ],
                    'pagination': {
                      'page': 1,
                      'limit': 50,
                      'total': 2,
                      'totalPages': 2,
                    },
                  },
                },
              );
            }
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [
                    _buildMsgJson(
                      id: 101,
                      conversationId: 42,
                      senderId: 10,
                      content: 'Tin nhắn lịch sử trang 2 cũ hơn',
                      createdAt: '2026-10-20T08:00:00.000Z',
                    ),
                  ],
                  'pagination': {
                    'page': 2,
                    'limit': 50,
                    'total': 2,
                    'totalPages': 2,
                  },
                },
              },
            );
          }
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': <String, dynamic>{}},
          );
        });

        final client = DioClient(dio: dio, secureStorage: storage);
        final authNotifier = AuthNotifier(
          _FakeAuthRepository(_guestUser),
          socket: socketService,
          dioClient: client,
        );

        await _setViewport(tester, const Size(1280, 800));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioClientProvider.overrideWithValue(client),
              socketServiceProvider.overrideWithValue(socketService),
              authNotifierProvider.overrideWith((_) => authNotifier),
              conversationsRepositoryProvider.overrideWithValue(
                ConversationsRepository(client),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MessagesScreen(initialConversationId: '42'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 500 error must show 'Lỗi máy chủ' and NOT 'Mất kết nối mạng'
        expect(find.text('Lỗi máy chủ'), findsOneWidget);
        expect(find.text('Mất kết nối mạng'), findsNothing);
        expect(find.text('Lỗi máy chủ nội bộ 500'), findsOneWidget);

        // Tap Retry -> loads conversations and page 1 of messages
        failConversations = false;
        await tester.tap(find.text('Thử lại').first);
        await tester.pumpAndSettle();

        expect(find.text('Tin nhắn trang 1 mới hơn'), findsOneWidget);
        expect(
            find.byKey(const Key('load_more_history_button')), findsOneWidget);

        // Tap 'Tải tin nhắn cũ hơn' -> loads page 2 and merges in chronological order
        await tester.tap(find.byKey(const Key('load_more_history_button')));
        await tester.pumpAndSettle();

        expect(find.text('Tin nhắn lịch sử trang 2 cũ hơn'), findsOneWidget);
        expect(find.byKey(const Key('load_more_history_button')), findsNothing);

        // Simulate typing indicator event from Host (userId: 20)
        socketService.handleRawPacketForTesting(
          '42["conversation:typing",{"conversationId":42,"userId":20,"isTyping":true}]',
        );
        await tester.pumpAndSettle();
        expect(
            find.byKey(const Key('typing_indicator_banner')), findsOneWidget);

        socketService.handleRawPacketForTesting(
          '42["conversation:typing",{"conversationId":42,"userId":20,"isTyping":false}]',
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('typing_indicator_banner')), findsNothing);

        socketService.dispose();
      },
    );
  });

  group('5. 200-Item List, Scroll Retention & Auto-Scroll Only Near Bottom',
      () {
    testWidgets(
      'Renders 200-item message list, retains scroll position when user scrolled up, and auto-scrolls when near bottom',
      (tester) async {
        final storage = _FakeSecureStorage('jwt-guest-10');
        final socketService = SocketService(secureStorage: storage);

        final twoHundredMessages = List<Map<String, dynamic>>.generate(
          200,
          (i) {
            final idx = i + 1;
            final minute = (i % 60).toString().padLeft(2, '0');
            final hour = ((i ~/ 60) % 24).toString().padLeft(2, '0');
            return _buildMsgJson(
              id: idx,
              conversationId: 42,
              senderId: idx.isEven ? 10 : 20,
              content: 'Tin nhắn lịch sử thứ #$idx trong cuộc trò chuyện',
              createdAt: '2026-10-20T$hour:$minute:00.000Z',
            );
          },
        );

        final dio = _buildMockDio((options) async {
          if (options.path == '/api/conversations') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [_buildConvJson(id: 42)],
                },
              },
            );
          }
          if (options.path == '/api/conversations/42/messages') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': twoHundredMessages,
                  'pagination': {
                    'page': 1,
                    'limit': 200,
                    'total': 200,
                    'totalPages': 1,
                  },
                },
              },
            );
          }
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': <String, dynamic>{}},
          );
        });

        final client = DioClient(dio: dio, secureStorage: storage);
        final authNotifier = AuthNotifier(
          _FakeAuthRepository(_guestUser),
          socket: socketService,
          dioClient: client,
        );

        await _setViewport(tester, const Size(390, 844));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioClientProvider.overrideWithValue(client),
              socketServiceProvider.overrideWithValue(socketService),
              authNotifierProvider.overrideWith((_) => authNotifier),
              conversationsRepositoryProvider.overrideWithValue(
                ConversationsRepository(client),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MessagesScreen(initialConversationId: '42'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollableFinder = find.descendant(
          of: find.byKey(const Key('chat_message_list_42')),
          matching: find.byType(Scrollable),
        );
        final scrollableState = tester.state<ScrollableState>(scrollableFinder);

        // User scrolls up to offset 250.0 (far from the bottom of the 200-item list)
        scrollableState.position.jumpTo(250.0);
        await tester.pump();
        expect(scrollableState.position.pixels, 250.0);

        // Incoming message #201 from Host arrives while user is scrolled up
        socketService.handleRawPacketForTesting(
          '42["message:new",{"conversationId":42,"message":{"id":201,"messageId":201,"conversationId":42,"senderUserId":20,"content":"Tin nhắn mới 201 khi đang cuộn lên","createdAt":"2026-10-20T23:59:00.000Z"}}]',
        );
        await tester.pumpAndSettle();

        // Scroll offset MUST be retained at 250.0 (no unwanted jump to bottom)
        expect(scrollableState.position.pixels, 250.0);
        // Floating pill "Tin nhắn mới (1)" appears
        expect(find.byKey(const Key('jump_to_bottom_button')), findsOneWidget);

        // Tap "Tin nhắn mới (1)" to jump to bottom
        await tester.tap(find.byKey(const Key('jump_to_bottom_button')));
        await tester.pumpAndSettle();
        expect(
          scrollableState.position.maxScrollExtent -
              scrollableState.position.pixels,
          lessThanOrEqualTo(120.0),
        );

        socketService.dispose();
      },
    );
  });

  group(
      '6. Responsive Widths (320/360/390/430dp), TextScale (1.0/1.3/1.6), Keyboard & Touch Targets',
      () {
    testWidgets(
      'MessagesScreen and HostMessageScreen render without overflow across 320/360/390/430dp, textScale 1.0/1.3/1.6, and open keyboard',
      (tester) async {
        final storage = _FakeSecureStorage('jwt-guest-10');
        final socketService = SocketService(secureStorage: storage);

        final dio = _buildMockDio((options) async {
          if (options.path == '/api/conversations') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [
                    _buildConvJson(
                      id: 42,
                      guestUserId: 20,
                      hostUserId: 10,
                      otherName:
                          'Chủ nhà Biệt Thự Nghỉ Dưỡng Minh Thanh Vũng Tàu Tên Rất Dài',
                      listingTitle:
                          'Biệt Thự Hồ Bơi Nước Mặn Sát Biển Bãi Sau Vũng Tàu Cao Cấp',
                    ),
                  ],
                },
              },
            );
          }
          if (options.path == '/api/conversations/42/messages') {
            return Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'items': [
                    _buildMsgJson(
                      id: 1,
                      conversationId: 42,
                      senderId: 20,
                      content:
                          'Nội dung tin nhắn rất dài không ngắt dòng https://minhthanhvilla.com/villa/vung-tau-bai-sau-ho-boi-nuoc-man-cao-cap-2026 để kiểm tra không tràn ở màn hình 320dp.',
                      createdAt: '2026-10-20T08:30:00.000Z',
                    ),
                    _buildMsgJson(
                      id: 2,
                      conversationId: 42,
                      senderId: 10,
                      content:
                          'Cảm ơn chủ nhà, đoàn mình gồm 15 người lớn và 4 trẻ em sẽ nhận phòng lúc 14:00 thứ Bảy tuần này ạ!',
                      createdAt: '2026-10-20T08:35:00.000Z',
                    ),
                  ],
                },
              },
            );
          }
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true, 'data': <String, dynamic>{}},
          );
        });

        final client = DioClient(dio: dio, secureStorage: storage);
        final authNotifier = AuthNotifier(
          _FakeAuthRepository(_guestUser),
          socket: socketService,
          dioClient: client,
        );

        const widths = <double>[320, 360, 390, 430];
        const scales = <double>[1.0, 1.3, 1.6];

        const testVilla = Villa(
          id: '101',
          code: 'MTV-101',
          name: 'Villa Bãi Sau Minh Thanh Vũng Tàu',
          tagline: 'Biệt thự hồ bơi riêng gần biển',
          address: 'Bãi Sau, TP. Vũng Tàu',
          description: 'Biệt thự nghỉ dưỡng cao cấp tại Bãi Sau.',
          basePriceVnd: 4500000,
          rating: 4.9,
          reviewCount: 18,
          imageUrls: ['assets/images/NDT05929-HDR1.jpg'],
          specs: VillaSpecs(
            bedrooms: 5,
            beds: 7,
            maxGuests: 15,
            bathrooms: 5,
          ),
        );

        for (final width in widths) {
          for (final scale in scales) {
            await _setViewport(tester, Size(width, 740));
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  dioClientProvider.overrideWithValue(client),
                  socketServiceProvider.overrideWithValue(socketService),
                  authNotifierProvider.overrideWith((_) => authNotifier),
                  conversationsRepositoryProvider.overrideWithValue(
                    ConversationsRepository(client),
                  ),
                  villaDetailProvider('101').overrideWith(
                    (_) async => testVilla,
                  ),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(width, 740),
                      textScaler: TextScaler.linear(scale),
                      viewInsets: const EdgeInsets.only(bottom: 240),
                    ),
                    child: child!,
                  ),
                  home: const MessagesScreen(
                    initialConversationId: '42',
                    isHostPortal: true,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Verify >= 48x48 touch targets on interactive controls
            final sendSize = tester.getSize(
              find.byKey(const Key('chat_send_button')),
            );
            expect(sendSize.width, greaterThanOrEqualTo(48));
            expect(sendSize.height, greaterThanOrEqualTo(48));

            final backSize = tester.getSize(
              find.byKey(const Key('chat_back_button')),
            );
            expect(backSize.width, greaterThanOrEqualTo(48));
            expect(backSize.height, greaterThanOrEqualTo(48));
          }
        }

        // Also verify HostMessageScreen at 320dp with textScale 1.6
        await _setViewport(tester, const Size(320, 740));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioClientProvider.overrideWithValue(client),
              socketServiceProvider.overrideWithValue(socketService),
              authNotifierProvider.overrideWith((_) => authNotifier),
              conversationsRepositoryProvider.overrideWithValue(
                ConversationsRepository(client),
              ),
              villaDetailProvider('101').overrideWith(
                (_) async => testVilla,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: const Size(320, 740),
                  textScaler: const TextScaler.linear(1.6),
                ),
                child: child!,
              ),
              home: const HostMessageScreen(villaId: '101'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Liên hệ Chủ nhà'), findsOneWidget);

        // Verify monochrome icon color in header
        final backIcon = tester.widget<Icon>(find.byType(Icon).first);
        expect(backIcon.color, AppColors.iconStrong);

        socketService.dispose();
      },
    );
  });
}
