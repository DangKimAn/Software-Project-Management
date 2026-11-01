import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/core/errors/app_failure.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/trips/domain/entities/booking.dart';
import 'package:hotel_booking_flutter/features/trips/domain/repositories/booking_repository.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/guest_payment_screen.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/multi_booking_screen.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/screens/payment_result_screen.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/view_models/trips_view_model.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/widgets/daily_price_breakdown.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/nightly_price.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';
import 'package:hotel_booking_flutter/features/villas/domain/repositories/villa_repository.dart';
import 'package:hotel_booking_flutter/features/villas/presentation/widgets/property_card.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';
import 'package:hotel_booking_flutter/shared/widgets/currency_language_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// TEST-ONLY FIXTURES (Explicitly marked per tiente.md Section IX — never in lib/)
// ============================================================================

final _fixedNowUtc = DateTime.utc(2026, 10, 31, 6, 0, 0);

ExchangeRateSnapshot _buildTestFixtureSnapshot({
  String usdRate = '0.00004',
  String krwRate = '0.054',
  DateTime? sourceUpdatedAt,
  DateTime? fetchedAt,
  bool isStale = false,
}) {
  return ExchangeRateSnapshot.validated(
    usdRateDecimal: usdRate,
    krwRateDecimal: krwRate,
    source: 'test_fixture_frankfurter',
    sourceUpdatedAt:
        sourceUpdatedAt ?? _fixedNowUtc.subtract(const Duration(hours: 2)),
    fetchedAt: fetchedAt ?? _fixedNowUtc.subtract(const Duration(minutes: 5)),
    serverMarkedStale: isStale,
    validationNow: _fixedNowUtc,
  );
}

const Villa _sampleVilla = Villa(
  id: '101',
  code: 'VT-101',
  name: 'The Palm Ocean Villa',
  tagline: 'Biệt thự sát biển Bãi Sau',
  address: '12 Trần Phú, Vũng Tàu',
  description: 'Không gian nghỉ dưỡng riêng tư sát biển.',
  imageUrls: <String>['assets/images/NDT05929-HDR1.jpg'],
  specs: VillaSpecs(
    bedrooms: 4,
    beds: 6,
    maxGuests: 12,
    bathrooms: 4,
  ),
  basePriceVnd: 3500000,
  saturdayPriceVnd: 5200000,
  cleaningFeeVnd: 300000,
);

Booking _buildSampleBooking({
  String id = '901',
  int totalAmount = 3500000,
  String status = 'pending_payment',
  String paymentStatus = 'unpaid',
}) {
  return Booking(
    id: id,
    listingId: '101',
    propertyName: 'The Palm Ocean Villa',
    coverImageUrl: 'assets/images/NDT05929-HDR1.jpg',
    checkInDate: '2026-11-10',
    checkOutDate: '2026-11-12',
    nights: 2,
    totalAmount: totalAmount,
    subtotalAmount: 3600000,
    cleaningFeeAmount: 200000,
    discountAmount: 300000,
    couponCode: 'WELCOME300',
    currency: 'VND',
    guestCount: 6,
    status: status,
    paymentStatus: paymentStatus,
    remainingPaymentSeconds: 600,
    paymentExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    priceBreakdown: BookingPriceBreakdown(
      totalNights: 2,
      weekdayNights: 1,
      weekendNights: 1,
      baseNightsAmount: 3000000,
      weekendSurchargeAmount: 600000,
      cleaningFee: 200000,
      discountAmount: 300000,
      totalAmount: totalAmount,
      couponCode: 'WELCOME300',
    ),
  );
}

class _FakeExchangeRateRepository implements ExchangeRateRepository {
  ExchangeRateSnapshot? nextSnapshot;
  ExchangeRateSnapshot? cached;
  final ExchangeRateCache? cacheStore;
  Object? errorToThrow;
  int fetchCalls = 0;

  _FakeExchangeRateRepository({
    this.nextSnapshot,
    this.cacheStore,
    this.errorToThrow,
  });

