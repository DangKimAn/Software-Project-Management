import 'dart:typed_data';
import 'package:dio/dio.dart';

import 'host_booking_status_helper.dart';

export 'host_booking_status_helper.dart';
export 'host_portal_kpi_helper.dart';
export 'host_sheet_sync_models.dart';

/// Giới hạn dung lượng tải tệp tối đa cho phân hệ Chủ nhà (5MB), khớp bộ kiểm tra của Backend.
const int kMaxHostUploadBytes = 5 * 1024 * 1024; // 5MB

/// Số lượng ảnh tối đa được phép tải lên cho một chỗ nghỉ.
const int kMaxListingImagesCount = 30;

/// Số lượng tệp đính kèm tối đa trong một bộ hồ sơ đăng ký KYC Chủ nhà.
const int kMaxKycFilesCount = 4;

/// Tập kiểu MIME hợp lệ cho chứng từ KYC tổng quát (bao gồm Giấy phép kinh doanh hỗ trợ PDF).
const Set<String> kAllowedKycMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
};

/// Tập kiểu MIME hợp lệ dành riêng cho ảnh giấy tờ định danh cá nhân (CCCD, CMND, Hộ chiếu, GPLX).
const Set<String> kAllowedIdentityKycMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
};

/// Tập kiểu MIME hợp lệ cho ảnh không gian chỗ nghỉ tải lên Cloudflare R2.
const Set<String> kAllowedListingImageMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
};

/// Đại diện cho một tệp tin thực được người dùng chọn từ bộ nhớ thiết bị hoặc trình duyệt.
class HostPickedFile {
  final String name;
  final String mimeType;
  final int sizeBytes;
  final Uint8List bytes;
  final String? path;

  /// Khởi tạo đối tượng tệp đã chọn kèm dữ liệu nhị phân `bytes` và `mimeType` chuẩn.
  const HostPickedFile({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.bytes,
    this.path,
  });

  /// Cho biết tệp có định dạng tài liệu PDF hay không.
  bool get isPdf =>
      mimeType.toLowerCase() == 'application/pdf' ||
      name.toLowerCase().endsWith('.pdf');

  /// Cho biết tệp có thuộc nhóm định dạng hình ảnh (`image/*`) hay không.
  bool get isImage => mimeType.toLowerCase().startsWith('image/');

  /// Chuỗi hiển thị dung lượng tệp dễ đọc theo đơn vị `B`, `KB` hoặc `MB`.
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }
}

/// Kiểm tra tính hợp lệ của tệp chứng từ KYC tổng quát `file` theo quy tắc dung lượng (tối đa 5MB) và MIME của Backend.
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

// Giải thuật kiểm tra tệp ảnh giấy tờ định danh cá nhân (CCCD/CMND mặt trước & sau, Hộ chiếu, GPLX):
// CONFLICT-RESOLVED: Đồng bộ với quy tắc image/* của Backend cho giấy tờ tùy thân; từ chối tệp PDF và chỉ chấp nhận JPG, PNG hoặc WebP <= 5MB.
/// Kiểm tra tính hợp lệ của tệp ảnh giấy tờ định danh cá nhân `file` (chỉ chấp nhận ảnh `JPG`, `PNG`, `WebP` không quá 5MB).
String? validateIdentityKycPickedFile(HostPickedFile file) {
  if (file.name.trim().isEmpty) {
    return 'Tên tệp ảnh không hợp lệ.';
  }
  if (file.sizeBytes <= 0 || file.bytes.isEmpty) {
    return 'Tệp "${file.name}" rỗng hoặc không đọc được dữ liệu.';
  }
  if (file.sizeBytes > kMaxHostUploadBytes) {
    return 'Ảnh "${file.name}" vượt quá giới hạn 5MB (${file.formattedSize}).';
  }
  final normalizedMime = file.mimeType.trim().toLowerCase();
  if (file.isPdf || normalizedMime == 'application/pdf') {
    return 'Giấy tờ định danh "${file.name}" không hỗ trợ tệp PDF. Vui lòng chọn ảnh chụp JPG, PNG hoặc WebP rõ nét.';
  }
  if (!kAllowedIdentityKycMimeTypes.contains(normalizedMime)) {
    return 'Định dạng "${file.name}" ($normalizedMime) không hỗ trợ cho giấy tờ định danh. Chỉ chấp nhận ảnh JPG, PNG hoặc WebP.';
  }
  return null;
}

/// Kiểm tra tệp ảnh chỗ nghỉ `file` đảm bảo không rỗng, không vượt quá 5MB và đúng định dạng ảnh được phép.
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

/// Trạng thái xét duyệt hồ sơ đăng ký trở thành Chủ nhà (Host KYC).
enum HostApplicationStatus {
  none,
  pending,
  approved,
  rejected,
  revoked,
  supplementRequired;

