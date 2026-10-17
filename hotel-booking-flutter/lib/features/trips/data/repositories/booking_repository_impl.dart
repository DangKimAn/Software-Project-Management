import 'package:dio/dio.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  final dynamic _client;

  const BookingRepositoryImpl(this._client);

  Dio get _dio => _client is Dio ? _client : (_client as dynamic).dio as Dio;

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

  @override
  Future<List<Booking>> getMyBookings({
    String? status,
    int? page,
    int? limit,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/bookings/mine',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          'page': page ?? 1,
          'limit': limit ?? 20,
        },
      );
      final dataObj = _unwrapEnvelope(response.data);
      List<dynamic> items = [];
      if (dataObj is Map<String, dynamic> && dataObj['items'] is List) {
        items = dataObj['items'] as List<dynamic>;
      } else if (dataObj is List) {
        items = dataObj;
      }

      return items
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

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

  @override
  Future<Booking> createBooking({
    required String listingId,
    required String checkInDate,
    required String checkOutDate,
    required int guestsCount,
    String? specialRequests,
    String? couponCode,
  }) async {
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

  @override
  Future<List<Booking>> createBulkBookings({
    required List<Map<String, dynamic>> items,
  }) async {
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

  @override
  Future<void> cancelBooking({
    required String bookingId,
    required String reason,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/bookings/$bookingId/cancel',
        data: {
          'reason': reason.trim(),
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

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

  @override
  Future<PaymentSessionResult> createPayment({
    required String bookingId,
    required String method,
    String? idempotencyKey,
  }) async {
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
