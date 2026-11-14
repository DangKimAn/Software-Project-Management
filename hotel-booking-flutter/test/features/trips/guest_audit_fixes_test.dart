import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hotel_booking_flutter/app/di/notifications_view_model.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/favorites/data/repositories/wishlist_repository_impl.dart';
import 'package:hotel_booking_flutter/features/messages/data/conversations_repository.dart';
import 'package:hotel_booking_flutter/features/reviews/domain/entities/review_item.dart';
import 'package:hotel_booking_flutter/features/reviews/domain/repositories/review_repository.dart';
import 'package:hotel_booking_flutter/features/reviews/presentation/widgets/review_list_widget.dart';
import 'package:hotel_booking_flutter/features/search/presentation/widgets/booking_date_range_picker.dart';
import 'package:hotel_booking_flutter/features/trips/data/repositories/booking_repository_impl.dart';
import 'package:hotel_booking_flutter/features/trips/domain/entities/booking.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/widgets/booking_payment_widgets.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/screens/villa_detail_screen.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/widgets/mobile_spec_summary.dart';
import 'package:hotel_booking_flutter/features/villas/data/repositories/villa_repository_impl.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';
import 'package:hotel_booking_flutter/features/villas/presentation/widgets/property_card.dart';
import 'package:hotel_booking_flutter/shared/widgets/vung_tau_map_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Dio _createMockDio(
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000'));
  dio.httpClientAdapter = _MockHttpClientAdapter(handler);
  return dio;
}

DioClient _createMockDioClient(
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  final client = DioClient(secureStorage: const SecureStorageService());
  client.dio.httpClientAdapter = _MockHttpClientAdapter(handler);
  return client;
}

class _PaginatedReviewRepo implements ReviewRepository {
  final List<({int? page, int? limit, int? rating})> calls = [];

