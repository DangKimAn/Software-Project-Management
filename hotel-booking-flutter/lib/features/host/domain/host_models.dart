import 'dart:typed_data';
import 'package:dio/dio.dart';

/// Allowed file upload limits and MIME types per backend validator.
const int kMaxHostUploadBytes = 5 * 1024 * 1024; // 5MB
const int kMaxListingImagesCount = 30;
const int kMaxKycFilesCount = 4;

const Set<String> kAllowedKycMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
};

const Set<String> kAllowedListingImageMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
};

/// Represents a real file selected from the user's device.
class HostPickedFile {
  final String name;
  final String mimeType;
  final int sizeBytes;
  final Uint8List bytes;
  final String? path;

  const HostPickedFile({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.bytes,
    this.path,
  });

  bool get isPdf =>
      mimeType.toLowerCase() == 'application/pdf' ||
      name.toLowerCase().endsWith('.pdf');

  bool get isImage => mimeType.toLowerCase().startsWith('image/');

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }
}

/// Validates a KYC document file according to backend multer/express-validator rules.
String? validateKycPickedFile(HostPickedFile file) {
  if (file.name.trim().isEmpty) {
    return 'Tên tệp không hợp lệ.';
  }
  if (file.sizeBytes <= 0 || file.bytes.isEmpty) {
    return 'Tệp "${file.name}" rỗng hoặc không đọc được dữ liệu.';
  }
  if (file.sizeBytes > kMaxHostUploadBytes) {
    return 'Tệp "${file.name}" vượt quá giới hạn 5MB (${file.formattedSize}).';
  }
  final normalizedMime = file.mimeType.trim().toLowerCase();
  if (!kAllowedKycMimeTypes.contains(normalizedMime)) {
    return 'Định dạng "${file.name}" ($normalizedMime) không hỗ trợ. Chỉ chấp nhận JPG, PNG, WebP hoặc PDF.';
  }
  return null;
}

/// Validates a listing image file according to backend uploads validator.
String? validateListingImagePickedFile(HostPickedFile file) {
  if (file.name.trim().isEmpty) {
    return 'Tên ảnh không hợp lệ.';
  }
  if (file.sizeBytes <= 0 || file.bytes.isEmpty) {
    return 'Ảnh "${file.name}" rỗng hoặc không đọc được dữ liệu.';
  }
  if (file.sizeBytes > kMaxHostUploadBytes) {
    return 'Ảnh "${file.name}" vượt quá dung lượng tối đa 5MB (${file.formattedSize}).';
  }
  final normalizedMime = file.mimeType.trim().toLowerCase();
  if (!kAllowedListingImageMimeTypes.contains(normalizedMime)) {
    return 'Ảnh "${file.name}" không đúng định dạng JPG, PNG, WebP hoặc GIF.';
  }
  return null;
}

// ============================================================================
// BUG-10: HOST APPLICATION & KYC MODELS
// ============================================================================

enum HostApplicationStatus {
  none,
  pending,
  approved,
  rejected,
  revoked,
  supplementRequired;

  static HostApplicationStatus fromApi(dynamic raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'pending':
      case 'submitted':
      case 'under_review':
        return HostApplicationStatus.pending;
      case 'approved':
      case 'verified':
        return HostApplicationStatus.approved;
      case 'rejected':
        return HostApplicationStatus.rejected;
      case 'revoked':
        return HostApplicationStatus.revoked;
      case 'supplement_required':
      case 'needs_more_info':
      case 'action_required':
        return HostApplicationStatus.supplementRequired;
      case 'none':
      default:
        return HostApplicationStatus.none;
    }
  }

  String get apiValue {
    switch (this) {
      case HostApplicationStatus.none:
        return 'none';
      case HostApplicationStatus.pending:
        return 'pending';
      case HostApplicationStatus.approved:
        return 'approved';
      case HostApplicationStatus.rejected:
        return 'rejected';
      case HostApplicationStatus.revoked:
        return 'revoked';
      case HostApplicationStatus.supplementRequired:
        return 'supplement_required';
    }
  }

  String get labelVi {
    switch (this) {
      case HostApplicationStatus.none:
        return 'Chưa đăng ký';
      case HostApplicationStatus.pending:
        return 'Đang chờ duyệt';
      case HostApplicationStatus.approved:
        return 'Đã phê duyệt';
      case HostApplicationStatus.rejected:
        return 'Bị từ chối';
      case HostApplicationStatus.revoked:
        return 'Đã thu hồi quyền Host';
      case HostApplicationStatus.supplementRequired:
        return 'Yêu cầu bổ sung hồ sơ';
    }
  }
}

enum HostProfileType {
  individual('individual', 'Cá nhân'),
  business('business', 'Doanh nghiệp / Hộ kinh doanh');

  final String value;
  final String labelVi;
  const HostProfileType(this.value, this.labelVi);

  static HostProfileType fromApi(String? raw) {
    if (raw?.trim().toLowerCase() == 'business') {
      return HostProfileType.business;
    }
    return HostProfileType.individual;
  }
}

enum HostDocumentType {
  cccd('cccd', 'Căn cước công dân (CCCD)'),
  cmnd('cmnd', 'Chứng minh nhân dân (CMND)'),
  passport('passport', 'Hộ chiếu (Passport)'),
  driverLicense('driver_license', 'Giấy phép lái xe (GPLX)');

  final String value;
  final String labelVi;
  const HostDocumentType(this.value, this.labelVi);

  static HostDocumentType fromApi(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'cmnd':
        return HostDocumentType.cmnd;
      case 'passport':
        return HostDocumentType.passport;
      case 'driver_license':
        return HostDocumentType.driverLicense;
      case 'cccd':
      default:
        return HostDocumentType.cccd;
    }
  }

  bool get requiresFrontAndBack =>
      this == HostDocumentType.cccd || this == HostDocumentType.cmnd;

  bool get requiresFrontOnlyWithOptionalBack =>
      this == HostDocumentType.driverLicense;

  bool get requiresSingleDocument => this == HostDocumentType.passport;
}

class HostIdentityAiResult {
  final String documentType;
  final String side;
  final String? idNumber;
  final String? fullName;
  final String? dateOfBirth;
  final String? gender;
  final String? nationality;
  final String? placeOfOrigin;
  final String? placeOfResidence;
  final String? expiryDate;
  final String? issueDate;
  final String? issuePlace;
  final String? mrz;
  final bool isClear;
  final bool isDocumentValid;
  final double confidence;
  final List<String> warnings;
  final String summaryVi;

  const HostIdentityAiResult({
    required this.documentType,
    required this.side,
    this.idNumber,
    this.fullName,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.placeOfOrigin,
    this.placeOfResidence,
    this.expiryDate,
    this.issueDate,
    this.issuePlace,
    this.mrz,
    this.isClear = true,
    this.isDocumentValid = true,
    this.confidence = 1.0,
    this.warnings = const [],
    this.summaryVi = '',
  });

  factory HostIdentityAiResult.fromJson(Map<String, dynamic> json) {
    return HostIdentityAiResult(
      documentType: json['documentType']?.toString() ?? 'cccd',
      side: json['side']?.toString() ?? 'front',
      idNumber: json['idNumber']?.toString(),
      fullName: json['fullName']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      gender: json['gender']?.toString(),
      nationality: json['nationality']?.toString(),
      placeOfOrigin: json['placeOfOrigin']?.toString(),
      placeOfResidence: json['placeOfResidence']?.toString(),
      expiryDate: json['expiryDate']?.toString(),
      issueDate: json['issueDate']?.toString(),
      issuePlace: json['issuePlace']?.toString(),
      mrz: json['mrz']?.toString(),
      isClear: json['isClear'] == true,
      isDocumentValid: json['isDocumentValid'] == true,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      summaryVi: json['summaryVi']?.toString() ?? '',
    );
  }

  /// Extracts the effective identification number from [idNumber] or from [mrz] (e.g. IDVNM012345678901).
  String? get effectiveIdNumber {
    if (idNumber != null && idNumber!.trim().isNotEmpty) {
      return idNumber!.trim();
    }
    if (mrz != null && mrz!.isNotEmpty) {
      final match = RegExp(r'IDVNM(\d{9,12})', caseSensitive: false).firstMatch(mrz!);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }
}

class HostApplicationDocument {
  final String documentType;
  final String fileUrl;
  final String? originalFilename;
  final String? mimeType;
  final int? fileSize;

  const HostApplicationDocument({
    required this.documentType,
    required this.fileUrl,
    this.originalFilename,
    this.mimeType,
    this.fileSize,
  });