  @override
  ExchangeRateSnapshot? getCachedSnapshot({DateTime? now}) {
    final evalNow = (now ?? DateTime.now()).toUtc();
    if (cacheStore != null) {
      return cacheStore!.readUsableSnapshot(now: evalNow);
    }
    if (cached == null || cached!.isExpiredAt(evalNow)) {
      return null;
    }
    return cached;
  }

  @override
  Future<ExchangeRateSnapshot> fetchLatestRates({DateTime? now}) async {
    fetchCalls += 1;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    final result = nextSnapshot ?? _buildTestFixtureSnapshot();
    cached = result;
    if (cacheStore != null) {
      await cacheStore!.writeSnapshot(result);
    }
    return result;
  }
}

class _FakeAuthRepository implements AuthRepository {
  User? user;
  _FakeAuthRepository();

  @override
  Future<User?> getCurrentUser() async => user;

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
    user = null;
  }
}

class _FakeVillaRepository implements VillaRepository {
  int getVillasCalls = 0;
  final List<Villa> villas = const <Villa>[_sampleVilla];

  _FakeVillaRepository();

  @override
  Future<List<Villa>> getVillas({
    String? searchQuery,
    String? locationGroup,
    double? lat,
    double? lng,
    int? radius,
    String? propertyType,
    int? priceMin,
    int? priceMax,
    int? minGuests,
    int? bedrooms,
    int? beds,
    int? bathrooms,
    List<String>? amenities,
    BookingDate? checkIn,
    BookingDate? checkOut,
    String? sort,
    int page = 1,
    int limit = 20,
  }) async {
    getVillasCalls += 1;
    return villas;
  }

  @override
  Future<PaginatedResult<Villa>> getVillasPaginated({
    String? searchQuery,
    String? locationGroup,
    double? lat,
    double? lng,
    int? radius,
    String? propertyType,
    int? priceMin,
    int? priceMax,
    int? minGuests,
    int? bedrooms,
    int? beds,
    int? bathrooms,
    List<String>? amenities,
    BookingDate? checkIn,
    BookingDate? checkOut,
    String? sort,
    int page = 1,
    int limit = 12,
  }) async {
    getVillasCalls += 1;
    return PaginatedResult<Villa>(items: villas);
  }

  @override
  Future<Villa?> getVillaById(String id) async => _sampleVilla;

  @override
  Future<VillaRules> getVillaRules(String villaId) async => const VillaRules();

  @override
  Future<List<Villa>> getRecommendations(String villaId,
          {int limit = 4}) async =>
      const <Villa>[];

  @override
  Future<Set<String>> getUnavailableDates(
    String villaId, {
    int monthsAhead = 6,
  }) async =>
      const <String>{};

  @override
  Future<List<NightlyPrice>> getNightlyPrices({
    required String villaId,
    required BookingDate checkIn,
    required BookingDate checkOut,
  }) async =>
      const <NightlyPrice>[
        NightlyPrice(
          date: BookingDate(year: 2026, month: 11, day: 10),
          priceVnd: 3500000,
        ),
        NightlyPrice(
          date: BookingDate(year: 2026, month: 11, day: 11),
          priceVnd: 5200000,
          isWeekend: true,
        ),
      ];

  @override
  Future<bool> checkAvailability({
    required String villaId,
    required BookingDate checkIn,
    required BookingDate checkOut,
  }) async =>
      true;

  @override
  Future<SemanticSearchResponse> semanticSearch({
    required String query,
    int topK = 12,
  }) async =>
      SemanticSearchResponse(query: query, items: villas);

  @override
  Future<List<Map<String, dynamic>>> getAmenitiesCatalog() async =>
      const <Map<String, dynamic>>[];
}

class _FakeBookingRepository implements BookingRepository {
  Booking booking;
  PaymentSessionResult? paymentRecord;
  int createPaymentCalls = 0;
  String? lastPaymentBookingId;
  String? lastPaymentMethod;

