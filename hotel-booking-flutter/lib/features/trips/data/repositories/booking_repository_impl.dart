import 'package:dio/dio.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';

/// Triển khai cụ thể của `BookingRepository` giao tiếp với các điểm cuối REST API
/// `/api/bookings`, `/api/coupons/validate` và `/api/payments`.
///
/// Chịu trách nhiệm chuẩn hóa dữ liệu đặt phòng đơn lẻ/hàng loạt, bóc tách lỗi chi tiết theo từng dòng
/// trong giao dịch lô (`BulkBookingException`), kiểm tra mã giảm giá, khởi tạo phiên thanh toán trực tuyến
/// (VNPay / MoMo) và đối soát trạng thái giao dịch.
class BookingRepositoryImpl implements BookingRepository {
  final dynamic _client;

  /// Khởi tạo `BookingRepositoryImpl` với đối tượng kết nối HTTP (`Dio` hoặc `DioClient`).
  const BookingRepositoryImpl(this._client);

  Dio get _dio => _client is Dio ? _client : (_client as dynamic).dio as Dio;

  // Giải thuật mở khung bao phản hồi chuẩn `{ success, data, message, code }` từ Backend API.
  static dynamic _unwrapEnvelope(dynamic responseBody) {
    if (responseBody is Map<String, dynamic>) {
      if (responseBody['success'] == false) {
        final msg = responseBody['message']?.toString() ??
            'Không thể thực hiện yêu cầu.';
        final code = responseBody['code']?.toString() ?? 'API_ERROR';
        throw ValidationFailure(msg,
            code: code,
            details: responseBody['details'] ?? responseBody['errors']);
      }
      if (responseBody.containsKey('data')) {
        return responseBody['data'];
      }
    }
    return responseBody;
  }