  factory HostApplicationDocument.fromJson(Map<String, dynamic> json) {
    return HostApplicationDocument(
      documentType:
          (json['documentType'] ?? json['document_type'] ?? 'identity')
              .toString(),
      fileUrl:
          (json['fileUrl'] ?? json['file_url'] ?? json['url'] ?? '').toString(),
      originalFilename:
          (json['originalFilename'] ?? json['original_filename'])?.toString(),
      mimeType: (json['mimeType'] ?? json['mime_type'])?.toString(),
      fileSize: json['fileSize'] is num
          ? (json['fileSize'] as num).toInt()
          : int.tryParse('${json['fileSize'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
        'documentType': documentType,
        'fileUrl': fileUrl,
        if (originalFilename != null) 'originalFilename': originalFilename,
        if (mimeType != null) 'mimeType': mimeType,
        if (fileSize != null) 'fileSize': fileSize,
      };
}

class HostApplicationRecord {
  final int? id;
  final HostApplicationStatus status;
  final String contactName;
  final String contactEmail;
  final String phone;
  final HostProfileType profileType;
  final HostDocumentType documentType;
  final String businessAddress;
  final String? note;
  final String? rejectReason;
  final String? reviewedAt;
  final String? createdAt;
  final String? updatedAt;
  final List<HostApplicationDocument> documents;

  const HostApplicationRecord({
    this.id,
    required this.status,
    required this.contactName,
    required this.contactEmail,
    required this.phone,
    required this.profileType,
    required this.documentType,
    required this.businessAddress,
    this.note,
    this.rejectReason,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
    this.documents = const [],
  });

  factory HostApplicationRecord.fromApiResponse(Map<String, dynamic> payload) {
    final appMap = payload['application'] is Map<String, dynamic>
        ? payload['application'] as Map<String, dynamic>
        : payload['verification'] is Map<String, dynamic>
            ? payload['verification'] as Map<String, dynamic>
            : payload;

    final rawStatus = payload['status'] ??
        payload['hostApplicationStatus'] ??
        appMap['status'] ??
        appMap['hostApplicationStatus'] ??
        'none';

    final rawDocs = appMap['documents'];
    final docs = <HostApplicationDocument>[];
    if (rawDocs is List) {
      for (final item in rawDocs) {
        if (item is Map<String, dynamic>) {
          docs.add(HostApplicationDocument.fromJson(item));
        } else if (item is Map<Object?, Object?>) {
          docs.add(
            HostApplicationDocument.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawId =
        appMap['id'] ?? appMap['applicationId'] ?? appMap['verificationId'];
    return HostApplicationRecord(
      id: rawId is num ? rawId.toInt() : int.tryParse('${rawId ?? ''}'),
      status: HostApplicationStatus.fromApi(rawStatus),
      contactName:
          (appMap['contactName'] ?? appMap['fullName'] ?? '').toString(),
      contactEmail:
          (appMap['contactEmail'] ?? appMap['email'] ?? '').toString(),
      phone: (appMap['phone'] ?? appMap['contactPhone'] ?? '').toString(),
      profileType: HostProfileType.fromApi(
        (appMap['profileType'] ?? appMap['entityType'])?.toString(),
      ),
      documentType: HostDocumentType.fromApi(
        appMap['documentType']?.toString(),
      ),
      businessAddress: (appMap['businessAddress'] ?? '').toString(),
      note: (appMap['note'] ?? appMap['notes'])?.toString(),
      rejectReason:
          (appMap['rejectReason'] ?? appMap['rejectionReason'])?.toString(),
      reviewedAt: appMap['reviewedAt']?.toString(),
      createdAt: (appMap['createdAt'] ?? appMap['submittedAt'])?.toString(),
      updatedAt: appMap['updatedAt']?.toString(),
      documents: docs,
    );
  }
}

/// DTO for `POST /api/host/applications` (`multipart/form-data`).
class HostKycSubmissionDto {
  final String contactName;
  final String contactEmail;
  final String phone;
  final HostProfileType profileType;
  final HostDocumentType documentType;
  final String businessAddress;
  final String note;
  final HostPickedFile? identityFront;
  final HostPickedFile? identityBack;
  final HostPickedFile? identitySingle;
  final HostPickedFile? businessLicense;

  const HostKycSubmissionDto({
    required this.contactName,
    required this.contactEmail,
    required this.phone,
    required this.profileType,
    required this.documentType,
    required this.businessAddress,
    this.note = '',
    this.identityFront,
    this.identityBack,
    this.identitySingle,
    this.businessLicense,
  });

  static final RegExp _vnPhoneRegex = RegExp(r'^(0|\+84)[0-9]{9}$');
  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Validates all fields & files against backend `host-applications.validator.ts`.
  String? validate() {
    final trimmedName = contactName.trim();
    if (trimmedName.isEmpty) {
      return 'Vui lòng nhập họ và tên người liên hệ.';
    }
    if (trimmedName.length > 120) {
      return 'Họ và tên không được vượt quá 120 ký tự.';
    }

    final trimmedEmail = contactEmail.trim();
    if (trimmedEmail.isNotEmpty && !_emailRegex.hasMatch(trimmedEmail)) {
      return 'Email liên hệ không hợp lệ.';
    }

    final normalizedPhone = phone.trim().replaceAll(' ', '');
    if (normalizedPhone.isEmpty) {
      return 'Vui lòng nhập số điện thoại liên hệ.';
    }
    if (!_vnPhoneRegex.hasMatch(normalizedPhone)) {
      return 'Số điện thoại phải gồm 10 chữ số bắt đầu bằng 0 hoặc +84.';
    }

    final trimmedAddress = businessAddress.trim();
    if (trimmedAddress.isEmpty) {
      return 'Vui lòng nhập địa chỉ kinh doanh / chỗ nghỉ.';
    }
    if (trimmedAddress.length > 500) {
      return 'Địa chỉ kinh doanh không được vượt quá 500 ký tự.';
    }

    if (note.trim().length > 2000) {
      return 'Ghi chú không được vượt quá 2000 ký tự.';
    }

    // Document rules by documentType
    switch (documentType) {
      case HostDocumentType.cccd:
      case HostDocumentType.cmnd:
        if (identityFront == null) {
          return 'Vui lòng chọn ảnh mặt trước ${documentType.labelVi}.';
        }
        if (identityBack == null) {
          return 'Vui lòng chọn ảnh mặt sau ${documentType.labelVi}.';
        }
        if (identitySingle != null) {
          return 'Không gửi tệp hộ chiếu khi đã chọn CCCD/CMND.';
        }
        break;
      case HostDocumentType.passport:
        if (identitySingle == null) {
          return 'Vui lòng chọn ảnh hoặc PDF Hộ chiếu (Passport).';
        }
        if (identityFront != null || identityBack != null) {
          return 'Hộ chiếu chỉ sử dụng 1 tệp giấy tờ định danh duy nhất.';
        }
        break;
      case HostDocumentType.driverLicense:
        if (identityFront == null) {
          return 'Vui lòng chọn ảnh mặt trước Giấy phép lái xe.';
        }
        if (identitySingle != null) {
          return 'Không gửi tệp hộ chiếu khi đã chọn Giấy phép lái xe.';
        }
        break;
    }

    // Business license rule by profileType
    if (profileType == HostProfileType.business && businessLicense == null) {
      return 'Hồ sơ Doanh nghiệp / Hộ kinh doanh bắt buộc phải đính kèm Giấy phép kinh doanh.';
    }
    if (profileType == HostProfileType.individual && businessLicense != null) {
      return 'Hồ sơ Cá nhân không đính kèm Giấy phép kinh doanh.';
    }

    // Validate each present file
    final filesToCheck = <HostPickedFile>[
      if (identityFront != null) identityFront!,
      if (identityBack != null) identityBack!,
      if (identitySingle != null) identitySingle!,
      if (businessLicense != null) businessLicense!,
    ];

    if (filesToCheck.isEmpty) {
      return 'Vui lòng đính kèm giấy tờ xác minh danh tính.';
    }
    if (filesToCheck.length > kMaxKycFilesCount) {
      return 'Tối đa $kMaxKycFilesCount tệp đính kèm.';
    }

    for (final file in filesToCheck) {
      final err = validateKycPickedFile(file);
      if (err != null) return err;
    }

    return null;
  }

  /// Builds real `FormData` (`multipart/form-data`) for `POST /api/host/applications`.
  FormData toFormData() {
    final validationError = validate();
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final normalizedPhone = phone.trim().replaceAll(' ', '');
    final fields = <String, dynamic>{
      'contactName': contactName.trim(),
      if (contactEmail.trim().isNotEmpty) 'contactEmail': contactEmail.trim(),
      'phone': normalizedPhone,
      'profileType': profileType.value,
      'businessAddress': businessAddress.trim(),
      'documentType': documentType.value,
      if (note.trim().isNotEmpty) 'note': note.trim(),
    };

    void attachFile(String fieldName, HostPickedFile? picked) {
      if (picked == null) return;
      final parts = picked.mimeType.split('/');
      final mediaType = parts.length == 2
          ? DioMediaType(parts[0], parts[1])
          : DioMediaType('application', 'octet-stream');
      fields[fieldName] = MultipartFile.fromBytes(
        picked.bytes,
        filename: picked.name,
        contentType: mediaType,
      );
    }

    if (documentType == HostDocumentType.passport) {
      attachFile('identitySingle', identitySingle);
    } else {
      attachFile('identityFront', identityFront);
      if (identityBack != null) {
        attachFile('identityBack', identityBack);
      }
    }

    if (profileType == HostProfileType.business && businessLicense != null) {
      attachFile('businessLicense', businessLicense);
    }

    return FormData.fromMap(fields);
  }
}

// ============================================================================
// BUG-11 & BUG-12: HOST LISTINGS, ENUMS, VUNG TAU WARDS & DTOs
// ============================================================================

enum HostListingStatus {
  draft('draft', 'Bản nháp'),
  pendingApproval('pending_approval', 'Chờ duyệt'),
  published('published', 'Đang hiển thị'),
  hidden('hidden', 'Đang ẩn'),
  rejected('rejected', 'Bị từ chối');

  final String value;
  final String labelVi;
  const HostListingStatus(this.value, this.labelVi);

  static HostListingStatus fromApi(dynamic raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'pending_approval':
      case 'pending':
        return HostListingStatus.pendingApproval;
      case 'published':
      case 'active':
      case 'approved':
        return HostListingStatus.published;
      case 'hidden':
      case 'inactive':
      case 'suspended':
        return HostListingStatus.hidden;
      case 'rejected':
        return HostListingStatus.rejected;
      case 'draft':
      default:
        return HostListingStatus.draft;
    }
  }

  bool canTransitionTo(HostListingStatus target, {bool isAdmin = false}) {
    if (isAdmin) return true;
    switch (this) {
      case HostListingStatus.draft:
        return target == HostListingStatus.draft ||
            target == HostListingStatus.pendingApproval;
      case HostListingStatus.pendingApproval:
        return target == HostListingStatus.draft ||
            target == HostListingStatus.pendingApproval;
      case HostListingStatus.published:
        return target == HostListingStatus.published ||
            target == HostListingStatus.hidden;
      case HostListingStatus.hidden:
        return target == HostListingStatus.published ||
            target == HostListingStatus.hidden;
      case HostListingStatus.rejected:
        return target == HostListingStatus.draft;
    }
  }
}

enum HostPropertyType {
  villa('villa', 'Villa'),
  apartment('apartment', 'Căn hộ'),
  homestay('homestay', 'Homestay'),
  hotel('hotel', 'Khách sạn');

  final String value;
  final String labelVi;
  const HostPropertyType(this.value, this.labelVi);

  static HostPropertyType fromApi(dynamic raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final item in HostPropertyType.values) {
      if (item.value == normalized) return item;
    }
    return HostPropertyType.villa;
  }
}

enum HostRoomType {
  entirePlace('entire_place', 'Nguyên căn'),
  privateRoom('private_room', 'Phòng riêng'),
  sharedRoom('shared_room', 'Phòng chung');

  final String value;
  final String labelVi;
  const HostRoomType(this.value, this.labelVi);

  static HostRoomType fromApi(dynamic raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final item in HostRoomType.values) {
      if (item.value == normalized) return item;
    }
    return HostRoomType.entirePlace;
  }
}

enum HostCancellationPolicy {
  flexible('flexible', 'Linh hoạt'),
  moderate('moderate', 'Vừa phải'),
  strict('strict', 'Nghiêm ngặt');

  final String value;
  final String labelVi;
  const HostCancellationPolicy(this.value, this.labelVi);

  static HostCancellationPolicy fromApi(dynamic raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final item in HostCancellationPolicy.values) {
      if (item.value == normalized) return item;
    }
    return HostCancellationPolicy.flexible;
  }
}

class VungTauWard {
  final String name;
  final double latitude;
  final double longitude;

  const VungTauWard({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

const String kVungTauCity = 'Vũng Tàu';
const double kDefaultVungTauLat = 10.3460;
const double kDefaultVungTauLng = 107.0843;

const List<VungTauWard> kVungTauWards = [
  VungTauWard(name: 'Phường 1', latitude: 10.3468, longitude: 107.0748),
  VungTauWard(name: 'Phường 2', latitude: 10.3372, longitude: 107.0846),
  VungTauWard(name: 'Phường 3', latitude: 10.3492, longitude: 107.0835),
  VungTauWard(name: 'Phường 4', latitude: 10.3547, longitude: 107.0789),
  VungTauWard(name: 'Phường 5', latitude: 10.3694, longitude: 107.0672),
  VungTauWard(name: 'Phường 7', latitude: 10.3636, longitude: 107.0845),
  VungTauWard(name: 'Phường 8', latitude: 10.3552, longitude: 107.0954),
  VungTauWard(name: 'Phường 9', latitude: 10.3738, longitude: 107.0853),
  VungTauWard(name: 'Phường 10', latitude: 10.3914, longitude: 107.1157),
  VungTauWard(name: 'Phường 11', latitude: 10.4046, longitude: 107.1292),
  VungTauWard(name: 'Phường 12', latitude: 10.4221, longitude: 107.1489),
  VungTauWard(
      name: 'Phường Thắng Nhất', latitude: 10.3852, longitude: 107.0951),
  VungTauWard(name: 'Phường Thắng Nhì', latitude: 10.3652, longitude: 107.0758),
  VungTauWard(name: 'Phường Thắng Tam', latitude: 10.3426, longitude: 107.0942),
  VungTauWard(
      name: 'Phường Nguyễn An Ninh', latitude: 10.3712, longitude: 107.0994),
  VungTauWard(name: 'Phường Rạch Dừa', latitude: 10.3976, longitude: 107.1082),
  VungTauWard(name: 'Xã Long Sơn', latitude: 10.4495, longitude: 107.0226),
];

bool isWithinVungTauBounds(double latitude, double longitude) {
  return latitude >= 10.30 &&
      latitude <= 10.48 &&
      longitude >= 106.98 &&
      longitude <= 107.20;
}

const List<String> kHalfHourTimeOptions = [
  '00:00',
  '00:30',
  '01:00',
  '01:30',
  '02:00',
  '02:30',
  '03:00',
  '03:30',
  '04:00',
  '04:30',
  '05:00',
  '05:30',
  '06:00',
  '06:30',
  '07:00',
  '07:30',
  '08:00',
  '08:30',
  '09:00',
  '09:30',
  '10:00',
  '10:30',
  '11:00',
  '11:30',
  '12:00',
  '12:30',
  '13:00',
  '13:30',
  '14:00',
  '14:30',
  '15:00',
  '15:30',
  '16:00',
  '16:30',
  '17:00',
  '17:30',
  '18:00',
  '18:30',
  '19:00',
  '19:30',
  '20:00',
  '20:30',
  '21:00',
  '21:30',
  '22:00',
  '22:30',
  '23:00',
  '23:30',
];

class HostListingUpsertDto {
  final String title;
  final String description;
  final String addressLine;
  final String ward;
  final String district;
  final String city;
  final String? stateRegion;
  final String country;
  final String? postalCode;
  final double latitude;
  final double longitude;
  final HostPropertyType propertyType;
  final HostRoomType roomType;
  final int maxGuests;
  final int bedrooms;
  final int beds;
  final double bathrooms;
  final double basePrice;
  final double weekendPrice;
  final double cleaningFee;
  final double surchargeAmount;
  final double? extraGuestFee;
  final int? includedGuests;
  final double? serviceFeePct;
  final String currency;
  final int minNights;
  final int? maxNights;
  final String checkInFrom;
  final String checkOutBefore;
  final HostCancellationPolicy cancellationPolicy;
  final bool instantBookEnabled;
  final List<int> amenityIds;
  final HostListingStatus status;

  const HostListingUpsertDto({
    required this.title,
    required this.description,
    required this.addressLine,
    required this.ward,
    this.district = kVungTauCity,
    this.city = kVungTauCity,
    this.stateRegion,
    this.country = 'VN',
    this.postalCode,
    required this.latitude,
    required this.longitude,
    required this.propertyType,
    required this.roomType,
    required this.maxGuests,
    required this.bedrooms,
    required this.beds,
    required this.bathrooms,
    required this.basePrice,
    required this.weekendPrice,
    this.cleaningFee = 0,
    this.surchargeAmount = 0,
    this.extraGuestFee,
    this.includedGuests,
    this.serviceFeePct,
    this.currency = 'VND',
    this.minNights = 1,
    this.maxNights,
    this.checkInFrom = '14:00',
    this.checkOutBefore = '12:00',
    this.cancellationPolicy = HostCancellationPolicy.flexible,
    this.instantBookEnabled = false,
    this.amenityIds = const [],
    this.status = HostListingStatus.draft,
  });

  String? validate() {
    if (title.trim().isEmpty) return 'Vui lòng nhập tiêu đề chỗ nghỉ.';
    if (title.trim().length > 255) return 'Tiêu đề tối đa 255 ký tự.';
    if (description.trim().isEmpty) return 'Vui lòng nhập mô tả chỗ nghỉ.';
    if (description.trim().length > 5000) return 'Mô tả tối đa 5000 ký tự.';
    if (addressLine.trim().isEmpty) return 'Vui lòng nhập địa chỉ cụ thể.';
    if (ward.trim().isEmpty) return 'Vui lòng chọn Phường/xã tại Vũng Tàu.';
    if (country != 'VN') return 'Quốc gia bắt buộc là VN.';
    if (currency != 'VND') return 'Loại tiền bắt buộc là VND.';
    if (!isWithinVungTauBounds(latitude, longitude)) {
      return 'Tọa độ phải nằm trong phạm vi Vũng Tàu (vĩ độ 10.30–10.48, kinh độ 106.98–107.20).';
    }
    if (maxGuests < 1) return 'Khách tối đa phải là số nguyên từ 1 trở lên.';
    if (bedrooms < 0) return 'Số phòng ngủ phải là số nguyên không âm.';
    if (beds < 1) return 'Số giường phải là số nguyên từ 1 trở lên.';
    if (bathrooms < 0.5) return 'Số phòng tắm (WC) phải từ 0.5 trở lên.';
    if (basePrice < 0) return 'Giá cơ bản không được âm.';
    if (weekendPrice < 0) return 'Giá cuối tuần không được âm.';
    if (cleaningFee < 0) return 'Phí dọn dẹp không được âm.';
    if (surchargeAmount < 0) return 'Phụ thu không được âm.';
    if (minNights < 1) return 'Số đêm tối thiểu phải từ 1 trở lên.';
    if (maxNights != null && maxNights! < minNights) {
      return 'Số đêm tối đa phải lớn hơn hoặc bằng số đêm tối thiểu.';
    }
    if (status != HostListingStatus.draft &&
        status != HostListingStatus.pendingApproval) {
      return 'Trạng thái tạo mới chỉ cho phép Lưu nháp (draft) hoặc Gửi duyệt (pending_approval).';
    }
    return null;
  }

  /// Exact payload for `POST /api/host/listings`.
  Map<String, dynamic> toCreateJson() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'addressLine': addressLine.trim(),
      'ward': ward.trim(),
      'district': district.trim().isEmpty ? kVungTauCity : district.trim(),
      'city': city.trim().isEmpty ? kVungTauCity : city.trim(),
      'stateRegion': stateRegion,
      'country': 'VN',
      'postalCode': postalCode,
      'latitude': double.parse(latitude.toStringAsFixed(6)),
      'longitude': double.parse(longitude.toStringAsFixed(6)),
      'propertyType': propertyType.value,
      'roomType': roomType.value,
      'maxGuests': maxGuests,
      'bedrooms': bedrooms,
      'beds': beds,
      'bathrooms': bathrooms,
      'basePrice': basePrice,
      'weekendPrice': weekendPrice,
      'cleaningFee': cleaningFee,
      'surchargeAmount': surchargeAmount,
      if (extraGuestFee != null) 'extraGuestFee': extraGuestFee,
      if (includedGuests != null) 'includedGuests': includedGuests,
      'serviceFeePct': serviceFeePct,
      'currency': 'VND',
      'minNights': minNights,
      'maxNights': maxNights,
      'checkInFrom': checkInFrom,
      'checkOutBefore': checkOutBefore,
      'cancellationPolicy': cancellationPolicy.value,
      'instantBookEnabled': instantBookEnabled,
      'amenityIds': amenityIds,
      'status': status == HostListingStatus.pendingApproval
          ? 'pending_approval'
          : 'draft',
    };
  }

  /// Exact payload for `PATCH /api/host/listings/:listingId`.
  Map<String, dynamic> toUpdateJson({HostListingStatus? nextStatus}) {
    final map = toCreateJson();
    map.remove('amenityIds');
    if (nextStatus != null) {
      map['status'] = nextStatus.value;
    } else {
      map.remove('status');
    }
    return map;
  }
}

class HostListingRulesDto {
  final String? checkInFrom;
  final String? checkOutBefore;
  final bool? smokingAllowed;
  final bool? petsAllowed;
  final bool? partyAllowed;
  final String? quietHours;

  const HostListingRulesDto({
    this.checkInFrom,
    this.checkOutBefore,
    this.smokingAllowed,
    this.petsAllowed,
    this.partyAllowed,
    this.quietHours,
  });

  Map<String, dynamic> toJson() => {
        if (checkInFrom != null) 'checkInFrom': checkInFrom,
        if (checkOutBefore != null) 'checkOutBefore': checkOutBefore,
        if (smokingAllowed != null) 'smokingAllowed': smokingAllowed,
        if (petsAllowed != null) 'petsAllowed': petsAllowed,
        if (partyAllowed != null) 'partyAllowed': partyAllowed,
        if (quietHours != null) 'quietHours': quietHours,
      };
}

// ============================================================================
// AI IMAGE VISION & 22-TAG TAXONOMY MODELS
// ============================================================================

class ImageTagTaxonomy {
  final String code;
  final String labelVi;
  final String category;

  const ImageTagTaxonomy({
    required this.code,
    required this.labelVi,
    required this.category,
  });

  factory ImageTagTaxonomy.fromJson(Map<String, dynamic> json) {
    return ImageTagTaxonomy(
      code: (json['code'] ?? json['tag'] ?? '').toString(),
      labelVi: (json['labelVi'] ?? json['label_vi'] ?? json['code'] ?? '')
          .toString(),
      category: (json['category'] ?? 'feature').toString(),
    );
  }
}

/// The 22 canonical AI Vision taxonomy tags from `Source goc`.
const List<ImageTagTaxonomy> kDefaultImageTagTaxonomies = [
  ImageTagTaxonomy(code: 'bedroom', labelVi: 'Phòng ngủ', category: 'room'),
  ImageTagTaxonomy(
      code: 'double_bed', labelVi: 'Giường đôi', category: 'amenity'),
  ImageTagTaxonomy(code: 'pool', labelVi: 'Hồ bơi', category: 'feature'),
  ImageTagTaxonomy(code: 'garden', labelVi: 'Sân vườn', category: 'feature'),
  ImageTagTaxonomy(code: 'bbq', labelVi: 'Khu vực BBQ', category: 'feature'),
  ImageTagTaxonomy(code: 'kitchen', labelVi: 'Bếp', category: 'room'),
  ImageTagTaxonomy(
      code: 'living_room', labelVi: 'Phòng khách', category: 'room'),
  ImageTagTaxonomy(code: 'toilet', labelVi: 'Nhà vệ sinh', category: 'room'),
  ImageTagTaxonomy(code: 'bathtub', labelVi: 'Bồn tắm', category: 'amenity'),
  ImageTagTaxonomy(code: 'balcony', labelVi: 'Ban công', category: 'feature'),
  ImageTagTaxonomy(code: 'sea_view', labelVi: 'View biển', category: 'view'),
  ImageTagTaxonomy(code: 'karaoke', labelVi: 'Karaoke', category: 'feature'),
  ImageTagTaxonomy(code: 'billiards', labelVi: 'Bàn bida', category: 'feature'),
  ImageTagTaxonomy(code: 'front_view', labelVi: 'Mặt tiền', category: 'view'),
  ImageTagTaxonomy(
      code: 'garage', labelVi: 'Chỗ đậu xe / Garage', category: 'feature'),
  ImageTagTaxonomy(
      code: 'air_conditioner', labelVi: 'Máy lạnh', category: 'amenity'),
  ImageTagTaxonomy(code: 'sofa', labelVi: 'Ghế sofa', category: 'amenity'),
  ImageTagTaxonomy(
      code: 'dining_table', labelVi: 'Bàn ăn', category: 'amenity'),
  ImageTagTaxonomy(code: 'modern', labelVi: 'Hiện đại', category: 'style'),
  ImageTagTaxonomy(code: 'luxury', labelVi: 'Sang trọng', category: 'style'),
  ImageTagTaxonomy(
      code: 'family_friendly',
      labelVi: 'Phù hợp gia đình',
      category: 'capacity'),
  ImageTagTaxonomy(
      code: 'large_group_friendly',
      labelVi: 'Phù hợp đoàn đông',
      category: 'capacity'),
];

class ListingImageAiTag {
  final String tag;
  final String labelVi;
  final String category;
  final double? confidence;
  final String source; // 'ai' | 'manual'

  const ListingImageAiTag({
    required this.tag,
    required this.labelVi,
    required this.category,
    this.confidence,
    this.source = 'ai',
  });

  factory ListingImageAiTag.fromDynamic(
    dynamic raw,
    List<ImageTagTaxonomy> taxonomies,
  ) {
    if (raw is String) {
      final code = raw.trim();
      final match = taxonomies.cast<ImageTagTaxonomy?>().firstWhere(
            (t) => t?.code == code,
            orElse: () => null,
          );
      return ListingImageAiTag(
        tag: code,
        labelVi: match?.labelVi ?? code,
        category: match?.category ?? 'feature',
      );
    }
    if (raw is Map<Object?, Object?>) {
      final code = (raw['tag'] ?? raw['code'] ?? '').toString().trim();
      final match = taxonomies.cast<ImageTagTaxonomy?>().firstWhere(
            (t) => t?.code == code,
            orElse: () => null,
          );
      return ListingImageAiTag(
        tag: code,
        labelVi: (raw['labelVi'] ?? raw['label_vi'] ?? match?.labelVi ?? code)
            .toString(),
        category: (raw['category'] ?? match?.category ?? 'feature').toString(),
        confidence: raw['confidence'] is num
            ? (raw['confidence'] as num).toDouble()
            : double.tryParse('${raw['confidence'] ?? ''}'),
        source: (raw['source'] ?? 'ai').toString(),
      );
    }
    return const ListingImageAiTag(
      tag: '',
      labelVi: '',
      category: 'feature',
    );
  }
}

class ExistingListingImage {
  final int imageId;
  final int? listingId;
  final String url;
  final String? key;
  final String? originalFilename;
  final String? displayTitle;
  final String? altText;
  final String? caption;
  final bool isCover;
  final int sortOrder;
  final String? roomType;
  final String
      aiAnalysisStatus; // 'pending' | 'analyzing' | 'analyzed' | 'failed'
  final String? aiErrorMessage;
  final double? aiConfidence;
  final List<String> aiWarnings;
  final List<ListingImageAiTag> tags;

  const ExistingListingImage({
    required this.imageId,
    this.listingId,
    required this.url,
    this.key,
    this.originalFilename,
    this.displayTitle,
    this.altText,
    this.caption,
    required this.isCover,
    required this.sortOrder,
    this.roomType,
    this.aiAnalysisStatus = 'pending',
    this.aiErrorMessage,
    this.aiConfidence,
    this.aiWarnings = const [],
    this.tags = const [],
  });

  factory ExistingListingImage.fromJson(
    Map<String, dynamic> json, {
    List<ImageTagTaxonomy> taxonomies = kDefaultImageTagTaxonomies,
  }) {
    final rawTags = json['effectiveTags'] ??
        json['tags'] ??
        json['aiTags'] ??
        const <dynamic>[];
    final parsedTags = <ListingImageAiTag>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        final item = ListingImageAiTag.fromDynamic(t, taxonomies);
        if (item.tag.isNotEmpty &&
            !parsedTags.any((existing) => existing.tag == item.tag)) {
          parsedTags.add(item);
        }
      }
    }

    final rawWarnings =
        json['aiWarnings'] ?? json['warnings'] ?? const <dynamic>[];
    final warnings = <String>[];
    if (rawWarnings is List) {
      for (final w in rawWarnings) {
        final text = w?.toString().trim() ?? '';
        if (text.isNotEmpty) warnings.add(text);
      }
    }

    final rawId = json['imageId'] ?? json['id'] ?? 0;
    final rawListingId = json['listingId'] ?? json['listing_id'];
    final rawSortOrder = json['sortOrder'] ?? json['sort_order'] ?? 0;
    final rawConfidence = json['aiConfidence'] ?? json['confidence'];

    final statusRaw = (json['aiAnalysisStatus'] ?? json['analysisStatus'] ?? '')
        .toString()
        .trim();
    final effectiveStatus = statusRaw.isNotEmpty
        ? statusRaw
        : (parsedTags.isNotEmpty ? 'analyzed' : 'pending');

    return ExistingListingImage(
      imageId: rawId is num ? rawId.toInt() : (int.tryParse('$rawId') ?? 0),
      listingId: rawListingId is num
          ? rawListingId.toInt()
          : int.tryParse('${rawListingId ?? ''}'),
      url: (json['url'] ?? json['imageUrl'] ?? '').toString(),
      key: (json['key'] ?? json['objectKey'])?.toString(),
      originalFilename:
          (json['originalFilename'] ?? json['original_filename'])?.toString(),
      displayTitle: (json['displayTitle'] ?? json['display_title'])?.toString(),
      altText: (json['altText'] ?? json['alt_text'])?.toString(),
      caption: json['caption']?.toString(),
      isCover: json['isCover'] == true || json['is_cover'] == true,
      sortOrder: rawSortOrder is num
          ? rawSortOrder.toInt()
          : (int.tryParse('$rawSortOrder') ?? 0),
      roomType: (json['roomType'] ?? json['spaceType'])?.toString(),
      aiAnalysisStatus: effectiveStatus,
      aiErrorMessage:
          (json['aiErrorMessage'] ?? json['errorMessage'])?.toString(),
      aiConfidence: rawConfidence is num
          ? rawConfidence.toDouble()
          : double.tryParse('${rawConfidence ?? ''}'),
      aiWarnings: warnings,
      tags: parsedTags,
    );
  }

  ExistingListingImage copyWith({
    bool? isCover,
    int? sortOrder,
    String? displayTitle,
    String? altText,
    String? caption,
    String? aiAnalysisStatus,
    String? aiErrorMessage,
    List<ListingImageAiTag>? tags,
  }) {
    return ExistingListingImage(
      imageId: imageId,
      listingId: listingId,
      url: url,
      key: key,
      originalFilename: originalFilename,
      displayTitle: displayTitle ?? this.displayTitle,
      altText: altText ?? this.altText,
      caption: caption ?? this.caption,
      isCover: isCover ?? this.isCover,
      sortOrder: sortOrder ?? this.sortOrder,
      roomType: roomType,
      aiAnalysisStatus: aiAnalysisStatus ?? this.aiAnalysisStatus,
      aiErrorMessage: aiErrorMessage ?? this.aiErrorMessage,
      aiConfidence: aiConfidence,
      aiWarnings: aiWarnings,
      tags: tags ?? this.tags,
    );
  }
}

// ============================================================================
// BUG-13: HOST BOOKING STATUS & ACTION STATE MACHINE (Port of bookingStatus.ts)
// ============================================================================

enum BookingActionRole { guest, host, admin }

enum BookingStatusTone { warning, danger, success, info, muted }

class BookingStatusActions {
  final bool canConfirm;
  final bool canCheckIn;
  final bool canCheckOut;
  final bool canCancel;