  /// Chuẩn hóa chuỗi trạng thái thô `raw` từ API sang giá trị `HostApplicationStatus`.
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

/// Phân loại tư cách pháp lý của hồ sơ Chủ nhà (Cá nhân hoặc Doanh nghiệp / Hộ kinh doanh).
enum HostProfileType {
  individual('individual', 'Cá nhân'),
  business('business', 'Doanh nghiệp / Hộ kinh doanh');

  final String value;
  final String labelVi;
  const HostProfileType(this.value, this.labelVi);

  /// Chuyển đổi chuỗi `raw` từ API sang `HostProfileType` tương ứng.
  static HostProfileType fromApi(String? raw) {
    if (raw?.trim().toLowerCase() == 'business') {
      return HostProfileType.business;
    }
    return HostProfileType.individual;
  }
}

/// Loại giấy tờ định danh cá nhân dùng trong quy trình xác minh KYC Chủ nhà.
enum HostDocumentType {
  cccd('cccd', 'Căn cước công dân (CCCD)'),
  cmnd('cmnd', 'Chứng minh nhân dân (CMND)'),
  passport('passport', 'Hộ chiếu (Passport)'),
  driverLicense('driver_license', 'Giấy phép lái xe (GPLX)');

  final String value;
  final String labelVi;
  const HostDocumentType(this.value, this.labelVi);

  /// Chuyển đổi chuỗi `raw` từ API sang `HostDocumentType` tương ứng.
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

  /// Cho biết loại giấy tờ bắt buộc tải đủ cả hai mặt trước và sau (CCCD, CMND).
  bool get requiresFrontAndBack =>
      this == HostDocumentType.cccd || this == HostDocumentType.cmnd;

  /// Cho biết loại giấy tờ yêu cầu mặt trước bắt buộc và mặt sau tùy chọn (GPLX).
  bool get requiresFrontOnlyWithOptionalBack =>
      this == HostDocumentType.driverLicense;

  /// Cho biết loại giấy tờ chỉ sử dụng một ảnh trang thông tin duy nhất (Hộ chiếu).
  bool get requiresSingleDocument => this == HostDocumentType.passport;
}

/// Kết quả bóc tách thông tin giấy tờ tùy thân tự động bằng AI OCR (`/api/ai/id-card-vision/extract`).
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

  /// Trích xuất số định danh hiệu lực từ trường `idNumber` hoặc giải mã chuỗi `mrz` mặt sau CCCD (`IDVNM...`).
  String? get effectiveIdNumber {
    if (idNumber != null && idNumber!.trim().isNotEmpty) {
      return idNumber!.trim();
    }
    if (mrz != null && mrz!.isNotEmpty) {
      final match =
          RegExp(r'IDVNM(\d{9,12})', caseSensitive: false).firstMatch(mrz!);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }
}

/// Thông tin siêu dữ liệu của một chứng từ đính kèm trong hồ sơ đăng ký Chủ nhà.
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

/// Bản ghi hồ sơ đăng ký KYC của Chủ nhà được chuẩn hóa từ phản hồi `/api/host/applications/me`.
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

/// Đối tượng truyền dữ liệu (DTO) nộp hồ sơ đăng ký Chủ nhà qua `POST /api/host/applications` (`multipart/form-data`).
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

  /// Khởi tạo bộ dữ liệu nộp hồ sơ KYC Chủ nhà.
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

  /// Kiểm tra toàn bộ trường thông tin và tổ hợp tệp đính kèm theo đúng quy tắc của `host-applications.validator.ts`.
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
          return 'Vui lòng chọn ảnh Hộ chiếu (Passport) định dạng JPG, PNG hoặc WebP.';
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
    final identityFiles = <HostPickedFile>[
      if (identityFront != null) identityFront!,
      if (identityBack != null) identityBack!,
      if (identitySingle != null) identitySingle!,
    ];
    final filesToCheck = <HostPickedFile>[
      ...identityFiles,
      if (businessLicense != null) businessLicense!,
    ];

    if (filesToCheck.isEmpty) {
      return 'Vui lòng đính kèm giấy tờ xác minh danh tính.';
    }
    if (filesToCheck.length > kMaxKycFilesCount) {
      return 'Tối đa $kMaxKycFilesCount tệp đính kèm.';
    }

    // CONFLICT-RESOLVED: Giấy tờ định danh chỉ cho phép ảnh JPG/PNG/WebP; Giấy phép kinh doanh vẫn hỗ trợ thêm PDF.
    for (final file in identityFiles) {
      final err = validateIdentityKycPickedFile(file);
      if (err != null) return err;
    }
    if (businessLicense != null) {
      final err = validateKycPickedFile(businessLicense!);
      if (err != null) return err;
    }