  static AppFailure _handleError(dynamic error) {
    if (error is AppFailure) return error;
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final rawData = error.response?.data;
      final mapData =
          rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};
      final serverMessage = mapData['message']?.toString();
      if (statusCode == 401 || statusCode == 403) {
        return AuthFailure(
          serverMessage ?? 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.',
          mapData['code']?.toString() ?? 'HTTP_$statusCode',
          statusCode ?? 401,
        );
      }
      if (statusCode == 404) {
        return NotFoundFailure(
          serverMessage ?? 'Không tìm thấy dữ liệu yêu cầu.',
        );
      }
      if (statusCode == 409) {
        return ConflictFailure(
          serverMessage ?? 'Dữ liệu xung đột hoặc đã được xử lý.',
        );
      }
      if (statusCode == 400 || statusCode == 422) {
        return ValidationFailure(
          serverMessage ?? 'Thông tin gửi lên không hợp lệ.',
          statusCode: statusCode,
        );
      }
      if (statusCode != null) {
        return ServerFailure(
          serverMessage ?? 'Lỗi máy chủ ($statusCode). Vui lòng thử lại sau.',
          statusCode: statusCode,
        );
      }
      return NetworkFailure(
        error.message ?? 'Không thể kết nối đến máy chủ.',
      );
    }
    return UnknownFailure(error.toString());
  }

  /// Truy vấn toàn bộ hoặc một trang lịch sử đặt phòng của khách hàng từ `GET /api/bookings/mine`.
  @override
  Future<List<Booking>> getMyBookings({
    String? status,
    int? page,
    int? limit,
  }) async {
    // Giải thuật phân trang toàn diện lịch sử đặt phòng của khách:
    // Khi không chỉ định `page` cố định, lặp tuần tự từ `page = 1` đến `totalPages`
    // với `limit = 50` và trần an toàn `maxPages = 20` để khách có >20 đơn không bị mất lịch sử.
    // CONFLICT-RESOLVED: Bỏ giới hạn cứng `page: 1, limit: 20` gây cắt cụt lịch sử chuyến đi của khách.
    try {
      final effectiveLimit = (limit ?? 50).clamp(1, 50);

      Future<({List<Booking> items, int totalPages})> fetchSinglePage(
        int targetPage,
      ) async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/bookings/mine',
          queryParameters: {
            if (status != null && status.isNotEmpty) 'status': status,
            'page': targetPage,
            'limit': effectiveLimit,
          },
        );
        final rawBody = response.data;
        final dataObj = _unwrapEnvelope(rawBody);
        List<dynamic> items = [];
        if (dataObj is Map<String, dynamic> && dataObj['items'] is List) {
          items = dataObj['items'] as List<dynamic>;
        } else if (dataObj is List) {
          items = dataObj;
        }

        final rawTopPagination = rawBody?['pagination'];
        final paginationMap = (dataObj is Map && dataObj['pagination'] is Map)
            ? Map<String, dynamic>.from(dataObj['pagination'] as Map)
            : (rawTopPagination is Map
                ? Map<String, dynamic>.from(rawTopPagination)
                : null);

        int? totalPages = (paginationMap?['totalPages'] as num?)?.toInt() ??
            (dataObj is Map
                ? (dataObj['totalPages'] as num?)?.toInt()
                : null) ??
            (rawBody?['totalPages'] as num?)?.toInt();

        if (totalPages == null) {
          final total = (paginationMap?['total'] as num?)?.toInt() ??
              (dataObj is Map ? (dataObj['total'] as num?)?.toInt() : null) ??
              (rawBody?['total'] as num?)?.toInt();
          if (total != null && total > 0) {
            totalPages = (total + effectiveLimit - 1) ~/ effectiveLimit;
          }
        }

        final parsed = items
            .whereType<Map<String, dynamic>>()
            .map(Booking.fromJson)
            .toList();

        return (
          items: parsed,
          totalPages: (totalPages != null && totalPages > 0) ? totalPages : 1,
        );
      }

      if (page != null) {
        final single = await fetchSinglePage(page);
        return single.items;
      }

      const maxPages = 20;
      final merged = <Booking>[];
      final seenIds = <String>{};

      for (int currentPage = 1; currentPage <= maxPages; currentPage++) {
        final result = await fetchSinglePage(currentPage);
        for (final booking in result.items) {
          if (booking.id.isEmpty || seenIds.add(booking.id)) {
            merged.add(booking);
          }
        }
        if (result.items.isEmpty || currentPage >= result.totalPages) {
          break;
        }
      }

      return merged;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Tải thông tin chi tiết đơn đặt phòng theo `bookingId` qua `GET /api/bookings/:id`.
  @override
  Future<Booking?> getBookingById(String bookingId) async {
    final trimmed = bookingId.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/api/bookings/$trimmed');
      final data = _unwrapEnvelope(response.data);
      if (data is Map<String, dynamic>) {
        final bookingJson = data['booking'] is Map<String, dynamic>
            ? data['booking'] as Map<String, dynamic>
            : data;
        return Booking.fromJson(bookingJson);
      }
      return null;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Tạo mới đơn đặt phòng đơn lẻ qua `POST /api/bookings`, chuẩn hóa mã ưu đãi in hoa và số lượng khách.
  @override
  Future<Booking> createBooking({
    required String listingId,
    required String checkInDate,
    required String checkOutDate,
    required int guestsCount,
    String? specialRequests,
    String? couponCode,
  }) async {
    // Giải thuật tạo đơn đặt phòng giữ chỗ tạm thời:
    // Chuẩn hóa `listingId`, cặp ngày `checkInDate` - `checkOutDate`, truyền đồng thời `guestCount` và `guestsCount`
    // để tương thích lược đồ Backend, viết hoa `couponCode` và giải mã thực thể `Booking` kèm hạn giữ chỗ `paymentExpiresAt`.
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/bookings',
        data: {
          'listingId': int.tryParse(listingId) ?? listingId,
          'checkInDate': checkInDate,
          'checkOutDate': checkOutDate,
          'guestCount': guestsCount,
          'guestsCount': guestsCount,
          if (specialRequests != null && specialRequests.trim().isNotEmpty)
            'specialRequests': specialRequests.trim(),
          if (couponCode != null && couponCode.trim().isNotEmpty)
            'couponCode': couponCode.trim().toUpperCase(),
        },
      );
      final data = _unwrapEnvelope(response.data);
      if (data is Map<String, dynamic>) {
        final bookingJson = data['booking'] is Map<String, dynamic>
            ? data['booking'] as Map<String, dynamic>
            : data;
        return Booking.fromJson(bookingJson);
      }
      throw Exception('Phản hồi tạo đặt phòng không hợp lệ');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Khởi tạo đặt phòng hàng loạt qua `POST /api/bookings/bulk` và bóc tách lỗi chi tiết theo từng dòng khi xung đột lịch.
  @override
  Future<List<Booking>> createBulkBookings({
    required List<Map<String, dynamic>> items,
  }) async {
    // Giải thuật đặt nhiều biệt thự cùng lúc (Bulk Booking):
    // Chuẩn hóa từng mục trong `items` về định dạng `{ listingId, checkInDate, checkOutDate, guestCount, couponCode }`.
    // Nếu máy chủ trả lỗi xác thực theo đường dẫn `items[i].field`, trích xuất qua `_tryParseBulkBookingException`
    // để giao diện đánh dấu chính xác dòng biệt thự bị trùng lịch hoặc sai điều kiện mã giảm giá.
    try {
      final normalizedItems = items.map((raw) {
        final guests =
            raw['guestCount'] ?? raw['guestsCount'] ?? raw['guests'] ?? 2;
        return <String, dynamic>{
          'listingId': raw['listingId'],
          'checkInDate': raw['checkInDate'] ?? raw['checkIn'],
          'checkOutDate': raw['checkOutDate'] ?? raw['checkOut'],
          'guestCount': guests,
          if (raw['couponCode'] != null &&
              raw['couponCode'].toString().trim().isNotEmpty)
            'couponCode': raw['couponCode'].toString().trim().toUpperCase(),
        };
      }).toList();

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/bookings/bulk',
        data: {
          'items': normalizedItems,
        },
      );
      final data = _unwrapEnvelope(response.data);
      List<dynamic> rawList = [];
      if (data is Map<String, dynamic>) {
        if (data['items'] is List) {
          rawList = data['items'] as List<dynamic>;
        } else if (data['bookings'] is List) {
          rawList = data['bookings'] as List<dynamic>;
        }
      } else if (data is List) {
        rawList = data;
      }
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList();
    } on DioException catch (dioErr) {
      final parsedBulkErr = _tryParseBulkBookingException(dioErr);
      if (parsedBulkErr != null) {
        throw parsedBulkErr;
      }
      throw _handleError(dioErr);
    } catch (e) {
      if (e is BulkBookingException) rethrow;
      throw _handleError(e);
    }
  }

  // Giải thuật trích xuất lỗi theo từng mục đặt phòng hàng loạt từ biểu thức chính quy `items[index].field`.
  BulkBookingException? _tryParseBulkBookingException(DioException error) {
    final responseData = error.response?.data;
    if (responseData is! Map) return null;

    final map = Map<String, dynamic>.from(responseData);
    final errorObj = map['error'] is Map
        ? Map<String, dynamic>.from(map['error'] as Map)
        : null;
    final topMessage = (errorObj?['message'] ??
            map['message'] ??
            'Không thể đặt một hoặc nhiều chỗ nghỉ trong danh sách.')
        .toString();

    final rawDetails = errorObj?['details'] ??
        errorObj?['errors'] ??
        map['details'] ??
        map['errors'];

    final itemErrors = <BulkBookingItemError>[];
    final itemPattern = RegExp(r'items\[(\d+)\](?:\.([a-zA-Z0-9_]+))?');

    if (rawDetails is List) {
      for (final d in rawDetails) {
        if (d is Map) {
          final path = (d['path'] ?? d['field'] ?? d['param'] ?? '').toString();
          final msg = (d['msg'] ?? d['message'] ?? topMessage).toString();
          final match = itemPattern.firstMatch(path);
          if (match != null) {
            final idx = int.tryParse(match.group(1) ?? '');
            if (idx != null) {
              itemErrors.add(
                BulkBookingItemError(
                  index: idx,
                  field: match.group(2),
                  message: msg,
                ),
              );
            }
          } else if (d['index'] is num) {
            itemErrors.add(
              BulkBookingItemError(
                index: (d['index'] as num).toInt(),
                field: path.isNotEmpty ? path : null,
                message: msg,
              ),
            );
          }
        }
      }
    }

    if (itemErrors.isEmpty) {
      final msgMatch = itemPattern.firstMatch(topMessage);
      if (msgMatch != null) {
        final idx = int.tryParse(msgMatch.group(1) ?? '');
        if (idx != null) {
          itemErrors.add(
            BulkBookingItemError(
              index: idx,
              field: msgMatch.group(2),
              message: topMessage,
            ),
          );
        }
      }
    }

    if (itemErrors.isEmpty) return null;
    return BulkBookingException(
      message: topMessage,
      itemErrors: itemErrors,
    );
  }

  /// Gửi yêu cầu hủy đơn đặt phòng `bookingId` kèm lý do `reason` qua `POST /api/bookings/:id/cancel`.
  @override
  Future<void> cancelBooking({
    required String bookingId,
    required String reason,
    String? bankName,
    String? accountNumber,
    String? accountName,
  }) async {
    try {
      final data = <String, dynamic>{
        'reason': reason.trim(),
      };
      if (bankName != null && bankName.trim().isNotEmpty) {
        data['bankName'] = bankName.trim();
      }
      if (accountNumber != null && accountNumber.trim().isNotEmpty) {
        data['accountNumber'] = accountNumber.trim();
      }
      if (accountName != null && accountName.trim().isNotEmpty) {
        data['accountName'] = accountName.trim();
      }

      await _dio.post<Map<String, dynamic>>(
        '/api/bookings/$bookingId/cancel',
        data: data,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Thẩm định mã giảm giá `code` và xem trước số tiền chiết khấu qua `GET /api/coupons/validate`.
  @override
  Future<CouponValidationResult> validateCoupon({
    required String code,
    int? bookingAmount,
    int? subtotalAmount,
    String? listingId,
    String? checkInDate,
    String? checkOutDate,
    int? guestsCount,
  }) async {
    // Giải thuật thẩm định và ước tính mức giảm giá (Coupon Preview):
    // Viết hoa mã `code`, lấy giá trị đơn cơ sở `bookingAmount ?? subtotalAmount ?? 0` và gửi kèm `listingId`
    // để máy chủ kiểm tra hạn dùng, giá trị đơn tối thiểu, giới hạn lượt dùng mỗi khách và phạm vi chỗ nghỉ.
    final normalizedCode = code.trim().toUpperCase();
    final effectiveBookingAmount = bookingAmount ?? subtotalAmount ?? 0;
    final parsedListingId =
        listingId != null ? int.tryParse(listingId.trim()) : null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/coupons/validate',
        queryParameters: {
          'code': normalizedCode,
          'bookingAmount': effectiveBookingAmount,
          if (parsedListingId != null && parsedListingId > 0)
            'listingId': parsedListingId,
        },
      );
      final data = _unwrapEnvelope(response.data);
      if (data is Map<String, dynamic>) {
        return CouponValidationResult.fromJson(
          data,
          fallbackCode: normalizedCode,
        );
      }
      return CouponValidationResult(
        valid: false,
        code: normalizedCode,
        discountAmount: 0,
        reason: 'Invalid coupon response',
        message: 'Mã giảm giá không hợp lệ.',
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Lấy danh sách cổng thanh toán khả dụng (VNPay, MoMo) từ `GET /api/payments/methods`.
  @override
  Future<List<PaymentMethodAvailability>> getPaymentMethods() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/api/payments/methods');
      final data = _unwrapEnvelope(response.data);
      List<dynamic> rawMethods = [];
      if (data is Map<String, dynamic> && data['methods'] is List) {
        rawMethods = data['methods'] as List<dynamic>;
      } else if (data is List) {
        rawMethods = data;
      }
      return rawMethods
          .whereType<Map<String, dynamic>>()
          .map(PaymentMethodAvailability.fromJson)
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Khởi tạo phiên thanh toán cổng trực tuyến qua `POST /api/payments` và gộp URL chuyển hướng (`paymentUrl` / `payUrl`).
  @override
  Future<PaymentSessionResult> createPayment({
    required String bookingId,
    required String method,
    String? idempotencyKey,
  }) async {
    // Giải thuật khởi tạo phiên thanh toán trực tuyến (VNPay / MoMo):
    // Gửi `bookingId` và phương thức `method` chuẩn hóa chữ thường tới `/api/payments`,
    // hợp nhất trường `paymentUrl` / `payUrl` ở cấp ngoài vào bản ghi `payment` con để trình duyệt mở cổng thanh toán.
    try {
      final parsedBookingId = int.tryParse(bookingId.trim());
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/payments',
        data: {
          'bookingId': parsedBookingId ?? bookingId.trim(),
          'method': method.trim().toLowerCase(),
        },
      );
      final data = _unwrapEnvelope(response.data);
      if (data is Map<String, dynamic>) {
        final paymentJson = data['payment'] is Map<String, dynamic>
            ? <String, dynamic>{
                ...(data['payment'] as Map<String, dynamic>),
                if (data['paymentUrl'] != null)
                  'paymentUrl': data['paymentUrl'],
                if (data['payUrl'] != null) 'payUrl': data['payUrl'],
              }
            : data;
        return PaymentSessionResult.fromJson(paymentJson);
      }
      throw Exception('Không thể khởi tạo phiên thanh toán');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Truy vấn trạng thái phiên thanh toán theo `paymentId` qua `GET /api/payments/:id` để phục vụ thăm dò kết quả.
  @override
  Future<PaymentSessionResult?> getPaymentById(String paymentId) async {
    final trimmed = paymentId.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/api/payments/$trimmed');
      final data = _unwrapEnvelope(response.data);
      if (data is Map<String, dynamic>) {
        final paymentJson = data['payment'] is Map<String, dynamic>
            ? data['payment'] as Map<String, dynamic>
            : data;
        return PaymentSessionResult.fromJson(paymentJson);
      }
      return null;
    } catch (e) {
      throw _handleError(e);
    }
  }
}
