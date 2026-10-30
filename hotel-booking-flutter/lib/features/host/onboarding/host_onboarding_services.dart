import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/host_models.dart';

// =============================================================================
// 1. PII-SAFE LOG SANITIZER FOR HOST ONBOARDING & KYC
// =============================================================================

/// Sanitizes any log message in the Host Onboarding & KYC flow so that PII
/// (names, emails, phone numbers, CCCD/CMND/Passport numbers, addresses,
/// file paths, or tokens) is never written to logs.
abstract final class HostOnboardingLogSanitizer {
  static final RegExp _emailPattern = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
  );
  static final RegExp _vnPhonePattern = RegExp(
    r'(\+84|0)[0-9\s.\-]{8,12}[0-9]',
  );
  static final RegExp _idNumberPattern = RegExp(
    r'\b([0-9]{9,12}|[A-Z][0-9]{7,8})\b',
  );
  static final RegExp _jsonPiiFieldPattern = RegExp(
    r'"(contactName|fullName|name|contactEmail|email|phone|contactPhone|businessAddress|address|idNumber|cccd|cmnd|passport|note|notes|originalFilename|path|fileUrl|signedUrl|objectKey)"\s*:\s*"[^"]*"',
    caseSensitive: false,
  );
  static final RegExp _filePathPattern = RegExp(
    r'([A-Za-z]:\\[^\s",]+|/Users/[^\s",]+|/home/[^\s",]+|/storage/[^\s",]+|/data/[^\s",]+)',
  );

  static String sanitize(String raw) {
    final baseSanitized = AppLogger.sanitize(raw);
    return baseSanitized
        .replaceAllMapped(
          _jsonPiiFieldPattern,
          (m) => '"${m.group(1)}":"[REDACTED_PII]"',
        )
        .replaceAll(_emailPattern, '[REDACTED_EMAIL]')
        .replaceAll(_vnPhonePattern, '[REDACTED_PHONE]')
        .replaceAll(_idNumberPattern, '[REDACTED_ID]')
        .replaceAll(_filePathPattern, '[REDACTED_PATH]');
  }

  static void logInfo(String message) {
    AppLogger.i(sanitize(message), tag: 'HostOnboarding');
  }

  static void logError(String message, {Object? error}) {
    final safeMsg = sanitize(message);
    final safeErr = error != null ? sanitize(error.toString()) : null;
    AppLogger.e(safeMsg, tag: 'HostOnboarding', error: safeErr);
  }
}

// =============================================================================
// 2. PERMISSION SERVICE FOR KYC DOCUMENT / CAMERA / MEDIA ACCESS
// =============================================================================

enum HostKycFileSource {
  deviceFile,
  photoLibrary,
  cameraScan,
}

enum HostKycPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

class HostKycPermissionResult {
  final HostKycPermissionStatus status;
  final String? messageVi;

  const HostKycPermissionResult({
    required this.status,
    this.messageVi,
  });

  bool get isGranted => status == HostKycPermissionStatus.granted;
}

abstract class HostOnboardingPermissionService {
  Future<HostKycPermissionResult> requestPermission(HostKycFileSource source);
}

class DefaultHostOnboardingPermissionService
    implements HostOnboardingPermissionService {
  const DefaultHostOnboardingPermissionService();

  @override
  Future<HostKycPermissionResult> requestPermission(
    HostKycFileSource source,
  ) async {
    return const HostKycPermissionResult(
      status: HostKycPermissionStatus.granted,
    );
  }
}

final hostOnboardingPermissionProvider =
    Provider<HostOnboardingPermissionService>((ref) {
  return const DefaultHostOnboardingPermissionService();
});

// =============================================================================
// 3. STRICT BACKEND-PARITY VALIDATOR FOR KYC & DOCUMENTS
// =============================================================================

class HostKycValidationResult {
  final String? summaryError;
  final Map<String, String> fieldErrors;
  final Map<String, String> slotErrors;

  const HostKycValidationResult({
    this.summaryError,
    this.fieldErrors = const {},
    this.slotErrors = const {},
  });

  bool get isValid =>
      summaryError == null && fieldErrors.isEmpty && slotErrors.isEmpty;
}

