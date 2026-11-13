import '../storage/preferences_service.dart';
import 'currency_preference.dart';
import 'exchange_rate_snapshot.dart';

/// Local persistence adapter for [CurrencyPreference] and [ExchangeRateSnapshot]
/// backed by [PreferencesService].
class ExchangeRateCache {
  final PreferencesService _prefs;

  const ExchangeRateCache(this._prefs);

  CurrencyPreference readPreference() {
    return CurrencyPreference.fromStorageString(
      _prefs.getCurrencyPreferenceRaw(),
    );
  }

  Future<void> writePreference(CurrencyPreference preference) async {
    await _prefs.setCurrencyPreferenceRaw(preference.toStorageString());
  }

  /// Reads the last validated snapshot from local storage.
  /// If stored JSON is corrupted or invalid, returns `null` safely without throwing.
  ExchangeRateSnapshot? readSnapshot({DateTime? now}) {
    final raw = _prefs.getExchangeRateSnapshotRaw();
    return ExchangeRateSnapshot.tryParseDynamic(raw, validationNow: now);
  }

  /// Reads the cached snapshot ONLY if it is still within the allowed 7-day maximum age.
  ExchangeRateSnapshot? readUsableSnapshot({DateTime? now}) {
    final evalNow = (now ?? DateTime.now()).toUtc();
    final snapshot = readSnapshot(now: evalNow);
    if (snapshot == null || snapshot.isExpiredAt(evalNow)) {
      return null;
    }
    return snapshot;
  }

  Future<void> writeSnapshot(ExchangeRateSnapshot snapshot) async {
    await _prefs.setExchangeRateSnapshotRaw(snapshot.toStorageString());
  }
}