    return null;
  }

  /// Đóng gói dữ liệu biểu mẫu và tệp nhị phân thành `FormData` (`multipart/form-data`) gửi tới `POST /api/host/applications`.
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

/// Trạng thái vòng đời hiển thị và kiểm duyệt của một chỗ nghỉ thuộc quyền quản lý của Host.
enum HostListingStatus {
  draft('draft', 'Bản nháp'),
  pendingApproval('pending_approval', 'Chờ duyệt'),
  published('published', 'Đang hiển thị'),
  hidden('hidden', 'Đang ẩn'),
  rejected('rejected', 'Bị từ chối');

  final String value;
  final String labelVi;
  const HostListingStatus(this.value, this.labelVi);

  /// Giải mã giá trị chuỗi `raw` từ API sang trạng thái `HostListingStatus`.
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

  // Giải thuật ánh xạ trạng thái chỗ nghỉ từ bản ghi JSON của Backend:
  // CONFLICT-RESOLVED: Ưu tiên kiểm tra internalStatus == 'rejected' song song với status == 'rejected'.
  /// Giải mã trạng thái chỗ nghỉ từ bản đồ JSON `raw`, ưu tiên nhận diện cờ `internalStatus == 'rejected'`.
  static HostListingStatus fromListingMap(Map<Object?, Object?> raw) {
    final internal =
        (raw['internalStatus'] ?? '').toString().trim().toLowerCase();
    if (internal == 'rejected') {
      return HostListingStatus.rejected;
    }
    return fromApi(raw['status']);
  }

  /// Kiểm tra máy trạng thái chỗ nghỉ có cho phép chuyển tiếp sang trạng thái đích `target` hay không.
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
        // CONFLICT-RESOLVED: Backend cho phép chỗ nghỉ bị từ chối chuyển sang draft, pending_approval hoặc giữ nguyên rejected khi sửa.
        return target == HostListingStatus.draft ||
            target == HostListingStatus.pendingApproval ||
            target == HostListingStatus.rejected;
    }
  }
}

/// Tóm tắt thông tin chỗ nghỉ chuẩn hóa cho danh sách Chỗ nghỉ của Host (`GET /api/host/listings/mine`).
class HostListingSummary {
  final String id;
  final String title;
  final HostListingStatus status;
  final String? internalStatus;
  final String? rejectionReason;
  final double basePrice;
  final double? weekendPrice;
  final int maxGuests;
  final HostPropertyType propertyType;
  final String imageUrl;
  final String addressDisplay;

  const HostListingSummary({
    required this.id,
    required this.title,
    required this.status,
    this.internalStatus,
    this.rejectionReason,
    required this.basePrice,
    this.weekendPrice,
    required this.maxGuests,
    required this.propertyType,
    this.imageUrl = '',
    this.addressDisplay = '',
  });

  // Giải thuật phân tích dữ liệu thẻ chỗ nghỉ từ JSON Backend (bao gồm trạng thái bị từ chối và lý do từ chối):
  // CONFLICT-RESOLVED: Trích xuất đồng bộ status/internalStatus == 'rejected' và rejectionReason (string | null).
  factory HostListingSummary.fromJson(Map<String, dynamic> json) {
    final id = (json['listingId'] ?? json['id'] ?? '').toString();
    final title = (json['title'] ?? 'Chỗ nghỉ #$id').toString();
    final status = HostListingStatus.fromListingMap(json);
    final rawInternal = json['internalStatus']?.toString().trim();
    final rawReason =
        (json['rejectionReason'] ?? json['rejectReason'])?.toString().trim();

    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      return double.tryParse('${val ?? 0}') ?? 0;
    }

    String extractCoverUrl(Map<String, dynamic> raw) {
      for (final key in const [
        'coverImageUrl',
        'imageUrl',
        'thumbnailUrl',
        'coverImage',
      ]) {
        final v = raw[key]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      final images = raw['images'];
      if (images is List && images.isNotEmpty) {
        Map<Object?, Object?>? coverMap;
        for (final item in images) {
          if (item is Map && item['isCover'] == true) {
            coverMap = item;
            break;
          }
        }
        final target =
            coverMap ?? (images.first is Map ? images.first as Map : null);
        if (target != null) {
          for (final key in const ['url', 'imageUrl', 'publicUrl']) {
            final v = target[key]?.toString().trim() ?? '';
            if (v.isNotEmpty) return v;
          }
        } else if (images.first is String) {
          return (images.first as String).trim();
        }
      }
      return '';
    }

    final addressDisplay = [
      json['addressLine'],
      json['ward'],
      json['district'],
      json['city'],
    ]
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .join(', ');

    final rawGuests = json['maxGuests'];
    final maxGuests = rawGuests is num
        ? rawGuests.toInt()
        : (int.tryParse('${rawGuests ?? 1}') ?? 1);

    return HostListingSummary(
      id: id,
      title: title,
      status: status,
      internalStatus:
          (rawInternal != null && rawInternal.isNotEmpty) ? rawInternal : null,
      rejectionReason:
          (rawReason != null && rawReason.isNotEmpty) ? rawReason : null,
      basePrice: parseDouble(json['basePrice'] ?? json['pricePerNight'] ?? 0),
      weekendPrice: json['weekendPrice'] != null
          ? parseDouble(json['weekendPrice'])
          : null,
      maxGuests: maxGuests < 1 ? 1 : maxGuests,
      propertyType: HostPropertyType.fromApi(json['propertyType']),
      imageUrl: extractCoverUrl(json),
      addressDisplay: addressDisplay,
    );
  }
}

