import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/di/providers.dart';
import '../config/app_config.dart';
import '../errors/app_failure.dart';

/// Feature flag provider (`--dart-define=ENABLE_MULTI_CURRENCY_DISPLAY`, default `true`).
/// Overridable in tests (`FX-30`) or emergency rollback.
final fxFeatureEnabledProvider = Provider<bool>((ref) {
  return AppConfig.enableMultiCurrencyDisplay;
});

/// Injectable clock for deterministic data-age & cooldown tests.
final currencyClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final exchangeRateCacheProvider = Provider<ExchangeRateCache>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return ExchangeRateCache(prefs);
});

final exchangeRateRepositoryProvider = Provider<ExchangeRateRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final cache = ref.watch(exchangeRateCacheProvider);
  return ExchangeRateRepositoryImpl(
    dioClient: dioClient,
    cache: cache,
  );
});

/// Manages `automatic` (follow language) vs `manual` (pinned currency) mode.
class CurrencyPreferenceNotifier extends StateNotifier<CurrencyPreference> {
  final ExchangeRateCache _cache;

  CurrencyPreferenceNotifier(this._cache) : super(_cache.readPreference());

  Future<void> setAutomatic() async {
    const next = CurrencyPreference.automatic();
    if (state == next) return;
    state = next;
    await _cache.writePreference(next);
  }

  Future<void> setManualCurrency(AppCurrency currency) async {
    final next = CurrencyPreference.manual(currency);
    if (state == next) return;
    state = next;
    await _cache.writePreference(next);
  }
}

final currencyPreferenceProvider =
    StateNotifierProvider<CurrencyPreferenceNotifier, CurrencyPreference>(
        (ref) {
  final cache = ref.watch(exchangeRateCacheProvider);
  return CurrencyPreferenceNotifier(cache);
});

/// Exposes the manual override currency if the guest explicitly selected one,
/// or `null` when following active language (`automatic` mode).
final manualCurrencyOverrideProvider = Provider<AppCurrency?>((ref) {
  return ref.watch(currencyPreferenceProvider).manualCurrencyOverride;
});

/// Synchronously derives the effective Guest display currency without race conditions:
/// `effectiveCurrency = manualCurrencyOverride ?? AppCurrency.defaultForLocale(locale)`
final effectiveCurrencyProvider = Provider<AppCurrency>((ref) {
  final locale = ref.watch(localeProvider);
  final preference = ref.watch(currencyPreferenceProvider);
  final featureEnabled = ref.watch(fxFeatureEnabledProvider);
  return preference.resolveEffectiveCurrency(
    locale,
    featureEnabled: featureEnabled,
  );
});

/// Immutable state for verified display-only exchange rates (`VND -> USD / KRW`).
class ExchangeRatesState {
  final ExchangeRateSnapshot? snapshot;
  final bool isRefreshing;
  final AppFailure? lastError;
  final DateTime? nextRetryAfterUtc;
  final int consecutiveFailures;

  const ExchangeRatesState({
    this.snapshot,
    this.isRefreshing = false,
    this.lastError,
    this.nextRetryAfterUtc,
    this.consecutiveFailures = 0,
  });

  /// Returns [snapshot] ONLY if it is within the maximum 7-day allowed age at [now].
  ExchangeRateSnapshot? usableSnapshotAt(DateTime now) {
    final current = snapshot;
    if (current == null || current.isExpiredAt(now)) {
      return null;
    }
    return current;
  }

  ExchangeRatesState copyWith({
    ExchangeRateSnapshot? snapshot,
    bool clearSnapshot = false,
    bool? isRefreshing,
    AppFailure? lastError,
    bool clearLastError = false,
    DateTime? nextRetryAfterUtc,
    bool clearNextRetryAfter = false,
    int? consecutiveFailures,
  }) {
    return ExchangeRatesState(
      snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      nextRetryAfterUtc: clearNextRetryAfter
          ? null
          : (nextRetryAfterUtc ?? this.nextRetryAfterUtc),
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    );
  }
}

/// Manages background FX refresh, local cache hydration, single-flight deduplication,
/// and HTTP 429 / transient error cooldowns (`FX-25`).
class ExchangeRatesNotifier extends StateNotifier<ExchangeRatesState> {
  final ExchangeRateRepository _repository;
  final DateTime Function() _clock;
  final bool _featureEnabled;

  Future<ExchangeRateSnapshot?>? _inFlightRefresh;

  ExchangeRatesNotifier({
    required ExchangeRateRepository repository,
    required DateTime Function() clock,
    bool featureEnabled = true,
  })  : _repository = repository,
        _clock = clock,
        _featureEnabled = featureEnabled,
        super(
          ExchangeRatesState(
            snapshot: repository.getCachedSnapshot(now: clock().toUtc()),
          ),
        );

  DateTime get _nowUtc => _clock().toUtc();