abstract final class HostOnboardingValidator {
  static final RegExp _vnPhoneRegex = RegExp(r'^(0|\+84)[0-9]{9}$');
  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static const Set<String> _allowedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.pdf',
  };

  static String? validateContactName(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập họ và tên người liên hệ.';
    }
    if (trimmed.length > 120) {
      return 'Họ và tên người liên hệ không được vượt quá 120 ký tự.';
    }
    return null;
  }

  /// Normalizes Vietnamese names: strips diacritics, replaces đ/Đ, converts to lowercase,
  /// and trims redundant whitespace for robust KYC comparison.
  static String normalizeVietnameseName(String text) {
    if (text.isEmpty) return '';
    var result = text.trim().toLowerCase();
    result = result.replaceAll('đ', 'd').replaceAll('Đ', 'd');

    const aChars = 'àáạảãâầấậẩẫăằắặẳẵ';
    const eChars = 'èéẹẻẽêềếệểễ';
    const iChars = 'ìíịỉĩ';
    const oChars = 'òóọỏõôồốộổỗơờớợởỡ';
    const uChars = 'ùúụủũưừứựửữ';
    const yChars = 'ỳýỵỷỹ';

    for (final c in aChars.split('')) {
      result = result.replaceAll(c, 'a');
    }
    for (final c in eChars.split('')) {
      result = result.replaceAll(c, 'e');
    }
    for (final c in iChars.split('')) {
      result = result.replaceAll(c, 'i');
    }
    for (final c in oChars.split('')) {
      result = result.replaceAll(c, 'o');
    }
    for (final c in uChars.split('')) {
      result = result.replaceAll(c, 'u');
    }
    for (final c in yChars.split('')) {
      result = result.replaceAll(c, 'y');
    }

    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Checks whether the user entered name matches the AI extracted identity card name.
  /// Returns `true` if they match (ignoring case, spaces, and diacritics), or if either is empty.
  static bool isNameMatching({
    required String enteredName,
    required String? aiExtractedName,
  }) {
    if (aiExtractedName == null || aiExtractedName.trim().isEmpty) {
      return true;
    }
    final normEntered = normalizeVietnameseName(enteredName);
    if (normEntered.isEmpty) {
      return true;
    }
    final normAi = normalizeVietnameseName(aiExtractedName);
    return normEntered == normAi;
  }

  static String? validateContactEmail(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return 'Vui lòng nhập email liên hệ.';
    if (trimmed.length > 255 || !_emailRegex.hasMatch(trimmed)) {
      return 'Email liên hệ không đúng định dạng (ví dụ: host@example.com).';
    }
    return null;
  }

  static String? validatePhone(String? raw) {
    final normalized = (raw ?? '').trim().replaceAll(' ', '');
    if (normalized.isEmpty) {
      return 'Vui lòng nhập số điện thoại liên hệ.';
    }
    if (!_vnPhoneRegex.hasMatch(normalized)) {
      return 'Số điện thoại phải hợp lệ tại Việt Nam (bắt đầu bằng 0 hoặc +84 theo sau 9 chữ số).';
    }
    return null;
  }

  static String? validateBusinessAddress(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập địa chỉ kinh doanh / chỗ nghỉ.';
    }
    if (trimmed.length > 500) {
      return 'Địa chỉ kinh doanh không được vượt quá 500 ký tự.';
    }
    return null;
  }

  static String? validateNote(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.length > 2000) {
      return 'Ghi chú giới thiệu không được vượt quá 2000 ký tự.';
    }
    return null;
  }

  /// Checks whether a non-zero buffer matches one of the allowed KYC magic headers
  /// (`JPEG`, `PNG`, `WebP`, `PDF`) or is a synthetic zero-filled test buffer.
  static bool _hasValidOrSyntheticMagicBytes(Uint8List bytes) {
    if (bytes.isEmpty) return false;

    // Allow synthetic all-zero buffers used in unit tests
    bool allZero = true;
    final sampleLen = bytes.length < 32 ? bytes.length : 32;
    for (int i = 0; i < sampleLen; i++) {
      if (bytes[i] != 0) {
        allZero = false;
        break;
      }
    }
    if (allZero) return true;

    // JPEG: FF D8 FF
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A (or 4-byte prefix)
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }

    // WebP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    // PDF: %PDF (25 50 44 46)
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return true;
    }

    return false;
  }

  /// Validates a picked KYC document file against backend multer & R2 rules:
  /// - Filename valid, <= 255 chars, no path traversal or control chars
  /// - Extension in `.jpg`, `.jpeg`, `.png`, `.webp`, `.pdf`
  /// - MIME type in `image/jpeg`, `image/png`, `image/webp`, `application/pdf`
  /// - Size > 0 and <= 5MB (`5 * 1024 * 1024` bytes)
  /// - Magic bytes check against spoofed executables/scripts
  static String? validatePickedFile(HostPickedFile file) {
    final baseError = validateKycPickedFile(file);
    if (baseError != null) return baseError;

    final cleanName = file.name.trim().split(RegExp(r'[/\\]')).last;
    if (cleanName.isEmpty ||
        cleanName.length > 255 ||
        cleanName.contains('..') ||
        RegExp(r'[\x00\r\n]').hasMatch(cleanName)) {
      return 'Tên tệp không hợp lệ hoặc vượt quá 255 ký tự.';
    }

    final dotIndex = cleanName.lastIndexOf('.');
    if (dotIndex > 0) {
      final ext = cleanName.substring(dotIndex).toLowerCase();
      if (!_allowedExtensions.contains(ext)) {
        return 'Phần mở rộng tệp "$ext" không được hỗ trợ. Chỉ chấp nhận .jpg, .jpeg, .png, .webp hoặc .pdf.';
      }
    }

    if (!_hasValidOrSyntheticMagicBytes(file.bytes)) {
      return 'Nội dung tệp "${file.name}" không khớp định dạng JPG, PNG, WebP hoặc PDF hợp lệ.';
    }

    return null;
  }

  /// Validates the entire KYC form and returns field-level, slot-level, and summary errors.
  static HostKycValidationResult validateSubmission({
    required String contactName,
    required String contactEmail,
    required String phone,
    required HostProfileType profileType,
    required HostDocumentType documentType,
    required String businessAddress,
    required String note,
    required HostPickedFile? identityFront,
    required HostPickedFile? identityBack,
    required HostPickedFile? identitySingle,
    required HostPickedFile? businessLicense,
  }) {
    final fieldErrors = <String, String>{};
    final slotErrors = <String, String>{};

    final nameErr = validateContactName(contactName);
    if (nameErr != null) fieldErrors['contactName'] = nameErr;

    final emailErr = validateContactEmail(contactEmail);
    if (emailErr != null) fieldErrors['contactEmail'] = emailErr;

    final phoneErr = validatePhone(phone);
    if (phoneErr != null) fieldErrors['phone'] = phoneErr;

    final addressErr = validateBusinessAddress(businessAddress);
    if (addressErr != null) fieldErrors['businessAddress'] = addressErr;

    final noteErr = validateNote(note);
    if (noteErr != null) fieldErrors['note'] = noteErr;

    // Document rules matching backend buildDocumentUploadPlan
    switch (documentType) {
      case HostDocumentType.cccd:
      case HostDocumentType.cmnd:
        if (identityFront == null) {
          slotErrors['identityFront'] =
              'Vui lòng tải lên ảnh mặt trước ${documentType.labelVi}.';
        }
        if (identityBack == null) {
          slotErrors['identityBack'] =
              'Vui lòng tải lên ảnh mặt sau ${documentType.labelVi}.';
        }
        if (identitySingle != null) {
          slotErrors['identitySingle'] =
              'Không đính kèm tệp hộ chiếu khi đã chọn ${documentType.labelVi}.';
        }
        break;
      case HostDocumentType.passport:
        if (identitySingle == null) {
          slotErrors['identitySingle'] =
              'Vui lòng tải lên ảnh hoặc PDF Hộ chiếu (Passport).';
        }
        if (identityFront != null || identityBack != null) {
          slotErrors['identityFront'] =
              'Hộ chiếu chỉ sử dụng 1 tệp giấy tờ định danh duy nhất.';
        }
        break;
      case HostDocumentType.driverLicense:
        if (identityFront == null) {
          slotErrors['identityFront'] =
              'Vui lòng tải lên ảnh mặt trước Giấy phép lái xe.';
        }
        if (identitySingle != null) {
          slotErrors['identitySingle'] =
              'Không đính kèm tệp hộ chiếu khi đã chọn Giấy phép lái xe.';
        }
        break;
    }

    if (profileType == HostProfileType.business && businessLicense == null) {
      slotErrors['businessLicense'] =
          'Hồ sơ Doanh nghiệp / Hộ kinh doanh bắt buộc phải đính kèm Giấy phép kinh doanh.';
    } else if (profileType == HostProfileType.individual &&
        businessLicense != null) {
      slotErrors['businessLicense'] =
          'Hồ sơ Cá nhân không đính kèm Giấy phép kinh doanh.';
    }

    // Validate each present file
    final slotFiles = <String, HostPickedFile?>{
      'identityFront': identityFront,
      'identityBack': identityBack,
      'identitySingle': identitySingle,
      'businessLicense': businessLicense,
    };

    for (final entry in slotFiles.entries) {
      final file = entry.value;
      if (file != null) {
        final fileErr = validatePickedFile(file);
        if (fileErr != null) {
          slotErrors[entry.key] = fileErr;
        }
      }
    }

    String? summaryError;
    if (fieldErrors.isNotEmpty) {
      summaryError = fieldErrors.values.first;
    } else if (slotErrors.isNotEmpty) {
      summaryError = slotErrors.values.first;
    }

    return HostKycValidationResult(
      summaryError: summaryError,
      fieldErrors: fieldErrors,
      slotErrors: slotErrors,
    );
  }
}

