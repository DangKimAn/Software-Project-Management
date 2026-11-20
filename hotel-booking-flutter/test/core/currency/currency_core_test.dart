import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/core/errors/app_failure.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';

class _FakeExchangeRateRepository implements ExchangeRateRepository {
  ExchangeRateSnapshot? cached;
  int fetchCallCount = 0;
  Future<ExchangeRateSnapshot> Function(DateTime? now)? onFetch;

  _FakeExchangeRateRepository({
    this.cached,
    this.onFetch,
  });

  @override
  ExchangeRateSnapshot? getCachedSnapshot({DateTime? now}) {
    final evalNow = (now ?? DateTime.now()).toUtc();
    if (cached == null || cached!.isExpiredAt(evalNow)) {
      return null;
    }
    return cached;
  }

  @override
  Future<ExchangeRateSnapshot> fetchLatestRates({DateTime? now}) async {
    fetchCallCount++;
    if (onFetch != null) {
      final result = await onFetch!(now);
      cached = result;
      return result;
    }
    throw const OfflineFailure();
  }
}

void main() {
  final fixedNow = DateTime.utc(2026, 10, 31, 6, 0, 0);

  ExchangeRateSnapshot buildTestSnapshot({
    String usd = '0.000038813',
    String krw = '0.051872',
    DateTime? sourceUpdatedAt,
    DateTime? fetchedAt,
    bool serverMarkedStale = false,
  }) {
    return ExchangeRateSnapshot.validated(
      usdRateDecimal: usd,
      krwRateDecimal: krw,
      source: 'frankfurter-test-fixture',
      sourceUpdatedAt:
          sourceUpdatedAt ?? fixedNow.subtract(const Duration(hours: 2)),
      fetchedAt: fetchedAt ?? fixedNow.subtract(const Duration(minutes: 15)),
      serverMarkedStale: serverMarkedStale,
      validationNow: fixedNow,
    );
  }

  group('AppCurrency & CurrencyPreference (FX-01..FX-07)', () {
    test(
        'default locale mapping: vi -> VND, en -> USD, ko -> KRW, unknown -> VND',
        () {
      expect(AppCurrency.defaultForLocale(null), AppCurrency.vnd);
      expect(AppCurrency.defaultForLocale(''), AppCurrency.vnd);
      expect(AppCurrency.defaultForLocale('vi'), AppCurrency.vnd);
      expect(AppCurrency.defaultForLocale('vi_VN'), AppCurrency.vnd);
      expect(AppCurrency.defaultForLocale('en'), AppCurrency.usd);
      expect(AppCurrency.defaultForLocale('en-US'), AppCurrency.usd);
      expect(AppCurrency.defaultForLocale('ko'), AppCurrency.krw);
      expect(AppCurrency.defaultForLocale('ko_KR'), AppCurrency.krw);
      expect(AppCurrency.defaultForLocale('fr'), AppCurrency.vnd);
    });

    test('fresh install defaults to automatic mode and VND for vi locale', () {
      final pref = CurrencyPreference.fromStorageString(null);
      expect(pref.isAutomatic, isTrue);
      expect(pref.manualCurrencyOverride, isNull);
      expect(pref.resolveEffectiveCurrency('vi'), AppCurrency.vnd);
      expect(pref.resolveEffectiveCurrency('en'), AppCurrency.usd);
      expect(pref.resolveEffectiveCurrency('ko'), AppCurrency.krw);
    });

    test(
        'manual override stays pinned across language changes until reset to automatic',
        () {
      const manualUsd = CurrencyPreference.manual(AppCurrency.usd);
      expect(manualUsd.isManual, isTrue);
      expect(manualUsd.resolveEffectiveCurrency('vi'), AppCurrency.usd);
      expect(manualUsd.resolveEffectiveCurrency('ko'), AppCurrency.usd);

      final roundTrip =
          CurrencyPreference.fromStorageString(manualUsd.toStorageString());
      expect(roundTrip, equals(manualUsd));

      // Feature flag disabled forces VND regardless of manual override (FX-30)
      expect(
        roundTrip.resolveEffectiveCurrency('ko', featureEnabled: false),
        AppCurrency.vnd,
      );
    });

    test('corrupted or legacy storage strings migrate safely without throwing',
        () {
      expect(
        CurrencyPreference.fromStorageString('KRW'),
        equals(const CurrencyPreference.manual(AppCurrency.krw)),
      );
      expect(
        CurrencyPreference.fromStorageString('automatic'),
        equals(const CurrencyPreference.automatic()),
      );
      expect(
        CurrencyPreference.fromStorageString('{corrupted-json'),
        equals(const CurrencyPreference.automatic()),
      );
      expect(
        CurrencyPreference.fromStorageString(
            '{"mode":"manual","currency":"EUR"}'),
        equals(const CurrencyPreference.automatic()),
      );
    });
  });

  group('ExactDecimal & MoneyFormatter Precision Rules (FX-15, FX-27)', () {
    test(
        'exact BigInt decimal math avoids IEEE-754 floating-point drift and scientific notation',
        () {
      final dec = ExactDecimal.parse('3.8813e-5');
      expect(dec.toPlainDecimalString(), '0.000038813');

      final product = dec * ExactDecimal.fromInt(3500000);
      // 3,500,000 * 0.000038813 = 135.8455
      expect(product.toPlainDecimalString(), '135.8455');
      expect(product.roundHalfUpToScaledUnits(0), BigInt.from(136));
      expect(product.roundHalfUpToScaledUnits(2), BigInt.from(13585));
    });

    test(
        'rounds USD to 0 decimals on villaCard and 2 decimals on breakdown/checkoutReference',
        () {
      final snapshot = buildTestSnapshot(usd: '0.000038813', krw: '0.051872');
      final usdFormatter = MoneyFormatter(
        localeCode: 'en',
        effectiveCurrency: AppCurrency.usd,
        snapshot: snapshot,
        clock: () => fixedNow,
      );

      final card =
          usdFormatter.format(3500000, context: MoneyDisplayContext.villaCard);
      expect(card.formatted, r'≈ $136');
      expect(card.displayedCurrency, AppCurrency.usd);
      expect(card.isApproximate, isTrue);

      final breakdown =
          usdFormatter.format(3500000, context: MoneyDisplayContext.breakdown);
      expect(breakdown.formatted, r'≈ $135.85');

      final krwFormatter = MoneyFormatter(
        localeCode: 'ko',
        effectiveCurrency: AppCurrency.krw,
        snapshot: snapshot,
        clock: () => fixedNow,
      );
      // 3,500,000 * 0.051872 = 181,552
      expect(
        krwFormatter
            .format(3500000, context: MoneyDisplayContext.villaCard)
            .formatted,
        '≈ ₩181,552',
      );
      expect(
        krwFormatter
            .format(3500000, context: MoneyDisplayContext.breakdown)
            .formatted,
        '≈ ₩181,552',
      );
    });

    test('FX-27: small positive VND amounts never round down to 0 or Free', () {
      final snapshot = buildTestSnapshot(usd: '0.00004', krw: '0.05');
      final usdFormatter = MoneyFormatter(
        localeCode: 'en',
        effectiveCurrency: AppCurrency.usd,
        snapshot: snapshot,
        clock: () => fixedNow,
      );
      final krwFormatter = MoneyFormatter(
        localeCode: 'ko',
        effectiveCurrency: AppCurrency.krw,
        snapshot: snapshot,
        clock: () => fixedNow,
      );

      // 5,000 VND * 0.00004 = $0.20 -> on 0-decimal card would round to 0 without guard!
      expect(
        usdFormatter
            .format(5000, context: MoneyDisplayContext.villaCard)
            .formatted,
        r'< $1',
      );
      // 100 VND * 0.00004 = $0.004 -> on 2-decimal breakdown would round to 0.00 without guard!
      expect(
        usdFormatter
            .format(100, context: MoneyDisplayContext.breakdown)
            .formatted,
        r'< $0.01',
      );
      // 5 VND * 0.05 = ₩0.25 -> < ₩1
      expect(
        krwFormatter
            .format(5, context: MoneyDisplayContext.villaCard)
            .formatted,
        '< ₩1',
      );
      // Actual 0 VND still renders $0 / $0.00
      expect(
        usdFormatter
            .format(0, context: MoneyDisplayContext.villaCard)
            .formatted,
        r'$0',
      );
    });

    test(
        'formats negative discounts and authoritative VND settlements strictly',
        () {
      final snapshot = buildTestSnapshot(usd: '0.00004', krw: '0.05');
      final usdFormatter = MoneyFormatter(
        localeCode: 'en',
        effectiveCurrency: AppCurrency.usd,
        snapshot: snapshot,
        clock: () => fixedNow,
      );

      // 250,000 * 0.00004 = $10.00 -> "-≈ $10.00"
      expect(usdFormatter.formatDiscount(250000), r'-≈ $10.00');

      // Authoritative contexts ALWAYS render exact VND even when effectiveCurrency is USD
      expect(
        usdFormatter
            .format(3500000, context: MoneyDisplayContext.checkoutPayableVnd)
            .formatted,
        '3.500.000 ₫',
      );
      expect(
        usdFormatter
            .format(3500000, context: MoneyDisplayContext.hostOrAdmin)
            .formatted,
        '3.500.000 ₫',
      );
    });

    test(
        'FX-15: converting VND sum once avoids cumulative multi-item rounding drift',
        () {
      final snapshot = buildTestSnapshot(usd: '0.0000384', krw: '0.051872');
      final usdFormatter = MoneyFormatter(
        localeCode: 'en',
        effectiveCurrency: AppCurrency.usd,
        snapshot: snapshot,
        clock: () => fixedNow,
      );
      // Each villa = 1,000,000 VND -> 1,000,000 * 0.0000384 = $38.40 (card rounds to $38)
      // 3 villas = 3,000,000 VND -> 3,000,000 * 0.0000384 = $115.20 (NOT 3 * $38 = $114.00!)
      final singleCard =
          usdFormatter.format(1000000, context: MoneyDisplayContext.villaCard);
      expect(singleCard.formatted, r'≈ $38');

      final authoritativeSumRef = usdFormatter.format(
        3000000,
        context: MoneyDisplayContext.checkoutReference,
      );
      expect(authoritativeSumRef.formatted, r'≈ $115.20');
    });
  });

  group(
      'ExchangeRateSnapshot Validation & Data Age Policy (FX-08..FX-11, FX-26)',
      () {
    test('rejects missing, zero, negative, NaN, or out-of-bounds FX rates', () {
      expect(
        () => ExchangeRateSnapshot.validated(
          usdRateDecimal: '0',
          krwRateDecimal: '0.052',
          source: 'bad',
          sourceUpdatedAt: fixedNow,
          fetchedAt: fixedNow,
          validationNow: fixedNow,
        ),
        throwsFormatException,
      );

      // Inverted rate (25400 instead of 0.000039) must be rejected (FX-26)
      expect(
        () => ExchangeRateSnapshot.validated(
          usdRateDecimal: '25400',
          krwRateDecimal: '0.052',
          source: 'inverted',
          sourceUpdatedAt: fixedNow,
          fetchedAt: fixedNow,
          validationNow: fixedNow,
        ),
        throwsFormatException,
      );

      // Missing KRW rate in JSON returns null without crashing (FX-11)
      final parsedMissing = ExchangeRateSnapshot.tryParseDynamic({
        'success': true,
        'data': {
          'baseCurrency': 'VND',
          'rates': {'VND': '1', 'USD': '0.000039'},
          'source': 'broken',
          'sourceUpdatedAt': fixedNow.toIso8601String(),
          'fetchedAt': fixedNow.toIso8601String(),
        },
      }, validationNow: fixedNow);
      expect(parsedMissing, isNull);
    });

    test(
        'enforces <=48h fresh, 48h..7d usable stale, and >7d expired fallback to VND',
        () {
      final staleSnapshot = buildTestSnapshot(
        sourceUpdatedAt: fixedNow.subtract(const Duration(hours: 60)),
      );
      expect(staleSnapshot.isStaleAt(fixedNow), isTrue);
      expect(staleSnapshot.isExpiredAt(fixedNow), isFalse);

      final staleFormatter = MoneyFormatter(
        localeCode: 'en',
        effectiveCurrency: AppCurrency.usd,
        snapshot: staleSnapshot,
        clock: () => fixedNow,
      );
      final staleRes = staleFormatter.format(2500000);
      expect(staleRes.displayedCurrency, AppCurrency.usd);
      expect(staleRes.isUsingStaleRate, isTrue);

      final expiredSnapshot = buildTestSnapshot(
        sourceUpdatedAt: fixedNow.subtract(const Duration(days: 8)),
      );
      expect(expiredSnapshot.isExpiredAt(fixedNow), isTrue);

      final expiredFormatter = MoneyFormatter(
        localeCode: 'en',
        effectiveCurrency: AppCurrency.usd,
        snapshot: expiredSnapshot,
        clock: () => fixedNow,
      );
      final fallbackRes = expiredFormatter.format(2500000);
      expect(fallbackRes.displayedCurrency, AppCurrency.vnd);
      expect(fallbackRes.didFallbackToVnd, isTrue);
      expect(fallbackRes.formatted, '2.500.000 ₫');
    });
  });

  group('Riverpod Providers, Single-Flight & 429 Cooldown (FX-25)', () {
    test(
        'synchronously derives effectiveCurrency and coalesces concurrent refreshes',
        () async {
      final prefs = PreferencesService.inMemory();
      final completer = Completer<ExchangeRateSnapshot>();
      final repo = _FakeExchangeRateRepository(
        onFetch: (_) => completer.future,
      );

      final container = ProviderContainer(
        overrides: [
          preferencesServiceProvider.overrideWithValue(prefs),
          exchangeRateRepositoryProvider.overrideWithValue(repo),
          currencyClockProvider.overrideWithValue(() => fixedNow),
        ],
      );
      addTearDown(container.dispose);

      // Default fresh install: vi + VND -> no foreign fetch needed
      expect(container.read(localeProvider), 'vi');
      expect(container.read(effectiveCurrencyProvider), AppCurrency.vnd);
      expect(container.read(moneyFormatterProvider).format(1500000).formatted,
          '1.500.000 ₫');
      expect(repo.fetchCallCount, 0);

      // Switch locale to 'en' -> effectiveCurrency synchronously becomes USD,
      // falls back to VND while fetch is in-flight, then updates once resolved.
      await container.read(localeProvider.notifier).setLocale('en');
      expect(container.read(effectiveCurrencyProvider), AppCurrency.usd);

      // Concurrent manual refresh calls must share the single in-flight request
      final f1 =
          container.read(exchangeRatesProvider.notifier).refreshIfNeeded();
      final f2 =
          container.read(exchangeRatesProvider.notifier).refreshIfNeeded();
      expect(repo.fetchCallCount, 1);

      final resolvedSnapshot = buildTestSnapshot(usd: '0.00004', krw: '0.05');
      completer.complete(resolvedSnapshot);
      await Future.wait([f1, f2]);

      expect(
        container.read(moneyFormatterProvider).format(2500000).formatted,
        r'≈ $100',
      );

      // Rapid switching vi -> en -> ko -> vi has zero race condition
      await container.read(localeProvider.notifier).setLocale('ko');
      expect(
        container.read(moneyFormatterProvider).format(2500000).formatted,
        '≈ ₩125,000',
      );
      await container.read(localeProvider.notifier).setLocale('vi');
      expect(
        container.read(moneyFormatterProvider).format(2500000).formatted,
        '2.500.000 ₫',
      );
    });

    test(
        'FX-25: HTTP 429 RateLimitFailure activates cooldown and retains cached snapshot',
        () async {
      var now = fixedNow;
      final cachedStale = buildTestSnapshot(
        usd: '0.00004',
        krw: '0.05',
        fetchedAt: fixedNow.subtract(const Duration(hours: 4)),
      );
      final repo = _FakeExchangeRateRepository(
        cached: cachedStale,
        onFetch: (_) async {
          throw const RateLimitFailure.withRetryAfter(
            'Rate limited',
            retryAfterSeconds: 120,
          );
        },
      );

      final container = ProviderContainer(
        overrides: [
          preferencesServiceProvider
              .overrideWithValue(PreferencesService.inMemory()),
          exchangeRateRepositoryProvider.overrideWithValue(repo),
          currencyClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      // Initialize reactive currency listener (as active UI widgets do via moneyFormatterProvider)
      expect(
        container.read(moneyFormatterProvider).format(1000000).formatted,
        '1.000.000 ₫',
      );

      await container.read(localeProvider.notifier).setLocale('en');
      await Future<void>.delayed(Duration.zero);
      expect(repo.fetchCallCount, 1);

      // Retained cached snapshot still formats USD cleanly without crashing
      expect(
        container.read(moneyFormatterProvider).format(1000000).formatted,
        r'≈ $40',
      );

      // Calling refreshIfNeeded again within 120s cooldown MUST NOT hit network
      await container.read(exchangeRatesProvider.notifier).refreshIfNeeded();
      expect(repo.fetchCallCount, 1);

      // Advance clock past 120s cooldown -> next refreshIfNeeded is allowed
      now = now.add(const Duration(seconds: 125));
      await container.read(exchangeRatesProvider.notifier).refreshIfNeeded();
      expect(repo.fetchCallCount, 2);
    });
  });
}
