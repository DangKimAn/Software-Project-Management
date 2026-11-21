import '../storage/preferences_service.dart';
import 'currency_preference.dart';
import 'exchange_rate_snapshot.dart';

/// Local persistence adapter for [CurrencyPreference] and [ExchangeRateSnapshot]
/// backed by [PreferencesService].
/// Bộ chuyển đổi lưu trữ cục bộ cho tùy chọn tiền tệ `CurrencyPreference` và bản chụp tỷ giá `ExchangeRateSnapshot` thông qua `PreferencesService`.
class ExchangeRateCache {
  final PreferencesService _prefs;

  const ExchangeRateCache(this._prefs);

  /// Đọc và khôi phục an toàn tùy chọn tiền tệ `CurrencyPreference` của khách từ bộ nhớ cục bộ.
  CurrencyPreference readPreference() {
    return CurrencyPreference.fromStorageString(
      _prefs.getCurrencyPreferenceRaw(),
    );
  }

  /// Ghi bền vững tùy chọn tiền tệ `preference` xuống bộ nhớ cục bộ dưới dạng chuỗi JSON.
  Future<void> writePreference(CurrencyPreference preference) async {
    await _prefs.setCurrencyPreferenceRaw(preference.toStorageString());
  }

  /// Reads the last validated snapshot from local storage.
  /// If stored JSON is corrupted or invalid, returns `null` safely without throwing.
  /// Đọc và kiểm định lại bản chụp tỷ giá từ bộ nhớ cục bộ; trả về `null` an toàn nếu dữ liệu trống hoặc hỏng.
  ExchangeRateSnapshot? readSnapshot({DateTime? now}) {
    final raw = _prefs.getExchangeRateSnapshotRaw();
    return ExchangeRateSnapshot.tryParseDynamic(raw, validationNow: now);
  }

  /// Reads the cached snapshot ONLY if it is still within the allowed 7-day maximum age.
  /// Đọc bản chụp tỷ giá đã lưu chỉ khi bản chụp chưa vượt quá giới hạn tuổi thọ tối đa 7 ngày tại thời điểm `now`.
  ExchangeRateSnapshot? readUsableSnapshot({DateTime? now}) {
    final evalNow = (now ?? DateTime.now()).toUtc();
    final snapshot = readSnapshot(now: evalNow);
    if (snapshot == null || snapshot.isExpiredAt(evalNow)) {
      return null;
    }
    return snapshot;
  }

  /// Lưu bền vững bản chụp tỷ giá đã xác thực `snapshot` xuống bộ nhớ cục bộ.
  Future<void> writeSnapshot(ExchangeRateSnapshot snapshot) async {
    await _prefs.setExchangeRateSnapshotRaw(snapshot.toStorageString());
  }
}