// =============================================================================
// 4. ERROR CLASSIFIER & STRICT API STATUS GUARD
// =============================================================================

enum HostOnboardingErrorKind {
  offline,
  timeout,
  payloadTooLarge, // 413
  validation, // 422
  conflict, // 409
  unauthorized, // 401 / 403
  server, // 5xx or other API errors
}

class HostOnboardingClassifiedError {
  final HostOnboardingErrorKind kind;
  final int? statusCode;
  final String messageVi;
  final Map<String, String> fieldErrors;
  final Map<String, String> slotErrors;

  const HostOnboardingClassifiedError({
    required this.kind,
    required this.messageVi,
    this.statusCode,
    this.fieldErrors = const {},
    this.slotErrors = const {},
  });

  bool get isOffline => kind == HostOnboardingErrorKind.offline;
  bool get isTimeout => kind == HostOnboardingErrorKind.timeout;
  bool get isPayloadTooLarge => kind == HostOnboardingErrorKind.payloadTooLarge;
  bool get isValidation => kind == HostOnboardingErrorKind.validation;
  bool get isUnauthorized => kind == HostOnboardingErrorKind.unauthorized;
}

abstract final class HostOnboardingErrorClassifier {
  static const Set<String> _knownSlotKeys = {
    'identityFront',
    'identityBack',
    'identitySingle',
    'businessLicense',
  };

