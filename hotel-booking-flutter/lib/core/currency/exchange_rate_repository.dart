import 'package:dio/dio.dart';
import '../errors/app_failure.dart';
import '../network/dio_client.dart';
import 'exchange_rate_cache.dart';
import 'exchange_rate_snapshot.dart';

abstract class ExchangeRateRepository {
  ExchangeRateSnapshot? getCachedSnapshot({DateTime? now});

  Future<ExchangeRateSnapshot> fetchLatestRates({DateTime? now});
}

/// Fetches verified display-only FX rates exclusively from the internal Backend API
/// (`GET /api/v1/exchange-rates`) and persists valid snapshots into [ExchangeRateCache].
///
/// Never calls external third-party FX APIs directly from the mobile client.
class ExchangeRateRepositoryImpl implements ExchangeRateRepository {
  static const String endpointPath = '/api/v1/exchange-rates';

  final DioClient _dioClient;
  final ExchangeRateCache _cache;

  const ExchangeRateRepositoryImpl({
    required DioClient dioClient,
    required ExchangeRateCache cache,
  })  : _dioClient = dioClient,
        _cache = cache;

  @override
  ExchangeRateSnapshot? getCachedSnapshot({DateTime? now}) {
    return _cache.readUsableSnapshot(now: now);
  }

  @override
  Future<ExchangeRateSnapshot> fetchLatestRates({DateTime? now}) async {
    final evalNow = (now ?? DateTime.now()).toUtc();
    final Response<dynamic> response;
    try {
      response = await _dioClient.dio.get<dynamic>(
        endpointPath,
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
          extra: const <String, Object>{
            'publicEndpoint': true,
            'skipAuthRefresh': true,
            'skipAuthToken': true,
            'skipSessionCancel': true,
            'disableRetry': true,
          },
        ),
      );
    } on DioException catch (e) {
      throw DioClient.handleError(e);
    }

    final parsed = ExchangeRateSnapshot.tryParseDynamic(
      response.data,
      validationNow: evalNow,
    );
    if (parsed == null) {
      throw const ValidationFailure(
        'Dữ liệu tỷ giá từ máy chủ không hợp lệ.',
        code: 'INVALID_FX_PAYLOAD',
      );
    }
    if (parsed.isExpiredAt(evalNow)) {
      throw const ValidationFailure(
        'Dữ liệu tỷ giá đã quá hạn sử dụng cho phép.',
        code: 'EXPIRED_FX_PAYLOAD',
      );
    }

    await _cache.writeSnapshot(parsed);
    return parsed;
  }
}
