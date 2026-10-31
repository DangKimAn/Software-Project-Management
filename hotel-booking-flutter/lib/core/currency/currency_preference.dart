import 'dart:convert';
import 'app_currency.dart';

/// Controls whether Guest display currency tracks the active language (`automatic`)
/// or stays pinned to an explicit user choice (`manual`).
enum CurrencySelectionMode {
  automatic,
  manual,
}

/// Immutable user preference for Guest display currency.
///
/// Formula enforced across the app:
/// `effectiveCurrency = manualCurrencyOverride ?? AppCurrency.defaultForLocale(locale)`
class CurrencyPreference {
  static const int currentSchemaVersion = 1;

  final CurrencySelectionMode mode;
  final AppCurrency? _manualCurrency;

  /// Default mode on fresh install: follows active locale (`vi -> VND`).
  const CurrencyPreference.automatic()
      : mode = CurrencySelectionMode.automatic,
        _manualCurrency = null;

  /// User explicitly pinned a display currency (`VND`, `USD`, or `KRW`).
  const CurrencyPreference.manual(AppCurrency currency)
      : mode = CurrencySelectionMode.manual,
        _manualCurrency = currency;

  bool get isAutomatic => mode == CurrencySelectionMode.automatic;
  bool get isManual =>
      mode == CurrencySelectionMode.manual && _manualCurrency != null;

  /// Non-null only when [mode] is [CurrencySelectionMode.manual].
  AppCurrency? get manualCurrencyOverride =>
      mode == CurrencySelectionMode.manual ? _manualCurrency : null;

  /// Resolves the effective display currency synchronously without race conditions.
  AppCurrency resolveEffectiveCurrency(
    String localeCode, {
    bool featureEnabled = true,
  }) {
    if (!featureEnabled) {
      return AppCurrency.vnd;
    }
    return manualCurrencyOverride ?? AppCurrency.defaultForLocale(localeCode);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': currentSchemaVersion,
        'mode': mode == CurrencySelectionMode.manual ? 'manual' : 'automatic',
        if (manualCurrencyOverride != null)
          'currency': manualCurrencyOverride!.code,
      };

  String toStorageString() => jsonEncode(toJson());

  /// Safely restores or migrates stored preference data without throwing on
  /// legacy formats, partial upgrades, or corrupted strings.
  static CurrencyPreference fromStorageString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const CurrencyPreference.automatic();
    }
    final trimmed = raw.trim();

    // Forward/backward migration: plain currency code string (e.g., "KRW" or "automatic")
    if (!trimmed.startsWith('{')) {
      if (trimmed.toLowerCase() == 'automatic' ||
          trimmed.toLowerCase() == 'auto') {
        return const CurrencyPreference.automatic();
      }
      final directCurrency = AppCurrency.fromCodeOrNull(trimmed);
      if (directCurrency != null) {
        return CurrencyPreference.manual(directCurrency);
      }
      return const CurrencyPreference.automatic();
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return const CurrencyPreference.automatic();
      }
      final map = Map<String, dynamic>.from(decoded);
      final rawMode = map['mode']?.toString().trim().toLowerCase();
      final parsedCurrency = AppCurrency.fromCodeOrNull(
        (map['currency'] ?? map['manualCurrency'])?.toString(),
      );
      if (rawMode == 'manual' && parsedCurrency != null) {
        return CurrencyPreference.manual(parsedCurrency);
      }
      return const CurrencyPreference.automatic();
    } catch (_) {
      return const CurrencyPreference.automatic();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CurrencyPreference &&
        other.mode == mode &&
        other.manualCurrencyOverride == manualCurrencyOverride;
  }

  @override
  int get hashCode => Object.hash(mode, manualCurrencyOverride);
}
