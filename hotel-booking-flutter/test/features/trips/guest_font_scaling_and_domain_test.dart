import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/favorites/data/repositories/wishlist_repository_impl.dart';
import 'package:hotel_booking_flutter/features/search/presentation/widgets/booking_date_range_picker.dart';
import 'package:hotel_booking_flutter/features/trips/data/repositories/booking_repository_impl.dart';
import 'package:hotel_booking_flutter/features/trips/domain/entities/booking.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/widgets/mobile_spec_summary.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/widgets/similar_villas_carousel_sizing.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';
import 'package:hotel_booking_flutter/features/villas/presentation/widgets/property_specs_row.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_notification_models.dart';
import 'package:hotel_booking_flutter/shared/widgets/vung_tau_map_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  _MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

Dio _mockDio(Future<ResponseBody> Function(RequestOptions options) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000'));
  dio.httpClientAdapter = _MockAdapter(handler);
  return dio;
}

ResponseBody _json(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  group('Guest Domain, Pagination & Route Normalization Runtime Verification',
      () {
    test('BookingRepositoryImpl.getMyBookings loops 1..totalPages with limit 50',
        () async {
      final pages = <int>[];
      final dio = _mockDio((options) async {
        final page = options.queryParameters['page'] as int;
        pages.add(page);
        if (page == 1) {
          return _json({
            'success': true,
            'data': {
              'items': List.generate(
                50,
                (i) => {
                  'bookingId': i + 1,
                  'listingId': 1,
                  'propertyName': 'Villa #${i + 1}',
                  'checkInDate': '2026-12-01',
                  'checkOutDate': '2026-12-03',
                  'totalAmount': 4000000,
                  'status': 'confirmed',
                },
              ),
              'pagination': {'page': 1, 'limit': 50, 'total': 62, 'totalPages': 2},
            },
          });
        }
        return _json({
          'success': true,
          'data': {
            'items': List.generate(
              12,
              (i) => {
                'bookingId': 51 + i,
                'listingId': 1,
                'propertyName': 'Villa #${51 + i}',
                'checkInDate': '2026-12-05',
                'checkOutDate': '2026-12-07',
                'totalAmount': 4200000,
                'status': 'completed',
              },
            ),
            'pagination': {'page': 2, 'limit': 50, 'total': 62, 'totalPages': 2},
          },
        });
      });

      final repo = BookingRepositoryImpl(dio);
      final list = await repo.getMyBookings();
      expect(pages, [1, 2]);
      expect(list.length, 62);
    });

    test(
        'Booking.effectiveStatusAt & deriveAuthoritativePaymentStatus resolve refundStatus and past paid stays accurately',
        () {
      final pastPaid = Booking.fromJson({
        'bookingId': 11,
        'listingId': 2,
        'propertyName': 'The Palm Villa',
        'checkInDate': '2026-10-10',
        'checkOutDate': '2026-10-12',
        'totalAmount': 5000000,
        'status': 'paid',
        'paymentStatus': 'paid',
      });
      expect(
        pastPaid.effectiveStatusAt(DateTime.utc(2026, 10, 11, 18, 0)),
        'completed',
      );
      expect(
        pastPaid.effectiveStatusAt(DateTime.utc(2026, 10, 10, 12, 0)),
        'paid',
      );

      final refundedBooking = Booking.fromJson({
        'bookingId': 12,
        'listingId': 2,
        'propertyName': 'The Palm Villa',
        'checkInDate': '2026-12-10',
        'checkOutDate': '2026-12-12',
        'totalAmount': 5000000,
        'status': 'cancelled_by_guest',
        'paymentStatus': 'paid',
        'refundStatus': 'succeeded',
      });
      expect(refundedBooking.effectiveStatus, 'refunded');

      const lateRefundSucceeded = PaymentSessionResult(
        paymentId: 'p1',
        bookingId: '12',
        method: 'vnpay',
        paymentStatus: 'paid',
        paymentResultStatus: 'paid',
        amount: 5000000,
        requiresRefund: true,
        refundStatus: 'succeeded',
      );
      expect(
        deriveAuthoritativePaymentStatus(payment: lateRefundSucceeded),
        'refunded',
      );

      const lateRefundPending = PaymentSessionResult(
        paymentId: 'p2',
        bookingId: '13',
        method: 'momo',
        paymentStatus: 'paid',
        paymentResultStatus: 'paid',
        amount: 5000000,
        requiresRefund: true,
        refundStatus: 'pending',
      );
      expect(
        deriveAuthoritativePaymentStatus(payment: lateRefundPending),
        'refund_pending',
      );
    });

    test(
        'AppNotificationItem maps /host/bao-cao & /host/... to /chu-nha/..., Wishlist rating defaults to 0.0, and Tháng caps at 30 nights',
        () async {
      final n1 = AppNotificationItem.fromJson({
        'id': '1',
        'eventType': 'PLATFORM_FEE_SCHEDULED',
        'title': 'Phí dịch vụ',
        'body': 'Chi tiết báo cáo',
        'actionUrl': '/host/bao-cao',
        'isRead': false,
        'createdAt': '2026-11-04T08:00:00Z',
      });
      expect(n1.resolveInternalRoute(), '/chu-nha/bao-cao');

      final n2 = AppNotificationItem.fromJson({
        'id': '2',
        'title': 'Thông báo Host',
        'body': 'Chi tiết',
        'actionUrl': '/host/uu-dai?tab=active',
        'isRead': false,
        'createdAt': '2026-11-04T08:00:00Z',
      });
      expect(n2.resolveInternalRoute(), '/chu-nha/uu-dai?tab=active');

      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferencesService.create();
      final dio = _mockDio((_) async {
        return _json({
          'success': true,
          'data': {
            'userId': 'u1',
            'listingIds': [88],
            'items': [
              {'id': 88, 'title': 'Villa Mới', 'pricePerNight': 3000000},
            ],
          },
        });
      });
      final wishlistRepo = WishlistRepositoryImpl(dio, prefs: prefs);
      final detail = await wishlistRepo.getWishlistDetail();
      expect(detail.items.single.rating, 0.0);

      final monthRange = SearchDateModeHelper.computeForMonths(
        [12],
        referenceToday: const BookingDate(year: 2026, month: 11, day: 4),
      );
      expect(monthRange.checkIn.differenceInNights(monthRange.checkOut), 30);
    });
  });

  group('Guest Font-Scaling Runtime Verification (1.3x–2.0x — all 4 clusters)',
      () {
    const specs = VillaSpecs(
      bedrooms: 5,
      beds: 8,
      maxGuests: 16,
      bathrooms: 6,
      beachDistanceMeters: 120,
    );

    const villa = Villa(
      id: '101',
      code: 'VT-101',
      name: 'The Palm Oceanfront Luxury Pool Villa Bãi Sau Vũng Tàu',
      tagline: 'Sát biển Thùy Vân, hồ bơi nước mặn riêng',
      address: '28 Thùy Vân, Phường 2, TP. Vũng Tàu',
      description: 'Biệt thự nghỉ dưỡng cao cấp.',
      imageUrls: [],
      specs: specs,
      basePriceVnd: 6500000,
      saturdayPriceVnd: 8900000,
      badges: [VillaBadgeType.nearBeach],
      rating: 4.9,
      reviewCount: 42,
    );

    testWidgets(
        'All 4 Guest font-scaling clusters render at 1.3x, 1.6x, and 2.0x without overflow',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final scale in [1.3, 1.6, 2.0]) {
        await tester.binding.setSurfaceSize(const Size(360, 900));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Builder(
                    builder: (context) {
                      final carouselHeight = computeSimilarVillasCarouselHeight(
                        context,
                        const [villa],
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: carouselHeight,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                SizedBox(
                                  width: 300,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 225),
                                      const SizedBox(height: 12),
                                      Text(
                                        villa.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      PropertySpecsRow(specs: villa.specs),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const MobileSpecSummary(specs: specs),
                          const SizedBox(height: 16),
                          const VungTauMapPicker(showPresetChips: true),
                          const SizedBox(height: 16),
                          BookingDateRangePicker(
                            initialCheckIn: const BookingDate(
                              year: 2026,
                              month: 12,
                              day: 15,
                            ),
                            initialCheckOut: const BookingDate(
                              year: 2026,
                              month: 12,
                              day: 22,
                            ),
                            minDate: const BookingDate(
                              year: 2026,
                              month: 12,
                              day: 1,
                            ),
                            onRangeSelected: (_) {},
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(
          tester.takeException(),
          isNull,
          reason: 'Zero overflow expected at textScale=$scale',
        );
      }
    });
  });
}