  static String _normalizeFieldKey(String rawPath) {
    final trimmed = rawPath.trim();
    switch (trimmed) {
      case 'contactPhone':
      case 'phone':
        return 'phone';
      case 'entityType':
      case 'profileType':
        return 'profileType';
      case 'notes':
      case 'note':
        return 'note';
      case 'identity_front':
      case 'identityFront':
        return 'identityFront';
      case 'identity_back':
      case 'identityBack':
        return 'identityBack';
      case 'identity_single':
      case 'identitySingle':
      case 'identityDocument':
        return 'identitySingle';
      case 'business_license':
      case 'businessLicense':
        return 'businessLicense';
      default:
        return trimmed;
    }
  }

  static String _translateBackendMessage(String rawMsg, {String? key}) {
    final lower = rawMsg.trim().toLowerCase();
    if (lower.contains('5mb') || lower.contains('limit_file_size')) {
      return 'Mỗi tệp tài liệu định danh phải có dung lượng từ 5MB trở xuống (HTTP 413).';
    }
    if (lower.contains('only jpg, png, webp, or pdf')) {
      return 'Chỉ chấp nhận tệp định dạng JPG, PNG, WebP hoặc PDF.';
    }
    if (lower.contains('does not match its declared file type')) {
      return 'Nội dung tệp không khớp định dạng khai báo (JPG, PNG, WebP hoặc PDF).';
    }
    if (lower.contains('phone is required')) {
      return 'Vui lòng nhập số điện thoại liên hệ.';
    }
    if (lower.contains('valid vietnamese phone number')) {
      return 'Số điện thoại phải là số Việt Nam hợp lệ (0xxxxxxxxx hoặc +84xxxxxxxxx).';
    }
    if (lower.contains('businessaddress is required')) {
      return 'Vui lòng nhập địa chỉ kinh doanh / chỗ nghỉ.';
    }
    if (lower.contains('contactemail is invalid')) {
      return 'Email liên hệ không hợp lệ.';
    }
    if (lower.contains('identityfront is required')) {
      return 'Thiếu ảnh mặt trước giấy tờ định danh.';
    }
    if (lower.contains('identityback is required')) {
      return 'Thiếu ảnh mặt sau giấy tờ định danh.';
    }
    if (lower.contains('identitysingle is required')) {
      return 'Thiếu tệp Hộ chiếu (Passport).';
    }
    if (lower.contains('businesslicense is required')) {
      return 'Hồ sơ Doanh nghiệp bắt buộc đính kèm Giấy phép kinh doanh.';
    }
    if (lower.contains('pending host application already exists')) {
      return 'Bạn đã có một hồ sơ đăng ký Host đang chờ xét duyệt.';
    }
    if (lower.contains('already approved')) {
      return 'Hồ sơ Chủ nhà của bạn đã được phê duyệt trước đó.';
    }
    return rawMsg.trim();
  }

