import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/network/socket_service.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/messages/data/conversations_repository.dart';
import 'package:hotel_booking_flutter/features/messages/presentation/screens/messages_screen.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';

class _FakeSecureStorage extends SecureStorageService {
  @override
  Future<String?> getAuthToken() async => 'mock-jwt-token';
}

class _FakeAuthNotifier extends StateNotifier<AsyncValue<User?>>
    implements AuthNotifier {
  _FakeAuthNotifier(User user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocaleNotifier extends StateNotifier<String>
    implements LocaleNotifier {
  _FakeLocaleNotifier([super.locale = 'en']);

  @override
  Future<void> setLocale(String languageCode) async {
    state = languageCode;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const guestUser = User(
    id: 'user-guest-10',
    email: 'guest@example.com',
    firstName: 'Ngoc Lan',
    lastName: 'Tran',
    role: 'guest',
  );

  const testVilla = Villa(
    id: 'villa-101',
    code: 'MTV-101',
    name: 'Seaside Sunset Homestay',
    tagline: 'Biệt thự hồ bơi riêng gần biển',
    address: '84 Hạ Long, Vũng Tàu',
    description: 'Chỗ nghỉ sát biển view hoàng hôn.',
    basePriceVnd: 3500000,
    rating: 4.9,
    reviewCount: 24,
    imageUrls: ['assets/images/NDT05929-HDR1.jpg'],
    specs: VillaSpecs(
      bedrooms: 4,
      beds: 5,
      maxGuests: 10,
      bathrooms: 4,
    ),
  );

  Dio buildMockDio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:7000'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/api/conversations/conv-42/messages') &&
              options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'items': <Map<String, dynamic>>[],
                    'pagination': {
                      'page': 1,
                      'limit': 50,
                      'total': 0,
                      'totalPages': 1,
                      'hasNext': false,
                      'hasPrev': false,
                    },
                  },
                },
              ),
            );
          }
          if (options.path == '/api/conversations' && options.method == 'GET') {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'items': [
                      {
                        'id': 'conv-42',
                        'conversationId': 'conv-42',
                        'listingId': 'villa-101',
                        'listingTitle': 'Seaside Sunset Homestay',
                        'guestUserId': 'user-guest-10',
                        'guestName': 'Ngoc Lan Tran',
                        'hostUserId': 'user-host-20',
                        'hostName': 'The Palm Villa Host',
                        'lastMessage': 'Hello there!',
                        'lastMessageAt': '2026-11-04T08:00:00.000Z',
                        'unreadCount': 0,
                        'otherParticipant': {
                          'userId': 'user-host-20',
                          'fullName': 'The Palm Villa Host',
                        },
                      }
                    ],
                  },
                },
              ),
            );
          }
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': <String, dynamic>{}},
            ),
          );
        },
      ),
    );
    return dio;
  }

  Widget buildMessagesApp(String localeCode) {
    final dio = buildMockDio();
    final client = DioClient(dio: dio, secureStorage: _FakeSecureStorage());
    final socket = SocketService(secureStorage: _FakeSecureStorage());

    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => _FakeLocaleNotifier(localeCode)),
        authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(guestUser)),
        dioClientProvider.overrideWithValue(client),
        socketServiceProvider.overrideWithValue(socket),
        conversationsRepositoryProvider.overrideWithValue(ConversationsRepository(client)),
        villaDetailProvider('villa-101').overrideWith((ref) async => testVilla),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: Locale(localeCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const MessagesScreen(initialConversationId: 'conv-42'),
      ),
    );
  }

  Widget buildHostMessageApp(String localeCode) {
    final dio = buildMockDio();
    final client = DioClient(dio: dio, secureStorage: _FakeSecureStorage());
    final socket = SocketService(secureStorage: _FakeSecureStorage());

    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => _FakeLocaleNotifier(localeCode)),
        authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier(guestUser)),
        dioClientProvider.overrideWithValue(client),
        socketServiceProvider.overrideWithValue(socket),
        conversationsRepositoryProvider.overrideWithValue(ConversationsRepository(client)),
        villaDetailProvider('villa-101').overrideWith((ref) async => testVilla),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: Locale(localeCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const HostMessageScreen(villaId: 'villa-101'),
      ),
    );
  }

  group('MessagesScreen & HostMessageScreen Locale Reactivity', () {
    testWidgets('Renders in English when locale is en', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(buildMessagesApp('en'));
      await tester.pumpAndSettle();

      // Check header button
      expect(find.text('View listing'), findsOneWidget);
      // Check input hint placeholder
      expect(find.text('Message'), findsOneWidget);
      // Check English quick-reply questions
      expect(
        find.text('Is this villa available for these dates?'),
        findsOneWidget,
      );
      // Check empty prompt
      expect(
        find.text('Send a message to start the conversation.'),
        findsOneWidget,
      );

      // Verify HostMessageScreen in English
      await tester.pumpWidget(buildHostMessageApp('en'));
      await tester.pumpAndSettle();

      expect(find.text('Contact Host'), findsOneWidget);
      expect(find.text('Back to villa details'), findsOneWidget);
      expect(find.text('Frequently asked questions for Host:'), findsOneWidget);
      expect(find.text('Send message & Open chat'), findsOneWidget);
    });

    testWidgets('Renders in Korean when locale is ko', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(buildMessagesApp('ko'));
      await tester.pumpAndSettle();

      // Check header button in Korean
      expect(find.text('숙소 보기'), findsOneWidget);
      // Check input placeholder in Korean
      expect(find.text('메시지 보내기'), findsOneWidget);
      // Check Korean quick-reply question
      expect(
        find.text('이 일정에 예약 가능한가요?'),
        findsOneWidget,
      );

      // Verify HostMessageScreen in Korean
      await tester.pumpWidget(buildHostMessageApp('ko'));
      await tester.pumpAndSettle();

      expect(find.text('호스트에게 문의하기'), findsOneWidget);
      expect(find.text('빌라 페이지로 돌아가기'), findsOneWidget);
      expect(find.text('호스트 자주 묻는 질문:'), findsOneWidget);
    });

    testWidgets('Renders in Vietnamese when locale is vi', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(buildMessagesApp('vi'));
      await tester.pumpAndSettle();

      // Check header button in Vietnamese
      expect(find.text('Xem chỗ nghỉ'), findsOneWidget);
      // Check input placeholder in Vietnamese
      expect(find.text('Nhắn tin'), findsOneWidget);
      // Check Vietnamese quick-reply question
      expect(
        find.text('Dạ căn còn trống lịch này không ạ?'),
        findsOneWidget,
      );

      // Verify HostMessageScreen in Vietnamese
      await tester.pumpWidget(buildHostMessageApp('vi'));
      await tester.pumpAndSettle();

      expect(find.text('Liên hệ Chủ nhà'), findsOneWidget);
      expect(find.text('Quay lại trang biệt thự'), findsOneWidget);
      expect(find.text('Câu hỏi thường gặp cho Chủ nhà:'), findsOneWidget);
    });
  });
}
