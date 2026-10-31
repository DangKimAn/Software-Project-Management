import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/host/data/host_repository.dart';
import 'package:hotel_booking_flutter/features/host/domain/host_models.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/host_portal_screens.dart';
import 'package:hotel_booking_flutter/features/host/services/host_file_picker_service.dart';

class DioClient {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
}

class FakeCalendarAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/api/host/listings/mine') {
      return ResponseBody.fromString(
        jsonEncode({
          'items': [
            {
              'listingId': 1,
              'title': 'The Song 5 sao tại Vũng Tàu',
              'propertyType': 'apartment',
              'basePrice': 1500000,
              'maxGuests': 4,
              'status': 'published',
            },
            {
              'listingId': 2,
              'title': 'Villa Bãi Trước Hồ Bơi Riêng',
              'propertyType': 'villa',
              'basePrice': 4500000,
              'maxGuests': 12,
              'status': 'hidden',
            },
          ],
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    if (options.path.contains('/calendar')) {
      return ResponseBody.fromString(
        jsonEncode({
          'days': [
            {
              'date': '2026-10-01',
              'basePrice': 1500000,
              'effectivePrice': 1500000,
              'isAvailable': true,
              'isBlockedByHost': false,
            },
            {
              'date': '2026-10-02',
              'basePrice': 1500000,
              'effectivePrice': 1800000,
              'isAvailable': false,
              'isBlockedByHost': true,
            },
            {
              'date': '2026-10-03',
              'basePrice': 1500000,
              'effectivePrice': 2000000,
              'isAvailable': false,
              'isBlockedByHost': false,
              'bookingStatus': 'confirmed',
              'guestName': 'Nguyễn Văn A',
            },
          ],
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    if (options.path == '/api/host/bookings') {
      return ResponseBody.fromString(
        jsonEncode({
          'items': [
            {
              'bookingId': 99,
              'listingId': 1,
              'checkInDate': '2026-10-03',
              'checkOutDate': '2026-10-05',
              'status': 'confirmed',
              'guestName': 'Nguyễn Văn A',
              'totalPrice': 4000000,
            },
          ],
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'items': <dynamic>[]}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeFilePickerService implements HostFilePickerService {
  @override
  Future<HostPickedFile?> pickKycDocument({BuildContext? context, String title = ''}) async => null;
  @override
  Future<List<HostPickedFile>> pickListingImages({BuildContext? context, int maxImages = 30}) async => [];
  @override
  Future<HostPickedFile?> pickAvatarImage({BuildContext? context}) async => null;
  @override
  Future<HostPickedFile> readFromFilePath(String filePath) async => throw UnimplementedError();
}

void main() {
  group('Host Calendar Airbnb Style & Personal Optimization Tests', () {
    late HostRepository testRepo;
    late FakeCalendarAdapter adapter;
    late FakeFilePickerService fakePicker;

    setUp(() {
      adapter = FakeCalendarAdapter();
      final client = DioClient()..dio.httpClientAdapter = adapter;
      testRepo = HostRepository(client);
      fakePicker = FakeFilePickerService();
    });

    testWidgets('Renders Airbnb Listing Overview, search, and switches to detailed calendar with Airbnb floating panel on tap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(testRepo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: const MaterialApp(
            home: HostPortalScreen(
              initialSection: HostPortalSection.calendar,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Kiểm tra màn hình Airbnb Overview
      expect(find.text('Lịch'), findsWidgets);
      expect(find.text('The Song 5 sao tại Vũng Tàu'), findsOneWidget);
      expect(find.text('Đang hiển thị'), findsWidgets);
      expect(find.text('Villa Bãi Trước Hồ Bơi Riêng'), findsOneWidget);
      expect(find.text('Đã hủy đăng'), findsOneWidget);

      // 2. Click vào chỗ nghỉ đầu tiên để mở Lịch chi tiết
      await tester.tap(find.text('The Song 5 sao tại Vũng Tàu'));
      await tester.pumpAndSettle();

      // 3. Yêu cầu 1: Kiểm tra có dòng to 'Lịch lưu trú & Giá theo ngày' và KHÔNG có dòng chữ nhỏ mô tả api/hướng dẫn dài
      expect(find.text('Lịch lưu trú & Giá theo ngày'), findsOneWidget);
      expect(find.textContaining('Khóa/mở ngày trống và thiết lập giá riêng cho từng ngày qua /api/host/listings/:id/calendar'), findsNothing);

      // 4. Yêu cầu 2: Lịch chi tiết 7 cột thu nhỏ, thấy ngay toàn bộ tháng
      expect(find.text('Tất cả chỗ nghỉ'), findsOneWidget);
      expect(find.text('Lấp đầy'), findsOneWidget);
      expect(find.text('Dự kiến'), findsOneWidget);
      expect(find.text('Giá TB'), findsOneWidget);
      expect(find.text('T2'), findsOneWidget);
      expect(find.text('T7'), findsOneWidget);
      expect(find.text('CN'), findsOneWidget);
      expect(find.text('Cuối tuần (T7, CN)'), findsOneWidget);
      expect(find.text('Ngày còn trống'), findsOneWidget);
      expect(find.text('Cả tháng'), findsOneWidget);

      // Yêu cầu 3: Khi CHƯA nhấn chọn ngày nào vào lịch thì KHÔNG hiện nút/panel cập nhật ở dưới
      expect(find.byKey(const Key('calendar_unlock_save_btn')), findsNothing);
      expect(find.byKey(const Key('calendar_lock_btn')), findsNothing);

      // 5. Khi NHẤN vào một ngày trên lịch (hoặc bấm chọn ngày):
      // -> Mới hiện ra nút/panel điều khiển chuẩn Airbnb!
      await tester.tap(find.byKey(const Key('calendar_day_2026-10-01')));
      await tester.pumpAndSettle();

      // Bây giờ các nút Airbnb đã xuất hiện:
      expect(find.byKey(const Key('calendar_unlock_save_btn')), findsOneWidget);
      expect(find.byKey(const Key('calendar_lock_btn')), findsOneWidget);
      expect(find.text('Giá mới cho chỗ ở cho thuê'), findsOneWidget);
      expect(find.text('Cài đặt tùy chỉnh'), findsOneWidget);
      expect(find.text('+10%'), findsOneWidget);
      expect(find.text('+20% (Cuối tuần/Lễ)'), findsOneWidget);
      expect(find.text('Giá gốc'), findsOneWidget);

      // 6. Test bấm '+10%' preset
      await tester.ensureVisible(find.text('+10%'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+10%'));
      await tester.pumpAndSettle();
      final priceInputFinder = find.byKey(const Key('calendar_price_override_input'));
      expect(priceInputFinder, findsOneWidget);
      final priceInput = tester.widget<TextField>(priceInputFinder);
      expect(priceInput.controller?.text, '1650000'); // 1500000 * 1.1 = 1650000

      // 7. Bấm 'Tất cả chỗ nghỉ' để quay lại danh sách Airbnb
      await tester.ensureVisible(find.text('Tất cả chỗ nghỉ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tất cả chỗ nghỉ'));
      await tester.pumpAndSettle();
      expect(find.text('The Song 5 sao tại Vũng Tàu'), findsOneWidget);
      expect(find.text('Villa Bãi Trước Hồ Bơi Riêng'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
