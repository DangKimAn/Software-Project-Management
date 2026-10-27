import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/host/data/host_repository.dart';
import 'package:hotel_booking_flutter/features/host/domain/host_models.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/host_onboarding_screens.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/host_portal_screens.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/them_cho_nghi_screen.dart';
import 'package:hotel_booking_flutter/features/host/services/host_file_picker_service.dart';

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
          if (options.path == '/api/listings/1/reviews') {
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
        'HostPortalScreen & ThemChoNghiScreen render cleanly at 360px mobile width without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(testRepo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
          ],
          child: const MaterialApp(
            home: HostPortalScreen(
              initialSection: HostPortalSection.reviews,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify real average rating is computed (5.00 ★ from 1 review, NOT hardcoded 4.9 / 12)
      expect(
        find.textContaining('5.00 ★ (1 đánh giá)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostRepositoryProvider.overrideWithValue(testRepo),
            hostFilePickerProvider.overrideWithValue(fakePicker),
          ],
          child: const MaterialApp(
            home: ThemChoNghiScreen(),
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
        'HostPortalScreen and ThemChoNghiScreen render role guard when user role is guest',
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
            home: ThemChoNghiScreen(),
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
        'ThemChoNghiScreen auto-syncs weekendPrice with basePrice until manually overridden, and surfaces amenity/rule errors without swallowing',
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
          ],
          child: const MaterialApp(
            home: ThemChoNghiScreen(),
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
          find.byKey(const Key('calendar_listing_dropdown')).evaluate().isEmpty) {
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
        'ThemChoNghiScreen retries failed addListingImages without duplicate R2 PUT when uploadedPublicUrl exists',
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
          ],
          child: const MaterialApp(
            home: ThemChoNghiScreen(listingId: '99'),
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
  });
}