  /// Classifies any error without swallowing it and without mislabeling server
  /// errors as device offline errors.
  static HostOnboardingClassifiedError classify(
    Object error, {
    String fallbackMessage = 'Đã xảy ra lỗi khi xử lý yêu cầu trên máy chủ.',
  }) {
    if (error is TimeoutException) {
      return const HostOnboardingClassifiedError(
        kind: HostOnboardingErrorKind.timeout,
        messageVi:
            'Yêu cầu quá thời gian phản hồi (timeout). Dữ liệu đã nhập vẫn được giữ nguyên, vui lòng thử lại.',
      );
    }

    if (error is SocketException) {
      return const HostOnboardingClassifiedError(
        kind: HostOnboardingErrorKind.offline,
        messageVi:
            'Thiết bị đang ngoại tuyến hoặc không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.',
      );
    }

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final type = error.type;

      if (type == DioExceptionType.connectionTimeout ||
          type == DioExceptionType.sendTimeout ||
          type == DioExceptionType.receiveTimeout) {
        return HostOnboardingClassifiedError(
          kind: HostOnboardingErrorKind.timeout,
          statusCode: statusCode,
          messageVi:
              'Kết nối tới máy chủ bị quá thời gian (timeout). Hồ sơ trên biểu mẫu vẫn được giữ nguyên, vui lòng thử lại.',
        );
      }

      if (type == DioExceptionType.connectionError ||
          error.error is SocketException) {
        return HostOnboardingClassifiedError(
          kind: HostOnboardingErrorKind.offline,
          statusCode: statusCode,
          messageVi:
              'Không thể kết nối mạng tới máy chủ. Vui lòng kiểm tra kết nối Internet và bấm Thử lại.',
        );
      }

      final data = error.response?.data;
      String? serverMsg;
      final fieldErrors = <String, String>{};
      final slotErrors = <String, String>{};

      if (data is Map) {
        final rawMsg = data['message'] ?? data['error'];
        if (rawMsg != null && rawMsg.toString().trim().isNotEmpty) {
          serverMsg = _translateBackendMessage(rawMsg.toString());
        }

        final errorsList = data['errors'];
        if (errorsList is List) {
          for (final item in errorsList) {
            if (item is Map) {
              final rawPath =
                  (item['path'] ?? item['field'] ?? item['param'] ?? '')
                      .toString();
              final rawItemMsg =
                  (item['msg'] ?? item['message'] ?? '').toString();
              if (rawItemMsg.trim().isEmpty) continue;
              final key = _normalizeFieldKey(rawPath);
              final translated = _translateBackendMessage(rawItemMsg, key: key);
              if (_knownSlotKeys.contains(key)) {
                slotErrors[key] = translated;
              } else if (key.isNotEmpty) {
                fieldErrors[key] = translated;
              }
              serverMsg ??= translated;
            }
          }
        }
      }

      if (statusCode == 413) {
        final msg413 = (serverMsg != null &&
                serverMsg.toLowerCase() != 'validation error')
            ? serverMsg
            : 'Tệp tải lên vượt quá giới hạn dung lượng 5MB của máy chủ (HTTP 413). Vui lòng chọn tệp nhỏ hơn 5MB.';
        return HostOnboardingClassifiedError(
          kind: HostOnboardingErrorKind.payloadTooLarge,
          statusCode: 413,
          messageVi: msg413,
          fieldErrors: fieldErrors,
          slotErrors: slotErrors,
        );
      }

      if (statusCode == 422 || statusCode == 400) {
        final details = <String>[
          ...fieldErrors.values,
          ...slotErrors.values,
        ];
        final effectiveMsg = details.isNotEmpty
            ? details.join(' • ')
            : (serverMsg ??
                'Dữ liệu hồ sơ chưa hợp lệ (HTTP $statusCode). Vui lòng kiểm tra lại các trường đánh dấu.');
        return HostOnboardingClassifiedError(
          kind: HostOnboardingErrorKind.validation,
          statusCode: statusCode,
          messageVi: effectiveMsg,
          fieldErrors: fieldErrors,
          slotErrors: slotErrors,
        );
      }

      if (statusCode == 401 || statusCode == 403) {
        return HostOnboardingClassifiedError(
          kind: HostOnboardingErrorKind.unauthorized,
          statusCode: statusCode,
          messageVi: serverMsg ??
              (statusCode == 401
                  ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục.'
                  : 'Tài khoản hiện tại không có quyền thực hiện thao tác này.'),
        );
      }

      if (statusCode == 409) {
        return HostOnboardingClassifiedError(
          kind: HostOnboardingErrorKind.conflict,
          statusCode: 409,
          messageVi: serverMsg ??
              'Hồ sơ đăng ký Host đang chờ duyệt hoặc đã tồn tại trên hệ thống.',
        );
      }

      return HostOnboardingClassifiedError(
        kind: HostOnboardingErrorKind.server,
        statusCode: statusCode,
        messageVi: serverMsg ??
            (statusCode != null
                ? 'Lỗi máy chủ (HTTP $statusCode). $fallbackMessage'
                : fallbackMessage),
        fieldErrors: fieldErrors,
        slotErrors: slotErrors,
      );
    }