  _FakeBookingRepository({
    Booking? booking,
    this.paymentRecord,
  }) : booking = booking ?? _buildSampleBooking();

  @override
  Future<List<Booking>> getMyBookings({
    String? status,
    int? page,
    int? limit,
  }) async =>
      <Booking>[booking];

  @override
  Future<Booking?> getBookingById(String bookingId) async => booking;

  @override
  Future<Booking> createBooking({
    required String listingId,
    required String checkInDate,
    required String checkOutDate,
    required int guestsCount,
    String? specialRequests,
    String? couponCode,
  }) async =>
      booking;

  @override
  Future<List<Booking>> createBulkBookings({
    required List<Map<String, dynamic>> items,
  }) async =>
      <Booking>[booking];

  @override
  Future<void> cancelBooking({
    required String bookingId,
    required String reason,
  }) async {}

  @override
  Future<CouponValidationResult> validateCoupon({
    required String code,
    int? bookingAmount,
    int? subtotalAmount,
    String? listingId,
    String? checkInDate,
    String? checkOutDate,
    int? guestsCount,
  }) async =>
      CouponValidationResult(valid: true, code: code, discountAmount: 300000);

  @override
  Future<List<PaymentMethodAvailability>> getPaymentMethods() async =>
      const <PaymentMethodAvailability>[
        PaymentMethodAvailability(
          method: 'vnpay',
          label: 'VNPay',
          available: true,
        ),
        PaymentMethodAvailability(
          method: 'momo',
          label: 'MoMo',
          available: false,
          unavailableReason: 'MoMo chưa được cấu hình trên máy chủ.',
        ),
      ];

  @override
  Future<PaymentSessionResult> createPayment({
    required String bookingId,
    required String method,
    String? idempotencyKey,
  }) async {
    createPaymentCalls += 1;
    lastPaymentBookingId = bookingId;
    lastPaymentMethod = method;
    return PaymentSessionResult(
      paymentId: 'pay_555',
      bookingId: bookingId,
      method: method,
      paymentStatus: 'pending',
      amount: booking.totalAmount,
      currency: 'VND',
      paymentUrl:
          'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_Amount=350000000',
    );
  }

  @override
  Future<PaymentSessionResult?> getPaymentById(String paymentId) async =>
      paymentRecord ??
      PaymentSessionResult(
        paymentId: paymentId,
        bookingId: booking.id,
        method: 'vnpay',
        paymentStatus: 'pending',
        amount: booking.totalAmount,
        currency: 'VND',
      );
}

final _testVillasOnceProvider = FutureProvider<List<Villa>>((ref) {
  return ref.watch(villaRepositoryProvider).getVillas();
});

class _TestRouterApp extends ConsumerStatefulWidget {
  final Widget home;
  final String initialLocation;

  const _TestRouterApp({
    required this.home,
    this.initialLocation = '/',
  });

  @override
  ConsumerState<_TestRouterApp> createState() => _TestRouterAppState();
}