/// Loại hình bất động sản nghỉ dưỡng của chỗ nghỉ (Villa, Căn hộ, Homestay, Khách sạn).
enum HostPropertyType {
  villa('villa', 'Villa'),
  apartment('apartment', 'Căn hộ'),
  homestay('homestay', 'Homestay'),
  hotel('hotel', 'Khách sạn');

  final String value;
  final String labelVi;
  const HostPropertyType(this.value, this.labelVi);

  /// Giải mã giá trị `raw` từ API sang `HostPropertyType` (mặc định `villa`).
  static HostPropertyType fromApi(dynamic raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final item in HostPropertyType.values) {
      if (item.value == normalized) return item;
    }
    return HostPropertyType.villa;
  }
}

/// Hình thức cho thuê không gian lưu trú (Nguyên căn, Phòng riêng, Phòng chung).
enum HostRoomType {
  entirePlace('entire_place', 'Nguyên căn'),
  privateRoom('private_room', 'Phòng riêng'),
  sharedRoom('shared_room', 'Phòng chung');

  final String value;
  final String labelVi;
  const HostRoomType(this.value, this.labelVi);

  /// Giải mã giá trị `raw` từ API sang `HostRoomType` (mặc định `entirePlace`).
  static HostRoomType fromApi(dynamic raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final item in HostRoomType.values) {
      if (item.value == normalized) return item;
    }
    return HostRoomType.entirePlace;
  }
}

/// Chính sách hoàn hủy đặt phòng áp dụng cho chỗ nghỉ.
enum HostCancellationPolicy {
  flexible('flexible', 'Linh hoạt'),
  moderate('moderate', 'Vừa phải'),
  strict('strict', 'Nghiêm ngặt');

  final String value;
  final String labelVi;
  const HostCancellationPolicy(this.value, this.labelVi);

  /// Giải mã giá trị `raw` từ API sang `HostCancellationPolicy` (mặc định `flexible`).
  static HostCancellationPolicy fromApi(dynamic raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    for (final item in HostCancellationPolicy.values) {
      if (item.value == normalized) return item;
    }
    return HostCancellationPolicy.flexible;
  }
}

/// Đơn vị hành chính Phường/Xã tại thành phố Vũng Tàu kèm tọa độ tâm bản đồ mặc định.
class VungTauWard {
  final String name;
  final double latitude;
  final double longitude;