  @override
  Future<List<ReviewItem>> getListingReviews(
    String listingId, {
    int? page,
    int? limit,
    int? rating,
  }) async {
    calls.add((page: page, limit: limit, rating: rating));
    final currentPage = page ?? 1;
    final pageLimit = limit ?? 20;
    if (pageLimit > 50) {
      throw StateError('HTTP 422: limit must be <= 50, got $pageLimit');
    }
    if (currentPage == 1) {
      return List.generate(
        20,
        (i) => ReviewItem(
          id: '${i + 1}',
          rating: 5.0,
          comment: 'Đánh giá thực tế số ${i + 1} tại Vũng Tàu.',
          reviewerName: 'Khách ${i + 1}',
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      );
    }
    if (currentPage == 2) {
      return List.generate(
        5,
        (i) => ReviewItem(
          id: '${21 + i}',
          rating: 4.0,
          comment: 'Đánh giá trang 2 số ${21 + i}.',
          reviewerName: 'Khách ${21 + i}',
          createdAt: DateTime.utc(2026, 9, 25),
        ),
      );
    }
    return const [];
  }

  @override
  Future<ReviewItem> createReview({
    required String bookingId,
    required int rating,
    required String comment,
  }) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  group('Group 2.1 — Guest Trips pagination & Booking.effectiveStatus', () {
    test(
        'BookingRepositoryImpl.getMyBookings loops 1..totalPages with limit 50 and deduplicates bookings',
        () async {
      final requestedPages = <int>[];
      final requestedLimits = <int>[];

      final dio = _createMockDio((options) async {
        expect(options.path, '/api/bookings/mine');
        final page = options.queryParameters['page'] as int;
        final limit = options.queryParameters['limit'] as int;
        requestedPages.add(page);
        requestedLimits.add(limit);

        if (page == 1) {
          return _jsonResponse({
            'success': true,
            'data': {
              'items': List.generate(
                50,
                (i) => {
                  'bookingId': i + 1,
                  'listingId': 10,
                  'propertyName': 'The Palm Villa #${i + 1}',
                  'checkInDate': '2026-12-01',
                  'checkOutDate': '2026-12-03',
                  'nights': 2,
                  'guestCount': 4,
                  'totalAmount': 5000000,
                  'status': 'confirmed',
                },
              ),
              'pagination': {
                'page': 1,
                'limit': 50,
                'total': 65,
                'totalPages': 2,
              },
            },
          });
        }
        return _jsonResponse({
          'success': true,
          'data': {
            'items': [
              // Include duplicate #50 to verify deduplication
              {
                'bookingId': 50,
                'listingId': 10,
                'propertyName': 'The Palm Villa #50',
                'checkInDate': '2026-12-01',
                'checkOutDate': '2026-12-03',
                'nights': 2,
                'guestCount': 4,
                'totalAmount': 5000000,
                'status': 'confirmed',
              },
              ...List.generate(
                15,
                (i) => {
                  'bookingId': 51 + i,
                  'listingId': 10,
                  'propertyName': 'The Palm Villa #${51 + i}',
                  'checkInDate': '2026-12-05',
                  'checkOutDate': '2026-12-07',
                  'nights': 2,
                  'guestCount': 4,
                  'totalAmount': 5500000,
                  'status': 'completed',
                },
              ),
            ],
            'pagination': {
              'page': 2,
              'limit': 50,
              'total': 65,
              'totalPages': 2,
            },
          },
        });
      });

      final repo = BookingRepositoryImpl(dio);
      final bookings = await repo.getMyBookings();

      expect(requestedPages, [1, 2]);
      expect(requestedLimits, [50, 50]);
      expect(bookings.length, 65);
      expect(bookings.first.id, '1');
      expect(bookings.last.id, '65');
    });

    test(
        'Booking.effectiveStatusAt maps refundStatus and auto-advances past paid stays to completed in Vietnam timezone',
        () {
      final refundedBooking = Booking.fromJson({
        'bookingId': 101,
        'listingId': 5,
        'propertyName': 'Villa Bãi Sau',
        'checkInDate': '2026-11-10',
        'checkOutDate': '2026-11-12',
        'totalAmount': 7000000,
        'status': 'cancelled_by_guest',
        'paymentStatus': 'paid',
        'refundStatus': 'succeeded',
      });
      expect(refundedBooking.effectiveStatus, 'refunded');
      expect(refundedBooking.statusDisplay, 'Đã hoàn tiền');

      final refundPendingBooking = Booking.fromJson({
        'bookingId': 102,
        'listingId': 5,
        'propertyName': 'Villa Bãi Sau',
        'checkInDate': '2026-11-10',
        'checkOutDate': '2026-11-12',
        'totalAmount': 7000000,
        'status': 'expired',
        'paymentStatus': 'paid',
        'refundStatus': 'processing',
      });
      expect(refundPendingBooking.effectiveStatus, 'refund_pending');
      expect(refundPendingBooking.statusDisplay, 'Đang chờ hoàn tiền');

      final pastPaidBooking = Booking.fromJson({
        'bookingId': 103,
        'listingId': 5,
        'propertyName': 'Villa Bãi Trước',
        'checkInDate': '2026-10-01',
        'checkOutDate': '2026-10-05',
        'totalAmount': 9000000,
        'status': 'paid',
        'paymentStatus': 'paid',
      });
      // Vietnam time 2026-10-05 01:00 ICT == 2026-10-04 18:00 UTC -> todayVn == 2026-10-05 >= checkOutDate
      final nowVnCheckoutDay = DateTime.utc(2026, 10, 4, 18, 0);
      expect(pastPaidBooking.effectiveStatusAt(nowVnCheckoutDay), 'completed');

      // Before checkOutDate in Vietnam time -> remains 'paid'
      final beforeCheckoutUtc = DateTime.utc(2026, 10, 3, 12, 0);
      expect(pastPaidBooking.effectiveStatusAt(beforeCheckoutUtc), 'paid');
    });
  });

  group('Group 2.2 — Authoritative Payment & Refund Status Resolution', () {
    test(
        'deriveAuthoritativePaymentStatus prioritizes refundStatus succeeded/pending BEFORE returning paid',
        () {
      const lateSucceededRefundPayment = PaymentSessionResult(
        paymentId: 'pay_1',
        bookingId: '88',
        method: 'vnpay',
        paymentStatus: 'paid',
        paymentResultStatus: 'paid',
        amount: 6000000,
        requiresRefund: true,
        refundStatus: 'succeeded',
      );
      expect(
        deriveAuthoritativePaymentStatus(payment: lateSucceededRefundPayment),
        'refunded',
      );

      const latePendingRefundPayment = PaymentSessionResult(
        paymentId: 'pay_2',
        bookingId: '89',
        method: 'momo',
        paymentStatus: 'paid',
        paymentResultStatus: 'paid',
        amount: 6000000,
        requiresRefund: true,
        refundStatus: 'pending',
      );
      expect(
        deriveAuthoritativePaymentStatus(payment: latePendingRefundPayment),
        'refund_pending',
      );

      final bookingWithPendingRefund = Booking.fromJson({
        'bookingId': 90,
        'listingId': 3,
        'propertyName': 'Ocean Villa',
        'checkInDate': '2026-12-01',
        'checkOutDate': '2026-12-03',
        'totalAmount': 8000000,
        'status': 'cancelled_by_host',
        'paymentStatus': 'paid',
        'refundStatus': 'processing',
      });
      expect(
        deriveAuthoritativePaymentStatus(booking: bookingWithPendingRefund),
        'refund_pending',
      );
    });

    testWidgets(
        'PaymentVerificationCard renders refunded instead of paid when payment.refundStatus is succeeded',
        (tester) async {
      final dio = _createMockDio((options) async {
        if (options.path == '/api/payments/pay_refund_ok') {
          return _jsonResponse({
            'success': true,
            'data': {
              'paymentId': 'pay_refund_ok',
              'bookingId': '501',
              'method': 'vnpay',
              'paymentStatus': 'paid',
              'paymentResultStatus': 'refunded',
              'requiresRefund': true,
              'refundStatus': 'succeeded',
              'amount': 4500000,
            },
          });
        }
        if (options.path == '/api/bookings/501') {
          return _jsonResponse({
            'success': true,
            'data': {
              'bookingId': 501,
              'listingId': 10,
              'propertyName': 'The Palm Villa',
              'checkInDate': '2026-12-10',
              'checkOutDate': '2026-12-12',
              'totalAmount': 4500000,
              'status': 'expired',
              'paymentStatus': 'paid',
              'refundStatus': 'succeeded',
            },
          });
        }
        throw AssertionError('Unexpected request: ${options.path}');
      });

      final repo = BookingRepositoryImpl(dio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PaymentVerificationCard(
                repository: repo,
                bookingId: '501',
                paymentId: 'pay_refund_ok',
                initialStatus: 'paid',
                method: 'vnpay',
                amount: 4500000,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thanh toán đặt phòng thành công!'), findsNothing);
      expect(find.textContaining('hoàn tiền'), findsWidgets);
    });
  });

  group('Group 2.3 — Messages oldest-prepend & Conversation pagination/scope',
      () {
    test(
        'ChatMessageItem.prependOlderMessages prepends older page, deduplicates by id, and preserves chronological order',
        () {
      final existingPage1 = [
        const ChatMessageItem(
          id: '51',
          conversationId: '10',
          senderId: '1',
          content: 'Tin nhắn #51',
          createdAt: '2026-11-04T10:01:00.000Z',
        ),
        const ChatMessageItem(
          id: '52',
          conversationId: '10',
          senderId: '2',
          content: 'Tin nhắn #52',
          createdAt: '2026-11-04T10:02:00.000Z',
        ),
      ];

      final olderPage2 = [
        const ChatMessageItem(
          id: '49',
          conversationId: '10',
          senderId: '1',
          content: 'Tin nhắn #49',
          createdAt: '2026-11-04T09:59:00.000Z',
        ),
        const ChatMessageItem(
          id: '50',
          conversationId: '10',
          senderId: '2',
          content: 'Tin nhắn #50',
          createdAt: '2026-11-04T10:00:00.000Z',
        ),
        // Duplicate #51 from boundary shift
        const ChatMessageItem(
          id: '51',
          conversationId: '10',
          senderId: '1',
          content: 'Tin nhắn #51',
          createdAt: '2026-11-04T10:01:00.000Z',
        ),
      ];

      final merged = ChatMessageItem.prependOlderMessages(
        olderPage2,
        existingPage1,
        conversationId: '10',
      );

      expect(merged.map((m) => m.id).toList(), ['49', '50', '51', '52']);
      expect(merged.first.content, 'Tin nhắn #49');
      expect(merged.last.content, 'Tin nhắn #52');
    });

    test(
        'ConversationsRepository.getConversations passes scope param and fetches all pages > 1',
        () async {
      final capturedQueries = <Map<String, dynamic>>[];
      final client = _createMockDioClient((options) async {
        expect(options.path, '/api/conversations');
        capturedQueries.add(Map<String, dynamic>.from(options.queryParameters));
        final page = options.queryParameters['page'] as int;
        if (page == 1) {
          return _jsonResponse({
            'success': true,
            'data': {
              'items': List.generate(
                30,
                (i) => {
                  'conversationId': i + 1,
                  'listingTitle': 'Villa #${i + 1}',
                  'unreadCount': 0,
                },
              ),
              'pagination': {
                'page': 1,
                'limit': 50,
                'total': 45,
                'totalPages': 2,
              },
            },
          });
        }
        return _jsonResponse({
          'success': true,
          'data': {
            'items': List.generate(
              15,
              (i) => {
                'conversationId': 31 + i,
                'listingTitle': 'Villa #${31 + i}',
                'unreadCount': 1,
              },
            ),
            'pagination': {
              'page': 2,
              'limit': 50,
              'total': 45,
              'totalPages': 2,
            },
          },
        });
      });

      final repo = ConversationsRepository(client);
      final allConversations = await repo.getConversations(scope: 'guest');

      expect(capturedQueries.length, 2);
      expect(capturedQueries[0]['scope'], 'guest');
      expect(capturedQueries[1]['scope'], 'guest');
      expect(allConversations.length, 45);
    });
  });

  group('Group 2.4 — Notifications unreadCount math & /host/... route mapping',
      () {
    test(
        'NotificationsNotifier decrements 35 -> 34 on markAsRead instead of recounting 20-item slice, and increments on new socket notification',
        () async {
      final socketController =
          StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(socketController.close);

      final client = _createMockDioClient((options) async {
        if (options.path == '/api/notifications' && options.method == 'GET') {
          return _jsonResponse({
            'success': true,
            'data': {
              'unreadCount': 35,
              'items': List.generate(
                20,
                (i) => {
                  'id': '${i + 1}',
                  'title': 'Thông báo #${i + 1}',
                  'body': 'Nội dung thông báo #${i + 1}',
                  'isRead': false,
                  'createdAt': '2026-11-04T08:00:00.000Z',
                },
              ),
            },
          });
        }
        if (options.path.startsWith('/api/notifications/') &&
            options.method == 'PATCH') {
          return _jsonResponse({'success': true});
        }
        throw AssertionError('Unexpected request: ${options.path}');
      });

      final notifier = NotificationsNotifier(
        client,
        true,
        socketController.stream,
        enablePolling: false,
        autoConnectSocket: false,
        autoFetch: false,
      );
      addTearDown(notifier.dispose);

      await notifier.fetchNotifications();
      expect(notifier.state.items.length, 20);
      expect(notifier.state.unreadCount, 35);

      await notifier.markAsRead('1');
      // Must be 34 (35 - 1), NOT 19!
      expect(notifier.state.unreadCount, 34);

      // Marking the same already-read item again must NOT decrement again
      await notifier.markAsRead('1');
      expect(notifier.state.unreadCount, 34);

      // Incoming new unread socket notification increments 34 -> 35
      socketController.add({
        'id': '999',
        'title': 'Phí nền tảng mới',
        'body': 'Chi tiết phí dịch vụ tháng 11',
        'actionUrl': '/host/bao-cao',
        'isRead': false,
        'createdAt': '2026-11-04T09:00:00.000Z',
      });
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.unreadCount, 35);
      expect(notifier.state.items.first.id, '999');
    });

    test(
        'AppNotificationItem maps /host/bao-cao -> /chu-nha/bao-cao and generalizes /host/... -> /chu-nha/...',
        () {
      final feeNotif = AppNotificationItem.fromJson({
        'id': '1',
        'eventType': 'PLATFORM_FEE_SCHEDULED',
        'title': 'Lịch thu phí nền tảng',
        'body': 'Xem báo cáo doanh thu',
        'actionUrl': '/host/bao-cao',
        'isRead': false,
        'createdAt': '2026-11-04T08:00:00.000Z',
      });
      expect(feeNotif.resolveInternalRoute(), '/chu-nha/bao-cao');

      final genericHostNotif = AppNotificationItem.fromJson({
        'id': '2',
        'title': 'Cập nhật lịch',
        'body': 'Kiểm tra lịch trống',
        'actionUrl': '/host/custom-section?month=11',
        'isRead': false,
        'createdAt': '2026-11-04T08:00:00.000Z',
      });
      expect(
        genericHostNotif.resolveInternalRoute(),
        '/chu-nha/custom-section?month=11',
      );
    });
  });

  group(
      'Group 2.5 — Favorites, Search filters, Tháng 30-night cap & Reviews pagination',
      () {
    test(
        'WishlistRepositoryImpl defaults missing rating to 0.0 and FavoritesNotifier invalidates wishlistDetailProvider immediately',
        () async {
      SharedPreferences.setMockInitialValues({
        'favorite_villa_ids': ['101'],
      });
      final prefs = await PreferencesService.create();

      final dio = _createMockDio((options) async {
        if (options.path == '/api/wishlist' && options.method == 'GET') {
          return _jsonResponse({
            'success': true,
            'data': {
              'userId': 'u1',
              'listingIds': [101],
              'items': [
                {
                  'id': 101,
                  'title': 'Biệt thự mới chưa có đánh giá',
                  'pricePerNight': 3500000,
                },
              ],
            },
          });
        }
        if (options.path == '/api/wishlist/101' && options.method == 'DELETE') {
          return _jsonResponse({'success': true});
        }
        throw AssertionError('Unexpected wishlist path: ${options.path}');
      });

      final repo = WishlistRepositoryImpl(dio, prefs: prefs);
      final detail = await repo.getWishlistDetail();
      expect(detail.items.single.rating, 0.0);

      var invalidatedCount = 0;
      final notifier = FavoritesNotifier(
        prefs,
        repo,
        true,
        onWishlistMutated: () => invalidatedCount++,
      );
      addTearDown(notifier.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.toggleFavorite('101');
      expect(notifier.state.contains('101'), isFalse);
      expect(notifier.isRemovedInSession('101'), isTrue);
      expect(invalidatedCount, greaterThanOrEqualTo(1));
    });

    test(
        'VillaRepositoryImpl passes bedrooms, beds, bathrooms, and pets query params to GET /api/listings',
        () async {
      Map<String, dynamic>? capturedParams;
      final client = _createMockDioClient((options) async {
        expect(options.path, '/api/listings');
        capturedParams = Map<String, dynamic>.from(options.queryParameters);
        return _jsonResponse({
          'success': true,
          'data': {
            'items': <dynamic>[],
            'pagination': {
              'page': 1,
              'limit': 12,
              'total': 0,
              'totalPages': 1,
            },
          },
        });
      });

      final repo = VillaRepositoryImpl(client);
      await repo.getVillasPaginated(
        bedrooms: 4,
        beds: 6,
        bathrooms: 4,
        pets: true,
      );

      expect(capturedParams, isNotNull);
      expect(capturedParams!['bedrooms'], 4);
      expect(capturedParams!['beds'], 6);
      expect(capturedParams!['bathrooms'], 4);
      expect(capturedParams!['pets'], true);
    });

    test(
        'SearchDateModeHelper.computeForMonths caps stay duration at 30 nights for 31-day and multi-month selections',
        () {
      final decRange = SearchDateModeHelper.computeForMonths(
        [12],
        referenceToday: const BookingDate(year: 2026, month: 11, day: 4),
      );
      expect(
          decRange.checkIn, const BookingDate(year: 2026, month: 12, day: 1));
      expect(
        decRange.checkIn.differenceInNights(decRange.checkOut),
        30,
      );

      final multiMonthRange = SearchDateModeHelper.computeForMonths(
        [12, 1],
        referenceToday: const BookingDate(year: 2026, month: 11, day: 4),
      );
      expect(
        multiMonthRange.checkIn.differenceInNights(multiMonthRange.checkOut),
        30,
      );
    });

    testWidgets(
        'ReviewListWidget paginates with limit <= 20 across pages without ever sending limit > 50',
        (tester) async {
      final fakeRepo = _PaginatedReviewRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ReviewListWidget(
                  listingId: '101',
                  averageRating: 4.9,
                  totalReviews: 25,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows 6 reviews fetched from page 1 with limit 20
      expect(fakeRepo.calls.single.page, 1);
      expect(fakeRepo.calls.single.limit, 20);
      expect(find.textContaining('Đánh giá thực tế số 1'), findsOneWidget);
      expect(find.textContaining('Đánh giá thực tế số 7'), findsNothing);

      // Tap "Xem thêm đánh giá" 3 times -> visibleLimit = 24 -> fetches page 2 with limit 20
      for (var i = 0; i < 3; i++) {
        final loadMoreBtn = find.textContaining('Xem thêm đánh giá');
        await tester.ensureVisible(loadMoreBtn);
        await tester.tap(loadMoreBtn);
        await tester.pumpAndSettle();
      }

      expect(fakeRepo.calls.every((c) => (c.limit ?? 0) <= 20), isTrue);
      expect(fakeRepo.calls.any((c) => c.page == 2), isTrue);
      expect(find.textContaining('Đánh giá trang 2 số 21'), findsOneWidget);
    });
  });

  group('Group 2.6 — Guest Font-Scaling (1.3x–2.0x — all 4 clusters)', () {
    const sampleSpecs = VillaSpecs(
      bedrooms: 5,
      beds: 8,
      maxGuests: 16,
      bathrooms: 6,
      beachDistanceMeters: 150,
    );

    const sampleVilla = Villa(
      id: '101',
      code: 'VT-101',
      name: 'The Palm Oceanfront Luxury Pool Villa Bãi Sau',
      tagline: 'Sát biển Thùy Vân, hồ bơi nước mặn riêng',
      address: '28 Thùy Vân, Phường 2, TP. Vũng Tàu',
      description: 'Biệt thự nghỉ dưỡng cao cấp tại Bãi Sau.',
      imageUrls: [],
      specs: sampleSpecs,
      basePriceVnd: 6500000,
      saturdayPriceVnd: 8900000,
      badges: [VillaBadgeType.nearBeach],
      rating: 4.9,
      reviewCount: 42,
    );

    testWidgets(
        'Cluster 1: Similar-listings horizontal carousel scales height dynamically at 2.0x without bottom overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 900),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Builder(
                  builder: (context) {
                    final height = computeSimilarVillasCarouselHeight(
                      context,
                      const [sampleVilla],
                    );
                    expect(height, greaterThan(450));
                    return SizedBox(
                      height: height,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          SizedBox(
                            width: 300,
                            child: PropertyCard(
                              villa: sampleVilla,
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Cluster 2: MobileSpecSummary switches to 2-column Wrap on narrow width or 2.0x text scale without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: MobileSpecSummary(specs: sampleSpecs),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Wrap), findsWidgets);
      expect(find.text('16 khách'), findsOneWidget);
      expect(find.text('Phòng ngủ'), findsOneWidget);
    });

    testWidgets(
        'Cluster 3: VungTauMapPicker preset filter chips expand vertically at 2.0x without clipping Vietnamese diacritics',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: VungTauMapPicker(showPresetChips: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Bãi Sau'), findsOneWidget);
      expect(find.text('Bãi Trước'), findsOneWidget);
    });

    testWidgets(
        'Cluster 4: BookingDateRangePicker wraps 2-digit day numbers inside FittedBox cleanly at 2.0x text scale',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 844),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: BookingDateRangePicker(
                  initialCheckIn:
                      const BookingDate(year: 2026, month: 12, day: 15),
                  initialCheckOut:
                      const BookingDate(year: 2026, month: 12, day: 20),
                  minDate: const BookingDate(year: 2026, month: 12, day: 1),
                  onRangeSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FittedBox), findsWidgets);
      expect(find.text('15'), findsWidgets);
      expect(find.text('28'), findsWidgets);
    });
  });
}
