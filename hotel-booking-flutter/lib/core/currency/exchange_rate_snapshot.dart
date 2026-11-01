import 'dart:convert';
import 'app_currency.dart';
import 'money_converter.dart';

/// Immutable, validated snapshot of display-only exchange rates (`1 VND -> USD / KRW`).
///
/// Enforces data-age & sanity rules:
/// - Within [defaultFreshMaxAge] (48h) of [sourceUpdatedAt]: fresh (`isStaleAt == false`).
/// - Between 48h and [defaultMaxStaleAge] (7d): usable as stale (`isStaleAt == true`).
/// - Beyond 7d: expired (`isExpiredAt == true`) -> MUST NOT be used; fallback to VND.
class ExchangeRateSnapshot {
  static const Duration defaultFreshMaxAge = Duration(hours: 48);
  static const Duration defaultMaxStaleAge = Duration(days: 7);
  static const Duration defaultRefreshInterval = Duration(hours: 3);

  // Sanity bounds for 1 VND -> target currency (rejects inverted rates, zeros, or corrupt data):
  // 1 USD between 5,000 VND (0.0002) and 100,000 VND (0.00001)
  static final ExactDecimal _minUsdPerVnd = ExactDecimal.parse('0.00001');
  static final ExactDecimal _maxUsdPerVnd = ExactDecimal.parse('0.0002');
  // 1 KRW between 4 VND (0.25) and 100 VND (0.01)
  static final ExactDecimal _minKrwPerVnd = ExactDecimal.parse('0.01');
  static final ExactDecimal _maxKrwPerVnd = ExactDecimal.parse('0.25');

  final String schemaVersion;
  final String baseCurrency;
  final String usdRateDecimal;
  final String krwRateDecimal;
  final String source;
  final DateTime sourceUpdatedAt;
  final DateTime fetchedAt;
  final bool serverMarkedStale;
  final bool displayOnly;

  const ExchangeRateSnapshot._({
    required this.schemaVersion,
    required this.baseCurrency,
    required this.usdRateDecimal,
    required this.krwRateDecimal,
    required this.source,
    required this.sourceUpdatedAt,
    required this.fetchedAt,
    required this.serverMarkedStale,
    required this.displayOnly,
  });

  /// Constructs and validates an [ExchangeRateSnapshot], throwing [FormatException]
  /// if any required field, timestamp, or rate fails integrity checks.
  factory ExchangeRateSnapshot.validated({
    String schemaVersion = '1.0',
    String baseCurrency = 'VND',
    required String usdRateDecimal,
    required String krwRateDecimal,
    required String source,
    required DateTime sourceUpdatedAt,
    required DateTime fetchedAt,
    bool serverMarkedStale = false,
    bool displayOnly = true,
    DateTime? validationNow,
  }) {
    if (baseCurrency.trim().toUpperCase() != 'VND') {
      throw const FormatException(
          'ExchangeRateSnapshot baseCurrency must be VND');
    }
    if (!displayOnly) {
      throw const FormatException(
          'ExchangeRateSnapshot must be displayOnly=true');
    }
    final cleanSource = source.trim();
    if (cleanSource.isEmpty) {
      throw const FormatException(
          'ExchangeRateSnapshot source must not be empty');
    }

    final usdDec = ExactDecimal.tryParse(usdRateDecimal);
    final krwDec = ExactDecimal.tryParse(krwRateDecimal);
    if (usdDec == null || !usdDec.isStrictlyPositive) {
      throw const FormatException('Invalid or non-positive USD exchange rate');
    }
    if (krwDec == null || !krwDec.isStrictlyPositive) {
      throw const FormatException('Invalid or non-positive KRW exchange rate');
    }

    if (usdDec.compareTo(_minUsdPerVnd) < 0 ||
        usdDec.compareTo(_maxUsdPerVnd) > 0) {
      throw FormatException(
        'Anomalous USD rate outside sane VND bounds: ${usdDec.toPlainDecimalString()}',
      );
    }
    if (krwDec.compareTo(_minKrwPerVnd) < 0 ||
        krwDec.compareTo(_maxKrwPerVnd) > 0) {
      throw FormatException(
        'Anomalous KRW rate outside sane VND bounds: ${krwDec.toPlainDecimalString()}',
      );
    }

    final srcUtc = sourceUpdatedAt.toUtc();
    final fetchUtc = fetchedAt.toUtc();
    final refNow = (validationNow ?? DateTime.now()).toUtc();

    // Reject impossible timestamps (e.g., year < 2020 or > 48h in the future)
    if (srcUtc.year < 2020 ||
        srcUtc.isAfter(refNow.add(const Duration(hours: 48)))) {
      throw FormatException(
        'Unreasonable sourceUpdatedAt timestamp: ${srcUtc.toIso8601String()}',
      );
    }
    if (fetchUtc.year < 2020 ||
        fetchUtc.isAfter(refNow.add(const Duration(hours: 48)))) {
      throw FormatException(
        'Unreasonable fetchedAt timestamp: ${fetchUtc.toIso8601String()}',
      );
    }

    return ExchangeRateSnapshot._(
      schemaVersion:
          schemaVersion.trim().isEmpty ? '1.0' : schemaVersion.trim(),
      baseCurrency: 'VND',
      usdRateDecimal: usdDec.toPlainDecimalString(),
      krwRateDecimal: krwDec.toPlainDecimalString(),
      source: cleanSource,
      sourceUpdatedAt: srcUtc,
      fetchedAt: fetchUtc,
      serverMarkedStale: serverMarkedStale,
      displayOnly: true,
    );
  }