  /// Khởi tạo thông tin Phường/Xã tại Vũng Tàu.
  const VungTauWard({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

/// Tên thành phố mặc định cho các chỗ nghỉ trên hệ thống.
const String kVungTauCity = 'Vũng Tàu';

/// Vĩ độ trung tâm mặc định tại thành phố Vũng Tàu.
const double kDefaultVungTauLat = 10.3460;

/// Kinh độ trung tâm mặc định tại thành phố Vũng Tàu.
const double kDefaultVungTauLng = 107.0843;

/// Danh mục 17 Phường/Xã chuẩn tại Vũng Tàu dùng cho bộ chọn địa chỉ chỗ nghỉ.
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

/// Kiểm tra tọa độ địa lý (`latitude`, `longitude`) có nằm trong khung giới hạn lãnh thổ Vũng Tàu hay không.
///
/// Giải thuật kiểm định hộp biên địa lý đồng nhất với `VUNG_TAU_MAP_BOUNDS` trên máy chủ (`10.28..10.50` Bắc, `107.00..107.26` Đông):
/// Bao phủ đầy đủ từ Mũi Nghinh Phong - Bãi Sau tới Xã Long Sơn và trục ven biển Chí Linh - Cửa Lấp.
bool isWithinVungTauBounds(double latitude, double longitude) {
  return latitude >= 10.28 &&
      latitude <= 10.50 &&
      longitude >= 107.00 &&
      longitude <= 107.26;
}

/// Danh sách mốc giờ cách nhau mỗi 30 phút dùng cho cấu hình giờ nhận phòng và trả phòng.
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

/// Đối tượng truyền dữ liệu (DTO) phục vụ tạo mới và cập nhật thông tin chỗ nghỉ của Chủ nhà.
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

  // Giải thuật kiểm tra hợp lệ dữ liệu tạo mới / chỉnh sửa chỗ nghỉ:
  // CONFLICT-RESOLVED: Chỉ ràng buộc status là draft/pending_approval khi tạo mới (isCreate == true); khi chỉnh sửa cho phép published, hidden, rejected.
  /// Kiểm tra toàn bộ ràng buộc trường dữ liệu, khung tọa độ Vũng Tàu, đơn giá và quy tắc trạng thái theo cờ `isCreate`.
  String? validate({bool isCreate = true}) {
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
    if (isCreate &&
        status != HostListingStatus.draft &&
        status != HostListingStatus.pendingApproval) {
      return 'Trạng thái tạo mới chỉ cho phép Lưu nháp (draft) hoặc Gửi duyệt (pending_approval).';
    }
    return null;
  }

  /// Sinh bản đồ dữ liệu JSON chuẩn gửi tới `POST /api/host/listings`.
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

  // Giải thuật tạo payload PATCH cập nhật chỗ nghỉ an toàn theo hợp đồng trạng thái Backend:
  // CONFLICT-RESOLVED: Chỉ đính kèm trường status khi includeStatus == true hoặc nextStatus != null để lưu thay đổi thông thường trên published/hidden không gây lỗi 422.
  /// Sinh bản đồ JSON gửi tới `PATCH /api/host/listings/:id`, chỉ đính kèm `status` khi có chuyển trạng thái tường minh.
  Map<String, dynamic> toUpdateJson({
    bool includeStatus = false,
    HostListingStatus? nextStatus,
  }) {
    final map = toCreateJson();
    map.remove('amenityIds');
    if (nextStatus != null) {
      map['status'] = nextStatus.value;
    } else if (includeStatus) {
      map['status'] = status.value;
    } else {
      map.remove('status');
    }
    return map;
  }
}

/// Đối tượng truyền dữ liệu (DTO) cập nhật nội quy lưu trú của chỗ nghỉ (`PATCH /api/host/listings/:id/rules`).
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

/// Định nghĩa một nhãn phân loại không gian/tiện ích chuẩn trong bộ từ điển thị giác máy tính (AI Vision Taxonomy).
class ImageTagTaxonomy {
  final String code;
  final String labelVi;
  final String category;

  /// Khởi tạo mục phân loại nhãn ảnh AI.
  const ImageTagTaxonomy({
    required this.code,
    required this.labelVi,
    required this.category,
  });

  /// Khởi tạo `ImageTagTaxonomy` từ JSON.
  factory ImageTagTaxonomy.fromJson(Map<String, dynamic> json) {
    return ImageTagTaxonomy(
      code: (json['code'] ?? json['tag'] ?? '').toString(),
      labelVi: (json['labelVi'] ?? json['label_vi'] ?? json['code'] ?? '')
          .toString(),
      category: (json['category'] ?? 'feature').toString(),
    );
  }
}

/// Tập 22 nhãn từ điển phân loại ảnh AI chuẩn hóa cho biệt thự và căn hộ nghỉ dưỡng.
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

/// Nhãn nhận diện không gian/tiện ích gắn trên từng ảnh chỗ nghỉ (do AI tự động gán hoặc Chủ nhà chỉnh sửa thủ công).
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

/// Thực thể ảnh chỗ nghỉ đã lưu trên hệ thống kèm trạng thái phân tích AI Vision và danh sách nhãn gắn kèm.
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
// BUG-13: HOST BOOKING STATUS & ACTION STATE MACHINE
// Extracted to host_booking_status_helper.dart (re-exported at top of file).
// ============================================================================

// ============================================================================
// BUG-13 & BUG-38: CALENDAR, PAYOUT, REPORT & BANK MODELS
// ============================================================================

/// Mô hình trạng thái chi tiết của một ngày trên lịch vận hành chỗ nghỉ (`YYYY-MM-DD`).
///
/// Đóng gói giá cơ bản, giá ghi đè `priceOverride`, số đêm tối thiểu ghi đè `minNightsOverride`,
/// cờ khóa thủ công `isBlockedByHost`, cờ có khách đặt `isBooked` và quyền chỉnh sửa `canEdit`.
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

  /// Khởi tạo thông tin một ngày trên lịch vận hành của Chủ nhà.
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

  /// Kiểm tra ô ngày có được phép chỉnh sửa giá hoặc đóng/mở phòng so với ngày `todayVietnam` hay không.
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

    // Giải thuật xác định trạng thái khóa ngày theo đơn đặt phòng hợp lệ trên lịch lưu trú:
    // CONFLICT-RESOLVED: Dùng isCalendarBlockingStatusCode(bookingStatus) để các đơn đã hủy/từ chối/quá hạn không khóa ngày lịch.
    final rawBookingStatus = json['bookingStatus']?.toString();
    final hasBookingStatus =
        rawBookingStatus != null && rawBookingStatus.trim().isNotEmpty;
    final hasBlockingBookingStatus =
        isCalendarBlockingStatusCode(rawBookingStatus);
    final booked = hasBookingStatus
        ? hasBlockingBookingStatus
        : (json['isBooked'] == true);
    final past = (json['isPast'] as bool?) ?? false;
    final rawCanEdit = json['canEdit'] as bool?;
    final editable = (hasBookingStatus && !hasBlockingBookingStatus)
        ? !past
        : (rawCanEdit ?? (!booked && !past));

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

/// Kết quả phân loại tập ngày được chọn khi cập nhật lịch hàng loạt (Bulk Calendar Update).
class CalendarDateSelectionValidation {
  /// Danh sách ngày hợp lệ (`YYYY-MM-DD`) đủ điều kiện cập nhật giá hoặc đóng/mở phòng.
  final List<String> editableDates;

  /// Danh sách ngày đang bị khóa do đã có khách đặt hoặc không được phép chỉnh sửa (`!canEdit`).
  final List<String> bookedDates;

  /// Danh sách ngày nằm trong quá khứ so với ngày hiện tại tại Việt Nam.
  final List<String> pastDates;

  /// Danh sách chuỗi ngày sai định dạng chuẩn ISO `YYYY-MM-DD`.
  final List<String> invalidFormatDates;

  /// Khởi tạo kết quả kiểm định tập ngày lịch hàng loạt.
  const CalendarDateSelectionValidation({
    this.editableDates = const [],
    this.bookedDates = const [],
    this.pastDates = const [],
    this.invalidFormatDates = const [],
  });

  /// Cho biết tập ngày chọn có chứa bất kỳ ngày vi phạm ràng buộc (đã đặt, quá khứ, sai định dạng) hay không.
  bool get hasUnauthorizedDates =>
      bookedDates.isNotEmpty ||
      pastDates.isNotEmpty ||
      invalidFormatDates.isNotEmpty;

  /// Cho biết toàn bộ ngày được chọn đều hợp lệ và có ít nhất một ngày khả dụng để cập nhật hay không.
  bool get isAllValid => !hasUnauthorizedDates && editableDates.isNotEmpty;

  /// Thông điệp lỗi tiếng Việt tổng hợp ưu tiên theo thứ tự: sai định dạng -> trùng đơn khách đặt -> ngày quá khứ.
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

// Giải thuật thẩm định danh sách ngày cập nhật lịch hàng loạt (`validateCalendarBulkDates`):
// Bước 1 (Lập chỉ mục lịch `O(N)`): Dựng bảng tra cứu `dayByDate` từ `currentCalendarDays` (hoặc `calendarDays`)
//   để truy xuất trạng thái khóa phòng/giá ghi đè của từng ngày trong thời gian hằng số `O(1)`.
// Bước 2 (Khử trùng & Phân tích định dạng `YYYY-MM-DD`): Cắt khoảng trắng và khử trùng lặp mảng `dates` qua `Set`
//   (hỗ trợ cả tập ngày rời rạc lẫn dải ngày liên tiếp sinh từ điều kiện `startDate <= endDate` có giới hạn số ngày tối đa),
//   sau đó kiểm tra biểu thức chính quy `^\d{4}-\d{2}-\d{2}$`; chuỗi sai chuẩn được tách vào `invalidFormatDates`.
// Bước 3 (Kiểm tra ràng buộc đặt phòng, khóa lịch & quá khứ):
//   - Nếu `known.isBooked == true`, đưa vào `bookedDates` để ngăn ghi đè giá hoặc mở khóa đè lên đơn đặt phòng thực.
//   - Nếu `known.isPast == true` hoặc chuỗi ngày nhỏ hơn `todayVietnam` theo thứ tự từ điển ISO, đưa vào `pastDates`.
//   - Nếu `known.canEdit == false`, đưa vào `bookedDates` để bảo vệ các ngày bị khóa cứng từ hệ thống.
// Bước 4 (Chuẩn hóa thứ tự tăng dần): Các ngày hợp lệ còn lại được thêm vào `editableDates`; sắp xếp từ điển tăng dần
//   cả 4 danh sách (`startDate <= ... <= endDate`) trước khi trả về `CalendarDateSelectionValidation`.
/// Kiểm tra và phân loại danh sách ngày `dates` (`YYYY-MM-DD`) phục vụ cập nhật giá/khóa phòng hàng loạt trên lịch Host.
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

/// Che giấu tất định số tài khoản ngân hàng nhạy cảm thành dạng `****1234` để bảo vệ dữ liệu tài chính trên giao diện.
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

/// Tạo bản sao bản đồ tài khoản/đợt chi trả `source` với trường `accountNumberMasked` và `accountNumber` đã được che bảo mật.
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

/// Kiểm tra chuỗi vai trò `role` có phải Chủ nhà (`host`) hoặc Quản trị viên (`admin`) được phép thao tác trên Host Portal hay không.
bool isApprovedHostRole(String? role) {
  final normalized = (role ?? '').trim().toLowerCase();
  return normalized == 'host' || normalized == 'admin';
}

/// Ngoại lệ ném ra khi người dùng chưa đăng nhập (`401`) hoặc không có quyền Chủ nhà (`403`) thực hiện thao tác thay đổi dữ liệu.
class HostAuthorizationException extends StateError {
  final int statusCode;
  final String? userRole;

  /// Khởi tạo ngoại lệ phân quyền Host kèm mã trạng thái HTTP `statusCode` và `userRole` hiện tại.
  HostAuthorizationException(
    super.message, {
    this.statusCode = 403,
    this.userRole,
  });
}

/// Phân loại nhóm lỗi chuẩn hóa trong toàn bộ phân hệ Chủ nhà.
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

/// Đối tượng đóng gói kết quả phân loại lỗi của phân hệ Chủ nhà kèm thông điệp tiếng Việt và lỗi chi tiết theo từng trường.
class HostErrorInfo {
  final HostErrorType type;
  final int? statusCode;
  final String message;
  final Map<String, String> fieldErrors;

  /// Khởi tạo thông tin lỗi đã phân loại của Host.
  const HostErrorInfo({
    required this.type,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  /// Cho biết lỗi bắt nguồn từ mất kết nối mạng hoặc hết thời gian chờ (timeout).
  bool get isOffline => type == HostErrorType.offline;

  /// Cho biết phiên xác thực của người dùng đã hết hạn (`401`).
  bool get isAuthExpired => type == HostErrorType.authExpired;

  /// Cho biết tài khoản hiện tại bị từ chối quyền truy cập nghiệp vụ Chủ nhà (`403`).
  bool get isForbidden => type == HostErrorType.forbidden;

  /// Cho biết dữ liệu biểu mẫu hoặc tham số đầu vào vi phạm quy tắc kiểm định (`400`/`422`).
  bool get isValidation => type == HostErrorType.validation;

  /// Cho biết lỗi mang tính tạm thời và người dùng có thể nhấn nút thử lại ngay.
  bool get isRetryable =>
      type == HostErrorType.offline ||
      type == HostErrorType.server ||
      type == HostErrorType.unknown;
}

// Giải thuật phân loại lỗi đa tầng và ánh xạ hướng dẫn xử lý tiếng Việt cho Host (`classifyHostError`):
// Bước 1 (Kiểm tra ngoại lệ phân quyền nội bộ): Nếu `error` là `HostAuthorizationException`,
//   trả về ngay `HostErrorType.forbidden` cùng `statusCode` (`401`/`403`) và thông điệp hướng dẫn đăng nhập tài khoản Host.
// Bước 2 (Giải mã cấu trúc lỗi từ `DioException`): Trích xuất `message`/`error` từ body JSON và duyệt `data['errors']`
//   (tương thích cả mảng `{ path/field, msg/message }` của `express-validator` lẫn bản đồ khóa-giá trị) để điền
//   vào `fieldErrors` và ghép nối chuỗi giải thích lỗi cụ thể cho người dùng.
// Bước 3 (Nhận diện đứt kết nối & Timeout mạng): Khi `statusCode == null` và kiểu lỗi thuộc `connectionError`,
//   `connectionTimeout`, `receiveTimeout` hoặc `sendTimeout`, gán nhãn `HostErrorType.offline` để bật giao diện thử lại.
// Bước 4 (Ánh xạ mã trạng thái HTTP `401/403/404/409/400/422/429/5xx`):
//   - `401` -> `HostErrorType.authExpired`: yêu cầu đăng nhập lại phiên làm việc.
//   - `403` -> `HostErrorType.forbidden`: thông báo thiếu quyền Chủ nhà.
//   - `404` -> `HostErrorType.notFound`: báo dữ liệu hoặc chỗ nghỉ không tồn tại.
//   - `409` -> `HostErrorType.conflict`: cảnh báo trùng lặp mã số hoặc xung đột trạng thái đặt phòng/lịch.
//   - `400` / `422` -> `HostErrorType.validation`: trả kèm `fieldErrors` để đánh dấu trực tiếp ô nhập sai.
//   - `>= 500` (`5xx`) -> `HostErrorType.server`: thông báo sự cố máy chủ tạm thời (cho phép thử lại).
//   - Các mã HTTP còn lại (như giới hạn tần suất `429`) -> `HostErrorType.unknown` kèm nguyên văn hướng dẫn `serverMsg` từ máy chủ.
// Bước 5 (Chuẩn hóa lỗi cục bộ): Chuyển `ArgumentError` và `StateError` thành `HostErrorType.validation`
//   để tầng ViewModel/UI xử lý đồng nhất với lỗi kiểm định từ máy chủ.
/// Phân tích đối tượng lỗi `error` thành `HostErrorInfo` có kiểu ngữ nghĩa rõ ràng và thông điệp tiếng Việt hướng dẫn cách khắc phục.
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
      final msg =
          (serverMsg != null && serverMsg.trim().toLowerCase() != 'conflict')
              ? serverMsg
              : 'Dữ liệu hoặc mã số bị trùng lặp / xung đột trạng thái (409).';
      return HostErrorInfo(
        type: HostErrorType.conflict,
        statusCode: 409,
        message: msg,
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

/// Thông tin ngân hàng thương mại Việt Nam lấy từ danh mục chuẩn `/api/banks/vn`.
class VietnamBank {
  final String code;
  final String name;
  final String shortName;
  final String? bin;
  final String? logo;

  /// Khởi tạo thông tin ngân hàng Việt Nam.
  const VietnamBank({
    required this.code,
    required this.name,
    required this.shortName,
    this.bin,
    this.logo,
  });

  /// Khởi tạo `VietnamBank` từ dữ liệu JSON.
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

  /// Chuỗi nhãn đầy đủ hiển thị tên viết tắt, tên chính thức và mã BIN trong ô chọn ngân hàng.
  String get displayLabel =>
      '${shortName.isNotEmpty ? shortName : code} - $name${(bin != null && bin!.isNotEmpty) ? ' ($bin)' : ''}';
}

/// Thông tin tài khoản ngân hàng thụ hưởng dùng để nhận tiền giải ngân đối soát của Chủ nhà.
class HostBankAccount {
  final String bankCode;
  final String bankName;
  final String bankShortName;
  final String? bankBin;
  final String accountNumber;
  final String accountHolderName;
  final String? branchName;

  /// Khởi tạo thông tin tài khoản ngân hàng nhận chi trả của Host.
  const HostBankAccount({
    required this.bankCode,
    required this.bankName,
    required this.bankShortName,
    this.bankBin,
    required this.accountNumber,
    required this.accountHolderName,
    this.branchName,
  });

  /// Chuỗi số tài khoản đã được che giấu chỉ giữ 4 ký tự cuối (`****1234`).
  String get accountNumberMasked => maskBankAccountNumber(accountNumber);

  /// Khởi tạo `HostBankAccount` từ dữ liệu JSON.
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

  /// Kiểm tra hợp lệ ngân hàng, độ dài chữ số tài khoản (6–30 chữ số) và tên chủ tài khoản.
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

/// Một điểm dữ liệu theo kỳ thời gian (ngày hoặc tháng) trên biểu đồ báo cáo doanh thu của Chủ nhà.
class HostRevenueSeriesPoint {
  final String period;
  final double grossRevenue;
  final double platformRevenue;
  final double hostRevenue;
  final int bookingCount;
  final int paymentCount;

  /// Khởi tạo điểm dữ liệu chuỗi thời gian doanh thu.
  const HostRevenueSeriesPoint({
    required this.period,
    required this.grossRevenue,
    required this.platformRevenue,
    required this.hostRevenue,
    required this.bookingCount,
    this.paymentCount = 0,
  });

  /// Khởi tạo `HostRevenueSeriesPoint` từ JSON.
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

/// Báo cáo tổng hợp doanh thu, phí nền tảng, doanh thu thực nhận, doanh thu chờ lưu trú và hoàn tiền của Chủ nhà.
class HostRevenueReport {
  final String from;
  final String to;
  final String group;
  final String? listingId;
  final double grossRevenue;
  final double platformRevenue;
  final double hostRevenue;
  final double pendingStayRevenue;
  final double pendingStayPlatformRevenue;
  final double pendingStayHostRevenue;
  final int pendingStayBookingCount;
  final double refundedAmount;
  final int refundCount;
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
    this.pendingStayRevenue = 0,
    this.pendingStayPlatformRevenue = 0,
    this.pendingStayHostRevenue = 0,
    this.pendingStayBookingCount = 0,
    this.refundedAmount = 0,
    this.refundCount = 0,
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
      pendingStayRevenue:
          toD(totals['pendingStayRevenue'] ?? json['pendingStayRevenue']),
      pendingStayPlatformRevenue: toD(
        totals['pendingStayPlatformRevenue'] ??
            json['pendingStayPlatformRevenue'],
      ),
      pendingStayHostRevenue: toD(
        totals['pendingStayHostRevenue'] ?? json['pendingStayHostRevenue'],
      ),
      pendingStayBookingCount: toI(
        totals['pendingStayBookingCount'] ?? json['pendingStayBookingCount'],
      ),
      refundedAmount: toD(totals['refundedAmount']),
      refundCount: toI(totals['refundCount']),
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