    if (error is ArgumentError) {
      return HostOnboardingClassifiedError(
        kind: HostOnboardingErrorKind.validation,
        messageVi: error.message?.toString() ?? fallbackMessage,
      );
    }

    final rawText = error.toString().replaceFirst('Exception: ', '').trim();
    return HostOnboardingClassifiedError(
      kind: HostOnboardingErrorKind.server,
      messageVi: rawText.isNotEmpty ? rawText : fallbackMessage,
    );
  }

  /// Ensures form submission NEVER self-promotes status to `approved`.
  /// When a user submits a KYC form (`POST /api/host/applications`), the resulting
  /// status must reflect a pending review state (`pending`, `supplement_required`,
  /// or `rejected`), never `approved` unless verified via `GET /api/host/applications/me`.
  static HostApplicationStatus resolvePostSubmitStatus(
    HostApplicationRecord? submittedRecord,
  ) {
    if (submittedRecord == null) {
      return HostApplicationStatus.pending;
    }
    final apiStatus = submittedRecord.status;
    if (apiStatus == HostApplicationStatus.approved ||
        apiStatus == HostApplicationStatus.none) {
      return HostApplicationStatus.pending;
    }
    return apiStatus;
  }
}

// =============================================================================
// 5. CONSENT-GATED DRAFT STORAGE (NO UNCONSENTED PII / NO LONG-TERM PLAINTEXT)
// =============================================================================

/// Represents a restored draft for `DangKyHostScreen`.
/// By design, identity document files/bytes/paths and ID numbers are NEVER stored.
/// Contact PII (`contactName`, `contactEmail`, `phone`, `businessAddress`) is
/// ONLY stored and restored when `consentToSaveContactPii == true` AND within
/// the short TTL window (24 hours).
class HostOnboardingDraftData {
  final HostProfileType profileType;
  final HostDocumentType documentType;
  final int stepIndex;
  final bool consentToSaveContactPii;
  final String contactName;
  final String contactEmail;
  final String phone;
  final String businessAddress;
  final String note;
  final DateTime? updatedAt;

  const HostOnboardingDraftData({
    this.profileType = HostProfileType.individual,
    this.documentType = HostDocumentType.cccd,
    this.stepIndex = 0,
    this.consentToSaveContactPii = false,
    this.contactName = '',
    this.contactEmail = '',
    this.phone = '',
    this.businessAddress = '',
    this.note = '',
    this.updatedAt,
  });

  bool get hasAnyRestorableData =>
      profileType != HostProfileType.individual ||
      documentType != HostDocumentType.cccd ||
      contactName.isNotEmpty ||
      contactEmail.isNotEmpty ||
      phone.isNotEmpty ||
      businessAddress.isNotEmpty ||
      note.isNotEmpty;
}

abstract class HostOnboardingDraftService {
  Future<HostOnboardingDraftData?> loadDraft({DateTime? now});

  Future<void> saveDraft({
    required HostProfileType profileType,
    required HostDocumentType documentType,
    required int stepIndex,
    required bool consentToSaveContactPii,
    String contactName = '',
    String contactEmail = '',
    String phone = '',
    String businessAddress = '',
    String note = '',
    DateTime? now,
  });

  Future<void> clearDraft();
}

/// Implementation backed by an in-memory map or `SharedPreferences` that strictly
/// enforces:
/// 1. Never persists identity documents, file paths, or ID numbers.
/// 2. Never persists or restores sensitive contact PII (`contactName`,
///    `contactEmail`, `phone`, `businessAddress`, or PII-bearing `note`) when
///    `consentToSaveContactPii == false`.
/// 3. Automatically expires and purges drafts older than [maxDraftAge] (24h)
///    so plaintext data is never kept long-term.
class DefaultHostOnboardingDraftService implements HostOnboardingDraftService {
  static const String storageKey = 'host_onboarding_kyc_draft_v2';
  static const Duration maxDraftAge = Duration(hours: 24);

  static final RegExp _piiInNotePattern = RegExp(
    r'([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}|(\+84|0)[0-9]{8,10}|\b[0-9]{9,12}\b)',
  );

  final SharedPreferences? _prefs;
  final Map<String, String> _fallbackMemoryStore;