  /// Returns the decimal rate string for [currency] (`"1"` for VND).
  String rateDecimalFor(AppCurrency currency) {
    switch (currency) {
      case AppCurrency.vnd:
        return '1';
      case AppCurrency.usd:
        return usdRateDecimal;
      case AppCurrency.krw:
        return krwRateDecimal;
    }
  }

  /// True when the snapshot is older than [maxAge] (default 7 days) from [sourceUpdatedAt]
  /// and MUST NOT be used for foreign currency display.
  bool isExpiredAt(
    DateTime now, {
    Duration maxAge = defaultMaxStaleAge,
  }) {
    final age = now.toUtc().difference(sourceUpdatedAt);
    return age > maxAge;
  }

  /// True when the snapshot is usable (not expired) at [now].
  bool isUsableAt(
    DateTime now, {
    Duration maxAge = defaultMaxStaleAge,
  }) {
    return !isExpiredAt(now, maxAge: maxAge);
  }

  /// True when the snapshot is older than [freshAge] (default 48h) or marked stale by server.
  bool isStaleAt(
    DateTime now, {
    Duration freshAge = defaultFreshMaxAge,
  }) {
    if (serverMarkedStale) return true;
    final age = now.toUtc().difference(sourceUpdatedAt);
    return age > freshAge;
  }

  /// True when the client should trigger a non-blocking background refresh.
  bool needsBackgroundRefresh(
    DateTime now, {
    Duration refreshInterval = defaultRefreshInterval,
  }) {
    return now.toUtc().difference(fetchedAt) >= refreshInterval;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'baseCurrency': baseCurrency,
        'rates': <String, String>{
          'VND': '1',
          'USD': usdRateDecimal,
          'KRW': krwRateDecimal,
        },
        'source': source,
        'sourceUpdatedAt': sourceUpdatedAt.toIso8601String(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'isStale': serverMarkedStale,
        'displayOnly': displayOnly,
      };

  String toStorageString() => jsonEncode(toJson());

  /// Parses backend API payload (`{ success: true, data: {...} }` or direct map).
  static ExchangeRateSnapshot? tryParseDynamic(
    dynamic raw, {
    DateTime? validationNow,
  }) {
    if (raw == null) return null;
    try {
      Map<String, dynamic>? map;
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) return null;
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } else if (raw is Map) {
        map = Map<String, dynamic>.from(raw);
      }
      if (map == null) return null;

      // Unwrap standard backend envelope `{ success: true, data: { ... } }` if present
      if (map['data'] is Map && map['rates'] == null) {
        if (map['success'] == false) return null;
        map = Map<String, dynamic>.from(map['data'] as Map);
      }

      final ratesRaw = map['rates'];
      if (ratesRaw is! Map) return null;
      final rates = Map<String, dynamic>.from(ratesRaw);

      final vndRaw = rates['VND'];
      if (vndRaw != null) {
        final vndDec = ExactDecimal.tryParse(vndRaw.toString());
        if (vndDec == null || vndDec.toPlainDecimalString() != '1') {
          return null;
        }
      }

      final usdRaw = rates['USD'];
      final krwRaw = rates['KRW'];
      if (usdRaw == null || krwRaw == null) return null;
      if (usdRaw is bool || krwRaw is bool) return null;

      final srcUpdatedStr = map['sourceUpdatedAt']?.toString().trim() ?? '';
      final fetchedStr = map['fetchedAt']?.toString().trim() ?? '';
      final parsedSrcUpdated = DateTime.tryParse(srcUpdatedStr);
      final parsedFetched = DateTime.tryParse(fetchedStr);
      if (parsedSrcUpdated == null || parsedFetched == null) {
        return null;
      }

      final rawDisplayOnly = map['displayOnly'];
      if (rawDisplayOnly is bool && !rawDisplayOnly) {
        return null;
      }

      return ExchangeRateSnapshot.validated(
        schemaVersion: (map['schemaVersion'] ?? '1.0').toString(),
        baseCurrency: (map['baseCurrency'] ?? '').toString(),
        usdRateDecimal: usdRaw.toString(),
        krwRateDecimal: krwRaw.toString(),
        source: (map['source'] ?? '').toString(),
        sourceUpdatedAt: parsedSrcUpdated,
        fetchedAt: parsedFetched,
        serverMarkedStale: map['isStale'] == true,
        displayOnly: true,
        validationNow: validationNow,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExchangeRateSnapshot &&
        other.schemaVersion == schemaVersion &&
        other.baseCurrency == baseCurrency &&
        other.usdRateDecimal == usdRateDecimal &&
        other.krwRateDecimal == krwRateDecimal &&
        other.source == source &&
        other.sourceUpdatedAt == sourceUpdatedAt &&
        other.fetchedAt == fetchedAt &&
        other.serverMarkedStale == serverMarkedStale &&
        other.displayOnly == displayOnly;
  }

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        baseCurrency,
        usdRateDecimal,
        krwRateDecimal,
        source,
        sourceUpdatedAt,
        fetchedAt,
        serverMarkedStale,
        displayOnly,
      );
}