  ExchangeRateSnapshot? get usableSnapshot => state.usableSnapshotAt(_nowUtc);

  /// Performs a non-blocking single-flight refresh if needed.
  ///
  /// Never throws to UI callers; on failure, retains any still-usable cached snapshot
  /// and records a cooldown timestamp to prevent retry storms.
  Future<ExchangeRateSnapshot?> refreshIfNeeded({bool force = false}) {
    if (!_featureEnabled) {
      return Future<ExchangeRateSnapshot?>.value(usableSnapshot);
    }

    final existingFlight = _inFlightRefresh;
    if (existingFlight != null) {
      return existingFlight;
    }

    final now = _nowUtc;
    if (!force) {
      final cooldownUntil = state.nextRetryAfterUtc;
      if (cooldownUntil != null && now.isBefore(cooldownUntil)) {
        return Future<ExchangeRateSnapshot?>.value(state.usableSnapshotAt(now));
      }
      final current = state.usableSnapshotAt(now);
      if (current != null && !current.needsBackgroundRefresh(now)) {
        return Future<ExchangeRateSnapshot?>.value(current);
      }
    }

    final future = _executeRefresh();
    _inFlightRefresh = future;
    future.whenComplete(() {
      if (identical(_inFlightRefresh, future)) {
        _inFlightRefresh = null;
      }
    });
    return future;
  }

  Future<ExchangeRateSnapshot?> _executeRefresh() async {
    if (mounted) {
      state = state.copyWith(isRefreshing: true);
    }

    try {
      final fresh = await _repository.fetchLatestRates(now: _nowUtc);
      if (mounted) {
        state = ExchangeRatesState(
          snapshot: fresh,
          isRefreshing: false,
          lastError: null,
          nextRetryAfterUtc: null,
          consecutiveFailures: 0,
        );
      }
      return fresh;
    } catch (error) {
      final failure =
          error is AppFailure ? error : UnknownFailure(error.toString(), error);
      final now = _nowUtc;
      final nextFailures = state.consecutiveFailures + 1;
      final cooldownSeconds = _computeCooldownSeconds(failure, nextFailures);
      final retained = state.usableSnapshotAt(now);

      if (mounted) {
        state = ExchangeRatesState(
          snapshot: retained,
          isRefreshing: false,
          lastError: failure,
          nextRetryAfterUtc: now.add(Duration(seconds: cooldownSeconds)),
          consecutiveFailures: nextFailures,
        );
      }
      return retained;
    }
  }

  static int _computeCooldownSeconds(
    AppFailure failure,
    int consecutiveFailures,
  ) {
    if (failure is RateLimitFailure && failure.retryAfterSeconds != null) {
      return math.max(failure.retryAfterSeconds!, 30).clamp(30, 3600);
    }
    final shift = (consecutiveFailures - 1).clamp(0, 5);
    final backoff = 30 * (1 << shift);
    return backoff.clamp(30, 600);
  }
}

final exchangeRatesProvider =
    StateNotifierProvider<ExchangeRatesNotifier, ExchangeRatesState>((ref) {
  final repository = ref.watch(exchangeRateRepositoryProvider);
  final clock = ref.watch(currencyClockProvider);
  final featureEnabled = ref.watch(fxFeatureEnabledProvider);

  final notifier = ExchangeRatesNotifier(
    repository: repository,
    clock: clock,
    featureEnabled: featureEnabled,
  );

  // Trigger a non-blocking background fetch whenever the guest switches to a
  // foreign currency (`USD` / `KRW`) and rates are missing or due for refresh.
  ref.listen<AppCurrency>(
    effectiveCurrencyProvider,
    (previous, next) {
      if (featureEnabled && next.isForeign) {
        unawaited(notifier.refreshIfNeeded());
      }
    },
    fireImmediately: true,
  );

  return notifier;
});

/// Central reactive [MoneyFormatter] bound to active locale, effective currency,
/// and verified [ExchangeRateSnapshot].
///
/// Rebuilds widgets ONLY when locale, effective currency, feature flag, or the
/// usable FX snapshot actually changes.
final moneyFormatterProvider = Provider<MoneyFormatter>((ref) {
  final localeCode = ref.watch(localeProvider);
  final effectiveCurrency = ref.watch(effectiveCurrencyProvider);
  final featureEnabled = ref.watch(fxFeatureEnabledProvider);
  final clock = ref.watch(currencyClockProvider);
  final snapshot = ref.watch(
    exchangeRatesProvider.select((s) => s.snapshot),
  );

  final evalNow = clock().toUtc();
  final usableSnapshot =
      (snapshot != null && snapshot.isUsableAt(evalNow)) ? snapshot : null;

  return MoneyFormatter(
    localeCode: localeCode,
    effectiveCurrency: effectiveCurrency,
    snapshot: usableSnapshot,
    featureEnabled: featureEnabled,
    clock: clock,
  );
});