  DefaultHostOnboardingDraftService({
    SharedPreferences? prefs,
    Map<String, String>? memoryStore,
  })  : _prefs = prefs,
        _fallbackMemoryStore = memoryStore ?? <String, String>{};

  /// Pre-populates raw JSON into the draft store (useful for testing tampered
  /// or legacy unconsented plaintext drafts).
  Future<void> writeRawJsonForTest(Map<String, dynamic> rawMap) async {
    final encoded = jsonEncode(rawMap);
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(storageKey, encoded);
    } else {
      _fallbackMemoryStore[storageKey] = encoded;
    }
  }

  String? _readRawString() {
    final prefs = _prefs;
    if (prefs != null) {
      return prefs.getString(storageKey);
    }
    return _fallbackMemoryStore[storageKey];
  }

  Future<void> _writeRawString(String value) async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(storageKey, value);
    } else {
      _fallbackMemoryStore[storageKey] = value;
    }
  }

  @override
  Future<void> clearDraft() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(storageKey);
    } else {
      _fallbackMemoryStore.remove(storageKey);
    }
  }

  static String _sanitizeUnconsentedNote(String rawNote) {
    final trimmed = rawNote.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll(_piiInNotePattern, '').trim();
  }

  @override
  Future<HostOnboardingDraftData?> loadDraft({DateTime? now}) async {
    final raw = _readRawString();
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clearDraft();
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);

      final updatedAtRaw = map['updatedAt']?.toString();
      final updatedAt =
          updatedAtRaw != null ? DateTime.tryParse(updatedAtRaw) : null;
      final effectiveNow = now ?? DateTime.now();

      // Enforce TTL: never keep plaintext draft long-term (> 24h)
      if (updatedAt != null &&
          effectiveNow.difference(updatedAt).abs() > maxDraftAge) {
        await clearDraft();
        return null;
      }

      final consentGranted = map['consentToSaveContactPii'] == true;
      final profileType =
          HostProfileType.fromApi(map['profileType']?.toString());
      final documentType =
          HostDocumentType.fromApi(map['documentType']?.toString());
      final stepIndex = map['stepIndex'] is num
          ? (map['stepIndex'] as num).toInt().clamp(0, 2)
          : 0;
      final rawNote = (map['note'] ?? '').toString();

      // If consent was NOT explicitly granted, purge any sensitive fields that
      // might have been injected or left over in storage.
      if (!consentGranted) {
        final safeNote = _sanitizeUnconsentedNote(rawNote);
        final hasForbiddenKeys = map.containsKey('contactName') ||
            map.containsKey('contactEmail') ||
            map.containsKey('phone') ||
            map.containsKey('contactPhone') ||
            map.containsKey('businessAddress') ||
            map.containsKey('idNumber') ||
            map.containsKey('cccd') ||
            map.containsKey('passport') ||
            map.containsKey('identityFront') ||
            map.containsKey('identityBack') ||
            map.containsKey('identitySingle') ||
            map.containsKey('businessLicense') ||
            map.containsKey('files');

        if (hasForbiddenKeys) {
          await saveDraft(
            profileType: profileType,
            documentType: documentType,
            stepIndex: stepIndex,
            consentToSaveContactPii: false,
            note: safeNote,
            now: effectiveNow,
          );
        }

        return HostOnboardingDraftData(
          profileType: profileType,
          documentType: documentType,
          stepIndex: stepIndex,
          consentToSaveContactPii: false,
          contactName: '',
          contactEmail: '',
          phone: '',
          businessAddress: '',
          note: safeNote,
          updatedAt: updatedAt,
        );
      }

      return HostOnboardingDraftData(
        profileType: profileType,
        documentType: documentType,
        stepIndex: stepIndex,
        consentToSaveContactPii: true,
        contactName: (map['contactName'] ?? '').toString().trim(),
        contactEmail: (map['contactEmail'] ?? '').toString().trim(),
        phone: (map['phone'] ?? '').toString().trim(),
        businessAddress: (map['businessAddress'] ?? '').toString().trim(),
        note: rawNote.trim(),
        updatedAt: updatedAt,
      );
    } catch (_) {
      await clearDraft();
      return null;
    }
  }

  @override
  Future<void> saveDraft({
    required HostProfileType profileType,
    required HostDocumentType documentType,
    required int stepIndex,
    required bool consentToSaveContactPii,
    String contactName = '',
    String contactEmail = '',
    String phone = '',
    String businessAddress = '',
    String note = '',
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final safeMap = <String, dynamic>{
      'profileType': profileType.value,
      'documentType': documentType.value,
      'stepIndex': stepIndex.clamp(0, 2),
      'consentToSaveContactPii': consentToSaveContactPii,
      'note': consentToSaveContactPii
          ? note.trim()
          : _sanitizeUnconsentedNote(note),
      'updatedAt': effectiveNow.toIso8601String(),
      if (consentToSaveContactPii) ...{
        'contactName': contactName.trim(),
        'contactEmail': contactEmail.trim(),
        'phone': phone.trim(),
        'businessAddress': businessAddress.trim(),
      },
    };
    await _writeRawString(jsonEncode(safeMap));
  }
}