class _TestRouterAppState extends ConsumerState<_TestRouterApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: widget.initialLocation,
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => widget.home,
        ),
        GoRoute(
          path: '/thanh-toan/ket-qua',
          builder: (context, state) {
            final q = state.uri.queryParameters;
            return Scaffold(
              body: Center(
                child: Text(
                  'RESULT:${q['bookingId']}:${q['method']}:${q['status']}:${q['amount']}',
                  key: const Key('routed_payment_result_probe'),
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/account/trips',
          builder: (context, state) =>
              const Scaffold(body: Text('TRIPS_SCREEN')),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) =>
              const Scaffold(body: Text('SEARCH_SCREEN')),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = ref.watch(localeProvider);
    return MaterialApp.router(
      locale: Locale(localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: _router,
    );
  }
}

Widget _buildTestRouterApp({
  required Widget home,
  String initialLocation = '/',
}) {
  return _TestRouterApp(home: home, initialLocation: initialLocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Currency Acceptance Matrix (FX-01..FX-30)', () {
    testWidgets(
      'FX-01..FX-07 & FX-12..FX-13: Fresh install vi/VND, realtime vi -> en -> ko -> manual USD -> automatic without refetching Villa API or losing dates',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sp = await SharedPreferences.getInstance();
        final prefs = PreferencesService(sp);
        final fxRepo = _FakeExchangeRateRepository(
          nextSnapshot: _buildTestFixtureSnapshot(
            usdRate: '0.00004', // 3,500,000 VND = $140; 5,200,000 VND = $208
            krwRate: '0.054', // 3,500,000 VND = ₩189,000
          ),
        );
        final villaRepo = _FakeVillaRepository();

        DateTimeRange selectedRange = DateTimeRange(
          start: DateTime(2026, 11, 10),
          end: DateTime(2026, 11, 12),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              preferencesServiceProvider.overrideWithValue(prefs),
              exchangeRateRepositoryProvider.overrideWithValue(fxRepo),
              villaRepositoryProvider.overrideWithValue(villaRepo),
              authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
              currencyClockProvider.overrideWithValue(() => _fixedNowUtc),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                final localeCode = ref.watch(localeProvider);
                final villasAsync = ref.watch(_testVillasOnceProvider);
                return MaterialApp(
                  locale: Locale(localeCode),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  home: Scaffold(
                    appBar: AppBar(
                      actions: const <Widget>[HeaderCurrencyLanguageButton()],
                    ),
                    body: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'RANGE:${selectedRange.start.day}->${selectedRange.end.day}',
                            key: const Key('selected_date_range_probe'),
                          ),
                          villasAsync.when(
                            data: (items) => PropertyCard(
                              villa: items.first,
                              onTap: () {},
                            ),
                            loading: () => const CircularProgressIndicator(),
                            error: (e, _) => Text('ERR:$e'),
                          ),
                          const DailyPriceBreakdown(
                            nightlyPrices: <NightlyPrice>[
                              NightlyPrice(
                                date:
                                    BookingDate(year: 2026, month: 11, day: 10),
                                priceVnd: 3500000,
                              ),
                              NightlyPrice(
                                date:
                                    BookingDate(year: 2026, month: 11, day: 11),
                                priceVnd: 5200000,
                                isWeekend: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // FX-01: Fresh install is Vietnamese + VND
        expect(find.text('VI · ₫'), findsOneWidget);
        expect(find.textContaining('3.500.000 ₫'), findsWidgets);
        expect(villaRepo.getVillasCalls, 1);

        // FX-02: Switch vi -> en via HeaderCurrencyLanguageButton
        await tester
            .tap(find.byKey(const Key('header_currency_language_button')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('sheet_lang_en')));
        await tester.tap(find.byKey(const Key('sheet_lang_en')));
        await tester.pumpAndSettle();

        expect(find.text('EN · \$'), findsOneWidget);
        expect(find.textContaining('From ≈ \$140 / night'), findsOneWidget);
        expect(find.text('≈ \$140.00'), findsOneWidget);
        expect(find.text('≈ \$208.00'), findsOneWidget);
        // FX-12 & FX-13: Villa API was NOT refetched and dates were NOT reset
        expect(villaRepo.getVillasCalls, 1);
        expect(find.text('RANGE:10->12'), findsOneWidget);

        // FX-03: Switch en -> ko
        await tester.ensureVisible(find.byKey(const Key('sheet_lang_ko')));
        await tester.tap(find.byKey(const Key('sheet_lang_ko')));
        await tester.pumpAndSettle();

        expect(find.text('KO · ₩'), findsOneWidget);
        expect(find.textContaining('1박당 ≈ ₩189,000부터'), findsOneWidget);
        expect(find.text('≈ ₩189,000'), findsOneWidget);
        expect(villaRepo.getVillasCalls, 1);

        // FX-05: Pin manual USD while interface stays Korean
        await tester.ensureVisible(find.byKey(const Key('sheet_currency_usd')));
        await tester.tap(find.byKey(const Key('sheet_currency_usd')));
        await tester.pumpAndSettle();

        expect(find.text('KO · \$'), findsOneWidget);
        expect(find.textContaining('1박당 ≈ \$140부터'), findsOneWidget);

        // FX-06: Switch language ko -> vi while manual USD is pinned -> keeps USD override
        await tester.ensureVisible(find.byKey(const Key('sheet_lang_vi')));
        await tester.tap(find.byKey(const Key('sheet_lang_vi')));
        await tester.pumpAndSettle();

        expect(find.text('VI · \$'), findsOneWidget);
        expect(find.textContaining('Từ ≈ \$140 / đêm'), findsOneWidget);

        // FX-07: Restore Automatic mode -> immediately follows 'vi' -> VND
        await tester.ensureVisible(
          find.byKey(const Key('sheet_currency_automatic')),
        );
        await tester.tap(find.byKey(const Key('sheet_currency_automatic')));
        await tester.pumpAndSettle();

        expect(find.text('VI · ₫'), findsOneWidget);
        expect(find.textContaining('Từ 3.500.000 ₫ / đêm'), findsOneWidget);
        expect(villaRepo.getVillasCalls, 1);

        // Close sheet cleanly
        await tester
            .tap(find.byKey(const Key('currency_language_sheet_close')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'FX-08..FX-11 & FX-21: Offline cache recovery, missing-cache VND fallback, >7d expired fallback, malformed payload safety, and cold restart persistence',
      (tester) async {
        // 1. FX-09 & FX-11: Offline / ServerFailure with NO cache -> keeps English copy & falls back to VND safely
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final spNoCache = await SharedPreferences.getInstance();
        final prefsNoCache = PreferencesService(spNoCache);
        final failingRepo = _FakeExchangeRateRepository(
          errorToThrow: const ServerFailure('Malformed upstream FX payload'),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              preferencesServiceProvider.overrideWithValue(prefsNoCache),
              exchangeRateRepositoryProvider.overrideWithValue(failingRepo),
              currencyClockProvider.overrideWithValue(() => _fixedNowUtc),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                final localeCode = ref.watch(localeProvider);
                return MaterialApp(
                  locale: Locale(localeCode),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          PropertyCard(villa: _sampleVilla, onTap: () {}),
                          const CurrencyLanguageSheetContent(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('sheet_lang_en')));
        await tester.tap(find.byKey(const Key('sheet_lang_en')));
        await tester.pumpAndSettle();

        // Language is English, price safely falls back to official VND with fallback notice
        expect(find.textContaining('From 3.500.000 ₫ / night'), findsOneWidget);
        expect(
          find.text(
            'Exchange rates unavailable. Displaying official prices in VND.',
          ),
          findsOneWidget,
        );

        // 2. FX-08 & FX-21: Persist ko + manual USD + cached snapshot, then simulate cold restart offline
        final validSnapshot = _buildTestFixtureSnapshot(
          usdRate: '0.00004',
          krwRate: '0.054',
        );
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final spRestart = await SharedPreferences.getInstance();
        final prefsBeforeRestart = PreferencesService(spRestart);
        await prefsBeforeRestart.setLocale('ko');
        await ExchangeRateCache(prefsBeforeRestart).writePreference(
          const CurrencyPreference.manual(AppCurrency.usd),
        );
        await ExchangeRateCache(prefsBeforeRestart)
            .writeSnapshot(validSnapshot);

        // Cold restart: new PreferencesService reading persisted SharedPreferences while network is offline
        final prefsAfterRestart = PreferencesService(spRestart);
        final offlineRepo = _FakeExchangeRateRepository(
          cacheStore: ExchangeRateCache(prefsAfterRestart),
          errorToThrow: const OfflineFailure(),
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey<String>('scope_cold_restart'),
            overrides: <Override>[
              preferencesServiceProvider.overrideWithValue(prefsAfterRestart),
              exchangeRateRepositoryProvider.overrideWithValue(offlineRepo),
              currencyClockProvider.overrideWithValue(() => _fixedNowUtc),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                final localeCode = ref.watch(localeProvider);
                return MaterialApp(
                  locale: Locale(localeCode),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: PropertyCard(villa: _sampleVilla, onTap: () {}),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Restores Korean copy + manual USD override + cached snapshot while offline!
        expect(find.textContaining('1박당 ≈ \$140부터'), findsOneWidget);

        // 3. FX-10: Advance clock > 7 days while still offline -> expired snapshot must fall back to VND
        final expiredClock = _fixedNowUtc.add(const Duration(days: 8));
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey<String>('scope_expired_clock'),
            overrides: <Override>[
              preferencesServiceProvider.overrideWithValue(prefsAfterRestart),
              exchangeRateRepositoryProvider.overrideWithValue(offlineRepo),
              currencyClockProvider.overrideWithValue(() => expiredClock),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                final localeCode = ref.watch(localeProvider);
                return MaterialApp(
                  locale: Locale(localeCode),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: PropertyCard(villa: _sampleVilla, onTap: () {}),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('1박당 3.500.000 ₫부터'), findsOneWidget);
      },
    );

    testWidgets(
      'FX-15: MultiBookingScreen converts authoritative VND grandTotal once instead of summing rounded foreign lines',
      (tester) async {
        // Rate = 0.00003945 USD/VND:
        // Each item = 1,000,100 VND -> 39.453945 -> rounds to $39.45 individually (3 * 39.45 = $118.35).
        // Authoritative VND sum = 3,000,300 VND -> 118.361835 -> rounds once to $118.36!
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sp = await SharedPreferences.getInstance();
        final prefs = PreferencesService(sp);
        await prefs.setLocale('en');
        for (int i = 1; i <= 3; i++) {
          await prefs.addToBookingQueue(
            BookingQueueItem(
              listingId: 'v$i',
              title: 'Villa #$i',
              imageUrl: 'assets/images/NDT05929-HDR1.jpg',
              basePrice: 1000100,
              checkIn: '2026-11-10',
              checkOut: '2026-11-11',
              guestsCount: 2,
            ),
          );
        }

        final fxRepo = _FakeExchangeRateRepository(
          nextSnapshot: _buildTestFixtureSnapshot(usdRate: '0.00003945'),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              preferencesServiceProvider.overrideWithValue(prefs),
              exchangeRateRepositoryProvider.overrideWithValue(fxRepo),
              bookingRepositoryProvider
                  .overrideWithValue(_FakeBookingRepository()),
              authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
              currencyClockProvider.overrideWithValue(() => _fixedNowUtc),
            ],
            child: _buildTestRouterApp(home: const MultiBookingScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Individual items show ≈ $39.45, while grandTotal converts 3,000,300 VND once -> ≈ $118.36!
        expect(find.text('Tạm tính (1 đêm): ≈ \$39.45'), findsNWidgets(3));
        expect(
          find.byKey(const Key('multi_booking_grand_total_display')),
          findsOneWidget,
        );
        expect(find.text('≈ \$118.36'), findsOneWidget);
        expect(
          find.textContaining('Total payable: 3.000.300 VND'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'FX-16, FX-17, FX-18, FX-24: GuestPaymentScreen renders 3-section Dual-Display, freezes FX snapshot during checkout, and sends pure VND to gateway',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sp = await SharedPreferences.getInstance();
        final prefs = PreferencesService(sp);
        await prefs.setLocale('en');

        final fxRepo = _FakeExchangeRateRepository(
          nextSnapshot: _buildTestFixtureSnapshot(
            usdRate: '0.00004', // 3,500,000 VND = $140.00
            krwRate: '0.054', // 3,500,000 VND = ₩189,000
          ),
        );
        final bookingRepo = _FakeBookingRepository(
          booking: _buildSampleBooking(id: '901', totalAmount: 3500000),
        );
        Uri? launchedGatewayUri;

        late WidgetRef capturedRef;

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              preferencesServiceProvider.overrideWithValue(prefs),
              exchangeRateRepositoryProvider.overrideWithValue(fxRepo),
              bookingRepositoryProvider.overrideWithValue(bookingRepo),
              authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
              currencyClockProvider.overrideWithValue(() => _fixedNowUtc),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return _buildTestRouterApp(
                  home: GuestPaymentScreen(
                    bookingId: '901',
                    externalUrlLauncher: (uri) async {
                      launchedGatewayUri = uri;
                      return true;
                    },
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Section B (Estimated USD Reference) & Section C (Official Payable VND)
        expect(
            find.byKey(const Key('checkout_fx_reference_box')), findsOneWidget);
        expect(
          find.text('Estimated price: ≈ \$140.00'),
          findsOneWidget,
        );
        expect(
          find.text('Total payable: 3.500.000 VND'),
          findsOneWidget,
        );
        expect(
          find.text(
            'You will be charged in VND. Your bank may apply exchange rates and fees.',
          ),
          findsOneWidget,
        );

        // Truthful gateway title — NO unverified Visa/Master claim
        expect(
          find.text('VNPay (QR Pay / Domestic Bank Card)'),
          findsOneWidget,
        );
        expect(find.textContaining('Visa / Master'), findsNothing);

        // CTA strictly displays VND, NEVER "Pay $140"
        expect(find.text('Pay 3.500.000 ₫ via VNPAY'), findsOneWidget);

        // FX-24: Simulate live background FX update (USD jumps to 0.00005 -> $175.00)
        fxRepo.nextSnapshot = _buildTestFixtureSnapshot(
          usdRate: '0.00005',
          krwRate: '0.060',
        );
        await capturedRef
            .read(exchangeRatesProvider.notifier)
            .refreshIfNeeded(force: true);
        await tester.pump();

        // Checkout reference stays FROZEN at $140.00 and payable VND stays 3.500.000 VND!
        expect(find.text('Estimated price: ≈ \$140.00'), findsOneWidget);
        expect(find.text('Estimated price: ≈ \$175.00'), findsNothing);
        expect(find.text('Total payable: 3.500.000 VND'), findsOneWidget);

        // FX-18: Switch locale to Korean ('ko') -> uses frozen KRW rate (0.054 -> ₩189,000, not 0.060)
        await capturedRef.read(localeProvider.notifier).setLocale('ko');
        await tester.pump();

        expect(find.text('예상 금액: 약 ₩189,000'), findsOneWidget);
        expect(find.text('실제 결제 총액: 3.500.000 VND'), findsOneWidget);
        expect(find.text('VNPAY로 3.500.000 ₫ 결제'), findsOneWidget);

        // Submit payment -> gateway receives bookingId='901', method='vnpay', pure VND URL!
        await tester.ensureVisible(
          find.byKey(const Key('checkout_pay_cta_button')),
        );
        await tester.tap(find.byKey(const Key('checkout_pay_cta_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(bookingRepo.createPaymentCalls, 1);
        expect(bookingRepo.lastPaymentBookingId, '901');
        expect(bookingRepo.lastPaymentMethod, 'vnpay');
        expect(launchedGatewayUri, isNotNull);
        expect(
          find.text('RESULT:901:vnpay:pending:3500000'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'FX-19 & FX-29: PaymentResultScreen shows authoritative VND amount, foreign settlement note, and never trusts unverified status=paid query',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sp = await SharedPreferences.getInstance();
        final prefs = PreferencesService(sp);
        await prefs.setLocale('en');

        final fxRepo = _FakeExchangeRateRepository(
          nextSnapshot: _buildTestFixtureSnapshot(),
        );
        // Backend still reports pending_payment / pending even though URL query claims status=paid (FX-29)
        final bookingRepo = _FakeBookingRepository(
          booking: _buildSampleBooking(
            id: '901',
            totalAmount: 3500000,
            status: 'pending_payment',
            paymentStatus: 'unpaid',
          ),
          paymentRecord: const PaymentSessionResult(
            paymentId: 'pay_555',
            bookingId: '901',
            method: 'vnpay',
            paymentStatus: 'pending',
            amount: 3500000,
            currency: 'VND',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              preferencesServiceProvider.overrideWithValue(prefs),
              exchangeRateRepositoryProvider.overrideWithValue(fxRepo),
              bookingRepositoryProvider.overrideWithValue(bookingRepo),
              authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
              currencyClockProvider.overrideWithValue(() => _fixedNowUtc),
            ],
            child: _buildTestRouterApp(
              home: const PaymentResultScreen(
                bookingId: '901',
                paymentId: 'pay_555',
                status: 'paid',
                method: 'vnpay',
                amount: 3500000,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // FX-29: Must NOT display fake success before IPN confirms
        expect(find.text('Giao dịch đang chờ xác nhận'), findsOneWidget);
        expect(find.text('Thanh toán đặt phòng thành công!'), findsNothing);

        // FX-19: Receipt displays authoritative VND + English settlement notice
        expect(find.text('3.500.000 ₫'), findsOneWidget);
        expect(
          find.text(
            'You will be charged in VND. Your bank may apply exchange rates and fees.',
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'FX-22, FX-23, FX-30: Zero RenderFlex overflow across 320/360/390/428px & textScale 1.3x/2.0x, plus clean feature-flag rollback to VND',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sp = await SharedPreferences.getInstance();
        final prefs = PreferencesService(sp);
        await prefs.setLocale('ko');
        await ExchangeRateCache(prefs).writePreference(
          const CurrencyPreference.manual(AppCurrency.krw),
        );

        final fxRepo = _FakeExchangeRateRepository(
          nextSnapshot: _buildTestFixtureSnapshot(),
        );
        final bookingRepo = _FakeBookingRepository();

        for (final width in <double>[320, 360, 390, 428]) {
          for (final scale in <double>[1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              ProviderScope(
                key: ValueKey<String>('scope_${width}_$scale'),
                overrides: <Override>[
                  preferencesServiceProvider.overrideWithValue(prefs),
                  exchangeRateRepositoryProvider.overrideWithValue(fxRepo),
                  bookingRepositoryProvider.overrideWithValue(bookingRepo),
                  authRepositoryProvider
                      .overrideWithValue(_FakeAuthRepository()),
                  currencyClockProvider.overrideWithValue(() => _fixedNowUtc),
                ],
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 900),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: _buildTestRouterApp(
                    home: const GuestPaymentScreen(bookingId: '901'),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));

            expect(
              tester.takeException(),
              isNull,
              reason: 'No overflow allowed at width=$width, scale=$scale',
            );
            expect(
              find.byKey(const Key('checkout_pay_cta_button')),
              findsOneWidget,
            );

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          }
        }

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // FX-30: Disable feature flag -> entire Guest UI & Checkout cleanly revert to VND
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey<String>('scope_fx_disabled'),
            overrides: <Override>[
              preferencesServiceProvider.overrideWithValue(prefs),
              exchangeRateRepositoryProvider.overrideWithValue(fxRepo),
              bookingRepositoryProvider.overrideWithValue(bookingRepo),
              authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
              currencyClockProvider.overrideWithValue(() => _fixedNowUtc),
              fxFeatureEnabledProvider.overrideWithValue(false),
            ],
            child: _buildTestRouterApp(
              home: const GuestPaymentScreen(bookingId: '901'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
            find.byKey(const Key('checkout_fx_reference_box')), findsNothing);
        expect(
            find.byKey(const Key('checkout_payable_vnd_box')), findsOneWidget);
        expect(find.text('VNPAY로 3.500.000 ₫ 결제'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}
