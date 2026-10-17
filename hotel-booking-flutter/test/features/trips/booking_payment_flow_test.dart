import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:hotel_booking_flutter/features/favorites/data/repositories/wishlist_repository_impl.dart';
import 'package:hotel_booking_flutter/features/trips/data/repositories/booking_repository_impl.dart';
import 'package:hotel_booking_flutter/features/trips/domain/entities/booking.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/widgets/booking_payment_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test-only HTTP adapter for simulating backend responses without touching network or production gateways.
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

class _FakeAuthRepository implements AuthRepository {
  User? currentUser;
  Map<String, dynamic>? lastUpdatedProfilePayload;
  Map<String, dynamic>? lastUpdatedAvatarPayload;
  bool shouldFailUpdate = false;

  _FakeAuthRepository({this.currentUser});

  @override
  Future<User?> getCurrentUser() async => currentUser;

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> loginWithGoogle({required String idToken}) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    throw UnimplementedError();
  }

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
  }) async {
    if (shouldFailUpdate) {
      throw Exception('Máy chủ từ chối cập nhật hồ sơ (500)');
    }
    lastUpdatedProfilePayload = {
      'fullName': fullName,
      'phone': phone,
      'bio': bio,
      'location': location,
      'job': job,
      'dreamDestination': dreamDestination,
      'school': school,
      'languages': languages,
      'avatarUrl': avatarUrl,
    };
    final split = User.splitFullName(fullName ?? currentUser?.fullName ?? '');
    currentUser = (currentUser ??
            const User(
              id: '1',
              email: 'guest@vungtaustay.vn',
              firstName: 'Guest',
              lastName: 'User',
            ))
        .copyWith(
      firstName: split.firstName,
      lastName: split.lastName,
      phone: phone,
      bio: bio,
      location: location,
      job: job,
      dreamDestination: dreamDestination,
      school: school,
      languages: languages,
      avatarUrl: avatarUrl,
    );
    return currentUser!;
  }

  @override
  Future<User> updateAvatar({required String url, String? key}) async {
    if (shouldFailUpdate) {
      throw Exception('Không thể tải ảnh đại diện lên máy chủ');
    }
    lastUpdatedAvatarPayload = {'url': url, 'key': key};
    currentUser = currentUser?.copyWith(avatarUrl: url);
    return currentUser!;
  }

  @override
  Future<void> logout() async {
    currentUser = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUG-08: Coupon Contract & Validation Tests', () {
    test(
        'validateCoupon sends GET /api/coupons/validate with bookingAmount and listingId matching coupons.validator.ts and parses valid discount',
        () async {
      Map<String, dynamic>? capturedQuery;
      final dio = _createMockDio((options) async {
        expect(options.path, '/api/coupons/validate');
        expect(options.method, 'GET');
        capturedQuery = Map<String, dynamic>.from(options.queryParameters);
        return _jsonResponse({
          'success': true,
          'data': {
            'valid': true,
            'code': 'SUMMER2026',
            'discountType': 'percentage',
            'discountValue': 10,
            'maxDiscountAmount': 1000000,
            'minOrderValue': 5000000,
            'discountAmount': 800000,
            'finalAmount': 7200000,
          },
        });
      });

      final repo = BookingRepositoryImpl(dio);
      final result = await repo.validateCoupon(
        code: 'summer2026',
        bookingAmount: 8000000,
        listingId: '15',
      );

      expect(capturedQuery, isNotNull);
      expect(capturedQuery!['code'], 'SUMMER2026');
      expect(capturedQuery!['bookingAmount'], 8000000);
      expect(capturedQuery!['listingId'], 15);
      expect(result.valid, isTrue);
      expect(result.code, 'SUMMER2026');
      expect(result.discountAmount, 800000);
      expect(result.finalAmount, 7200000);
      expect(result.discountType, 'percentage');
      expect(result.maxDiscountAmount, 1000000);
    });

    test(
        'validateCoupon parses rejection reason (expired / minOrder / listing mismatch) and forces discountAmount = 0 when valid is false',
        () async {
      final dio = _createMockDio((options) async {
        return _jsonResponse({
          'success': true,
          'data': {
            'valid': false,
            'code': 'EXPIRED50',
            'discountAmount':
                500000, // Even if server sends a number, client must not apply if !valid
            'reason': 'COUPON_EXPIRED',
          },
        });
      });

      final repo = BookingRepositoryImpl(dio);
      final result = await repo.validateCoupon(
        code: 'EXPIRED50',
        bookingAmount: 5000000,
      );

      expect(result.valid, isFalse);
      expect(result.discountAmount, 0);
      expect(result.reason, 'COUPON_EXPIRED');
      expect(result.displayMessage, contains('hết hạn'));
    });
  });

  group('BUG-03: Payment Creation, Methods & Verification Contract Tests', () {
    test(
        'getPaymentMethods parses gateway availability and createPayment sends {bookingId, method}',
        () async {
      Map<String, dynamic>? capturedPostBody;
      final dio = _createMockDio((options) async {
        if (options.path == '/api/payments/methods' &&
            options.method == 'GET') {
          return _jsonResponse({
            'success': true,
            'data': {
              'methods': [
                {'method': 'vnpay', 'available': true, 'label': 'VNPay QR'},
                {
                  'method': 'momo',
                  'available': false,
                  'reason': 'Cổng MoMo đang bảo trì định kỳ',
                },
              ],
            },
          });
        }
        if (options.path == '/api/payments' && options.method == 'POST') {
          capturedPostBody = Map<String, dynamic>.from(options.data as Map);
          return _jsonResponse({
            'success': true,
            'data': {
              'paymentId': 'pay_9988',
              'bookingId': '456',
              'method': 'vnpay',
              'paymentStatus': 'pending',
              'paymentUrl':
                  'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?txn=9988',
              'amount': 10500000,
            },
          });
        }
        throw AssertionError('Unexpected request: ${options.path}');
      });

      final repo = BookingRepositoryImpl(dio);
      final methods = await repo.getPaymentMethods();
      expect(methods.length, 2);
      expect(methods.first.method, 'vnpay');
      expect(methods.first.available, isTrue);
      expect(methods.last.method, 'momo');
      expect(methods.last.available, isFalse);
      expect(methods.last.reason, 'Cổng MoMo đang bảo trì định kỳ');

      final session = await repo.createPayment(
        bookingId: '456',
        method: 'vnpay',
      );
      expect(capturedPostBody, {'bookingId': 456, 'method': 'vnpay'});
      expect(session.paymentId, 'pay_9988');
      expect(session.paymentStatus, 'pending');
      expect(session.paymentResultStatus, 'pending');
      expect(session.paymentUrl, contains('sandbox.vnpayment.vn'));
    });

    testWidgets(
        'PaymentVerificationCard NEVER trusts status=paid query param, shows unverified on network failure, transitions pending -> paid/failed/cancelled/expired, and re-verifies on resume without creating new payment',
        (tester) async {
      bool shouldFailNetwork = true;
      String backendPaymentStatus = 'pending';
      String backendBookingStatus = 'pending_payment';
      int getPaymentCalls = 0;
      int createPaymentCalls = 0;

      final dio = _createMockDio((options) async {
        if (options.path == '/api/payments' && options.method == 'POST') {
          createPaymentCalls++;
        }
        if (shouldFailNetwork) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'Mất kết nối mạng',
          );
        }
        if (options.path == '/api/payments/pay_123') {
          getPaymentCalls++;
          return _jsonResponse({
            'success': true,
            'data': {
              'paymentId': 'pay_123',
              'bookingId': '777',
              'method': 'vnpay',
              'paymentStatus': backendPaymentStatus,
              'amount': 6500000,
            },
          });
        }
        if (options.path == '/api/bookings/777') {
          return _jsonResponse({
            'success': true,
            'data': {
              'bookingId': 777,
              'listingId': 12,
              'propertyName': 'Ocean Breeze Villa',
              'checkInDate': '2026-12-01',
              'checkOutDate': '2026-12-03',
              'totalAmount': 6500000,
              'status': backendBookingStatus,
              'remainingPaymentSeconds': 500,
            },
          });
        }
        throw AssertionError('Unexpected path ${options.path}');
      });

      final repo = BookingRepositoryImpl(dio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PaymentVerificationCard(
                repository: repo,
                bookingId: '777',
                paymentId: 'pay_123',
                initialStatus: 'paid', // Spoofed query string status=paid!
                method: 'vnpay',
                amount: 6500000,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. When network fails during verification, MUST show "Chưa xác nhận được giao dịch", NEVER fake paid or fake failed
      expect(find.text('Chưa xác nhận được giao dịch'), findsOneWidget);
      expect(find.text('Thanh toán đặt phòng thành công!'), findsNothing);

      // 2. Restore network, backend still reports 'pending'
      shouldFailNetwork = false;
      await tester.tap(find.text('Kiểm tra lại trạng thái'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Giao dịch đang chờ xác nhận'), findsOneWidget);
      expect(find.text('Thanh toán đặt phòng thành công!'), findsNothing);
      expect(getPaymentCalls, 1);

      // 3. Simulate app resume (AppLifecycleState.resumed) after user completes payment in external browser
      backendPaymentStatus = 'paid';
      backendBookingStatus = 'confirmed';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Thanh toán đặt phòng thành công!'), findsOneWidget);
      expect(getPaymentCalls, 2);
      // Resume must NEVER create a duplicate POST /api/payments transaction
      expect(createPaymentCalls, 0);
    });
  });

  group('BUG-19: Multi-Booking Queue & Bulk Booking Tests', () {
    test(
        'PreferencesService booking queue updates item in place, enforces max 5 items, and persists/restores accurately',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferencesService.create();

      for (int i = 1; i <= 5; i++) {
        final res = await prefs.addBookingQueueItem(
          BookingQueueItem(
            listingId: '$i',
            title: 'Villa #$i',
            imageUrl: 'https://example.com/$i.jpg',
            pricePerNight: 3000000,
            checkIn: '2026-11-10',
            checkOut: '2026-11-12',
            guestsCount: 4,
            maxGuests: 12,
          ),
        );
        expect(res.status, BookingQueueAddStatus.added);
      }

      // 6th item must be rejected with BookingQueueAddStatus.full
      final sixthRes = await prefs.addBookingQueueItem(
        const BookingQueueItem(
          listingId: '6',
          title: 'Villa #6',
          imageUrl: 'https://example.com/6.jpg',
          pricePerNight: 3000000,
        ),
      );
      expect(sixthRes.status, BookingQueueAddStatus.full);
      expect(prefs.getBookingQueue().length, 5);

      // Update item #2 dates and guests in place using updateBookingQueueItem
      final updatedItem2 = prefs.getBookingQueue()[1].copyWith(
            checkIn: '2026-11-15',
            checkOut: '2026-11-18',
            guestsCount: 8,
          );
      await prefs.updateBookingQueueItem(updatedItem2);

      final restoredQueue = prefs.getBookingQueue();
      expect(restoredQueue.length, 5);
      expect(restoredQueue[1].listingId, '2');
      expect(restoredQueue[1].checkIn, '2026-11-15');
      expect(restoredQueue[1].checkOut, '2026-11-18');
      expect(restoredQueue[1].guestsCount, 8);
    });

    test(
        'createBulkBookings parses all 1..N created bookings and throws BulkBookingException with per-item errors on failure',
        () async {
      bool failSecondItem = true;
      final dio = _createMockDio((options) async {
        expect(options.path, '/api/bookings/bulk');
        expect(options.method, 'POST');
        if (failSecondItem) {
          return _jsonResponse(
            {
              'success': false,
              'message': 'Một số căn biệt thự đã kín lịch trong ngày bạn chọn.',
              'errors': [
                {
                  'path': 'items[1].checkInDate',
                  'message': 'Căn Villa #2 đã có khách đặt từ 15/11 đến 18/11',
                },
              ],
            },
            statusCode: 409,
          );
        }

        return _jsonResponse({
          'success': true,
          'data': {
            'bookings': [
              {
                'bookingId': 801,
                'listingId': 1,
                'propertyName': 'Villa #1',
                'checkInDate': '2026-11-10',
                'checkOutDate': '2026-11-12',
                'nights': 2,
                'guestCount': 4,
                'totalAmount': 6000000,
                'status': 'pending_payment',
                'remainingPaymentSeconds': 900,
              },
              {
                'bookingId': 802,
                'listingId': 2,
                'propertyName': 'Villa #2',
                'checkInDate': '2026-11-15',
                'checkOutDate': '2026-11-18',
                'nights': 3,
                'guestCount': 8,
                'totalAmount': 9500000,
                'status': 'pending_payment',
                'remainingPaymentSeconds': 900,
              },
            ],
          },
        });
      });

      final repo = BookingRepositoryImpl(dio);

      // 1. Verify per-item error parsing
      try {
        await repo.createBulkBookings(items: [
          {
            'listingId': 1,
            'checkInDate': '2026-11-10',
            'checkOutDate': '2026-11-12',
            'guestsCount': 4,
          },
          {
            'listingId': 2,
            'checkInDate': '2026-11-15',
            'checkOutDate': '2026-11-18',
            'guestsCount': 8,
          },
        ]);
        fail('Expected BulkBookingException');
      } on BulkBookingException catch (e) {
        expect(e.itemErrors.length, 1);
        expect(e.itemErrors.first.index, 1);
        expect(
          e.itemErrors.first.message,
          contains('Căn Villa #2 đã có khách đặt'),
        );
      }

      // 2. Verify all 1..N bookings are parsed on success
      failSecondItem = false;
      final created = await repo.createBulkBookings(items: [
        {
          'listingId': 1,
          'checkInDate': '2026-11-10',
          'checkOutDate': '2026-11-12',
          'guestsCount': 4,
        },
        {
          'listingId': 2,
          'checkInDate': '2026-11-15',
          'checkOutDate': '2026-11-18',
          'guestsCount': 8,
        },
      ]);

      expect(created.length, 2);
      expect(created[0].id, '801');
      expect(created[1].id, '802');
      expect(created[1].propertyName, 'Villa #2');
      expect(created[1].totalAmount, 9500000);
    });
  });

  group('BUG-37: Favorites Guest -> Authenticated User Migration Tests', () {
    test(
        'Guest favorites migrate valid IDs via POST /api/wishlist/:id, merge with server without overwriting, filter invalid IDs, and clear on logout',
        () async {
      SharedPreferences.setMockInitialValues({
        'guest_favorite_villa_ids': ['101', 'invalid-slug', '-5', '102'],
      });
      final prefs = await PreferencesService.create();

      final postedIds = <String>[];
      final serverIds = <String>{'205', '101'};
      bool failServer = true;

      final dio = _createMockDio((options) async {
        if (failServer) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        if (options.path.startsWith('/api/wishlist/') &&
            options.method == 'POST') {
          final id = options.path.split('/').last;
          postedIds.add(id);
          serverIds.add(id);
          return _jsonResponse({'success': true});
        }
        if (options.path == '/api/wishlist' && options.method == 'GET') {
          return _jsonResponse({
            'success': true,
            'data': {
              'userId': 'user_1',
              'listingIds': serverIds.map(int.parse).toList(),
              'items': serverIds
                  .map(
                    (id) => {
                      'id': int.parse(id),
                      'title': 'Villa $id',
                      'pricePerNight': 4000000,
                    },
                  )
                  .toList(),
            },
          });
        }
        throw AssertionError('Unexpected wishlist request ${options.path}');
      });

      final wishlistRepo = WishlistRepositoryImpl(dio, prefs: prefs);

      // 1. When server fails, MUST NOT mark synced and must keep pending guest favorites
      await expectLater(
        wishlistRepo.getWishlistListingIds(),
        throwsA(anything),
      );
      expect(prefs.isWishlistSynced, isFalse);
      expect(prefs.getPendingGuestFavorites(), ['101', '102']);

      // 2. When server succeeds, migrates valid guest IDs ('101', '102'), ignores 'invalid-slug' & '-5', and merges with server '205'
      failServer = false;
      final mergedIds = await wishlistRepo.getWishlistListingIds();

      expect(postedIds, containsAll(['101', '102']));
      expect(postedIds, isNot(contains('invalid-slug')));
      expect(mergedIds.toSet(), {'101', '102', '205'});
      expect(prefs.isWishlistSynced, isTrue);

      // 3. Subsequent call does not re-POST already migrated guest favorites
      postedIds.clear();
      final secondSync = await wishlistRepo.getWishlistListingIds();
      expect(postedIds, isEmpty);
      expect(secondSync.toSet(), {'101', '102', '205'});

      // 4. Logout clears user session data so next user account never inherits previous user's wishlist
      await prefs.clearSessionData();
      expect(prefs.isWishlistSynced, isFalse);
      expect(prefs.getFavorites(), isEmpty);
      expect(prefs.getPendingGuestFavorites(), isEmpty);
    });
  });

  group('BUG-22 & Section 12: Profile Update & Responsive Widget Tests', () {
    testWidgets(
        'ProfileAccountEditorCard displays real user.isVerified status, submits school/location/job/dreamDestination/languages to backend, and preserves draft on error',
        (tester) async {
      const initialUser = User(
        id: '42',
        email: 'minh@vungtaustay.vn',
        firstName: 'Minh',
        lastName: 'Nguyen',
        phone: '0909123456',
        isVerified: false, // Unverified account must NOT show "Đã xác minh"
        location: 'TP. Hồ Chí Minh',
        job: 'Kỹ sư phần mềm',
        dreamDestination: 'Bãi Trước, Vũng Tàu',
        school: 'ĐH Bách Khoa',
        languages: ['Tiếng Việt', 'English'],
      );

      final fakeAuthRepo = _FakeAuthRepository(currentUser: initialUser);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileAccountEditorCard(
                user: initialUser,
                onUpdateProfile: fakeAuthRepo.updateProfile,
                onUpdateAvatar: fakeAuthRepo.updateAvatar,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify real identity verification status is shown (NOT hardcoded "Đã xác minh")
      expect(find.text('Chưa xác minh'), findsOneWidget);
      expect(find.text('Kỹ sư phần mềm'), findsOneWidget);
      expect(find.text('ĐH Bách Khoa'), findsOneWidget);

      // Open edit profile modal
      await tester.tap(find.text('Sửa hồ sơ'));
      await tester.pumpAndSettle();

      // Simulate API failure first to verify draft preservation and real error message
      fakeAuthRepo.shouldFailUpdate = true;
      await tester.enterText(
        find.widgetWithText(TextField, 'Trường học'),
        'ĐH Khoa Học Tự Nhiên',
      );
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Máy chủ từ chối cập nhật hồ sơ'),
        findsOneWidget,
      );
      // Input must still be preserved in the modal
      expect(find.text('ĐH Khoa Học Tự Nhiên'), findsOneWidget);

      // Now allow backend update to succeed and retry
      fakeAuthRepo.shouldFailUpdate = false;
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(fakeAuthRepo.lastUpdatedProfilePayload, isNotNull);
      expect(
        fakeAuthRepo.lastUpdatedProfilePayload!['school'],
        'ĐH Khoa Học Tự Nhiên',
      );
      expect(
        fakeAuthRepo.lastUpdatedProfilePayload!['location'],
        'TP. Hồ Chí Minh',
      );
      expect(
        fakeAuthRepo.lastUpdatedProfilePayload!['job'],
        'Kỹ sư phần mềm',
      );
      expect(
        fakeAuthRepo.lastUpdatedProfilePayload!['dreamDestination'],
        'Bãi Trước, Vũng Tàu',
      );
      expect(
        fakeAuthRepo.lastUpdatedProfilePayload!['languages'],
        ['Tiếng Việt', 'English'],
      );
      expect(find.text('ĐH Khoa Học Tự Nhiên'), findsOneWidget);
    });

    testWidgets(
        'ResponsiveTripBookingCard and MultiBookingQueueEditor render cleanly on narrow 320px and 430px viewports without Row overflow and enforce canCancel rules',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferencesService.create();
      await prefs.addBookingQueueItem(
        const BookingQueueItem(
          listingId: '12',
          title: 'Biệt thự Biển Xanh Vũng Tàu',
          imageUrl: '',
          pricePerNight: 4500000,
          checkIn: '2026-12-10',
          checkOut: '2026-12-12',
          guestsCount: 6,
          maxGuests: 12,
        ),
      );

      final checkedInBooking = Booking.fromJson({
        'bookingId': 901,
        'listingId': 12,
        'propertyName': 'Biệt thự Biển Xanh Vũng Tàu',
        'checkInDate': '2026-12-10',
        'checkOutDate': '2026-12-12',
        'nights': 2,
        'guestCount': 6,
        'totalAmount': 9000000,
        'status': 'checked_in', // Active, but canCancel MUST be false!
      });

      final dio = _createMockDio((options) async {
        return _jsonResponse({'success': true, 'data': <dynamic>[]});
      });
      final repo = BookingRepositoryImpl(dio);

      // Test narrow 320px viewport
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ResponsiveTripBookingCard(booking: checkedInBooking),
                  MultiBookingQueueEditor(prefs: prefs, repository: repo),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đã nhận phòng'), findsOneWidget);
      // checked_in booking must NOT show "Hủy phòng" button
      expect(find.text('Hủy phòng'), findsNothing);
      expect(find.text('Biệt thự Biển Xanh Vũng Tàu'), findsWidgets);
      expect(find.text('6/12'), findsOneWidget);

      // Test 430px mobile and 1024px desktop viewports without overflow
      tester.view.physicalSize = const Size(430, 844);
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpAndSettle();
    });
  });
}