  const BookingStatusActions({
    this.canConfirm = false,
    this.canCheckIn = false,
    this.canCheckOut = false,
    this.canCancel = false,
  });

  bool get hasAnyAction => canConfirm || canCheckIn || canCheckOut || canCancel;
}

class BookingDisplayStatus {
  final String label;
  final BookingStatusTone tone;
  final String normalizedStatus;
  final String code;
  final String? reason;
  final bool isTerminal;
  final BookingStatusActions actions;

  const BookingDisplayStatus({
    required this.label,
    required this.tone,
    required this.normalizedStatus,
    required this.code,
    this.reason,
    required this.isTerminal,
    required this.actions,
  });
}

/// Returns current date string `YYYY-MM-DD` in Vietnam timezone (`UTC+7`).
String getVietnamTodayDateString([DateTime? now]) {
  final current = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  final y = current.year.toString().padLeft(4, '0');
  final m = current.month.toString().padLeft(2, '0');
  final d = current.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String? _extractDateOnly(dynamic value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  final datePart = raw.split('T').first;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
    return datePart;
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final y = parsed.year.toString().padLeft(4, '0');
  final m = parsed.month.toString().padLeft(2, '0');
  final d = parsed.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

bool isDateReachedInVietnam(dynamic dateValue, [DateTime? now]) {
  final dateStr = _extractDateOnly(dateValue);
  if (dateStr == null) return false;
  return dateStr.compareTo(getVietnamTodayDateString(now)) <= 0;
}

const Set<String> _terminalStatuses = {
  'payment_expired',
  'completed',
  'cancelled_by_guest',
  'cancelled_by_host',
  'cancelled_by_admin',
  'rejected',
};

const Set<String> _paidStatuses = {
  'paid',
  'confirmed',
  'checked_in',
  'checked_out',
  'completed',
};

String? _normalizeKnownBookingCode(dynamic value) {
  final normalized = (value?.toString() ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'pending':
    case 'pending_payment':
      return 'pending_payment';
    case 'expired':
    case 'payment_expired':
      return 'payment_expired';
    case 'pending_host':
    case 'pending_host_confirmation':
    case 'paid':
      return 'paid';
    case 'confirmed':
      return 'confirmed';
    case 'checked_in':
      return 'checked_in';
    case 'checked_out':
      return 'checked_out';
    case 'completed':
      return 'completed';
    case 'cancelled_by_guest':
      return 'cancelled_by_guest';
    case 'host_cancelled':
    case 'cancelled_by_host':
      return 'cancelled_by_host';
    case 'cancelled_by_admin':
      return 'cancelled_by_admin';
    case 'rejected':
      return 'rejected';
    case 'refund_pending':
      return 'refund_pending';
    case 'refunded':
      return 'refunded';
    case 'payout_pending':
      return 'payout_pending';
    case 'payout_paid':
      return 'payout_paid';
    default:
      return null;
  }
}

String _normalizeLegacyCancellation(Map<String, dynamic> booking) {
  final reason =
      (booking['cancellationReason'] ?? booking['cancellation_reason'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
  if (reason == 'ADMIN_CANCELLED') return 'cancelled_by_admin';
  if (reason == 'HOST_REJECTED') return 'rejected';
  final cancelledBy =
      booking['cancelledByUserId'] ?? booking['cancelled_by_user_id'];
  final hostId = booking['hostUserId'] ?? booking['host_user_id'];
  if (cancelledBy != null && hostId != null && '$cancelledBy' == '$hostId') {
    return 'cancelled_by_host';
  }
  return 'cancelled_by_guest';
}

String getBookingLifecycleStatus(Map<String, dynamic> booking) {
  final displayMap = booking['displayStatus'] is Map<Object?, Object?>
      ? Map<String, dynamic>.from(
          booking['displayStatus'] as Map<Object?, Object?>,
        )
      : null;
  final backendDisplayCode =
      _normalizeKnownBookingCode(displayMap?['normalizedStatus']) ??
          _normalizeKnownBookingCode(displayMap?['code']);
  final publicStatus = _normalizeKnownBookingCode(booking['status']);
  final persistedStatus =
      _normalizeKnownBookingCode(booking['persistedStatus']);
  final internalStatus = _normalizeKnownBookingCode(booking['internalStatus']);

  final rawStatus = (booking['internalStatus'] ??
          booking['persistedStatus'] ??
          booking['status'] ??
          '')
      .toString()
      .trim()
      .toLowerCase();
  if (rawStatus == 'cancelled') {
    return _normalizeLegacyCancellation(booking);
  }

  if (backendDisplayCode != null &&
      _terminalStatuses.contains(backendDisplayCode)) {
    return backendDisplayCode;
  }
  if (publicStatus != null && _terminalStatuses.contains(publicStatus)) {
    return publicStatus;
  }

  return internalStatus ??
      persistedStatus ??
      backendDisplayCode ??
      publicStatus ??
      'unknown';
}

bool _isBookingPaid(Map<String, dynamic> booking, String lifecycleStatus) {
  final paymentStatus =
      (booking['paymentStatus'] ?? booking['payment_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  return paymentStatus == 'paid' ||
      booking['paidAt'] != null ||
      _paidStatuses.contains(lifecycleStatus);
}

String _getEffectiveLifecycleStatus(
  Map<String, dynamic> booking,
  DateTime now,
) {
  final lifecycle = getBookingLifecycleStatus(booking);
  final reason =
      (booking['cancellationReason'] ?? '').toString().trim().toUpperCase();

  if (reason == 'PAYMENT_EXPIRED') return 'payment_expired';

  if (lifecycle == 'pending_payment' && _isBookingPaid(booking, lifecycle)) {
    return 'paid';
  }

  return lifecycle;
}

BookingStatusActions getBookingStatusActions(
  Map<String, dynamic> booking, {
  BookingActionRole role = BookingActionRole.host,
  DateTime? now,
}) {
  final currentNow = now ?? DateTime.now();
  final lifecycle = _getEffectiveLifecycleStatus(booking, currentNow);

  if (_terminalStatuses.contains(lifecycle)) {
    return const BookingStatusActions();
  }

  final isStaff =
      role == BookingActionRole.host || role == BookingActionRole.admin;
  if (!isStaff) {
    // Guests NEVER get host confirm/checkIn/checkOut actions!
    return BookingStatusActions(
      canCancel:
          const {'pending_payment', 'paid', 'confirmed'}.contains(lifecycle),
    );
  }

  final checkInDate = booking['checkInDate'] ?? booking['check_in_date'];
  final checkOutDate = booking['checkOutDate'] ?? booking['check_out_date'];

  return BookingStatusActions(
    canConfirm: lifecycle == 'paid',
    canCheckIn: lifecycle == 'confirmed' &&
        isDateReachedInVietnam(checkInDate, currentNow),
    canCheckOut: lifecycle == 'checked_in' &&
        isDateReachedInVietnam(checkOutDate, currentNow),
    canCancel: lifecycle == 'paid' || lifecycle == 'confirmed',
  );
}

BookingDisplayStatus getBookingDisplayStatus(
  Map<String, dynamic> booking, {
  BookingActionRole role = BookingActionRole.host,
  DateTime? now,
}) {
  final currentNow = now ?? DateTime.now();
  final lifecycle = _getEffectiveLifecycleStatus(booking, currentNow);
  final actions = getBookingStatusActions(booking, role: role, now: currentNow);

  String code = lifecycle;
  final payoutStatus =
      (booking['payoutStatus'] ?? '').toString().trim().toLowerCase();
  final refundStatus =
      (booking['refundStatus'] ?? '').toString().trim().toLowerCase();
  final paymentStatus =
      (booking['paymentStatus'] ?? '').toString().trim().toLowerCase();

  if ((role == BookingActionRole.host || role == BookingActionRole.admin) &&
      (lifecycle == 'checked_out' || lifecycle == 'completed')) {
    if (payoutStatus == 'paid') {
      code = 'payout_paid';
    } else if (const {'pending', 'approved', 'processing'}
        .contains(payoutStatus)) {
      code = 'payout_pending';
    }
  }

  if (paymentStatus == 'refunded' || refundStatus == 'succeeded') {
    code = 'refunded';
  } else if (_terminalStatuses.contains(lifecycle) &&
      const {'pending', 'processing'}.contains(refundStatus)) {
    code = 'refund_pending';
  }

  String label;
  BookingStatusTone tone;
  switch (code) {
    case 'pending_payment':
      label = 'Chờ thanh toán';
      tone = BookingStatusTone.warning;
      break;
    case 'payment_expired':
      label = 'Quá hạn thanh toán';
      tone = BookingStatusTone.danger;
      break;
    case 'paid':
      label = 'Thanh toán thành công';
      tone = BookingStatusTone.success;
      break;
    case 'confirmed':
      label = 'Đã xác nhận';
      tone = BookingStatusTone.success;
      break;
    case 'checked_in':
      label = 'Đã nhận phòng';
      tone = BookingStatusTone.info;
      break;
    case 'checked_out':
      label = 'Đã trả phòng';
      tone = BookingStatusTone.info;
      break;
    case 'completed':
      label = 'Hoàn tất';
      tone = BookingStatusTone.success;
      break;
    case 'cancelled_by_guest':
      label = 'Khách đã hủy';
      tone = BookingStatusTone.muted;
      break;
    case 'cancelled_by_host':
      label = 'Host đã hủy';
      tone = BookingStatusTone.danger;
      break;
    case 'cancelled_by_admin':
      label = 'Admin đã hủy';
      tone = BookingStatusTone.danger;
      break;
    case 'rejected':
      label = 'Host đã từ chối';
      tone = BookingStatusTone.danger;
      break;
    case 'refund_pending':
      label = 'Đang chờ hoàn tiền';
      tone = BookingStatusTone.warning;
      break;
    case 'refunded':
      label = 'Đã hoàn tiền';
      tone = BookingStatusTone.success;
      break;
    case 'payout_pending':
      label = 'Đang chờ chi trả';
      tone = BookingStatusTone.warning;
      break;
    case 'payout_paid':
      label = 'Đã chi trả';
      tone = BookingStatusTone.success;
      break;
    default:
      label = 'Không rõ';
      tone = BookingStatusTone.muted;
      break;
  }

  final rawReason = booking['cancellationReason']?.toString().trim();
  String? localizedReason = rawReason;
  if (rawReason != null && rawReason.isNotEmpty) {
    switch (rawReason.toUpperCase()) {
      case 'PAYMENT_EXPIRED':
      case 'EXPIRED':
      case 'HOLD_EXPIRED':
        localizedReason =
            'Quá thời hạn thanh toán (hệ thống tự động hủy giữ chỗ)';
        break;
      case 'CUSTOMER_CANCELLED':
      case 'CANCELLED_BY_GUEST':
      case 'GUEST_CANCELLED':
        localizedReason = 'Khách hàng chủ động hủy đặt phòng';
        break;
      case 'HOST_REJECTED':
      case 'REJECTED':
        localizedReason = 'Chủ nhà từ chối yêu cầu đặt phòng';
        break;
      case 'HOST_CANCELLED':
      case 'CANCELLED_BY_HOST':
        localizedReason = 'Chủ nhà đã hủy đặt phòng';
        break;
      case 'ADMIN_CANCELLED':
      case 'CANCELLED_BY_ADMIN':
        localizedReason = 'Quản trị viên đã hủy đặt phòng';
        break;
      case 'LATE_PAYMENT_AFTER_BOOKING_EXPIRED':
      case 'PAYMENT_SUCCESS_AFTER_HOLD_EXPIRED':
        localizedReason = 'Thanh toán phát sinh sau khi đã hết thời gian giữ chỗ';
        break;
      default:
        if (RegExp(r'^[A-Za-z0-9]+(_[A-Za-z0-9]+)+$').hasMatch(rawReason)) {
          localizedReason = 'Đơn đặt phòng đã bị hủy theo quy định hệ thống';
        }
        break;
    }
  }

  return BookingDisplayStatus(
    label: label,
    tone: tone,
    normalizedStatus: code,
    code: code,
    reason: localizedReason,
    isTerminal: _terminalStatuses.contains(lifecycle) ||
        _terminalStatuses.contains(code) ||
        code == 'refunded',
    actions: actions,
  );
}

bool bookingMatchesDisplayStatus(
  Map<String, dynamic> booking,
  String filterStatus, {
  BookingActionRole role = BookingActionRole.host,
  DateTime? now,
}) {
  if (filterStatus == 'all' || filterStatus.isEmpty) return true;
  final display = getBookingDisplayStatus(booking, role: role, now: now);
  if (filterStatus == 'cancelled') {
    return const {
      'cancelled_by_guest',
      'cancelled_by_host',
      'cancelled_by_admin',
      'rejected',
    }.contains(display.normalizedStatus);
  }
  return display.normalizedStatus == filterStatus;
}

// ============================================================================
// BUG-13 & BUG-38: CALENDAR, PAYOUT, REPORT & BANK MODELS
// ============================================================================

class HostCalendarDay {
  final String date; // YYYY-MM-DD
  final double basePrice;
  final double effectivePrice;
  final double? priceOverride;
  final int? minNightsOverride;
  final bool isAvailable;
  final bool isBlockedByHost;
  final bool isBooked;
  final bool isPast;
  final bool canEdit;
  final String? bookingStatus;
  final int? bookingId;
  final String? guestName;
  final String? notes;

  const HostCalendarDay({
    required this.date,
    required this.basePrice,
    required this.effectivePrice,
    this.priceOverride,
    this.minNightsOverride,
    this.isAvailable = true,
    this.isBlockedByHost = false,
    this.isBooked = false,
    this.isPast = false,
    this.canEdit = true,
    this.bookingStatus,
    this.bookingId,
    this.guestName,
    this.notes,
  });

  bool isEditable({String? todayVietnam}) {
    if (!canEdit || isBooked || isPast) return false;
    if (todayVietnam != null &&
        date.isNotEmpty &&
        date.compareTo(todayVietnam) < 0) {
      return false;
    }
    return true;
  }

  factory HostCalendarDay.fromJson(Map<String, dynamic> json) {
    double toDoubleVal(dynamic v, [double fallback = 0]) {
      if (v is num) return v.toDouble();
      return double.tryParse('${v ?? ''}') ?? fallback;
    }

    final base = toDoubleVal(
      json['basePrice'] ?? json['defaultPrice'] ?? json['price'],
    );
    final override = json['priceOverride'] != null
        ? toDoubleVal(json['priceOverride'])
        : null;
    final effective = json['effectivePrice'] != null
        ? toDoubleVal(json['effectivePrice'])
        : (override ??
            (json['price'] != null ? toDoubleVal(json['price']) : base));

    final rawBookingStatus = json['bookingStatus']?.toString();
    final hasBookingStatus =
        rawBookingStatus != null && rawBookingStatus.trim().isNotEmpty;
    final booked = (json['isBooked'] as bool?) ?? hasBookingStatus;
    final past = (json['isPast'] as bool?) ?? false;
    final editable = (json['canEdit'] as bool?) ?? (!booked && !past);

    return HostCalendarDay(
      date: (json['date'] ?? '').toString().split('T').first,
      basePrice: base,
      effectivePrice: effective,
      priceOverride: override,
      minNightsOverride: json['minNightsOverride'] is num
          ? (json['minNightsOverride'] as num).toInt()
          : int.tryParse('${json['minNightsOverride'] ?? ''}'),
      isAvailable: json['isAvailable'] != false,
      isBlockedByHost: json['isBlockedByHost'] == true,
      isBooked: booked,
      isPast: past,
      canEdit: editable,
      bookingStatus: rawBookingStatus ?? (booked ? 'booked' : null),
      bookingId: json['bookingId'] is num
          ? (json['bookingId'] as num).toInt()
          : int.tryParse('${json['bookingId'] ?? ''}'),
      guestName: json['guestName']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class CalendarDateSelectionValidation {
  final List<String> editableDates;
  final List<String> bookedDates;
  final List<String> pastDates;
  final List<String> invalidFormatDates;

  const CalendarDateSelectionValidation({
    this.editableDates = const [],
    this.bookedDates = const [],
    this.pastDates = const [],
    this.invalidFormatDates = const [],
  });

  bool get hasUnauthorizedDates =>
      bookedDates.isNotEmpty ||
      pastDates.isNotEmpty ||
      invalidFormatDates.isNotEmpty;

  bool get isAllValid => !hasUnauthorizedDates && editableDates.isNotEmpty;

  String? get errorMessage {
    if (invalidFormatDates.isNotEmpty) {
      return 'Định dạng ngày không hợp lệ: ${invalidFormatDates.join(', ')}';
    }
    if (bookedDates.isNotEmpty) {
      return 'Không thể thay đổi ngày đã có khách đặt: ${bookedDates.join(', ')}';
    }
    if (pastDates.isNotEmpty) {
      return 'Không thể thay đổi ngày trong quá khứ: ${pastDates.join(', ')}';
    }
    return null;
  }
}

CalendarDateSelectionValidation validateCalendarBulkDates(
  List<String> dates, {
  List<HostCalendarDay> calendarDays = const [],
  List<HostCalendarDay>? currentCalendarDays,
  String? todayVietnam,
}) {
  final effectiveCalendarDays = currentCalendarDays ?? calendarDays;
  final dayByDate = <String, HostCalendarDay>{
    for (final d in effectiveCalendarDays) d.date: d,
  };
  final editable = <String>[];
  final booked = <String>[];
  final past = <String>[];
  final invalid = <String>[];
  final isoRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  for (final raw in dates.map((e) => e.trim()).toSet()) {
    if (!isoRegex.hasMatch(raw)) {
      invalid.add(raw);
      continue;
    }
    final known = dayByDate[raw];
    if (known != null && known.isBooked) {
      booked.add(raw);
      continue;
    }
    if ((known != null && known.isPast) ||
        (todayVietnam != null && raw.compareTo(todayVietnam) < 0)) {
      past.add(raw);
      continue;
    }
    if (known != null && !known.canEdit) {
      booked.add(raw);
      continue;
    }
    editable.add(raw);
  }

  editable.sort();
  booked.sort();
  past.sort();
  invalid.sort();

  return CalendarDateSelectionValidation(
    editableDates: editable,
    bookedDates: booked,
    pastDates: past,
    invalidFormatDates: invalid,
  );
}

/// Deterministic masking of sensitive bank account numbers so raw digits are
/// never exposed in payout lists or account summaries (`****1234`).
String maskBankAccountNumber(dynamic rawAccountNumber) {
  final raw = (rawAccountNumber ?? '').toString().trim();
  if (raw.isEmpty) return '—';
  if (raw.startsWith('****') && raw.length <= 8) {
    return raw;
  }
  final digitsOnly = raw.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  if (digitsOnly.isEmpty) return '****';
  if (digitsOnly.length <= 4) {
    return '****$digitsOnly';
  }
  final last4 = digitsOnly.substring(digitsOnly.length - 4);
  return '****$last4';
}

/// Ensures payout account or batch maps always have `accountNumberMasked`
/// populated and any raw `accountNumber` masked before display.
Map<String, dynamic> maskSensitivePayoutMap(Map<String, dynamic> source) {
  final copy = Map<String, dynamic>.from(source);
  final rawAcc = copy['accountNumber'] ??
      copy['account_number'] ??
      copy['accountNumberMasked'] ??
      copy['account_number_masked'] ??
      copy['accountNumberLast4'];
  if (rawAcc != null && rawAcc.toString().trim().isNotEmpty) {
    final masked = maskBankAccountNumber(rawAcc);
    copy['accountNumberMasked'] = masked;
    if (copy.containsKey('accountNumber')) {
      copy['accountNumber'] = masked;
    }
  }
  return copy;
}

/// Returns true if the given role is an approved Host or Admin allowed to
/// access Host Portal and perform Host mutations.
bool isApprovedHostRole(String? role) {
  final normalized = (role ?? '').trim().toLowerCase();
  return normalized == 'host' || normalized == 'admin';
}

class HostAuthorizationException extends StateError {
  final int statusCode;
  final String? userRole;

  HostAuthorizationException(
    super.message, {
    this.statusCode = 403,
    this.userRole,
  });
}

enum HostErrorType {
  offline,
  authExpired,
  forbidden,
  validation,
  notFound,
  conflict,
  server,
  unknown,
}

class HostErrorInfo {
  final HostErrorType type;
  final int? statusCode;
  final String message;
  final Map<String, String> fieldErrors;

  const HostErrorInfo({
    required this.type,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  bool get isOffline => type == HostErrorType.offline;
  bool get isAuthExpired => type == HostErrorType.authExpired;
  bool get isForbidden => type == HostErrorType.forbidden;
  bool get isValidation => type == HostErrorType.validation;
  bool get isRetryable =>
      type == HostErrorType.offline ||
      type == HostErrorType.server ||
      type == HostErrorType.unknown;
}

HostErrorInfo classifyHostError(Object error, [String? fallback]) {
  if (error is HostAuthorizationException) {
    return HostErrorInfo(
      type: HostErrorType.forbidden,
      statusCode: error.statusCode,
      message: error.message,
    );
  }
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final fieldErrors = <String, String>{};
    String? serverMsg;

    if (data is Map) {
      final rawMsg = data['message'] ?? data['error'];
      if (rawMsg is String && rawMsg.trim().isNotEmpty) {
        serverMsg = rawMsg.trim();
      }
      final errorsRaw = data['errors'];
      final msgs = <String>[];
      if (errorsRaw is List && errorsRaw.isNotEmpty) {
        for (final item in errorsRaw) {
          if (item is Map) {
            final path =
                (item['path'] ?? item['field'] ?? '').toString().trim();
            final m = (item['msg'] ?? item['message'] ?? '').toString().trim();
            if (m.isNotEmpty) {
              msgs.add(m);
              if (path.isNotEmpty && !fieldErrors.containsKey(path)) {
                fieldErrors[path] = m;
              }
            }
          }
        }
      } else if (errorsRaw is Map && errorsRaw.isNotEmpty) {
        errorsRaw.forEach((key, value) {
          final path = key.toString().trim();
          String m = '';
          if (value is List && value.isNotEmpty) {
            m = value
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .join(', ');
          } else if (value != null) {
            m = value.toString().trim();
          }
          if (m.isNotEmpty) {
            msgs.add(m);
            if (path.isNotEmpty && !fieldErrors.containsKey(path)) {
              fieldErrors[path] = m;
            }
          }
        });
      }
      if (msgs.isNotEmpty) {
        if (serverMsg == null ||
            serverMsg.toLowerCase() == 'validation error') {
          serverMsg = msgs.join('; ');
        } else {
          serverMsg = '$serverMsg: ${msgs.join('; ')}';
        }
      }
    }

    if (statusCode == null) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return const HostErrorInfo(
          type: HostErrorType.offline,
          message:
              'Không thể kết nối máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.',
        );
      }
      return HostErrorInfo(
        type: HostErrorType.unknown,
        message: serverMsg ?? 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.',
      );
    }

    if (statusCode == 401) {
      return HostErrorInfo(
        type: HostErrorType.authExpired,
        statusCode: 401,
        message: serverMsg ??
            'Phiên đăng nhập đã hết hạn (401). Vui lòng đăng nhập lại.',
      );
    }
    if (statusCode == 403) {
      return HostErrorInfo(
        type: HostErrorType.forbidden,
        statusCode: 403,
        message: serverMsg ??
            'Bạn không có quyền Chủ nhà để thực hiện thao tác này (403).',
      );
    }
    if (statusCode == 404) {
      return HostErrorInfo(
        type: HostErrorType.notFound,
        statusCode: 404,
        message: serverMsg ?? 'Không tìm thấy dữ liệu yêu cầu (404).',
      );
    }
    if (statusCode == 409) {
      return HostErrorInfo(
        type: HostErrorType.conflict,
        statusCode: 409,
        message: serverMsg ?? 'Dữ liệu bị xung đột trạng thái (409).',
      );
    }
    if (statusCode == 400 || statusCode == 422) {
      return HostErrorInfo(
        type: HostErrorType.validation,
        statusCode: statusCode,
        message: serverMsg ?? 'Dữ liệu gửi lên không hợp lệ ($statusCode).',
        fieldErrors: fieldErrors,
      );
    }
    if (statusCode >= 500) {
      return HostErrorInfo(
        type: HostErrorType.server,
        statusCode: statusCode,
        message: serverMsg ??
            'Máy chủ đang gặp sự cố ($statusCode). Vui lòng thử lại sau.',
      );
    }
    return HostErrorInfo(
      type: HostErrorType.unknown,
      statusCode: statusCode,
      message: serverMsg ?? 'Yêu cầu thất bại ($statusCode).',
      fieldErrors: fieldErrors,
    );
  }

  if (error is ArgumentError) {
    return HostErrorInfo(
      type: HostErrorType.validation,
      message: error.message?.toString() ?? 'Dữ liệu không hợp lệ.',
    );
  }
  if (error is StateError) {
    return HostErrorInfo(
      type: HostErrorType.validation,
      message: error.message,
    );
  }

  return HostErrorInfo(
    type: HostErrorType.unknown,
    message: error.toString(),
  );
}

class VietnamBank {
  final String code;
  final String name;
  final String shortName;
  final String? bin;
  final String? logo;

  const VietnamBank({
    required this.code,
    required this.name,
    required this.shortName,
    this.bin,
    this.logo,
  });

  factory VietnamBank.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] ?? json['bankCode'] ?? '').toString().trim();
    final name = (json['name'] ?? json['bankName'] ?? code).toString().trim();
    final shortName =
        (json['shortName'] ?? json['bankShortName'] ?? code).toString().trim();
    return VietnamBank(
      code: code,
      name: name,
      shortName: shortName,
      bin: json['bin']?.toString(),
      logo: json['logo']?.toString(),
    );
  }

  String get displayLabel =>
      '${shortName.isNotEmpty ? shortName : code} - $name${(bin != null && bin!.isNotEmpty) ? ' ($bin)' : ''}';
}

class HostBankAccount {
  final String bankCode;
  final String bankName;
  final String bankShortName;
  final String? bankBin;
  final String accountNumber;
  final String accountHolderName;
  final String? branchName;

  const HostBankAccount({
    required this.bankCode,
    required this.bankName,
    required this.bankShortName,
    this.bankBin,
    required this.accountNumber,
    required this.accountHolderName,
    this.branchName,
  });

  String get accountNumberMasked => maskBankAccountNumber(accountNumber);

  factory HostBankAccount.fromJson(Map<String, dynamic> json) {
    return HostBankAccount(
      bankCode: (json['bankCode'] ?? '').toString(),
      bankName: (json['bankName'] ?? '').toString(),
      bankShortName:
          (json['bankShortName'] ?? json['bankCode'] ?? '').toString(),
      bankBin: json['bankBin']?.toString(),
      accountNumber: (json['accountNumber'] ?? '').toString(),
      accountHolderName:
          (json['accountHolderName'] ?? json['accountName'] ?? '').toString(),
      branchName: json['branchName']?.toString(),
    );
  }

  String? validate() {
    if (bankCode.trim().isEmpty || bankName.trim().isEmpty) {
      return 'Vui lòng chọn ngân hàng từ danh sách.';
    }
    final trimmedAcc = accountNumber.trim();
    if (trimmedAcc.isEmpty) {
      return 'Số tài khoản là bắt buộc.';
    }
    if (!RegExp(r'^\d{6,30}$').hasMatch(trimmedAcc)) {
      return 'Số tài khoản chỉ được chứa chữ số và dài từ 6 đến 30 ký tự.';
    }
    if (accountHolderName.trim().isEmpty) {
      return 'Tên chủ tài khoản là bắt buộc.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'bankCode': bankCode.trim(),
        'bankName': bankName.trim(),
        'bankShortName': bankShortName.trim().isNotEmpty
            ? bankShortName.trim()
            : bankCode.trim(),
        if (bankBin != null && bankBin!.trim().isNotEmpty)
          'bankBin': bankBin!.trim(),
        'accountNumber': accountNumber.trim(),
        'accountHolderName': accountHolderName.trim().toUpperCase(),
        'branchName': (branchName != null && branchName!.trim().isNotEmpty)
            ? branchName!.trim()
            : null,
      };
}

class HostRevenueSeriesPoint {
  final String period;
  final double grossRevenue;
  final double platformRevenue;
  final double hostRevenue;
  final int bookingCount;
  final int paymentCount;

  const HostRevenueSeriesPoint({
    required this.period,
    required this.grossRevenue,
    required this.platformRevenue,
    required this.hostRevenue,
    required this.bookingCount,
    this.paymentCount = 0,
  });

  factory HostRevenueSeriesPoint.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) =>
        v is num ? v.toDouble() : (double.tryParse('${v ?? 0}') ?? 0);
    int toI(dynamic v) =>
        v is num ? v.toInt() : (int.tryParse('${v ?? 0}') ?? 0);

    return HostRevenueSeriesPoint(
      period:
          (json['period'] ?? json['date'] ?? json['month'] ?? '').toString(),
      grossRevenue: toD(json['grossRevenue']),
      platformRevenue: toD(json['platformRevenue']),
      hostRevenue: toD(json['hostRevenue']),
      bookingCount: toI(json['bookingCount']),
      paymentCount: toI(json['paymentCount']),
    );
  }
}

class HostRevenueReport {
  final String from;
  final String to;
  final String group;
  final String? listingId;
  final double grossRevenue;
  final double platformRevenue;
  final double hostRevenue;
  final int bookingCount;
  final int paymentCount;
  final List<HostRevenueSeriesPoint> series;

  const HostRevenueReport({
    this.from = '',
    this.to = '',
    this.group = 'day',
    this.listingId,
    this.grossRevenue = 0,
    this.platformRevenue = 0,
    this.hostRevenue = 0,
    this.bookingCount = 0,
    this.paymentCount = 0,
    this.series = const [],
  });

  factory HostRevenueReport.fromJson(
    Map<String, dynamic> json, {
    String? listingId,
  }) {
    final range = json['range'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(json['range'] as Map<Object?, Object?>)
        : const <String, dynamic>{};
    final totals = json['totals'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(json['totals'] as Map<Object?, Object?>)
        : json;
    final rawSeries = json['series'] is List
        ? json['series'] as List<dynamic>
        : const <dynamic>[];

    double toD(dynamic v) =>
        v is num ? v.toDouble() : (double.tryParse('${v ?? 0}') ?? 0);
    int toI(dynamic v) =>
        v is num ? v.toInt() : (int.tryParse('${v ?? 0}') ?? 0);

    return HostRevenueReport(
      from: (range['from'] ?? json['from'] ?? '').toString(),
      to: (range['to'] ?? json['to'] ?? '').toString(),
      group: (json['group'] ?? 'day').toString(),
      listingId: listingId ?? json['listingId']?.toString(),
      grossRevenue: toD(totals['grossRevenue']),
      platformRevenue: toD(totals['platformRevenue']),
      hostRevenue: toD(totals['hostRevenue']),
      bookingCount: toI(totals['bookingCount']),
      paymentCount: toI(totals['paymentCount']),
      series: rawSeries
          .whereType<Map<Object?, Object?>>()
          .map(
            (e) => HostRevenueSeriesPoint.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}
