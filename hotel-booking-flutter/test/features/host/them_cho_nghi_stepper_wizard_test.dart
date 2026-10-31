import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/features/host/data/host_repository.dart';
import 'package:hotel_booking_flutter/features/host/domain/host_models.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/them_cho_nghi_screen.dart';
import 'package:hotel_booking_flutter/features/host/services/host_file_picker_service.dart';

class FakeTestFilePickerService implements HostFilePickerService {
  HostPickedFile? nextKycFile;
  List<HostPickedFile> nextListingImages = [];

  @override
  Future<HostPickedFile?> pickKycDocument({
    BuildContext? context,
    String title = '',
  }) async =>
      nextKycFile;

  @override
  Future<List<HostPickedFile>> pickListingImages({
    BuildContext? context,
    int maxImages = 30,
  }) async =>
      nextListingImages;

  @override
  Future<HostPickedFile?> pickAvatarImage({BuildContext? context}) async =>
      nextKycFile;

  @override
  Future<HostPickedFile> readFromFilePath(String filePath) async {
    return HostPickedFile(
      bytes: Uint8List.fromList([1, 2, 3]),
      name: 'test.jpg',
      sizeBytes: 3,
      mimeType: 'image/jpeg',
    );
  }
}

class FakeRecordingHttpClientAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) responder;
  final List<RequestOptions> requests = [];

  FakeRecordingHttpClientAdapter({required this.responder});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(dynamic data, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'ThemChoNghiScreen Step-by-Step Wizard navigates steps, reviews summary, and shows success dialog',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final apiAdapter = FakeRecordingHttpClientAdapter(
      responder: (options) {
        if (options.path == '/api/amenities') {
          return jsonResponse({
            'items': [
              {'amenityId': 1, 'name': 'Wifi tốc độ cao', 'category': 'Cơ bản'},
              {'amenityId': 2, 'name': 'Hồ bơi riêng', 'category': 'Tiện ích'},
            ],
          });
        }
        if (options.method == 'POST' && options.path == '/api/host/listings') {
          return jsonResponse({
            'listingId': 105,
            ...Map<String, dynamic>.from(options.data as Map),
          }, statusCode: 201);
        }
        if (options.path == '/api/host/listings/105/amenities') {
          return jsonResponse({'amenityIds': []});
        }
        if (options.path == '/api/host/listings/105/rules') {
          return jsonResponse({'ok': true});
        }
        return jsonResponse({});
      },
    );

    final client = DioClient()..dio.httpClientAdapter = apiAdapter;
    final repo = HostRepository(client);
    final fakePicker = FakeTestFilePickerService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostRepositoryProvider.overrideWithValue(repo),
          hostFilePickerProvider.overrideWithValue(fakePicker),
          hostCurrentUserRoleProvider.overrideWithValue('host'),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ThemChoNghiScreen(
              embedded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Kiểm tra xuất hiện thanh Stepper Bar với Bước 1/7
    expect(find.textContaining('Bước 1/7'), findsOneWidget);
    expect(find.text('Cơ bản'), findsWidgets);

    // 2. Điền thông tin Bước 1 (Tên & Mô tả)
    await tester.enterText(
      find.byKey(const Key('listing_title_input')),
      'The Palm Luxury Ocean Villa',
    );
    await tester.enterText(
      find.byKey(const Key('listing_description_input')),
      'Biệt thự nghỉ dưỡng view biển tuyệt đẹp tại Bãi Sau Vũng Tàu.',
    );
    await tester.pumpAndSettle();

    // 3. Nhấn Tiếp tục -> Chuyển sang Bước 2 (Vị trí)
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bước 2/7'), findsOneWidget);

    // 4. Nhập địa chỉ Bước 2
    await tester.enterText(
      find.byKey(const Key('listing_address_input')),
      '120 Hạ Long, Phường 2',
    );
    await tester.pumpAndSettle();

    // 5. Cuộn ngang Stepper Bar và bấm vào tab 'Xem lại'
    final reviewTab = find.text('Xem lại').first;
    await tester.ensureVisible(reviewTab);
    await tester.pumpAndSettle();
    await tester.tap(reviewTab);
    await tester.pumpAndSettle();

    // Kiểm tra đã ở Bước 7: Xem lại thông tin
    expect(find.textContaining('Bước 7/7'), findsOneWidget);
    expect(find.text('Kiểm tra & Xác nhận thông tin'), findsOneWidget);
    expect(find.text('The Palm Luxury Ocean Villa'), findsWidgets);
    expect(find.textContaining('120 Hạ Long'), findsOneWidget);

    // 6. Nhấn nút "Lưu chỗ nghỉ" (listing_save_btn)
    final saveBtn = find.byKey(const Key('listing_save_btn'));
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // 7. Kiểm tra xuất hiện Dialog Lưu thành công đẹp mắt
    expect(find.text('Thêm chỗ nghỉ thành công!'), findsOneWidget);
    expect(find.text('Quản lý danh sách chỗ nghỉ'), findsOneWidget);
    expect(find.text('Thêm tiếp chỗ nghỉ khác'), findsOneWidget);
  });
}
