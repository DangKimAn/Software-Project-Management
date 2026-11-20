import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/di/providers.dart';
import '../config/app_config.dart';
import '../errors/app_failure.dart';

/// Feature flag provider (`--dart-define=ENABLE_MULTI_CURRENCY_DISPLAY`, default `true`).
/// Overridable in tests (`FX-30`) or emergency rollback.
/// Provider cờ bật/tắt tính năng hiển thị đa tiền tệ (`ENABLE_MULTI_CURRENCY_DISPLAY`), cho phép ghi đè trong kiểm thử hoặc thu hồi khẩn cấp.
final fxFeatureEnabledProvider = Provider<bool>((ref) {
  return AppConfig.enableMultiCurrencyDisplay;
});

/// Injectable clock for deterministic data-age & cooldown tests.
/// Provider đồng hồ thời gian có thể tiêm phụ thuộc phục vụ kiểm thử tất định tuổi dữ liệu tỷ giá và thời gian chờ thử lại.
final currencyClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// Provider cung cấp bộ nhớ đệm cục bộ `ExchangeRateCache` cho tùy chọn tiền tệ và bản chụp tỷ giá.
final exchangeRateCacheProvider = Provider<ExchangeRateCache>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return ExchangeRateCache(prefs);
});

/// Provider cung cấp kho lưu trữ `ExchangeRateRepository` tải tỷ giá nội bộ từ máy chủ và đồng bộ xuống bộ nhớ đệm.
final exchangeRateRepositoryProvider = Provider<ExchangeRateRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final cache = ref.watch(exchangeRateCacheProvider);
  return ExchangeRateRepositoryImpl(
    dioClient: dioClient,
    cache: cache,
  );
});

/// Manages `automatic` (follow language) vs `manual` (pinned currency) mode.
/// Bộ quản lý trạng thái chế độ tiền tệ của Khách (`automatic` bám theo ngôn ngữ hoặc `manual` ghim cố định) đồng bộ với bộ nhớ cục bộ.
class CurrencyPreferenceNotifier extends StateNotifier<CurrencyPreference> {
  final ExchangeRateCache _cache;

  CurrencyPreferenceNotifier(this._cache) : super(_cache.readPreference());

  /// Chuyển về chế độ tiền tệ tự động bám theo ngôn ngữ giao diện và lưu bền vững nếu trạng thái thay đổi.
  Future<void> setAutomatic() async {
    const next = CurrencyPreference.automatic();
    if (state == next) return;
    state = next;
    await _cache.writePreference(next);
  }

  /// Ghim thủ công đơn vị tiền tệ hiển thị `currency` và lưu bền vững vào bộ nhớ cục bộ.
  Future<void> setManualCurrency(AppCurrency currency) async {
    final next = CurrencyPreference.manual(currency);
    if (state == next) return;
    state = next;
    await _cache.writePreference(next);
  }
}

/// Provider quản lý trạng thái tùy chọn tiền tệ `CurrencyPreference` của người dùng.
final currencyPreferenceProvider =
    StateNotifierProvider<CurrencyPreferenceNotifier, CurrencyPreference>(
        (ref) {
  final cache = ref.watch(exchangeRateCacheProvider);
  return CurrencyPreferenceNotifier(cache);
});

/// Exposes the manual override currency if the guest explicitly selected one,
/// or `null` when following active language (`automatic` mode).
/// Provider trả về đơn vị tiền tệ do khách ghim thủ công, hoặc `null` khi đang ở chế độ tự động theo ngôn ngữ.
final manualCurrencyOverrideProvider = Provider<AppCurrency?>((ref) {
  return ref.watch(currencyPreferenceProvider).manualCurrencyOverride;
});

/// Synchronously derives the effective Guest display currency without race conditions:
/// `effectiveCurrency = manualCurrencyOverride ?? AppCurrency.defaultForLocale(locale)`
/// Provider suy diễn đồng bộ đơn vị tiền tệ hiển thị hiệu lực từ `localeProvider`, `currencyPreferenceProvider` và cờ tính năng.
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
/// Trạng thái bất biến quản lý bản chụp tỷ giá hiện hành, cờ đang tải mới, lỗi gần nhất và thời điểm mở khóa thử lại (`nextRetryAfterUtc`).
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
  /// Trả về `snapshot` chỉ khi bản chụp tồn tại và chưa vượt quá tuổi thọ tối đa 7 ngày tại thời điểm `now`.
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
/// Bộ điều phối làm mới tỷ giá ngầm với cơ chế hợp nhất một luồng duy nhất (Single-Flight) và giãn cách lũy thừa chống bão thử lại (`FX-25`).
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
  /// Giải thuật làm mới tỷ giá ngầm hợp nhất đơn luồng (`refreshIfNeeded`):
  /// 1. Nếu tính năng đa tiền tệ tắt thì trả về ngay bản chụp khả dụng hiện tại.
  /// 2. Khử trùng lặp Single-Flight: Nếu đã có tiến trình `_inFlightRefresh` đang chạy thì dùng chung chính `Future` đó thay vì phát thêm yêu cầu mạng.
  /// 3. Khi `force == false`: Tôn trọng khoảng lùi `nextRetryAfterUtc` sau lỗi và bỏ qua gọi mạng nếu bản chụp hiện tại chưa tới chu kỳ làm mới 3 giờ (`!needsBackgroundRefresh`).
  /// 4. Khởi chạy `_executeRefresh()`, gắn vào `_inFlightRefresh` và tự động dọn khóa trong `whenComplete`.
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

  /// Thực thi tải tỷ giá mới từ kho lưu trữ; nếu thất bại vẫn giữ lại bản chụp cũ còn hạn (dưới 7 ngày) và thiết lập thời gian chờ thử lại tiếp theo.
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

  /// Giải thuật tính thời gian chờ thử lại theo cấp số nhân (`Exponential Backoff`):
  /// - Nếu gặp lỗi giới hạn tần suất HTTP 429 (`RateLimitFailure`) có `retryAfterSeconds`: kẹp giá trị trong đoạn `[30, 3600]` giây.
  /// - Với các lỗi mạng/máy chủ tạm thời khác: tính `30 * 2^clamp(consecutiveFailures - 1, 0, 5)` và kẹp trong đoạn `[30, 600]` giây.
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

/// Provider quản lý trạng thái tỷ giá và tự động kích hoạt làm mới ngầm mỗi khi khách chuyển sang ngoại tệ (`USD` hoặc `KRW`).
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
/// Provider cung cấp bộ định dạng tiền tệ trung tâm `MoneyFormatter`, chỉ kích hoạt dựng lại widget khi ngôn ngữ, tiền tệ hiệu lực hoặc bản chụp tỷ giá khả dụng thực sự thay đổi.
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
