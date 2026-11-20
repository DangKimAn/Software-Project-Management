import 'package:dio/dio.dart';
import '../errors/app_failure.dart';
import '../network/dio_client.dart';
import 'exchange_rate_cache.dart';
import 'exchange_rate_snapshot.dart';

/// Hợp đồng kho dữ liệu cung cấp bản chụp tỷ giá từ bộ nhớ đệm cục bộ và tải mới từ máy chủ nội bộ.
abstract class ExchangeRateRepository {
  /// Lấy nhanh bản chụp tỷ giá còn hạn sử dụng (dưới 7 ngày) từ bộ nhớ đệm cục bộ.
  ExchangeRateSnapshot? getCachedSnapshot({DateTime? now});

  /// Tải bản chụp tỷ giá mới nhất từ API nội bộ, xác thực tính toàn vẹn và lưu vào bộ nhớ đệm.
  Future<ExchangeRateSnapshot> fetchLatestRates({DateTime? now});
}

/// Fetches verified display-only FX rates exclusively from the internal Backend API
/// (`GET /api/v1/exchange-rates`) and persists valid snapshots into [ExchangeRateCache].
///
/// Never calls external third-party FX APIs directly from the mobile client.
/// Triển khai `ExchangeRateRepository` chỉ truy vấn duy nhất điểm cuối nội bộ `GET /api/v1/exchange-rates` và lưu đệm vào `ExchangeRateCache`.
///
/// Giải thuật tải và kiểm định tỷ giá (`fetchLatestRates`):
/// 1. Gọi điểm cuối công khai `/api/v1/exchange-rates` với thời gian chờ ngắn `6` giây, tắt đính kèm JWT, tắt làm mới phiên và tắt tự thử lại tầng Dio để không chặn luồng chính.
/// 2. Giải mã và kiểm tra biên hợp lệ qua `ExchangeRateSnapshot.tryParseDynamic`; ném `ValidationFailure` (`INVALID_FX_PAYLOAD`) nếu sai cấu trúc hoặc nằm ngoài ngưỡng an toàn.
/// 3. Từ chối dữ liệu quá hạn 7 ngày từ máy chủ (`EXPIRED_FX_PAYLOAD`), sau đó ghi bền vững bản chụp hợp lệ vào `ExchangeRateCache`.
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
