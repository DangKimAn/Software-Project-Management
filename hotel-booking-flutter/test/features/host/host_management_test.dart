import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/features/host/data/host_repository.dart';
import 'package:hotel_booking_flutter/features/host/domain/host_models.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/host_onboarding_screens.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/host_portal_screens.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/host_listing_form_screen.dart';
import 'package:hotel_booking_flutter/features/host/presentation/widgets/host_chat_composer_bar.dart';
import 'package:hotel_booking_flutter/features/host/presentation/widgets/host_studio_widgets.dart';
import 'package:hotel_booking_flutter/features/host/services/host_file_picker_service.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_image.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_semantic_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DioClient {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
}

/// Recorded HTTP request for assertions in unit & widget tests.
class RecordedHttpRequest {
  final String method;
  final String path;
  final Map<String, dynamic> queryParameters;
  final Map<String, dynamic> headers;
  final dynamic data;

  const RecordedHttpRequest({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.headers,
    required this.data,
  });
}

/// Fake [HttpClientAdapter] that intercepts Dio requests in memory and records them.
class FakeRecordingHttpClientAdapter implements HttpClientAdapter {
  final List<RecordedHttpRequest> requests = [];
  final ResponseBody Function(RequestOptions options) responder;

  FakeRecordingHttpClientAdapter({required this.responder});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      RecordedHttpRequest(
        method: options.method.toUpperCase(),
        path: options.path,
        queryParameters: Map<String, dynamic>.from(options.queryParameters),
        headers: Map<String, dynamic>.from(options.headers),
        data: options.data,
      ),
    );
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  Object body, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// Fake [HostFilePickerService] for deterministic widget tests.
class FakeTestFilePickerService implements HostFilePickerService {
  HostPickedFile? nextKycFile;
  List<HostPickedFile> nextListingImages = [];

  bool? lastImageOnlyFlag;

  @override
  Future<HostPickedFile?> pickKycDocument({
    BuildContext? context,
    String title = '',
    // CONFLICT-RESOLVED: Đáp ứng chữ ký `pickKycDocument` hợp nhất gồm cả `imageOnly` và `source`.
    bool imageOnly = false,
    HostKycFileSource source = HostKycFileSource.deviceFile,
  }) async {
    lastImageOnlyFlag = imageOnly;
    return nextKycFile;
  }

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
    return nextKycFile!;
  }
}

// 1x1 transparent PNG bytes for widget tests
final Uint8List kSamplePngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

HostPickedFile createValidImageFile({
  String name = 'villa_front.png',
  String mimeType = 'image/png',
  int? sizeBytes,
}) {
  final bytes = sizeBytes != null ? Uint8List(sizeBytes) : kSamplePngBytes;
  return HostPickedFile(
    name: name,
    mimeType: mimeType,
    sizeBytes: bytes.length,
    bytes: bytes,
  );
}

