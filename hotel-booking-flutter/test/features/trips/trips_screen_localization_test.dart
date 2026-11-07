import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/trips/domain/entities/booking.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/trips_screen.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/guest_payment_screen.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/view_models/trips_view_model.dart';

class _FakeAuthNotifier extends StateNotifier<AsyncValue<User?>>
    implements AuthNotifier {
  _FakeAuthNotifier([User? user]) : super(AsyncValue.data(user));

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
  final now = DateTime.now();
  const testUser = User(
    id: 'user-guest-1',
    email: 'guest@example.com',
    firstName: 'John',
    lastName: 'Doe',
    role: 'guest',
  );

  final upcomingBooking = Booking(
    id: 'booking-upcoming-101',
    listingId: 'villa-101',
    propertyName: 'Seaside Sunset Homestay',
    address: '84 Ha Long',
    checkInDate: '2026-11-04',
    checkOutDate: '2026-11-06',
    nights: 2,
    guestCount: 2,
    totalAmount: 3010000,
    status: 'paid',
    paymentStatus: 'paid',
    createdAt: now,
    priceBreakdown: const BookingPriceBreakdown(
      totalNights: 2,
      baseNightsAmount: 2500000,
      cleaningFee: 300000,
      serviceFee: 210000,
      totalAmount: 3010000,
    ),
  );

  final completedBooking = Booking(
    id: 'booking-completed-102',
    listingId: 'villa-102',
    propertyName: 'The Palm Luxury Sea View',
    address: '120 Tran Phu',
    checkInDate: '2026-10-25',
    checkOutDate: '2026-10-28',
    nights: 3,
    guestCount: 4,
    totalAmount: 8300000,
    status: 'completed',
    paymentStatus: 'paid',
    hasReview: false,
    createdAt: now.subtract(const Duration(days: 10)),
    priceBreakdown: const BookingPriceBreakdown(
      totalNights: 3,
      baseNightsAmount: 7500000,
      cleaningFee: 500000,
      serviceFee: 300000,
      totalAmount: 8300000,
    ),
  );

  final cancelledBooking = Booking(
    id: 'booking-cancelled-103',
    listingId: 'villa-103',
    propertyName: 'Seaside Sunset Homestay',
    address: '84 Ha Long',
    checkInDate: '2026-11-08',
    checkOutDate: '2026-11-09',
    nights: 1,
    guestCount: 2,
    totalAmount: 1580000,
    status: 'cancelled',
    paymentStatus: 'failed',
    createdAt: now.subtract(const Duration(days: 2)),
    priceBreakdown: const BookingPriceBreakdown(
      totalNights: 1,
      baseNightsAmount: 1300000,
      cleaningFee: 150000,
      serviceFee: 130000,
      totalAmount: 1580000,
    ),
  );

  final testFxSnapshot = ExchangeRateSnapshot.validated(
    usdRateDecimal: '0.00004',
    krwRateDecimal: '0.054',
    source: 'test_fixture',
    sourceUpdatedAt: now.toUtc().subtract(const Duration(hours: 1)),
    fetchedAt: now.toUtc(),
    serverMarkedStale: false,
    validationNow: now.toUtc(),
  );

  group('TripsScreen English Localization Tests', () {
    testWidgets('renders English tabs and empty state when locale is en',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider
                .overrideWith((ref) => _FakeAuthNotifier(testUser)),
            localeProvider.overrideWith((ref) => _FakeLocaleNotifier('en')),
            myBookingsProvider.overrideWith((ref) => Future.value([])),
            activePendingBookingProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(
            home: TripsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tabs in English
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);

      // Empty state in English
      expect(find.text('No upcoming trips'), findsOneWidget);
      expect(find.text('Explore villas'), findsOneWidget);
    });

    testWidgets(
        'renders English villa info, status, nights, total payment, details and review buttons',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider
                .overrideWith((ref) => _FakeAuthNotifier(testUser)),
            localeProvider.overrideWith((ref) => _FakeLocaleNotifier('en')),
            myBookingsProvider
                .overrideWith((ref) => Future.value([upcomingBooking])),
            activePendingBookingProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(
            home: TripsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Villa title & address
      expect(find.text('Seaside Sunset Homestay'), findsOneWidget);
      expect(find.text('84 Ha Long'), findsOneWidget);

      // Status in English
      expect(find.text('Payment successful'), findsOneWidget);

      // Nights & guests in English
      expect(find.text('2 nights • 2 guests'), findsOneWidget);

      // Total payment header in English
      expect(find.text('Total payment'), findsOneWidget);

      // Buttons in English: Details button
      expect(find.text('Details'), findsOneWidget);

      // Tap "Details" to expand price breakdown
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      // Button toggles to "Hide details"
      expect(find.text('Hide details'), findsOneWidget);

      // Expanded drawer details in English
      expect(
          find.text('Booking details #booking-upcoming-101'), findsOneWidget);
      expect(find.text('Room rate (2 nights)'), findsOneWidget);
      expect(find.text('Cleaning fee'), findsOneWidget);
      expect(find.text('Service fee'), findsOneWidget);
    });

    testWidgets(
        'renders Completed tab with Review button and opens English review modal',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider
                .overrideWith((ref) => _FakeAuthNotifier(testUser)),
            localeProvider.overrideWith((ref) => _FakeLocaleNotifier('en')),
            myBookingsProvider
                .overrideWith((ref) => Future.value([completedBooking])),
            activePendingBookingProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(
            home: TripsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Completed tab
      await tester.tap(find.widgetWithText(Tab, 'Completed'));
      await tester.pumpAndSettle();

      // Verify Completed card
      expect(find.text('The Palm Luxury Sea View'), findsOneWidget);
      // "Completed" appears in Tab and card status badge
      expect(find.text('Completed'), findsNWidgets(2));
      expect(find.text('3 nights • 4 guests'), findsOneWidget);

      // Buttons: Details and Review
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);

      // Tap Review button
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      // Review dialog in English
      expect(find.text('Review your stay at The Palm Luxury Sea View'),
          findsOneWidget);
      expect(find.text('Your rating:'), findsOneWidget);
      expect(find.text('Share your experience *'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Submit review'), findsOneWidget);
    });

    testWidgets(
        'converts prices and breakdown to foreign currency in Cancelled and Completed tabs',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider
                .overrideWith((ref) => _FakeAuthNotifier(testUser)),
            localeProvider.overrideWith((ref) => _FakeLocaleNotifier('en')),
            moneyFormatterProvider.overrideWithValue(MoneyFormatter(
              localeCode: 'en',
              effectiveCurrency: AppCurrency.usd,
              snapshot: testFxSnapshot,
            )),
            myBookingsProvider.overrideWith((ref) =>
                Future.value([completedBooking, cancelledBooking])),
            activePendingBookingProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(
            home: TripsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Check Cancelled tab
      await tester.tap(find.widgetWithText(Tab, 'Cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('Seaside Sunset Homestay'), findsOneWidget);
      // Converted total payment in USD
      expect(find.text('≈ \$63.20'), findsOneWidget);
      expect(
          find.textContaining('Total payable: 1.580.000 VND'), findsOneWidget);

      // Expand details drawer
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      // Verify all breakdown items converted to USD
      expect(find.text('≈ \$52.00'), findsOneWidget);
      expect(find.text('≈ \$6.00'), findsOneWidget);
      expect(find.text('≈ \$5.20'), findsOneWidget);

      // 2. Check Completed tab
      await tester.tap(find.widgetWithText(Tab, 'Completed'));
      await tester.pumpAndSettle();

      expect(find.text('The Palm Luxury Sea View'), findsOneWidget);
      // Converted total payment in USD
      expect(find.text('≈ \$332.00'), findsOneWidget);
      expect(
          find.textContaining('Total payable: 8.300.000 VND'), findsOneWidget);

      // Expand details drawer
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      // Verify breakdown items converted to USD
      expect(find.text('≈ \$300.00'), findsOneWidget);
      expect(find.text('≈ \$20.00'), findsOneWidget);
      expect(find.text('≈ \$12.00'), findsOneWidget);
    });
  });

  group('Trips and Payment Loading Localization Tests', () {
    testWidgets('TripsScreen shows localized loading message for en, ko, vi',
        (tester) async {
      for (final (localeCode, expectedMessage) in [
        ('en', 'Loading trips...'),
        ('ko', '여행 일정을 불러오는 중...'),
        ('vi', 'Đang tải lịch trình...'),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('trips_loading_$localeCode'),
            overrides: [
              authNotifierProvider
                  .overrideWith((ref) => _FakeAuthNotifier(testUser)),
              localeProvider
                  .overrideWith((ref) => _FakeLocaleNotifier(localeCode)),
              myBookingsProvider
                  .overrideWith((ref) => Completer<List<Booking>>().future),
              activePendingBookingProvider.overrideWithValue(null),
            ],
            child: MaterialApp(
              locale: Locale(localeCode),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TripsScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(expectedMessage), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets(
        'GuestPaymentScreen shows localized loading message for en, ko, vi',
        (tester) async {
      for (final (localeCode, expectedMessage) in [
        ('en', 'Loading booking payment details...'),
        ('ko', '예약 결제 정보를 불러오는 중...'),
        ('vi', 'Đang tải thông tin thanh toán đặt phòng...'),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('payment_loading_$localeCode'),
            overrides: [
              authNotifierProvider
                  .overrideWith((ref) => _FakeAuthNotifier(testUser)),
              localeProvider
                  .overrideWith((ref) => _FakeLocaleNotifier(localeCode)),
              moneyFormatterProvider.overrideWithValue(MoneyFormatter(
                localeCode: localeCode,
                effectiveCurrency: AppCurrency.vnd,
              )),
              bookingDetailProvider('booking-101')
                  .overrideWith((ref) => Completer<Booking?>().future),
              paymentMethodsProvider.overrideWith((ref) => Future.value([])),
            ],
            child: MaterialApp(
              locale: Locale(localeCode),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const GuestPaymentScreen(bookingId: 'booking-101'),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(expectedMessage), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