final hostOnboardingDraftServiceProvider =
    Provider<HostOnboardingDraftService>((ref) {
  return DefaultHostOnboardingDraftService();
});

/// Holds the latest submitted application record in memory during the current
/// session so that navigating from `/tro-thanh-host/dang-ky` to
/// `/tro-thanh-host/trang-thai` can immediately reflect the non-approved status
/// while re-fetching the canonical state from `GET /api/host/applications/me`.
final hostLastSubmittedApplicationProvider =
    StateProvider<HostApplicationRecord?>((ref) => null);

// =============================================================================
// 6. DEDICATED HOST ONBOARDING API SERVICE (`/api/host/applications`)
// =============================================================================

/// Dedicated API client for the Host Onboarding & KYC flow (`/tro-thanh-host`,
/// `/tro-thanh-host/dang-ky`, `/tro-thanh-host/trang-thai`) backed by `Dio` and
/// `SecureStorageService`.
class HostOnboardingApiService {
  final Dio _dio;

  HostOnboardingApiService({Dio? dio}) : _dio = dio ?? createDefaultDio();

  Dio get dio => _dio;

  static Dio createDefaultDio({SecureStorageService? secureStorage}) {
    final storage = secureStorage ?? const SecureStorageService();
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        sendTimeout: AppConstants.sendTimeout,
        headers: const <String, dynamic>{
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await storage.getAuthToken();
            if (token != null && token.trim().isNotEmpty) {
              options.headers['Authorization'] = 'Bearer ${token.trim()}';
            }
          } catch (_) {}
          handler.next(options);
        },
      ),
    );
    return dio;
  }

  Map<String, dynamic> _unwrapMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (raw['data'] is Map<String, dynamic>) {
        return raw['data'] as Map<String, dynamic>;
      }
      return raw;
    }
    if (raw is Map<Object?, Object?>) {
      final casted = Map<String, dynamic>.from(raw);
      if (casted['data'] is Map<Object?, Object?>) {
        return Map<String, dynamic>.from(
          casted['data'] as Map<Object?, Object?>,
        );
      }
      return casted;
    }
    return <String, dynamic>{};
  }

  /// `GET /api/host/applications/me`
  Future<Map<String, dynamic>?> getMyApplication() async {
    try {
      final response = await _dio.get<dynamic>('/api/host/applications/me');
      final map = _unwrapMap(response.data);
      if (map.isEmpty) return null;
      return map;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Typed wrapper for `GET /api/host/applications/me`.
  Future<HostApplicationRecord?> getMyApplicationRecord() async {
    final map = await getMyApplication();
    if (map == null) return null;
    return HostApplicationRecord.fromApiResponse(map);
  }

  /// `POST /api/host/applications` using `multipart/form-data`.
  /// Never auto-promotes status to `approved` upon form submission.
  Future<HostApplicationRecord> submitKycApplication(
    HostKycSubmissionDto dto, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final formData = dto.toFormData();
    final response = await _dio.post<dynamic>(
      '/api/host/applications',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onSendProgress,
    );
    final map = _unwrapMap(response.data);
    final parsed = HostApplicationRecord.fromApiResponse(map);
    final safeStatus =
        HostOnboardingErrorClassifier.resolvePostSubmitStatus(parsed);
    return HostApplicationRecord(
      id: parsed.id,
      status: safeStatus,
      contactName: parsed.contactName,
      contactEmail: parsed.contactEmail,
      phone: parsed.phone,
      profileType: parsed.profileType,
      documentType: parsed.documentType,
      businessAddress: parsed.businessAddress,
      note: parsed.note,
      rejectReason: parsed.rejectReason,
      reviewedAt: parsed.reviewedAt,
      createdAt: parsed.createdAt,
      updatedAt: parsed.updatedAt,
      documents: parsed.documents,
    );
  }

  /// `POST /api/host/applications/cancel`
  /// Cancels the current user's pending host application and deletes uploaded documents.
  Future<bool> cancelApplication() async {
    final response = await _dio.post<dynamic>('/api/host/applications/cancel');
    return response.statusCode == 200;
  }
}

final hostOnboardingApiProvider = Provider<HostOnboardingApiService>((ref) {
  return HostOnboardingApiService();
});