void main() {
  // ===========================================================================
  // 1. FILE VALIDATION & HOST ONBOARDING DTO / MULTIPART FORMDATA TESTS
  // ===========================================================================
  group('BUG-10: Host Onboarding DTO, File Validation & Multipart FormData',
      () {
    test(
        'validateKycPickedFile accepts JPG, PNG, WebP, PDF <= 5MB and rejects > 5MB or unsupported MIME',
        () {
      final validJpg = createValidImageFile(
        name: 'cccd_front.jpg',
        mimeType: 'image/jpeg',
      );
      final validPdf = HostPickedFile(
        name: 'business_license.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 1024,
        bytes: Uint8List(1024),
      );
      expect(validateKycPickedFile(validJpg), isNull);
      expect(validateKycPickedFile(validPdf), isNull);

      final oversized = HostPickedFile(
        name: 'huge.png',
        mimeType: 'image/png',
        sizeBytes: kMaxHostUploadBytes + 1,
        bytes: Uint8List(16),
      );
      expect(validateKycPickedFile(oversized), contains('5MB'));

      final invalidMime = HostPickedFile(
        name: 'script.exe',
        mimeType: 'application/x-msdownload',
        sizeBytes: 128,
        bytes: Uint8List(128),
      );
      expect(validateKycPickedFile(invalidMime), contains('không hỗ trợ'));
    });

    test(
        'HostKycSubmissionDto enforces CCCD front+back, Passport single, and Business license rules',
        () {
      final front =
          createValidImageFile(name: 'front.jpg', mimeType: 'image/jpeg');
      final back =
          createValidImageFile(name: 'back.jpg', mimeType: 'image/jpeg');
      final single =
          createValidImageFile(name: 'passport.jpg', mimeType: 'image/jpeg');
      final license = HostPickedFile(
        name: 'gpkd.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 512,
        bytes: Uint8List(512),
      );

      // Missing back image on CCCD fails
      final missingBackDto = HostKycSubmissionDto(
        contactName: 'Nguyen Van Host',
        contactEmail: 'host@vungtau.vn',
        phone: '0901234567',
        profileType: HostProfileType.individual,
        documentType: HostDocumentType.cccd,
        businessAddress: '12 Thuy Van, Phuong Thang Tam, Vung Tau',
        identityFront: front,
      );
      expect(missingBackDto.validate(), contains('mặt sau'));

      // Business profile without businessLicense fails
      final missingLicenseDto = HostKycSubmissionDto(
        contactName: 'Cong Ty Villa VT',
        contactEmail: 'biz@vungtau.vn',
        phone: '+84901234567',
        profileType: HostProfileType.business,
        documentType: HostDocumentType.cccd,
        businessAddress: '12 Thuy Van, Phuong Thang Tam, Vung Tau',
        identityFront: front,
        identityBack: back,
      );
      expect(missingLicenseDto.validate(), contains('Giấy phép kinh doanh'));

      // Valid Business + CCCD + License builds FormData with exact fields & files
      final validBizDto = HostKycSubmissionDto(
        contactName: 'Cong Ty Villa VT',
        contactEmail: 'biz@vungtau.vn',
        phone: '0901234567',
        profileType: HostProfileType.business,
        documentType: HostDocumentType.cccd,
        businessAddress: '12 Thuy Van, Phuong Thang Tam, Vung Tau',
        note: 'Chuoi 5 villa sat bien',
        identityFront: front,
        identityBack: back,
        businessLicense: license,
      );
      expect(validBizDto.validate(), isNull);
      final formData = validBizDto.toFormData();
      final fieldMap = {for (final f in formData.fields) f.key: f.value};
      expect(fieldMap['contactName'], 'Cong Ty Villa VT');
      expect(fieldMap['profileType'], 'business');
      expect(fieldMap['documentType'], 'cccd');
      expect(fieldMap['phone'], '0901234567');

      final fileKeys = formData.files.map((e) => e.key).toSet();
      expect(
        fileKeys,
        containsAll(['identityFront', 'identityBack', 'businessLicense']),
      );

      // Valid Passport individual builds FormData with identitySingle only
      final validPassportDto = HostKycSubmissionDto(
        contactName: 'Tran Thi B',
        contactEmail: 'tranthib@vungtau.vn',
        phone: '0912345678',
        profileType: HostProfileType.individual,
        documentType: HostDocumentType.passport,
        businessAddress: '88 Phan Chu Trinh, Phuong 2, Vung Tau',
        identitySingle: single,
      );
      expect(validPassportDto.validate(), isNull);
      final passportForm = validPassportDto.toFormData();
      expect(
        passportForm.files.map((e) => e.key).toList(),
        equals(['identitySingle']),
      );
    });

    test(
        'HostRepository calls GET /api/host/applications/me and POST /api/host/applications',
        () async {
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.method == 'GET' &&
              options.path == '/api/host/applications/me') {
            return jsonResponse({
              'status': 'pending',
              'application': {
                'id': 42,
                'status': 'pending',
                'contactName': 'Le Host',
                'contactEmail': 'lehost@vt.vn',
                'phone': '0987654321',
                'profileType': 'individual',
                'documentType': 'cccd',
                'businessAddress': '100 Ha Long, Vung Tau',
                'documents': [
                  {
                    'documentType': 'identity_front',
                    'fileUrl': 'https://cdn.example.com/kyc/front.jpg',
                    'originalFilename': 'front.jpg',
                  },
                ],
              },
            });
          }
          if (options.method == 'POST' &&
              options.path == '/api/host/applications') {
            return jsonResponse({
              'status': 'pending',
              'application': {
                'id': 43,
                'status': 'pending',
                'contactName': 'Le Host',
                'phone': '0987654321',
                'profileType': 'individual',
                'businessAddress': '100 Ha Long, Vung Tau',
              },
            }, statusCode: 201);
          }
          return jsonResponse({'message': 'Not found'}, statusCode: 404);
        },
      );

      final client = DioClient();
      client.dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client);

      final record = await repo.getMyApplicationRecord();
      expect(record, isNotNull);
      expect(record!.id, 42);
      expect(record.status, HostApplicationStatus.pending);
      expect(record.documents.first.originalFilename, 'front.jpg');
      expect(apiAdapter.requests.first.path, '/api/host/applications/me');

      final dto = HostKycSubmissionDto(
        contactName: 'Le Host',
        contactEmail: 'lehost@vt.vn',
        phone: '0987654321',
        profileType: HostProfileType.individual,
        documentType: HostDocumentType.cccd,
        businessAddress: '100 Ha Long, Vung Tau',
        identityFront: createValidImageFile(name: 'front.png'),
        identityBack: createValidImageFile(name: 'back.png'),
      );
      final submitted = await repo.submitKycApplication(dto);
      expect(submitted.id, 43);
      expect(apiAdapter.requests.last.path, '/api/host/applications');
      expect(apiAdapter.requests.last.data, isA<FormData>());
    });
  });

  // ===========================================================================
  // 2. R2 PRESIGNED UPLOAD FLOW & AI VISION 22-TAG TAXONOMY TESTS
  // ===========================================================================
  group('R2 Presigned Upload & AI Vision 22-Tag Taxonomy', () {
    test(
        'uploadFileToR2 requests presigned URL and PUTs raw bytes WITHOUT Authorization Bearer header',
        () async {
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.method == 'POST' &&
              options.path == '/api/uploads/presign') {
            return jsonResponse({
              'uploadUrl':
                  'https://r2.cloudflarestorage.com/bucket/listings/img1.png?sig=abc',
              'publicUrl': 'https://pub-r2.example.com/listings/img1.png',
              'key': 'listings/img1.png',
              'expiresIn': 300,
            });
          }
          return jsonResponse({}, statusCode: 404);
        },
      );

      final r2Adapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          return ResponseBody.fromString('', 200);
        },
      );

      final apiClient = DioClient();
      apiClient.dio.options.headers['Authorization'] =
          'Bearer secret-api-jwt-token';
      apiClient.dio.httpClientAdapter = apiAdapter;

      final cleanR2Dio = Dio();
      cleanR2Dio.httpClientAdapter = r2Adapter;

      final repo = HostRepository(
        apiClient,
        r2Uploader: HostR2DirectUploader(cleanDio: cleanR2Dio),
      );

      final imageFile = createValidImageFile(
        name: 'pool_view.png',
        mimeType: 'image/png',
      );
      final result = await repo.uploadFileToR2(
        imageFile,
        folder: 'listings',
        listingId: '99',
      );

      expect(result.publicUrl, 'https://pub-r2.example.com/listings/img1.png');
      expect(result.key, 'listings/img1.png');

      // Verify presign request went to backend API with listingId
      expect(apiAdapter.requests.single.path, '/api/uploads/presign');
      expect(apiAdapter.requests.single.data['folder'], 'listings');
      expect(apiAdapter.requests.single.data['listingId'], 99);

      // Verify PUT request went to R2 with raw bytes and NO Authorization header!
      final r2Req = r2Adapter.requests.single;
      expect(r2Req.method, 'PUT');
      expect(
        r2Req.path,
        'https://r2.cloudflarestorage.com/bucket/listings/img1.png?sig=abc',
      );
      expect(r2Req.headers.containsKey('Authorization'), isFalse);
      expect(r2Req.headers.containsKey('authorization'), isFalse);
      expect(r2Req.data, isA<Uint8List>());
    });

    test('AI Vision 22-Tag Taxonomy & image analysis endpoints', () async {
      expect(kDefaultImageTagTaxonomies.length, 22);

      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.method == 'GET' &&
              options.path == '/api/host/listings/99/images/analysis') {
            return jsonResponse({
              'listingId': 99,
              'tagTaxonomies': kDefaultImageTagTaxonomies
                  .map((t) => {
                        'code': t.code,
                        'labelVi': t.labelVi,
                        'category': t.category
                      })
                  .toList(),
              'images': [
                {
                  'imageId': 501,
                  'url': 'https://pub-r2.example.com/listings/pool.jpg',
                  'isCover': true,
                  'sortOrder': 0,
                  'roomType': 'Hồ bơi ngoài trời',
                  'aiAnalysisStatus': 'analyzed',
                  'aiConfidence': 0.94,
                  'effectiveTags': ['pool', 'sea_view', 'luxury'],
                },
              ],
            });
          }
          if (options.method == 'PATCH' &&
              options.path == '/api/host/images/501/tags') {
            return jsonResponse({
              'image': {
                'imageId': 501,
                'url': 'https://pub-r2.example.com/listings/pool.jpg',
                'isCover': true,
                'sortOrder': 0,
                'aiAnalysisStatus': 'analyzed',
                'effectiveTags': options.data['tags'],
              },
            });
          }
          return jsonResponse({});
        },
      );

      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client);

      final analysis = await repo.getListingImagesAnalysis('99');
      expect(analysis.tagTaxonomies.length, 22);
      expect(analysis.images.single.imageId, 501);
      expect(
        analysis.images.single.tags.map((t) => t.tag).toList(),
        equals(['pool', 'sea_view', 'luxury']),
      );

      final updated = await repo.updateListingImageTags(
        501,
        ['pool', 'sea_view', 'luxury', 'bbq'],
      );
      expect(updated.tags.map((t) => t.tag), contains('bbq'));
    });
  });

  // ===========================================================================
  // 3. BUG-11 & BUG-12: HOST LISTING CRUD, ENUMS, AMENITIES & RULES
  // ===========================================================================
  group('BUG-11 & BUG-12: Host Listing CRUD, Status Enums, Amenities & Rules',
      () {
    test(
        'Listing CRUD uses /api/host/listings/mine, PATCH for updates/rules, PUT for amenities',
        () async {
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.method == 'GET' &&
              options.path == '/api/host/listings/mine') {
            return jsonResponse({
              'items': [
                {
                  'listingId': 10,
                  'title': 'Villa Biển Bãi Sau',
                  'propertyType': 'villa',
                  'roomType': 'entire_place',
                  'basePrice': 3500000,
                  'maxGuests': 12,
                  'status': 'pending_approval',
                },
              ],
            });
          }
          if (options.method == 'POST' &&
              options.path == '/api/host/listings') {
            return jsonResponse({
              'listingId': 11,
              ...Map<String, dynamic>.from(options.data as Map),
            }, statusCode: 201);
          }
          if (options.method == 'PATCH' &&
              options.path == '/api/host/listings/11') {
            return jsonResponse({
              'listingId': 11,
              ...Map<String, dynamic>.from(options.data as Map),
            });
          }
          if (options.method == 'PUT' &&
              options.path == '/api/host/listings/11/amenities') {
            return jsonResponse({'amenityIds': options.data['amenityIds']});
          }
          if (options.method == 'PATCH' &&
              options.path == '/api/host/listings/11/rules') {
            return jsonResponse({'rules': options.data});
          }
          return jsonResponse({});
        },
      );

      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client);

      final mine = await repo.getHostListings(status: 'pending_approval');
      expect(mine.single['status'], 'pending_approval');
      expect(apiAdapter.requests.first.path, '/api/host/listings/mine');
      expect(
        apiAdapter.requests.first.queryParameters['status'],
        'pending_approval',
      );

      const createDto = HostListingUpsertDto(
        title: 'Ocean Pool Villa',
        description: 'Villa sát biển Bãi Sau có hồ bơi riêng.',
        addressLine: '164B Phan Chu Trinh',
        ward: 'Phường 2',
        latitude: 10.3372,
        longitude: 107.0846,
        propertyType: HostPropertyType.villa,
        roomType: HostRoomType.entirePlace,
        maxGuests: 10,
        bedrooms: 4,
        beds: 5,
        bathrooms: 4,
        basePrice: 4000000,
        weekendPrice: 5000000,
        instantBookEnabled: true,
        amenityIds: [1, 3, 5],
        status: HostListingStatus.pendingApproval,
      );
      expect(createDto.validate(), isNull);

      final created = await repo.createHostListing(createDto.toCreateJson());
      expect(created['country'], 'VN');
      expect(created['currency'], 'VND');
      expect(created['roomType'], 'entire_place');
      expect(created['instantBookEnabled'], isTrue);
      expect(created['status'], 'pending_approval');

      await repo.updateListingAmenities('11', [1, 3, 5]);
      final amenityReq = apiAdapter.requests.firstWhere(
        (r) => r.path == '/api/host/listings/11/amenities',
      );
      expect(amenityReq.method, 'PUT');
      expect(
          amenityReq.data,
          equals({
            'amenityIds': [1, 3, 5]
          }));

      await repo.updateListingRules('11', {
        'checkInFrom': '14:00',
        'checkOutBefore': '12:00',
        'smokingAllowed': false,
        'petsAllowed': true,
        'partyAllowed': true,
      });
      final rulesReq = apiAdapter.requests.firstWhere(
        (r) => r.path == '/api/host/listings/11/rules',
      );
      expect(rulesReq.method, 'PATCH');
      expect(rulesReq.data['petsAllowed'], isTrue);
      expect(rulesReq.data['partyAllowed'], isTrue);
    });
  });

  // ===========================================================================
  // 4. BUG-13 & BUG-38: CALENDAR, BOOKINGS, PAYOUTS, REPORTS, BANKS & REVIEWS
  // ===========================================================================
  group(
      'BUG-13 & BUG-38: Calendar, Bookings, Role Guard, Payouts, Reports, Banks & Reviews',
      () {
    test('Calendar GET & PATCH /api/host/listings/:id/calendar/bulk', () async {
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.method == 'GET' &&
              options.path == '/api/host/listings/10/calendar') {
            return jsonResponse({
              'listingId': 10,
              'month': 10,
              'year': 2026,
              'days': [
                {
                  'date': '2026-10-15',
                  'basePrice': 2000000,
                  'effectivePrice': 2500000,
                  'priceOverride': 2500000,
                  'isAvailable': true,
                  'isBlockedByHost': false,
                },
              ],
            });
          }
          if (options.method == 'PATCH' &&
              options.path == '/api/host/listings/10/calendar/bulk') {
            return jsonResponse({'updated': 2});
          }
          return jsonResponse({});
        },
      );

      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client);

      final days = await repo.getListingCalendarDays(
        '10',
        month: 10,
        year: 2026,
      );
      expect(days.single.date, '2026-10-15');
      expect(days.single.effectivePrice, 2500000);

      await repo.bulkUpdateListingCalendar(
        '10',
        dates: ['2026-10-20', '2026-10-21'],
        isAvailable: false,
        isBlockedByHost: true,
        priceOverride: 3000000,
      );
      final bulkReq = apiAdapter.requests.last;
      expect(bulkReq.method, 'PATCH');
      expect(bulkReq.path, '/api/host/listings/10/calendar/bulk');
      expect(bulkReq.data['dates'], equals(['2026-10-20', '2026-10-21']));
      expect(bulkReq.data['isBlockedByHost'], isTrue);
    });

    test('Host Bookings confirm/check-in/check-out/cancel & Guest role guard',
        () async {
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) =>
            jsonResponse({'bookingId': 77, 'status': 'confirmed'}),
      );
      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client);

      final now = DateTime.utc(2026, 10, 15, 5, 0); // 2026-10-15 12:00 VN
      final paidBooking = {
        'bookingId': 77,
        'status': 'paid',
        'paymentStatus': 'paid',
        'checkInDate': '2026-10-15',
        'checkOutDate': '2026-10-17',
      };

      // Guest role NEVER gets confirm/checkIn/checkOut actions
      final guestActions = getBookingStatusActions(
        paidBooking,
        role: BookingActionRole.guest,
        now: now,
      );
      expect(guestActions.canConfirm, isFalse);
      expect(guestActions.canCheckIn, isFalse);
      expect(guestActions.canCheckOut, isFalse);

      // Guest role is blocked by assertHostRoleAuthorized
      expect(
        () => repo.confirmHostBooking(
          '77',
          currentBooking: paidBooking,
          userRole: 'guest',
        ),
        throwsStateError,
      );

      // Host role can confirm paid booking -> PATCH /api/host/bookings/77/confirm
      await repo.confirmHostBooking(
        '77',
        currentBooking: paidBooking,
        userRole: 'host',
      );
      expect(apiAdapter.requests.last.method, 'PATCH');
      expect(apiAdapter.requests.last.path, '/api/host/bookings/77/confirm');

      // Confirmed booking on checkInDate can check-in -> POST /api/host/bookings/77/check-in
      final confirmedBooking = {
        ...paidBooking,
        'status': 'confirmed',
      };
      await repo.checkInHostBooking(
        '77',
        currentBooking: confirmedBooking,
        userRole: 'host',
        now: now,
      );
      expect(apiAdapter.requests.last.method, 'POST');
      expect(apiAdapter.requests.last.path, '/api/host/bookings/77/check-in');

      // Checked-in booking on checkOutDate can check-out -> POST /api/host/bookings/77/check-out
      final checkedInBooking = {
        ...paidBooking,
        'status': 'checked_in',
        'checkOutDate': '2026-10-15',
      };
      await repo.checkOutHostBooking(
        '77',
        currentBooking: checkedInBooking,
        userRole: 'host',
        now: now,
      );
      expect(apiAdapter.requests.last.method, 'POST');
      expect(apiAdapter.requests.last.path, '/api/host/bookings/77/check-out');
    });

    test('Payouts, Revenue Report, Vietnam Banks (items key), and Review Reply',
        () async {
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/banks/vn') {
            return jsonResponse({
              'items': [
                {
                  'code': 'VCB',
                  'shortName': 'Vietcombank',
                  'name': 'Ngân hàng TMCP Ngoại thương Việt Nam',
                  'bin': '970436',
                },
              ],
            });
          }
          if (options.path == '/api/host/reports/revenue') {
            return jsonResponse({
              'range': {'from': '2026-09-16', 'to': '2026-10-15'},
              'group': 'day',
              'totals': {
                'grossRevenue': 20000000,
                'platformRevenue': 2000000,
                'hostRevenue': 18000000,
                'bookingCount': 5,
                'paymentCount': 5,
              },
              'series': [
                {
                  'period': '2026-10-10',
                  'grossRevenue': 20000000,
                  'platformRevenue': 2000000,
                  'hostRevenue': 18000000,
                  'bookingCount': 5,
                },
              ],
            });
          }
          if (options.method == 'POST' &&
              options.path == '/api/reviews/301/reply') {
            return jsonResponse({
              'reviewId': 301,
              'hostReply': options.data['reply'],
            });
          }
          return jsonResponse({});
        },
      );

      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client);

      final banks = await repo.getTypedVietnamBanks();
      expect(banks.single.code, 'VCB');
      expect(banks.single.bin, '970436');

      final report = await repo.getTypedRevenueReport(rangeKey: '30d');
      expect(report.hostRevenue, 18000000);
      expect(report.bookingCount, 5);
      expect(report.series.single.period, '2026-10-10');

      final replyRes = await repo.replyToReview(
        '301',
        'Cảm ơn quý khách đã nghỉ dưỡng tại Villa!',
      );
      expect(
        replyRes['hostReply'],
        'Cảm ơn quý khách đã nghỉ dưỡng tại Villa!',
      );
    });
  });

  // ===========================================================================
  // 5. RESPONSIVE WIDGET TESTS (320px - 600px)
  // ===========================================================================
  group('Responsive Widget Tests (320px–600px)', () {
    late HostRepository testRepo;
    late HostOnboardingApiService testOnboardingApi;
    late FakeTestFilePickerService fakePicker;

    setUp(() {
      final adapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/host/applications/me') {
            return jsonResponse({
              'status': 'rejected',
              'application': {
                'id': 12,
                'status': 'rejected',
                'contactName': 'Chủ nhà Test',
                'contactEmail': 'host@vt.vn',
                'phone': '0901234567',
                'profileType': 'individual',
                'documentType': 'cccd',
                'businessAddress': '10 Thùy Vân, Vũng Tàu',
                'rejectReason': 'Ảnh mặt sau CCCD bị mờ, vui lòng chụp lại.',
              },
            });
          }
          if (options.path == '/api/host/listings/mine') {
            return jsonResponse({
              'items': [
                {
                  'listingId': 1,
                  'title': 'Villa Biển Thùy Vân',
                  'propertyType': 'villa',
                  'basePrice': 2500000,
                  'maxGuests': 8,
                  'status': 'published',
                },
              ],
            });
          }
          if (options.path == '/api/host/listings/1/reviews' ||
              options.path == '/api/listings/1/reviews') {
            return jsonResponse({
              'items': [
                {
                  'reviewId': 88,
                  'reviewerName': 'Khách Nguyễn',
                  'rating': 5,
                  'comment': 'Villa rất sạch và gần biển.',
                  'createdAt': '2026-10-01',
                },
              ],
            });
          }
          return jsonResponse({'items': <dynamic>[]});
        },
      );
      final client = DioClient()..dio.httpClientAdapter = adapter;
      testRepo = HostRepository(client);
      testOnboardingApi = HostOnboardingApiService(dio: client.dio);
      fakePicker = FakeTestFilePickerService();
    });

    testWidgets(
        'DangKyHostScreen & TrangThaiHostScreen render cleanly at 320px width',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(testRepo),
            hostOnboardingApiProvider.overrideWithValue(testOnboardingApi),
            hostFilePickerProvider.overrideWithValue(fakePicker),
          ],
          child: const MaterialApp(
            home: TrangThaiHostScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hồ sơ bị từ chối'), findsOneWidget);
      expect(
        find.textContaining('Ảnh mặt sau CCCD bị mờ'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'HostPortalScreen & HostListingFormScreen render cleanly at 360px mobile width without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
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
              initialSection: HostPortalSection.reviews,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify real average rating is computed (5.00 / 5.0 from 1 review, NOT hardcoded 4.9 / 12)
      expect(
        find.textContaining('5.00 / 5.0 (1 đánh giá)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(testRepo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: const MaterialApp(
            home: HostListingFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thêm chỗ nghỉ mới'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // 6. HOST QA: AUTHORIZATION, 422/403 CRUD, UPLOAD RETRY, CALENDAR,
  //    WEEKEND PRICE, PAYOUT MASKING, REPORT FILTERS & RESPONSIVE 320/768
  // ===========================================================================
  group('Host Authorization, Error Classification & CRUD Guards', () {
    test(
        'HostRepository blocks non-host roles on mutations and classifies 422/403/500/offline accurately',
        () async {
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/host/listings' &&
              options.method == 'POST') {
            return jsonResponse({
              'message': 'Dữ liệu chỗ nghỉ không hợp lệ',
              'errors': {
                'title': ['Tiêu đề chỗ nghỉ đã tồn tại'],
                'basePrice': 'Giá mỗi đêm phải lớn hơn 100.000đ',
              },
            }, statusCode: 422);
          }
          if (options.path == '/api/host/listings/99' &&
              options.method == 'DELETE') {
            return jsonResponse({
              'message': 'Bạn không phải chủ sở hữu chỗ nghỉ này.',
            }, statusCode: 403);
          }
          if (options.path == '/api/host/reports/revenue') {
            return jsonResponse({
              'message': 'Internal database timeout',
            }, statusCode: 500);
          }
          return jsonResponse({});
        },
      );

      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final guestRepo = HostRepository(client, roleResolver: () => 'guest');
      final hostRepo = HostRepository(client, roleResolver: () => 'host');

      // 1. Non-host role blocked before network call
      expect(
        () => guestRepo.createHostListing({'title': 'Test'}),
        throwsA(isA<HostAuthorizationException>()),
      );
      expect(
        () => guestRepo.deleteHostListing('99'),
        throwsA(isA<HostAuthorizationException>()),
      );
      expect(apiAdapter.requests, isEmpty);

      // 2. 422 Validation error extracts field errors without misclassifying as offline
      try {
        await hostRepo.createHostListing({'title': 'Dup'});
        fail('Expected 422 DioException');
      } catch (e) {
        final info = hostRepo.classifyError(e, 'Fallback');
        expect(info.type, HostErrorType.validation);
        expect(info.isOffline, isFalse);
        expect(info.message, contains('Tiêu đề chỗ nghỉ đã tồn tại'));
        expect(info.fieldErrors['basePrice'], contains('100.000đ'));
      }

      // 3. 403 Forbidden error classified as forbidden
      try {
        await hostRepo.deleteHostListing('99');
        fail('Expected 403 DioException');
      } catch (e) {
        final info = hostRepo.classifyError(e, 'Fallback');
        expect(info.type, HostErrorType.forbidden);
        expect(info.isForbidden, isTrue);
        expect(info.isOffline, isFalse);
        expect(info.message, contains('không phải chủ sở hữu'));
      }

      // 4. 500 Server error is NEVER misclassified as offline
      try {
        await hostRepo.getRevenueReport();
        fail('Expected 500 DioException');
      } catch (e) {
        final info = hostRepo.classifyError(e, 'Fallback');
        expect(info.type, HostErrorType.server);
        expect(info.isOffline, isFalse);
      }
    });

    testWidgets(
        'HostPortalScreen and HostListingFormScreen render role guard when user role is guest',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = DioClient()
        ..dio.httpClientAdapter = FakeRecordingHttpClientAdapter(
          responder: (_) => jsonResponse({'items': <dynamic>[]}),
        );
      final repo = HostRepository(client, roleResolver: () => 'guest');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostCurrentUserRoleProvider.overrideWithValue('guest'),
          ],
          child: const MaterialApp(
            home: HostPortalScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('host_portal_unauthorized_guard')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('host_portal_go_onboarding_btn')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostCurrentUserRoleProvider.overrideWithValue('guest'),
          ],
          child: const MaterialApp(
            home: HostListingFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('listing_form_unauthorized_guard')),
        findsOneWidget,
      );
    });
  });

  group('Payout Masking, Calendar Validation & Revenue Filters', () {
    test('maskBankAccountNumber and getPayoutAccounts mask sensitive digits',
        () async {
      expect(maskBankAccountNumber('0123456789'), '****6789');
      expect(maskBankAccountNumber('9704 3600 1234 5678'), '****5678');
      expect(maskBankAccountNumber('****9988'), '****9988');

      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/host/payout-accounts') {
            return jsonResponse({
              'items': [
                {
                  'id': 1,
                  'bankName': 'Vietcombank',
                  'accountHolderName': 'NGUYEN VAN HOST',
                  'accountNumber': '0071001234567',
                },
              ],
            });
          }
          if (options.path == '/api/host/payouts') {
            return jsonResponse({
              'items': [
                {
                  'payoutId': 55,
                  'amount': 9500000,
                  'status': 'paid',
                  'accountNumber': '0071001234567',
                  'transferReference': 'VCB-55',
                  'createdAt': '2026-10-20T08:00:00Z',
                },
              ],
            });
          }
          return jsonResponse({});
        },
      );

      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client);

      final accounts = await repo.getPayoutAccounts();
      expect(accounts.single['accountNumber'], '****4567');
      expect(accounts.single['accountNumberMasked'], '****4567');

      final payouts = await repo.getPayouts();
      expect(payouts.single['accountNumber'], '****4567');
      expect(payouts.single['accountNumberMasked'], '****4567');
    });

    test(
        'bulkUpdateListingCalendar rejects booked or past dates before network call',
        () async {
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (_) => jsonResponse({'updated': 1}),
      );
      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client);

      const calendarDays = [
        HostCalendarDay(
          date: '2026-10-10',
          basePrice: 2000000,
          effectivePrice: 2000000,
          isPast: true,
          canEdit: false,
        ),
        HostCalendarDay(
          date: '2026-10-28',
          basePrice: 2000000,
          effectivePrice: 2000000,
          isBooked: true,
          bookingStatus: 'confirmed',
          canEdit: false,
        ),
        HostCalendarDay(
          date: '2026-10-29',
          basePrice: 2000000,
          effectivePrice: 2000000,
          isAvailable: true,
          canEdit: true,
        ),
      ];

      // Attempt to update booked date -> throws StateError and makes 0 HTTP requests
      expect(
        () => repo.bulkUpdateListingCalendar(
          '10',
          dates: ['2026-10-28', '2026-10-29'],
          isAvailable: false,
          isBlockedByHost: true,
          currentCalendarDays: calendarDays,
        ),
        throwsStateError,
      );
      expect(apiAdapter.requests, isEmpty);

      // Attempt to update past date -> throws StateError and makes 0 HTTP requests
      expect(
        () => repo.bulkUpdateListingCalendar(
          '10',
          dates: ['2026-10-10'],
          isAvailable: false,
          isBlockedByHost: true,
          currentCalendarDays: calendarDays,
        ),
        throwsStateError,
      );
      expect(apiAdapter.requests, isEmpty);

      // Valid editable date succeeds
      await repo.bulkUpdateListingCalendar(
        '10',
        dates: ['2026-10-29'],
        isAvailable: false,
        isBlockedByHost: true,
        currentCalendarDays: calendarDays,
      );
      expect(apiAdapter.requests.length, 1);
    });

    test(
        'getTypedRevenueReport forwards rangeKey, groupOverride, and listingId query params',
        () async {
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          return jsonResponse({
            'range': {'from': '2026-07-01', 'to': '2026-10-01'},
            'group': options.queryParameters['group'] ?? 'month',
            'totals': {
              'grossRevenue': 50000000,
              'platformRevenue': 5000000,
              'hostRevenue': 45000000,
              'pendingStayRevenue': 8300000,
              'pendingStayPlatformRevenue': 800000,
              'pendingStayHostRevenue': 7500000,
              'pendingStayBookingCount': 1,
              'refundedAmount': 500000,
              'bookingCount': 8,
              'paymentCount': 8,
            },
            'series': [
              {
                'period': '2026-09',
                'grossRevenue': 50000000,
                'platformRevenue': 5000000,
                'hostRevenue': 45000000,
                'bookingCount': 8,
              },
            ],
          });
        },
      );
      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client);

      final report = await repo.getTypedRevenueReport(
        rangeKey: '90d',
        groupOverride: 'day',
        listingId: '15',
      );
      expect(report.hostRevenue, 45000000);
      expect(report.pendingStayRevenue, 8300000);
      expect(report.pendingStayHostRevenue, 7500000);
      expect(report.pendingStayBookingCount, 1);
      expect(report.refundedAmount, 500000);
      expect(report.group, 'day');
      expect(report.listingId, '15');

      final req = apiAdapter.requests.single;
      expect(req.path, '/api/host/reports/revenue');
      expect(req.queryParameters['group'], 'day');
      expect(req.queryParameters['listingId'], '15');
    });
  });

  group(
      'Host Widget Tests: Weekend Price, Upload Retry, Calendar Confirm & 320/768dp Responsive',
      () {
    testWidgets(
        'HostListingFormScreen auto-syncs weekendPrice with basePrice until manually overridden, and surfaces amenity/rule errors without swallowing',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var failRules = true;
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/amenities') {
            return jsonResponse({
              'items': [
                {
                  'amenityId': 1,
                  'name': 'Wifi tốc độ cao',
                  'category': 'Cơ bản'
                },
              ],
            });
          }
          if (options.method == 'POST' &&
              options.path == '/api/host/listings') {
            return jsonResponse({
              'listingId': 88,
              ...Map<String, dynamic>.from(options.data as Map),
            }, statusCode: 201);
          }
          if (options.method == 'PATCH' &&
              options.path == '/api/host/listings/88') {
            return jsonResponse({
              'listingId': 88,
              ...Map<String, dynamic>.from(options.data as Map),
            });
          }
          if (options.path == '/api/uploads/presign') {
            return jsonResponse({
              'uploadUrl': 'https://r2.example.com/upload/img1.png',
              'publicUrl': 'https://cdn.example.com/listings/88/img1.png',
              'key': 'listings/88/img1.png',
            });
          }
          if (options.path == '/api/host/listings/88/images' &&
              options.method == 'POST') {
            return jsonResponse({
              'imageId': 901,
              'url': 'https://cdn.example.com/listings/88/img1.png',
              'isCover': true,
              'sortOrder': 0,
            }, statusCode: 201);
          }
          if (options.path == '/api/host/listings/88/amenities') {
            return jsonResponse({
              'amenityIds': [1]
            });
          }
          if (options.path == '/api/host/listings/88/rules') {
            if (failRules) {
              return jsonResponse({
                'message': 'Giờ nhận phòng không hợp lệ từ máy chủ',
              }, statusCode: 422);
            }
            return jsonResponse({'ok': true});
          }
          if (options.path == '/api/host/listings/88/images/analysis') {
            return jsonResponse({
              'listingId': 88,
              'tagTaxonomies': kDefaultImageTagTaxonomies
                  .map((t) => {
                        'code': t.code,
                        'labelVi': t.labelVi,
                        'category': t.category,
                      })
                  .toList(),
              'images': [
                {
                  'imageId': 901,
                  'url': 'https://cdn.example.com/listings/88/img1.png',
                  'isCover': true,
                  'sortOrder': 0,
                  'aiAnalysisStatus': 'pending',
                },
              ],
            });
          }
          return jsonResponse({});
        },
      );

      final r2Adapter = FakeRecordingHttpClientAdapter(
        responder: (_) => ResponseBody.fromString('', 200),
      );
      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final cleanR2 = Dio()..httpClientAdapter = r2Adapter;
      final repo = HostRepository(
        client,
        r2Uploader: HostR2DirectUploader(cleanDio: cleanR2),
      );
      final fakePicker = FakeTestFilePickerService()
        ..nextListingImages = [createValidImageFile(name: 'cover.png')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: const MaterialApp(
            home: HostListingFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Base price auto-syncs weekend price until weekend price is edited
      final baseInput = find.byKey(const Key('listing_base_price_input'));
      final weekendInput = find.byKey(const Key('listing_weekend_price_input'));
      await tester.enterText(baseInput, '3200000');
      await tester.pump();

      final weekendFieldBefore = tester.widget<TextFormField>(weekendInput);
      expect(weekendFieldBefore.controller?.text, '3200000');

      // Manual override on weekend price
      await tester.enterText(weekendInput, '4500000');
      await tester.pump();
      await tester.enterText(baseInput, '3500000');
      await tester.pump();
      expect(
        tester.widget<TextFormField>(weekendInput).controller?.text,
        '4500000',
      );

      // Fill required fields and pick 1 image
      await tester.enterText(
        find.byKey(const Key('listing_title_input')),
        'Villa Hồ Bơi Bãi Sau',
      );
      await tester.enterText(
        find.byKey(const Key('listing_description_input')),
        'Villa rộng rãi sát biển Bãi Sau, có hồ bơi riêng và BBQ.',
      );
      await tester.enterText(
        find.byKey(const Key('listing_address_input')),
        '120 Phan Chu Trinh',
      );

      final pickBtn = find.byKey(const Key('listing_pick_images_btn'));
      await tester.ensureVisible(pickBtn);
      await tester.tap(pickBtn);
      await tester.pumpAndSettle();

      // Submit form -> rules endpoint returns 422 -> error MUST be surfaced, not swallowed!
      final saveBtn = find.byKey(const Key('listing_save_btn'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Giờ nhận phòng không hợp lệ từ máy chủ'),
        findsOneWidget,
      );

      // Now fix rules on server and retry -> updates existing listing #88 without re-creating
      failRules = false;
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Đã cập nhật chỗ nghỉ thành công.'),
        findsOneWidget,
      );
      final postCreateCalls = apiAdapter.requests
          .where((r) => r.method == 'POST' && r.path == '/api/host/listings')
          .length;
      expect(postCreateCalls, 1);
    });

    testWidgets(
        'HostPortalScreen Calendar requires confirmation before bulk update and blocks booked/past dates',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/host/listings/mine') {
            return jsonResponse({
              'items': [
                {
                  'listingId': 10,
                  'title': 'Villa Biển Vũng Tàu',
                  'propertyType': 'villa',
                  'basePrice': 3000000,
                  'maxGuests': 10,
                  'status': 'published',
                },
              ],
            });
          }
          if (options.path == '/api/host/listings/10/calendar' &&
              options.method == 'GET') {
            return jsonResponse({
              'listingId': 10,
              'days': [
                {
                  'date': '2026-10-28',
                  'basePrice': 3000000,
                  'effectivePrice': 3000000,
                  'isAvailable': false,
                  'isBooked': true,
                  'bookingStatus': 'confirmed',
                  'canEdit': false,
                },
                {
                  'date': '2026-10-29',
                  'basePrice': 3000000,
                  'effectivePrice': 3000000,
                  'isAvailable': true,
                  'isBooked': false,
                  'isPast': false,
                  'canEdit': true,
                },
              ],
            });
          }
          if (options.path == '/api/host/listings/10/calendar/bulk' &&
              options.method == 'PATCH') {
            return jsonResponse({'updated': 1});
          }
          return jsonResponse({'items': <dynamic>[]});
        },
      );

      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
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

      final listingCard = find.text('Villa Biển Vũng Tàu');
      if (listingCard.evaluate().isNotEmpty &&
          find
              .byKey(const Key('calendar_listing_dropdown'))
              .evaluate()
              .isEmpty) {
        await tester.tap(listingCard);
        await tester.pumpAndSettle();
      }

      // 1. Tapping booked date 2026-10-28 shows error and does NOT select it
      final bookedDay = find.byKey(const Key('calendar_day_2026-10-28'));
      await tester.ensureVisible(bookedDay);
      await tester.tap(bookedDay);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('đã có khách đặt phòng, không thể chỉnh sửa'),
        findsOneWidget,
      );

      // 2. Tapping editable date 2026-10-29 selects it
      final editableDay = find.byKey(const Key('calendar_day_2026-10-29'));
      await tester.tap(editableDay);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('(1 ngày đã chọn)'),
        findsOneWidget,
      );

      // 3. Tapping "Khóa ngày đã chọn" opens confirmation dialog first
      final lockBtn = find.byKey(const Key('calendar_lock_btn'));
      await tester.ensureVisible(lockBtn);
      await tester.tap(lockBtn);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calendar_bulk_confirm_dialog')),
        findsOneWidget,
      );

      // Confirm dialog -> sends PATCH /api/host/listings/10/calendar/bulk and refreshes
      await tester
          .tap(find.byKey(const Key('calendar_bulk_confirm_submit_btn')));
      await tester.pumpAndSettle();

      final patchCalls = apiAdapter.requests.where(
        (r) =>
            r.method == 'PATCH' &&
            r.path == '/api/host/listings/10/calendar/bulk',
      );
      expect(patchCalls.length, 1);
      expect(patchCalls.single.data['dates'], equals(['2026-10-29']));
      expect(
        find.textContaining('Đã cập nhật lịch lưu trú thành công'),
        findsOneWidget,
      );
    });

    testWidgets(
        'HostPortalScreen renders cleanly at 320dp and 768dp with textScale 1.3 and masks payout bank numbers',
        (tester) async {
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/host/payout-accounts') {
            return jsonResponse({
              'items': [
                {
                  'id': 1,
                  'bankName': 'Vietcombank',
                  'accountHolderName': 'NGUYEN VAN A',
                  'accountNumber': '0071009876543',
                },
              ],
            });
          }
          if (options.path == '/api/host/payouts') {
            return jsonResponse({
              'items': [
                {
                  'payoutId': 101,
                  'amount': 12000000,
                  'status': 'paid',
                  'accountNumber': '0071009876543',
                  'transferReference': 'VCB-101',
                  'createdAt': '2026-10-22',
                },
              ],
            });
          }
          return jsonResponse({'items': <dynamic>[]});
        },
      );
      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client);

      for (final width in [320.0, 360.0, 390.0, 430.0, 768.0]) {
        for (final scale in [1.0, 1.3, 1.6]) {
          await tester.binding.setSurfaceSize(Size(width, 900));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                hostRepositoryProvider.overrideWithValue(repo),
                hostCurrentUserRoleProvider.overrideWithValue('host'),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(scale),
                ),
                child: const MaterialApp(
                  home: HostPortalScreen(
                    initialSection: HostPortalSection.payouts,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Masked account number is shown; raw full account number is NEVER shown
          expect(find.textContaining('****6543'), findsWidgets);
          expect(find.textContaining('0071009876543'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
    });

    testWidgets(
        'HostListingFormScreen retries failed addListingImages without duplicate R2 PUT when uploadedPublicUrl exists',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var failAttachOnce = true;
      var r2PutCount = 0;

      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/host/listings/99' &&
              options.method == 'GET') {
            return jsonResponse({
              'listingId': 99,
              'title': 'Villa Đồi Ngọc Tước',
              'description': 'Mô tả chi tiết villa',
              'addressLine': '20 Thi Sách',
              'ward': 'Phường Thắng Tam',
              'city': 'Vũng Tàu',
              'latitude': 10.34,
              'longitude': 107.09,
              'propertyType': 'villa',
              'roomType': 'entire_place',
              'maxGuests': 8,
              'bedrooms': 4,
              'beds': 4,
              'bathrooms': 4,
              'basePrice': 3000000,
              'weekendPrice': 3500000,
              'status': 'draft',
              'images': <dynamic>[],
              'amenities': <dynamic>[],
            });
          }
          if (options.path == '/api/host/listings/99' &&
              options.method == 'PATCH') {
            return jsonResponse({'listingId': 99, 'status': 'draft'});
          }
          if (options.path == '/api/host/listings/99/amenities') {
            return jsonResponse({'ok': true});
          }
          if (options.path == '/api/host/listings/99/rules') {
            return jsonResponse({'ok': true});
          }
          if (options.path == '/api/uploads/presign') {
            return jsonResponse({
              'uploadUrl': 'https://r2.vt.vn/put-99',
              'publicUrl': 'https://cdn.vt.vn/listings/99/photo.png',
              'key': 'listings/99/photo.png',
            });
          }
          if (options.path == '/api/host/listings/99/images' &&
              options.method == 'POST') {
            if (failAttachOnce) {
              return jsonResponse(
                {'message': 'Lỗi tạm thời khi gắn ảnh vào listing.'},
                statusCode: 500,
              );
            }
            return jsonResponse({
              'items': [
                {
                  'imageId': 701,
                  'imageUrl': 'https://cdn.vt.vn/listings/99/photo.png',
                  'isCover': true,
                  'sortOrder': 0,
                  'tags': <dynamic>[],
                },
              ],
            });
          }
          if (options.path == '/api/host/listings/99/images/701/analyze') {
            return jsonResponse(
              {'message': 'AI Vision tạm quá tải'},
              statusCode: 503,
            );
          }
          return jsonResponse({'items': <dynamic>[]});
        },
      );

      final r2Adapter = FakeRecordingHttpClientAdapter(
        responder: (_) {
          r2PutCount++;
          return ResponseBody.fromString('', 200);
        },
      );
      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final cleanR2 = Dio()..httpClientAdapter = r2Adapter;
      final repo = HostRepository(
        client,
        r2Uploader: HostR2DirectUploader(cleanDio: cleanR2),
      );
      final fakePicker = FakeTestFilePickerService()
        ..nextListingImages = [createValidImageFile(name: 'pool.png')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: const MaterialApp(
            home: HostListingFormScreen(listingId: '99'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pick 1 image and save -> R2 PUT succeeds, POST /images fails (500)
      final pickBtn = find.byKey(const Key('listing_pick_images_btn'));
      await tester.ensureVisible(pickBtn);
      await tester.pumpAndSettle();
      await tester.tap(pickBtn);
      await tester.pumpAndSettle();

      final saveBtn = find.byKey(const Key('listing_save_btn'));
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(r2PutCount, 1);
      expect(
        find.textContaining('một số ảnh tải lên R2 thất bại'),
        findsOneWidget,
      );

      // Now allow POST /images to succeed, tap per-image retry -> reuses uploadedPublicUrl without 2nd R2 PUT!
      failAttachOnce = false;
      final retryBtn = find.widgetWithText(TextButton, 'Thử lại').first;
      await tester.ensureVisible(retryBtn);
      await tester.pumpAndSettle();
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(r2PutCount, 1);
      expect(find.textContaining('AI Vision tạm quá tải'), findsWidgets);
    });

    testWidgets(
        'HostPortalScreen synchronizes monochrome icons, NotificationBell, logout & home actions across desktop and mobile',
        (tester) async {
      final adapter = FakeRecordingHttpClientAdapter(
        responder: (_) => jsonResponse({'items': <dynamic>[]}),
      );
      final client = DioClient()..dio.httpClientAdapter = adapter;
      final repo = HostRepository(client, roleResolver: () => 'host');
      final fakePicker = FakeTestFilePickerService();

      // Desktop viewport (1280x900)
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: const MaterialApp(
            home: HostPortalScreen(
              initialSection: HostPortalSection.overview,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // NotificationBell & synchronized logout/home buttons exist on Host Portal
      expect(find.byType(NotificationBell), findsOneWidget);
      expect(find.byKey(const Key('host_portal_home_btn')), findsOneWidget);
      expect(find.byKey(const Key('host_portal_logout_btn')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('host_portal_logout_btn')),
          matching: find.byIcon(AppSemanticIcons.logout),
        ),
        findsOneWidget,
      );

      // Active sidebar item uses monochrome AppColors.iconStrong (#222222)
      final activeSidebarIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('host_sidebar_overview')),
          matching: find.byIcon(AppSemanticIcons.dashboard),
        ),
      );
      expect(activeSidebarIcon.color, AppColors.iconStrong);

      // Switch to Settings -> zero CircleAvatar icon background & uses camera icon
      await tester.tap(find.byKey(const Key('host_sidebar_settings')));
      await tester.pumpAndSettle();
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byIcon(AppSemanticIcons.changeAvatar), findsOneWidget);
    });

    testWidgets(
        'HostPortalScreen Studio Minimalist Overview renders frosted header/dock, grouped Bento KPI cards, and clean booking card without overflow across 320-768dp',
        (tester) async {
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/host/listings/mine') {
            return jsonResponse({
              'items': [
                {'listingId': 1, 'title': 'Villa 1', 'status': 'published'},
                {'listingId': 2, 'title': 'Villa 2', 'status': 'published'},
                {'listingId': 3, 'title': 'Villa 3', 'status': 'published'},
              ],
            });
          }
          if (options.path == '/api/host/bookings') {
            return jsonResponse({
              'items': [
                {
                  'bookingId': 22,
                  'listingTitle': 'Ocean Pearl Garden Villa Bãi Trước',
                  'guestName': 'ĐẶNG KIM AN',
                  'guestPhone': '0909123456',
                  'guestsCount': 2,
                  'checkInDate': '2026-10-29',
                  'checkOutDate': '2026-10-31',
                  'totalPrice': 7900000,
                  'status': 'payment_expired',
                  'paymentStatus': 'expired',
                },
                {
                  'bookingId': 21,
                  'listingTitle': 'Palm Beach Villa Bãi Sau',
                  'guestName': 'Trần Minh Quân',
                  'guestsCount': 6,
                  'checkInDate': '2026-11-05',
                  'checkOutDate': '2026-11-07',
                  'totalPrice': 12500000,
                  'status': 'confirmed',
                  'paymentStatus': 'paid',
                },
              ],
            });
          }
          if (options.path == '/api/host/payout-accounts') {
            return jsonResponse({
              'items': [
                {
                  'id': 1,
                  'bankName': 'Vietcombank',
                  'accountHolderName': 'CHU NHA VT',
                  'accountNumber': '0071001122334',
                },
              ],
            });
          }
          if (options.path == '/api/host/reports/revenue') {
            return jsonResponse({
              'totals': {'hostRevenue': 0},
              'series': <dynamic>[],
            });
          }
          return jsonResponse({'items': <dynamic>[]});
        },
      );
      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client, roleResolver: () => 'host');
      final fakePicker = FakeTestFilePickerService();

      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final width in [320.0, 360.0, 390.0, 430.0, 768.0]) {
        for (final scale in [1.0, 1.3, 1.6]) {
          await tester.binding.setSurfaceSize(Size(width, 900));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                hostRepositoryProvider.overrideWithValue(repo),
                hostFilePickerProvider.overrideWithValue(fakePicker),
                hostCurrentUserRoleProvider.overrideWithValue('host'),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(scale),
                ),
                child: const MaterialApp(
                  home: HostPortalScreen(
                    initialSection: HostPortalSection.overview,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }

      // Inspect detailed Studio layout at standard 390dp mobile viewport
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: const MaterialApp(
            home: HostPortalScreen(
              initialSection: HostPortalSection.overview,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Frosted header + frosted bottom dock
      expect(find.byType(BackdropFilter), findsAtLeastNWidgets(2));
      expect(find.byKey(const Key('host_bottom_navigation')), findsOneWidget);

      // Manual 'Tải lại' icon button is removed on Overview (RefreshIndicator preserved)
      expect(find.byTooltip('Tải lại'), findsNothing);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Grouped Bento KPI cards + circular arrowUpRight affordances
      expect(find.byKey(const Key('host_overview_kpi_group')), findsOneWidget);
      expect(find.byType(HostStudioKpiCard), findsNWidgets(4));
      expect(find.byIcon(LucideIcons.arrowUpRight), findsAtLeastNWidgets(4));

      // Recent bookings group + tidy booking card #22
      expect(
        find.byKey(const Key('host_overview_recent_bookings_group')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('host_booking_card_22')), findsOneWidget);
      expect(find.text('#22'), findsOneWidget);
      expect(
        find.text('Ocean Pearl Garden Villa Bãi Trước'),
        findsOneWidget,
      );
      expect(find.text('ĐẶNG KIM AN · 2 khách'), findsOneWidget);
      expect(find.text('29/10/2026 → 31/10/2026'), findsOneWidget);
      expect(find.textContaining('7.900.000'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets(
        'HostPortalScreen Properties section renders AppImage thumbnails, Lucide sort chevron, filter pills, and >=48dp targets without overflow across 320-768dp',
        (tester) async {
      final allItems = [
        {
          'listingId': 105,
          'title': 'Ocean Pearl Garden Villa Bãi Trước',
          'addressLine': '15 Quang Trung',
          'ward': 'Phường 1',
          'district': 'Thành phố Vũng Tàu',
          'city': 'Vũng Tàu',
          'propertyType': 'villa',
          'basePrice': 3800000,
          'weekendPrice': 4900000,
          'maxGuests': 14,
          'status': 'published',
          'imageUrl': 'assets/images/343vothisau.jpg',
        },
        {
          'listingId': 106,
          'title': 'Sunset Pool Villa Bãi Sau',
          'addressLine': '88 Thùy Vân',
          'ward': 'Phường 2',
          'city': 'Vũng Tàu',
          'propertyType': 'villa',
          'basePrice': 4200000,
          'maxGuests': 10,
          'status': 'published',
          'images': [
            {
              'url': 'assets/images/sunset.jpg',
              'isCover': true,
            },
          ],
        },
        {
          'listingId': 107,
          'title': 'Cozy Studio Homestay',
          'addressLine': '12 Hạ Long',
          'ward': 'Phường 2',
          'city': 'Vũng Tàu',
          'propertyType': 'homestay',
          'basePrice': 1500000,
          'maxGuests': 4,
          'status': 'rejected',
          'rejectionReason': 'Thiếu ảnh phòng tắm thực tế.',
        },
      ];

      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/host/listings/mine') {
            final statusFilter = options.queryParameters['status']?.toString();
            final filtered = (statusFilter == null || statusFilter.isEmpty)
                ? allItems
                : allItems
                    .where((item) => item['status'] == statusFilter)
                    .toList();
            return jsonResponse({'items': filtered});
          }
          return jsonResponse({'items': <dynamic>[]});
        },
      );
      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client, roleResolver: () => 'host');
      final fakePicker = FakeTestFilePickerService();

      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final width in [320.0, 360.0, 390.0, 430.0, 768.0]) {
        for (final scale in [1.0, 1.3, 1.6]) {
          await tester.binding.setSurfaceSize(Size(width, 900));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                hostRepositoryProvider.overrideWithValue(repo),
                hostFilePickerProvider.overrideWithValue(fakePicker),
                hostCurrentUserRoleProvider.overrideWithValue('host'),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(scale),
                ),
                child: const MaterialApp(
                  home: HostPortalScreen(
                    initialSection: HostPortalSection.properties,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }

      // Detailed assertions at 390x844 mobile viewport
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: const MaterialApp(
            home: HostPortalScreen(
              initialSection: HostPortalSection.properties,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // AppImage renders seeded cover assets cleanly (zero 'Chưa có ảnh' text)
      expect(find.text('Chưa có ảnh'), findsNothing);
      expect(find.byType(AppImage), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byKey(const Key('host_listing_item_105')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('host_listing_item_106')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );

      // Sort dropdown uses LucideIcons.chevronDown and zero Material Icons.arrow_drop_down
      expect(find.byKey(const Key('listing_sort_dropdown')), findsOneWidget);
      expect(find.byIcon(LucideIcons.chevronDown), findsWidgets);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);

      // Duplicate body 'Thêm chỗ nghỉ' button is removed (top header '+' quick button handles adding)
      expect(find.byKey(const Key('properties_add_new_btn')), findsNothing);

      // Touch targets >= 48dp
      expect(
        tester
            .getSize(
                find.byKey(const Key('host_portal_add_property_quick_btn')))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(const Key('listing_filter_all'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(const Key('listing_edit_btn_105'))).height,
        greaterThanOrEqualTo(48),
      );

      // Filtering by 'Chờ duyệt' (0 items) preserves overall KPI total ('3') via snapshot
      final pendingFilter =
          find.byKey(const Key('listing_filter_pending_approval'));
      await tester.ensureVisible(pendingFilter);
      await tester.pumpAndSettle();
      await tester.tap(pendingFilter);
      await tester.pumpAndSettle();
      expect(find.text('Chưa có chỗ nghỉ phù hợp bộ lọc.'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets(
        'Guests and Reports sections use capsule pill borders and naked monochrome icons cleanly',
        (tester) async {
      final todayIso = getVietnamTodayDateString();
      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/host/bookings') {
            return jsonResponse({
              'items': [
                {
                  'bookingId': 501,
                  'guestName': 'Nguyễn Minh',
                  'guestPhone': '0901234567',
                  'listingId': 105,
                  'listingTitle': 'The Palm Villa',
                  'checkInDate': todayIso,
                  'checkOutDate': todayIso,
                  'guestsCount': 2,
                  'totalPrice': 3500000,
                  'status': 'confirmed',
                },
              ],
            });
          }
          if (options.path == '/api/host/reports/revenue') {
            return jsonResponse({
              'grossRevenue': 4550000,
              'platformRevenue': 420000,
              'hostRevenue': 4130000,
              'bookingCount': 1,
              'series': <dynamic>[],
            });
          }
          return jsonResponse({'items': <dynamic>[]});
        },
      );
      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client, roleResolver: () => 'host');
      final fakePicker = FakeTestFilePickerService();

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: const MaterialApp(
            home: HostPortalScreen(
              initialSection: HostPortalSection.guests,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Gọi điện and Nhắn tin buttons use StadiumBorder (full capsule pill)
      final callBtn = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Gọi điện'),
          matching: find.bySubtype<OutlinedButton>(),
        ),
      );
      final msgBtn = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Nhắn tin'),
          matching: find.bySubtype<FilledButton>(),
        ),
      );
      expect(
        callBtn.style?.shape?.resolve({}),
        isA<StadiumBorder>(),
      );
      expect(
        msgBtn.style?.shape?.resolve({}),
        isA<StadiumBorder>(),
      );

      // Open the guest status filter modal
      await tester.tap(find.text('Tất cả khách hàng'));
      await tester.pumpAndSettle();

      expect(find.text('Lọc theo trạng thái khách'), findsOneWidget);
      expect(find.text('Đã xác nhận'), findsWidgets);
      expect(find.text('Quá hạn thanh toán'), findsOneWidget);
      expect(find.text('Đã hủy'), findsOneWidget);

      // Close button has >= 48dp hit target and uses LucideIcons.x
      final closeBtn = find.widgetWithIcon(IconButton, LucideIcons.x);
      expect(closeBtn, findsOneWidget);
      expect(tester.getSize(closeBtn).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(closeBtn).height, greaterThanOrEqualTo(48));

      // Select 'Quá hạn thanh toán' and verify modal closes and updates trigger text cleanly
      await tester.tap(find.text('Quá hạn thanh toán'));
      await tester.pumpAndSettle();
      expect(find.text('Lọc theo trạng thái khách'), findsNothing);
      expect(find.text('Quá hạn thanh toán'), findsOneWidget);

      // Also verify Reports section renders capsule segmented switcher and dropdowns cleanly
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: MaterialApp(
            home: HostPortalScreen(
              key: UniqueKey(),
              initialSection: HostPortalSection.reports,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('30 ngày'), findsWidgets);
      expect(find.text('90 ngày'), findsWidgets);
      expect(find.text('1 năm'), findsWidgets);
      expect(find.byKey(const Key('reports_listing_filter_dropdown')),
          findsOneWidget);

      // Verify redundant inner titles and manual 'Tải lại' icon buttons are removed in Bookings, Payouts, and Calendar
      for (final section in [
        HostPortalSection.bookings,
        HostPortalSection.payouts,
        HostPortalSection.calendar,
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(repo),
              hostFilePickerProvider.overrideWithValue(fakePicker),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: MaterialApp(
              home: HostPortalScreen(
                key: UniqueKey(),
                initialSection: section,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Tải lại'), findsNothing);
        expect(
          find.text('Tổng quan lịch chỗ nghỉ & tình trạng phòng'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    });

    test(
        'Host booking status helper separates financial overlays from lifecycle filters accurately',
        () async {
      final now = DateTime.utc(2026, 11, 4, 5, 0); // 2026-11-04 12:00 VN

      // 1. Completed booking with payout_paid / payout_pending STILL matches 'completed' ("Hoàn tất")
      final completedPaidOut = <String, dynamic>{
        'bookingId': 801,
        'status': 'completed',
        'persistedStatus': 'completed',
        'internalStatus': 'completed',
        'paymentStatus': 'paid',
        'payoutStatus': 'paid',
        'checkedInAt': '2026-10-20T07:00:00Z',
        'checkedOutAt': '2026-10-22T05:00:00Z',
      };
      final dispCompleted = getBookingDisplayStatus(
        completedPaidOut,
        role: BookingActionRole.host,
        now: now,
      );
      expect(dispCompleted.normalizedStatus, 'completed');
      expect(dispCompleted.code, 'payout_paid');
      expect(dispCompleted.label, 'Hoàn tất · Đã chi trả');
      expect(
        bookingMatchesDisplayStatus(completedPaidOut, 'completed', now: now),
        isTrue,
      );
      expect(
        bookingMatchesDisplayStatus(completedPaidOut, 'checked_out', now: now),
        isTrue,
      );
      expect(
        bookingMatchesDisplayStatus(completedPaidOut, 'cancelled', now: now),
        isFalse,
      );

      final checkedOutPendingPayout = <String, dynamic>{
        'bookingId': 802,
        'status': 'checked_out',
        'payoutStatus': 'pending',
      };
      expect(
        bookingMatchesDisplayStatus(
          checkedOutPendingPayout,
          'completed',
          now: now,
        ),
        isTrue,
      );

      // 2. Checked-in booking matches 'checked_in' ("Khách đã nhận phòng")
      final checkedIn = <String, dynamic>{
        'bookingId': 803,
        'status': 'checked_in',
        'paymentStatus': 'paid',
        'checkInDate': '2026-11-03',
        'checkOutDate': '2026-11-05',
      };
      final dispCheckedInHost = getBookingDisplayStatus(
        checkedIn,
        role: BookingActionRole.host,
        now: now,
      );
      final dispCheckedInGuest = getBookingDisplayStatus(
        checkedIn,
        role: BookingActionRole.guest,
        now: now,
      );
      expect(dispCheckedInHost.normalizedStatus, 'checked_in');
      expect(dispCheckedInHost.label, 'Khách đã nhận phòng');
      expect(dispCheckedInGuest.label, 'Đã nhận phòng');
      expect(
        bookingMatchesDisplayStatus(checkedIn, 'checked_in', now: now),
        isTrue,
      );

      // 3. Cancelled / Rejected bookings with refund STILL match 'cancelled' ("Đã hủy")
      for (final cancelledCase in <Map<String, dynamic>>[
        {
          'bookingId': 804,
          'status': 'cancelled_by_guest',
          'paymentStatus': 'refunded',
          'refundStatus': 'succeeded',
        },
        {
          'bookingId': 805,
          'status': 'cancelled_by_host',
          'paymentStatus': 'paid',
          'refundStatus': 'pending',
        },
        {
          'bookingId': 806,
          'status': 'cancelled_by_admin',
          'paymentStatus': 'refunded',
        },
        {
          'bookingId': 807,
          'status': 'rejected',
          'paymentStatus': 'paid',
          'refundStatus': 'processing',
        },
      ]) {
        expect(
          bookingMatchesDisplayStatus(cancelledCase, 'cancelled', now: now),
          isTrue,
          reason:
              'Booking #${cancelledCase['bookingId']} must remain in Đã hủy even with refund status',
        );
        expect(
          bookingMatchesDisplayStatus(cancelledCase, 'completed', now: now),
          isFalse,
        );
        expect(isSuccessfulHostBooking(cancelledCase, now), isFalse);
        expect(isCalendarBlockingHostBooking(cancelledCase, now), isFalse);
      }

      // 4. Unpaid pending_payment hold past lockedUntil resolves to 'payment_expired'
      final expiredHold = <String, dynamic>{
        'bookingId': 808,
        'status': 'pending_payment',
        'paymentStatus': 'unpaid',
        'lockedUntil': '2026-11-04T04:30:00Z',
      };
      expect(
        getEffectiveBookingLifecycleStatus(expiredHold, now),
        'payment_expired',
      );
      expect(
        bookingMatchesDisplayStatus(expiredHold, 'payment_expired', now: now),
        isTrue,
      );
      expect(
        bookingMatchesDisplayStatus(expiredHold, 'pending_payment', now: now),
        isFalse,
      );
      expect(isSuccessfulHostBooking(<String, dynamic>{}, now), isFalse);

      // 5. Guest partition excludes cancelled/expired/completed from default Hôm nay & Sắp tới
      final partitionAll = partitionHostGuestBookings(
        [
          checkedIn,
          completedPaidOut,
          {
            'bookingId': 809,
            'status': 'cancelled_by_guest',
            'checkInDate': '2026-11-04',
            'checkOutDate': '2026-11-06',
          },
          {
            'bookingId': 810,
            'status': 'confirmed',
            'paymentStatus': 'paid',
            'checkInDate': '2026-11-10',
            'checkOutDate': '2026-11-12',
          },
        ],
        statusFilter: 'all',
        now: now,
      );
      expect(
        partitionAll.todayBookings.map((b) => b['bookingId']).toList(),
        [803],
      );
      expect(
        partitionAll.upcomingBookings.map((b) => b['bookingId']).toList(),
        [810],
      );

      // 6. Multi-page getAllHostBookings fetches remaining pages and deduplicates by bookingId
      final pageAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/host/bookings') {
            final page =
                int.tryParse('${options.queryParameters['page'] ?? 1}') ?? 1;
            if (page == 1) {
              return jsonResponse({
                'items': [
                  {'bookingId': 903, 'status': 'confirmed'},
                  {'bookingId': 902, 'status': 'checked_in'},
                ],
                'pagination': {
                  'page': 1,
                  'limit': 2,
                  'total': 3,
                  'totalPages': 2,
                },
              });
            }
            return jsonResponse({
              'items': [
                {'bookingId': 902, 'status': 'checked_in'},
                {
                  'bookingId': 901,
                  'status': 'completed',
                  'payoutStatus': 'paid',
                },
              ],
              'pagination': {
                'page': 2,
                'limit': 2,
                'total': 3,
                'totalPages': 2,
              },
            });
          }
          return jsonResponse({'items': <dynamic>[]});
        },
      );
      final repo = HostRepository(
        DioClient()..dio.httpClientAdapter = pageAdapter,
      );
      final allBookings = await repo.getAllHostBookings(pageSize: 2);
      expect(allBookings.map((b) => b['bookingId']).toList(), [903, 902, 901]);
    });

    testWidgets(
        'Host Bookings and Guests sections filter Khách đã nhận phòng, Hoàn tất, Đã hủy, and Quá hạn thanh toán accurately',
        (tester) async {
      final todayIso = getVietnamTodayDateString();
      final futureDate = DateTime.now()
          .toUtc()
          .add(const Duration(days: 7, hours: 7))
          .toIso8601String()
          .split('T')
          .first;

      final sampleBookings = <Map<String, dynamic>>[
        {
          'bookingId': 701,
          'listingId': 105,
          'listingTitle': 'Ocean Pearl Villa',
          'guestName': 'Lê Hoàng Nam',
          'guestPhone': '0901112233',
          'guestsCount': 4,
          'checkInDate': todayIso,
          'checkOutDate': futureDate,
          'totalPrice': 6800000,
          'status': 'checked_in',
          'paymentStatus': 'paid',
        },
        {
          'bookingId': 702,
          'listingId': 105,
          'listingTitle': 'Ocean Pearl Villa',
          'guestName': 'Phạm Thu Hà',
          'guestsCount': 2,
          'checkInDate': '2026-09-10',
          'checkOutDate': '2026-09-12',
          'totalPrice': 5200000,
          'status': 'completed',
          'paymentStatus': 'paid',
          'payoutStatus': 'paid',
          'checkedInAt': '2026-09-10T07:00:00Z',
          'checkedOutAt': '2026-09-12T05:00:00Z',
        },
        {
          'bookingId': 703,
          'listingId': 105,
          'listingTitle': 'Ocean Pearl Villa',
          'guestName': 'Vũ Quốc Bảo',
          'guestsCount': 3,
          'checkInDate': todayIso,
          'checkOutDate': futureDate,
          'totalPrice': 4500000,
          'status': 'cancelled_by_guest',
          'paymentStatus': 'refunded',
          'refundStatus': 'succeeded',
        },
        {
          'bookingId': 704,
          'listingId': 105,
          'listingTitle': 'Ocean Pearl Villa',
          'guestName': 'Đặng Ngọc Mai',
          'guestsCount': 5,
          'checkInDate': futureDate,
          'checkOutDate': futureDate,
          'totalPrice': 8100000,
          'status': 'rejected',
          'paymentStatus': 'paid',
          'refundStatus': 'pending',
        },
        {
          'bookingId': 705,
          'listingId': 105,
          'listingTitle': 'Ocean Pearl Villa',
          'guestName': 'Hoàng Gia Huy',
          'guestsCount': 2,
          'checkInDate': futureDate,
          'checkOutDate': futureDate,
          'totalPrice': 3900000,
          'status': 'pending_payment',
          'paymentStatus': 'unpaid',
          'lockedUntil': '2020-01-01T00:00:00Z',
        },
      ];

      final apiAdapter = FakeRecordingHttpClientAdapter(
        responder: (options) {
          if (options.path == '/api/host/bookings') {
            return jsonResponse({'items': sampleBookings});
          }
          return jsonResponse({'items': <dynamic>[]});
        },
      );
      final client = DioClient()..dio.httpClientAdapter = apiAdapter;
      final repo = HostRepository(client, roleResolver: () => 'host');
      final fakePicker = FakeTestFilePickerService();

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // A. Verify HostPortalSection.bookings category chips
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: const MaterialApp(
            home: HostPortalScreen(
              initialSection: HostPortalSection.bookings,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Khách đã nhận phòng"
      final chipCheckedIn = find.byKey(const Key('booking_chip_checked_in'));
      await tester.ensureVisible(chipCheckedIn);
      await tester.tap(chipCheckedIn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('host_booking_card_701')), findsOneWidget);
      expect(find.byKey(const Key('host_booking_card_702')), findsNothing);
      expect(find.byKey(const Key('host_booking_card_703')), findsNothing);

      // Tap "Hoàn tất" -> must include payout_paid completed booking #702
      final chipCompleted = find.byKey(const Key('booking_chip_completed'));
      await tester.ensureVisible(chipCompleted);
      await tester.tap(chipCompleted);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('host_booking_card_702')), findsOneWidget);
      expect(find.text('Hoàn tất · Đã chi trả'), findsOneWidget);
      expect(find.byKey(const Key('host_booking_card_701')), findsNothing);

      // Tap "Đã hủy" -> must include refunded guest-cancelled #703 AND refund-pending rejected #704
      final chipCancelled = find.byKey(const Key('booking_chip_cancelled'));
      await tester.ensureVisible(chipCancelled);
      await tester.tap(chipCancelled);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('host_booking_card_703')), findsOneWidget);
      expect(find.byKey(const Key('host_booking_card_704')), findsOneWidget);
      expect(find.text('Khách đã hủy · Đã hoàn tiền'), findsOneWidget);
      expect(find.text('Host đã từ chối · Chờ hoàn tiền'), findsOneWidget);
      expect(find.byKey(const Key('host_booking_card_705')), findsNothing);

      // Tap "Quá hạn thanh toán" -> must include expired hold #705
      final chipExpired = find.byKey(const Key('booking_chip_payment_expired'));
      await tester.ensureVisible(chipExpired);
      await tester.tap(chipExpired);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('host_booking_card_705')), findsOneWidget);
      expect(find.byKey(const Key('host_booking_card_703')), findsNothing);

      // B. Verify HostPortalSection.guests default Hôm nay + status filter modal
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(repo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
            hostCurrentUserRoleProvider.overrideWithValue('host'),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              textScaler: TextScaler.linear(1.4),
            ),
            child: MaterialApp(
              home: HostPortalScreen(
                key: UniqueKey(),
                initialSection: HostPortalSection.guests,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Default 'Tất cả khách hàng' + 'Hôm nay' shows active checked_in #701, NOT cancelled #703
      expect(find.text('Lê Hoàng Nam'), findsOneWidget);
      expect(find.text('Vũ Quốc Bảo'), findsNothing);

      // Filter by "Hoàn tất" in Guests modal -> shows historical completed #702
      await tester.tap(find.text('Tất cả khách hàng'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guest_status_option_completed')));
      await tester.pumpAndSettle();
      expect(find.text('Phạm Thu Hà'), findsOneWidget);
      expect(find.text('Lê Hoàng Nam'), findsNothing);

      // Filter by "Đã hủy" in Guests modal -> shows #703 and #704
      await tester.tap(find.text('Hoàn tất'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guest_status_option_cancelled')));
      await tester.pumpAndSettle();
      expect(find.text('Vũ Quốc Bảo'), findsOneWidget);
      expect(find.text('Đặng Ngọc Mai'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // 8. GROUP 1: HOST PORTAL & KYC 7 BUGS + 1.3x–2.0x FONT SCALING VERIFICATION
  // ===========================================================================
  group('Group 1: Host Portal & KYC 7 Bugs + 1.3x–2.0x Font Scaling', () {
    test(
      'Item 1 & 2 (Unit): HostListingStatus.rejected, internalStatus fallback, HostListingSummary, validate(isCreate: false), and toUpdateJson(includeStatus)',
      () {
        expect(
          HostListingStatus.fromApi('rejected'),
          HostListingStatus.rejected,
        );
        expect(HostListingStatus.rejected.labelVi, 'Bị từ chối');
        expect(
          HostListingStatus.fromListingMap({
            'status': 'draft',
            'internalStatus': 'rejected',
          }),
          HostListingStatus.rejected,
        );

        final summary = HostListingSummary.fromJson({
          'listingId': 301,
          'title': 'Villa Đồi Sứ Bãi Trước',
          'status': 'draft',
          'internalStatus': 'rejected',
          'rejectionReason': 'Ảnh bìa chứa số điện thoại cá nhân.',
          'propertyType': 'villa',
          'basePrice': 3900000,
          'maxGuests': 12,
        });
        expect(summary.id, '301');
        expect(summary.status, HostListingStatus.rejected);
        expect(
          summary.rejectionReason,
          'Ảnh bìa chứa số điện thoại cá nhân.',
        );

        const publishedDto = HostListingUpsertDto(
          title: 'Villa Biển Đang Hiển Thị',
          description: 'Mô tả hợp lệ đầy đủ tiện nghi cao cấp.',
          addressLine: '10 Thùy Vân',
          ward: 'Phường Thắng Tam',
          city: 'Vũng Tàu',
          latitude: 10.34,
          longitude: 107.09,
          propertyType: HostPropertyType.villa,
          roomType: HostRoomType.entirePlace,
          maxGuests: 10,
          bedrooms: 4,
          beds: 5,
          bathrooms: 4,
          basePrice: 4000000,
          weekendPrice: 4500000,
          status: HostListingStatus.published,
        );

        // Create mode blocks 'published', edit mode allows 'published', 'hidden', 'rejected'
        expect(publishedDto.validate(isCreate: true), isNotNull);
        expect(publishedDto.validate(isCreate: false), isNull);

        // Normal "Lưu thay đổi" omits status; explicit targetStatus includes status
        final patchWithoutStatus =
            publishedDto.toUpdateJson(includeStatus: false);
        expect(patchWithoutStatus.containsKey('status'), isFalse);

        final patchWithStatus = publishedDto.toUpdateJson(
          includeStatus: true,
          nextStatus: HostListingStatus.pendingApproval,
        );
        expect(patchWithStatus['status'], 'pending_approval');
      },
    );

    testWidgets(
      'Item 1 (Widget): HostListingFormScreen edits published/hidden listings without status transition and shows Lưu & Gửi duyệt for rejected listing',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String currentServerStatus = 'published';
        String? currentInternalStatus;
        final patchPayloads = <Map<String, dynamic>>[];

        final apiAdapter = FakeRecordingHttpClientAdapter(
          responder: (options) {
            if (options.path == '/api/host/listings/501' &&
                options.method == 'GET') {
              return jsonResponse({
                'listingId': 501,
                'title': 'Villa Biển Bãi Sau',
                'description': 'Biệt thự sát biển đầy đủ hồ bơi riêng.',
                'addressLine': '88 Thùy Vân',
                'ward': 'Phường 2',
                'city': 'Vũng Tàu',
                'latitude': 10.34,
                'longitude': 107.09,
                'propertyType': 'villa',
                'roomType': 'entire_place',
                'maxGuests': 10,
                'bedrooms': 4,
                'beds': 5,
                'bathrooms': 4,
                'basePrice': 3600000,
                'weekendPrice': 4200000,
                'status': currentServerStatus,
                if (currentInternalStatus != null)
                  'internalStatus': currentInternalStatus,
                'images': [
                  {
                    'imageId': 1,
                    'url': 'assets/images/343vothisau.jpg',
                    'isCover': true,
                    'sortOrder': 0,
                  },
                ],
                'amenities': <dynamic>[],
              });
            }
            if (options.path == '/api/host/listings/501' &&
                options.method == 'PATCH') {
              final data = Map<String, dynamic>.from(options.data as Map);
              patchPayloads.add(data);
              return jsonResponse({
                'listingId': 501,
                'status': data['status'] ?? currentServerStatus,
              });
            }
            if (options.path == '/api/host/listings/501/amenities' ||
                options.path == '/api/host/listings/501/rules') {
              return jsonResponse({'ok': true});
            }
            return jsonResponse({'items': <dynamic>[]});
          },
        );

        final client = DioClient()..dio.httpClientAdapter = apiAdapter;
        final repo = HostRepository(client, roleResolver: () => 'host');
        final fakePicker = FakeTestFilePickerService();

        // A. Published listing: "Lưu & Gửi duyệt" hidden; "Lưu thay đổi" omits status
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(repo),
              hostFilePickerProvider.overrideWithValue(fakePicker),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: const MaterialApp(
              home: HostListingFormScreen(listingId: '501'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('listing_submit_approval_btn')),
          findsNothing,
        );
        final saveBtn = find.byKey(const Key('listing_save_btn'));
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(patchPayloads, hasLength(1));
        expect(patchPayloads.single.containsKey('status'), isFalse);

        // B. Hidden listing: "Lưu & Gửi duyệt" also hidden
        currentServerStatus = 'hidden';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(repo),
              hostFilePickerProvider.overrideWithValue(fakePicker),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: MaterialApp(
              home: HostListingFormScreen(
                key: UniqueKey(),
                listingId: '501',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('listing_submit_approval_btn')),
          findsNothing,
        );

        // C. Rejected listing: "Lưu & Gửi duyệt" visible and sends status: 'pending_approval'
        currentServerStatus = 'draft';
        currentInternalStatus = 'rejected';
        patchPayloads.clear();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(repo),
              hostFilePickerProvider.overrideWithValue(fakePicker),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: MaterialApp(
              key: UniqueKey(),
              home: HostListingFormScreen(
                key: UniqueKey(),
                listingId: '501',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final submitApprovalBtn =
            find.byKey(const Key('listing_submit_approval_btn'));
        expect(submitApprovalBtn, findsOneWidget);
        await tester.ensureVisible(submitApprovalBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitApprovalBtn);
        await tester.pumpAndSettle();

        expect(patchPayloads, hasLength(1));
        expect(patchPayloads.single['status'], 'pending_approval');
      },
    );

    testWidgets(
      'Item 2 & 3: getMyListings paginates all pages, Properties rejected tab shows reason & Gửi duyệt lại (never Hiện), and _allListingsSnapshot stays decoupled',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var rejectedSubmitted = false;
        final patchRequests = <Map<String, dynamic>>[];

        final page1Items = <Map<String, dynamic>>[
          {
            'listingId': 201,
            'title': 'Palm Ocean Villa 1',
            'propertyType': 'villa',
            'basePrice': 3500000,
            'maxGuests': 10,
            'status': 'published',
          },
          {
            'listingId': 202,
            'title': 'Palm Hidden Homestay',
            'propertyType': 'homestay',
            'basePrice': 1800000,
            'maxGuests': 4,
            'status': 'hidden',
          },
        ];

        Map<String, dynamic> buildRejectedItem() => {
              'listingId': 203,
              'title': 'Villa Cần Bổ Sung Ảnh',
              'propertyType': 'villa',
              'basePrice': 4100000,
              'maxGuests': 12,
              'status': rejectedSubmitted ? 'pending_approval' : 'rejected',
              'internalStatus':
                  rejectedSubmitted ? 'pending_approval' : 'rejected',
              'rejectionReason': rejectedSubmitted
                  ? null
                  : 'Thiếu hình ảnh mặt tiền và hồ bơi thực tế.',
            };

        final apiAdapter = FakeRecordingHttpClientAdapter(
          responder: (options) {
            if (options.path == '/api/host/listings/mine' &&
                options.method == 'GET') {
              final statusFilter =
                  options.queryParameters['status']?.toString();
              final page =
                  int.tryParse('${options.queryParameters['page'] ?? 1}') ?? 1;
              final allItems = [...page1Items, buildRejectedItem()];
              if (statusFilter != null && statusFilter.isNotEmpty) {
                final filtered = allItems
                    .where((item) => item['status'] == statusFilter)
                    .toList();
                return jsonResponse({
                  'items': filtered,
                  'pagination': {
                    'page': 1,
                    'limit': 50,
                    'total': filtered.length,
                    'totalPages': 1,
                  },
                });
              }
              if (page == 1) {
                return jsonResponse({
                  'items': page1Items,
                  'pagination': {
                    'page': 1,
                    'limit': 2,
                    'total': 3,
                    'totalPages': 2,
                  },
                });
              }
              return jsonResponse({
                'items': [buildRejectedItem()],
                'pagination': {
                  'page': 2,
                  'limit': 2,
                  'total': 3,
                  'totalPages': 2,
                },
              });
            }
            if (options.path == '/api/host/listings/203' &&
                options.method == 'PATCH') {
              final body = Map<String, dynamic>.from(options.data as Map);
              patchRequests.add(body);
              if (body['status'] == 'pending_approval') {
                rejectedSubmitted = true;
              }
              return jsonResponse(buildRejectedItem());
            }
            return jsonResponse({'items': <dynamic>[]});
          },
        );

        final client = DioClient()..dio.httpClientAdapter = apiAdapter;
        final repo = HostRepository(client, roleResolver: () => 'host');

        // Verify multi-page getMyListings fetches page 1 + page 2 (total 3 listings)
        final multiPageItems =
            (await tester.runAsync(() => repo.getMyListings(limit: 2)))!;
        expect(multiPageItems.length, 3);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(repo),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: const MaterialApp(
              home: HostPortalScreen(
                initialSection: HostPortalSection.properties,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Filter by "Bị từ chối"
        final rejectedTab = find.byKey(const Key('listing_filter_rejected'));
        await tester.ensureVisible(rejectedTab);
        await tester.tap(rejectedTab);
        await tester.pumpAndSettle();

        expect(find.text('Villa Cần Bổ Sung Ảnh'), findsOneWidget);
        expect(find.text('Palm Ocean Villa 1'), findsNothing);
        expect(
          find.byKey(const Key('listing_rejection_reason_203')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Thiếu hình ảnh mặt tiền và hồ bơi thực tế.'),
          findsOneWidget,
        );
        expect(find.text('Chỉnh sửa'), findsOneWidget);
        expect(find.text('Gửi duyệt lại'), findsOneWidget);
        // Rejected listing MUST NEVER render "Hiện" toggle button
        expect(
          find.byKey(const Key('listing_toggle_visibility_btn_203')),
          findsNothing,
        );

        // Tap "Gửi duyệt lại" -> sends PATCH {status: 'pending_approval'} and preserves _allListingsSnapshot (total = 3)
        await tester
            .tap(find.byKey(const Key('listing_submit_approval_btn_203')));
        await tester.pumpAndSettle();

        expect(patchRequests, hasLength(1));
        expect(patchRequests.single['status'], 'pending_approval');
        // Snapshot still knows there are 3 total listings even while filtered on 'rejected' (now 0 items)
        expect(find.text('3'), findsWidgets);
      },
    );

    testWidgets(
      'Item 4: getMyPayouts paginates all pages, Chờ xử lý sums ONLY pending/approved/processing (excludes rejected/failed/cancelled), and renders all status tabs',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final page1Payouts = [
          {
            'payoutId': 1,
            'amount': 1000000,
            'status': 'pending',
            'accountNumber': '0071001112223',
            'createdAt': '2026-10-25',
          },
          {
            'payoutId': 2,
            'amount': 2000000,
            'status': 'approved',
            'accountNumber': '0071001112223',
            'createdAt': '2026-10-26',
          },
          {
            'payoutId': 3,
            'amount': 3000000,
            'status': 'processing',
            'accountNumber': '0071001112223',
            'createdAt': '2026-10-27',
          },
        ];
        final page2Payouts = [
          {
            'payoutId': 4,
            'amount': 10000000,
            'status': 'paid',
            'accountNumber': '0071001112223',
            'createdAt': '2026-10-28',
          },
          {
            'payoutId': 5,
            'amount': 5000000,
            'status': 'rejected',
            'accountNumber': '0071001112223',
            'createdAt': '2026-10-29',
          },
          {
            'payoutId': 6,
            'amount': 4000000,
            'status': 'failed',
            'accountNumber': '0071001112223',
            'createdAt': '2026-10-30',
          },
          {
            'payoutId': 7,
            'amount': 6000000,
            'status': 'cancelled',
            'accountNumber': '0071001112223',
            'createdAt': '2026-10-31',
          },
        ];

        final apiAdapter = FakeRecordingHttpClientAdapter(
          responder: (options) {
            if (options.path == '/api/host/payout-accounts') {
              return jsonResponse({'items': <dynamic>[]});
            }
            if (options.path == '/api/host/payouts') {
              final page =
                  int.tryParse('${options.queryParameters['page'] ?? 1}') ?? 1;
              return jsonResponse({
                'items': page == 1 ? page1Payouts : page2Payouts,
                'pagination': {
                  'page': page,
                  'limit': 3,
                  'total': 7,
                  'totalPages': 2,
                },
              });
            }
            return jsonResponse({'items': <dynamic>[]});
          },
        );

        final client = DioClient()..dio.httpClientAdapter = apiAdapter;
        final repo = HostRepository(client, roleResolver: () => 'host');

        final allPayouts =
            (await tester.runAsync(() => repo.getMyPayouts(limit: 3)))!;
        expect(allPayouts.length, 7);
        final summary = computeHostPayoutSummary(allPayouts);
        expect(summary.totalPaid, 10000000);
        // MUST equal 1M + 2M + 3M = 6M (never includes 5M rejected, 4M failed, 6M cancelled)
        expect(summary.totalPending, 6000000);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(repo),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: const MaterialApp(
              home: HostPortalScreen(
                initialSection: HostPortalSection.payouts,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('6.000.000'), findsWidgets);
        expect(find.textContaining('21.000.000'), findsNothing);

        // Verify filter chips & Vietnamese labels for processing, failed, cancelled
        expect(
          find.byKey(const Key('payout_filter_chip_processing')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('payout_filter_chip_failed')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('payout_filter_chip_cancelled')),
          findsOneWidget,
        );
        expect(find.text('Đang chuyển'), findsWidgets);
        expect(find.text('Thất bại'), findsWidgets);
        expect(find.text('Đã hủy'), findsWidgets);

        final failedChip = find.byKey(const Key('payout_filter_chip_failed'));
        await tester.ensureVisible(failedChip);
        await tester.tap(failedChip);
        await tester.pumpAndSettle();
        expect(find.textContaining('#6'), findsOneWidget);
        expect(find.textContaining('#4'), findsNothing);
      },
    );

    testWidgets(
      'Item 5: Calendar Month Grid allows editing cancelled/rejected/expired booking days and prioritizes isBooked before isToday on today cell',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Unit check on HostCalendarDay.fromJson
        final cancelledDay = HostCalendarDay.fromJson({
          'date': '2026-12-10',
          'basePrice': 2500000,
          'effectivePrice': 2500000,
          'isAvailable': true,
          'isBooked': false,
          'bookingStatus': 'cancelled_by_guest',
          'canEdit': true,
        });
        expect(cancelledDay.isBooked, isFalse);
        expect(cancelledDay.isEditable(), isTrue);

        final now = DateTime.now().toUtc().add(const Duration(hours: 7));
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final altDayNum = now.day == 15 ? 16 : 15;
        final altDateStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${altDayNum.toString().padLeft(2, '0')}';

        final apiAdapter = FakeRecordingHttpClientAdapter(
          responder: (options) {
            if (options.path == '/api/host/listings/mine') {
              return jsonResponse({
                'items': [
                  {
                    'listingId': 10,
                    'title': 'Villa Lịch Tháng',
                    'propertyType': 'villa',
                    'basePrice': 3000000,
                    'maxGuests': 8,
                    'status': 'published',
                  },
                ],
              });
            }
            if (options.path == '/api/host/listings/10/calendar') {
              return jsonResponse({
                'listingId': 10,
                'days': [
                  {
                    'date': todayStr,
                    'basePrice': 3000000,
                    'effectivePrice': 3000000,
                    'isAvailable': false,
                    'isBooked': true,
                    'bookingStatus': 'confirmed',
                    'isPast': false,
                    'canEdit': false,
                  },
                  {
                    'date': altDateStr,
                    'basePrice': 3000000,
                    'effectivePrice': 3000000,
                    'isAvailable': true,
                    'isBooked': false,
                    'bookingStatus': 'cancelled_by_guest',
                    'isPast': false,
                    'canEdit': true,
                  },
                ],
              });
            }
            return jsonResponse({'items': <dynamic>[]});
          },
        );

        final client = DioClient()..dio.httpClientAdapter = apiAdapter;
        final repo = HostRepository(client, roleResolver: () => 'host');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(repo),
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

        // Today is booked -> must use booked bg Color(0xFFF8FAFC) (not unbooked today pink 0xFFFFF1F2) while keeping AppColors.primary border!
        final todayCellFinder = find.byKey(Key('calendar_day_$todayStr'));
        expect(todayCellFinder, findsOneWidget);
        final todayContainer = tester.widget<Container>(
          find
              .descendant(
                of: todayCellFinder,
                matching: find.byType(Container),
              )
              .first,
        );
        final todayDecoration = todayContainer.decoration! as BoxDecoration;
        expect(todayDecoration.color, const Color(0xFFF8FAFC));
        expect(
          (todayDecoration.border! as Border).top.color,
          AppColors.primary,
        );

        // Non-blocking cancelled_by_guest date remains selectable!
        final cancelledCellFinder =
            find.byKey(Key('calendar_day_$altDateStr'));
        await tester.ensureVisible(cancelledCellFinder);
        await tester.pumpAndSettle();
        await tester.tap(cancelledCellFinder);
        await tester.pumpAndSettle();
        expect(find.textContaining('(1 ngày đã chọn)'), findsOneWidget);
      },
    );

    testWidgets(
      'Item 6: getListingReviews uses /api/host/listings/:id/reviews (with 404 fallback) and Reports renders pendingStayHostRevenue & pendingStayBookingCount',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final apiAdapter = FakeRecordingHttpClientAdapter(
          responder: (options) {
            if (options.path == '/api/host/listings/77/reviews') {
              return jsonResponse({
                'items': [
                  {
                    'reviewId': 1,
                    'reviewerName': 'Trần Thanh',
                    'rating': 5,
                    'comment': 'Đánh giá trên chỗ nghỉ đang ẩn vẫn tải được!',
                  },
                ],
              });
            }
            if (options.path == '/api/host/listings/88/reviews') {
              return jsonResponse({'message': 'Not found'}, statusCode: 404);
            }
            if (options.path == '/api/listings/88/reviews') {
              return jsonResponse({
                'items': [
                  {'reviewId': 2, 'reviewerName': 'Fallback Guest', 'rating': 4},
                ],
              });
            }
            if (options.path == '/api/host/listings/mine') {
              return jsonResponse({
                'items': [
                  {
                    'listingId': 77,
                    'title': 'Hidden Pool Villa',
                    'status': 'hidden',
                  },
                ],
              });
            }
            if (options.path == '/api/host/reports/revenue') {
              return jsonResponse({
                'totals': {
                  'grossRevenue': 20000000,
                  'platformRevenue': 2000000,
                  'hostRevenue': 18000000,
                  'pendingStayRevenue': 9000000,
                  'pendingStayHostRevenue': 8100000,
                  'pendingStayBookingCount': 2,
                  'bookingCount': 3,
                },
                'series': <dynamic>[],
              });
            }
            return jsonResponse({'items': <dynamic>[]});
          },
        );

        final client = DioClient()..dio.httpClientAdapter = apiAdapter;
        final repo = HostRepository(client, roleResolver: () => 'host');

        // 1. Primary host reviews endpoint works for hidden/draft/rejected listings
        final hiddenReviews =
            (await tester.runAsync(() => repo.getListingReviews('77')))!;
        expect(hiddenReviews, hasLength(1));
        expect(
          apiAdapter.requests.first.path,
          '/api/host/listings/77/reviews',
        );

        // 2. Fallback to public reviews endpoint when host endpoint returns 404
        final fallbackReviews =
            (await tester.runAsync(() => repo.getListingReviews('88')))!;
        expect(fallbackReviews, hasLength(1));

        // 3. Reports UI renders pendingStayHostRevenue & pendingStayBookingCount card
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(repo),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: const MaterialApp(
              home: HostPortalScreen(
                initialSection: HostPortalSection.reports,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('reports_pending_stay_card')),
          findsOneWidget,
        );
        expect(
          find.text('Doanh thu chờ hoàn tất lưu trú'),
          findsOneWidget,
        );
        expect(
          find.text('2 đơn đang & sắp lưu trú'),
          findsOneWidget,
        );
        expect(find.textContaining('8.100.000'), findsOneWidget);
      },
    );

    testWidgets(
      'Item 7a & 7b: Identity KYC rejects PDF (allows image only) and Host Messages materializes support chat + calls markConversationRead + handles 404 no online admin',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 7a. Identity KYC rejects PDF while Business License still accepts PDF
        final pdfFile = HostPickedFile(
          name: 'cccd_front.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 1024,
          bytes: Uint8List(1024),
        );
        final pngFile = createValidImageFile(
          name: 'cccd_front.png',
          mimeType: 'image/png',
        );
        expect(
          validateIdentityKycPickedFile(pdfFile),
          contains('không hỗ trợ tệp PDF'),
        );
        expect(validateIdentityKycPickedFile(pngFile), isNull);

        final badIdentityDto = HostKycSubmissionDto(
          contactName: 'Nguyễn Văn Host',
          contactEmail: 'host@vt.vn',
          phone: '0901234567',
          profileType: HostProfileType.individual,
          documentType: HostDocumentType.passport,
          businessAddress: '12 Thùy Vân, Vũng Tàu',
          identitySingle: pdfFile,
        );
        expect(
          badIdentityDto.validate(),
          contains('không hỗ trợ tệp PDF'),
        );

        // 7b. Support chat & markConversationRead
        var adminOnline = false;
        final apiAdapter = FakeRecordingHttpClientAdapter(
          responder: (options) {
            if (options.path == '/api/conversations' &&
                options.method == 'GET') {
              return jsonResponse({
                'items': [
                  {
                    'id': '502',
                    'conversationId': '502',
                    'guestName': 'Khách Lê Minh',
                    'otherParticipant': {
                      'fullName': 'Khách Lê Minh',
                      'role': 'guest',
                    },
                    'lastMessage': {
                      'content': 'Cho mình hỏi giờ nhận phòng nhé',
                      'createdAt': '2026-11-01T10:00:00Z',
                    },
                    'unreadCount': 3,
                  },
                ],
              });
            }
            if (options.path == '/api/conversations/502/read' &&
                options.method == 'PATCH') {
              return jsonResponse({'ok': true});
            }
            if (options.path == '/api/conversations/502/messages' &&
                options.method == 'GET') {
              return jsonResponse({'items': <dynamic>[]});
            }
            if (options.path == '/api/conversations' &&
                options.method == 'POST') {
              final data = Map<String, dynamic>.from(options.data as Map);
              if (data['support'] == true) {
                if (!adminOnline) {
                  return jsonResponse(
                    {'message': 'No active admin found'},
                    statusCode: 404,
                  );
                }
                return jsonResponse({
                  'id': '777',
                  'conversationId': '777',
                  'otherParticipant': {
                    'fullName': 'Quản trị viên Hỗ trợ',
                    'role': 'admin',
                  },
                  'unreadCount': 0,
                }, statusCode: 201);
              }
            }
            if (options.path == '/api/conversations/777/read' &&
                options.method == 'PATCH') {
              return jsonResponse({'ok': true});
            }
            if (options.path == '/api/conversations/777/messages' &&
                options.method == 'GET') {
              return jsonResponse({
                'items': [
                  {
                    'messageId': 'm777',
                    'content': 'Xin chào, Admin đang hỗ trợ bạn!',
                    'isMe': false,
                    'createdAt': '2026-11-01T10:05:00Z',
                  },
                ],
              });
            }
            if (options.path.contains('admin_support')) {
              return jsonResponse(
                {'message': 'Invalid non-numeric id admin_support'},
                statusCode: 422,
              );
            }
            return jsonResponse({'items': <dynamic>[]});
          },
        );

        final client = DioClient()..dio.httpClientAdapter = apiAdapter;
        final repo = HostRepository(client, roleResolver: () => 'host');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(repo),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: const MaterialApp(
              home: HostPortalScreen(
                initialSection: HostPortalSection.messages,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Unread badge '3' visible before opening
        expect(find.text('3'), findsOneWidget);

        // Open numeric conversation '502' -> calls PATCH /api/conversations/502/read
        await tester.tap(find.text('Khách Lê Minh'));
        await tester.pumpAndSettle();
        expect(
          apiAdapter.requests.any(
            (r) =>
                r.method == 'PATCH' && r.path == '/api/conversations/502/read',
          ),
          isTrue,
        );

        // Return to list -> unread badge '3' is now cleared
        await tester.tap(find.byTooltip('Quay lại danh sách'));
        await tester.pumpAndSettle();
        expect(find.text('3'), findsNothing);

        // Open Support section and tap support_chat_with_admin_btn while adminOnline == false (404) -> friendly Vietnamese state, ZERO calls to admin_support
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(repo),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: MaterialApp(
              home: HostPortalScreen(
                key: UniqueKey(),
                initialSection: HostPortalSection.support,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final supportBtnOffline =
            find.byKey(const Key('support_chat_with_admin_btn'));
        await tester.ensureVisible(supportBtnOffline);
        await tester.pumpAndSettle();
        await tester.tap(supportBtnOffline);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Hiện chưa có Quản trị viên trực tuyến'),
          findsOneWidget,
        );
        expect(
          apiAdapter.requests.any((r) => r.path.contains('admin_support')),
          isFalse,
        );

        // Now bring Admin online and tap support_chat_with_admin_btn -> materializes real numeric conversation '777'
        adminOnline = true;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(repo),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: MaterialApp(
              home: HostPortalScreen(
                key: UniqueKey(),
                initialSection: HostPortalSection.support,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final supportBtnOnline =
            find.byKey(const Key('support_chat_with_admin_btn'));
        await tester.ensureVisible(supportBtnOnline);
        await tester.pumpAndSettle();
        await tester.tap(supportBtnOnline);
        await tester.pumpAndSettle();

        expect(
          apiAdapter.requests.any(
            (r) =>
                r.method == 'POST' &&
                r.path == '/api/conversations' &&
                (r.data as Map)['support'] == true,
          ),
          isTrue,
        );
        expect(find.text('Xin chào, Admin đang hỗ trợ bạn!'), findsOneWidget);
        expect(
          apiAdapter.requests.any((r) => r.path.contains('admin_support')),
          isFalse,
        );
      },
    );

    testWidgets(
      'Item 7c: Host font-scaling (1.3x–2.0x) prevents overflow on Voice Recording bar, Chat Composer bar (usable TextField width), Review 58x58 score box, and HostStudioInitialsBadge',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final apiAdapter = FakeRecordingHttpClientAdapter(
          responder: (options) {
            if (options.path == '/api/conversations' &&
                options.method == 'GET') {
              return jsonResponse({
                'items': [
                  {
                    'id': '901',
                    'conversationId': '901',
                    'guestName': 'Nguyễn Thị Bảo Trâm',
                    'otherParticipant': {'fullName': 'Nguyễn Thị Bảo Trâm'},
                    'lastMessage': {'content': 'Xin chào Host'},
                  },
                ],
              });
            }
            if (options.path == '/api/host/listings/mine') {
              return jsonResponse({
                'items': [
                  {
                    'listingId': 1,
                    'title': 'The Palm Oceanfront Villa',
                    'status': 'published',
                  },
                ],
              });
            }
            if (options.path == '/api/host/listings/1/reviews') {
              return jsonResponse({
                'items': [
                  {
                    'reviewId': 10,
                    'reviewerName': 'Trần Hoàng Minh',
                    'rating': 5,
                    'comment': 'Rất tuyệt vời!',
                  },
                ],
              });
            }
            return jsonResponse({'items': <dynamic>[]});
          },
        );

        final client = DioClient()..dio.httpClientAdapter = apiAdapter;
        final repo = HostRepository(client, roleResolver: () => 'host');

        await tester.binding.setSurfaceSize(const Size(320, 800));
        for (final scale in [1.3, 2.0]) {
          // 1. Narrow 320px chat detail view + active voice recording bar at 1.3x & 2.0x
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                hostRepositoryProvider.overrideWithValue(repo),
                hostCurrentUserRoleProvider.overrideWithValue('host'),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: MaterialApp(
                  home: HostPortalScreen(
                    key: UniqueKey(),
                    initialSection: HostPortalSection.messages,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Nguyễn Thị Bảo Trâm').first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Check TextField retains usable width even at 2.0x on 320px viewport
          final inputSize =
              tester.getSize(find.byKey(const Key('host_message_input')));
          expect(
            inputSize.width,
            greaterThanOrEqualTo(95),
            reason:
                'Chat TextField width (${inputSize.width}) must stay usable at scale=$scale',
          );

          // Toggle voice recording bar -> must not overflow Row at 1.3x or 2.0x!
          await tester.tap(find.byKey(const Key('chat_mic_btn')));
          await tester.pump();
          expect(find.byType(HostVoiceRecordingBar), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Cancel recording cleanly so timer is disposed
          await tester
              .tap(find.byKey(const Key('host_voice_recording_cancel_btn')));
          await tester.pump();
          expect(tester.takeException(), isNull);

          // 2. Reviews 58x58 score box & HostStudioInitialsBadge at 1.3x & 2.0x
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                hostRepositoryProvider.overrideWithValue(repo),
                hostCurrentUserRoleProvider.overrideWithValue('host'),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: MaterialApp(
                  home: HostPortalScreen(
                    key: UniqueKey(),
                    initialSection: HostPortalSection.reviews,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('5.0'), findsOneWidget);
          expect(find.byType(HostStudioInitialsBadge), findsWidgets);
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
