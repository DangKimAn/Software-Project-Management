import 'dart:typed_data';
import '../../auth/domain/entities/user.dart';

/// Maximum lengths and constraints aligned with `backend/src/modules/users/users.validator.ts`
/// and `backend/src/modules/uploads/uploads.service.ts`.
const int kMaxFullNameLength = 255;
const int kMaxBioLength = 2000;
const int kMaxProfileTextFieldLength = 255;
const int kMaxLanguagesCount = 20;
const int kMaxLanguageItemLength = 64;
const int kMaxAvatarFileSizeBytes = 5 * 1024 * 1024; // 5MB

const Set<String> kAllowedAvatarMimeTypes = <String>{
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
};

final RegExp kVietnamesePhoneRegex = RegExp(r'^(0|\+84)[0-9]{9}$');

/// Parses a comma-separated string of languages into a clean list of non-empty tokens.
List<String> parseLanguagesInput(String raw) {
  return raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// Validates an optional HTTP/HTTPS URL string.
bool isValidHttpUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
    return false;
  }
  return uri.scheme == 'http' || uri.scheme == 'https';
}

/// Resolves canonical image MIME type from magic header bytes and/or filename extension.
String resolveAvatarMimeType(String filename, {Uint8List? headerBytes}) {
  if (headerBytes != null && headerBytes.length >= 4) {
    // JPEG: FF D8 FF
    if (headerBytes[0] == 0xFF &&
        headerBytes[1] == 0xD8 &&
        headerBytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    // PNG: 89 50 4E 47
    if (headerBytes[0] == 0x89 &&
        headerBytes[1] == 0x50 &&
        headerBytes[2] == 0x4E &&
        headerBytes[3] == 0x47) {
      return 'image/png';
    }
    // GIF: 47 49 46 38
    if (headerBytes[0] == 0x47 &&
        headerBytes[1] == 0x49 &&
        headerBytes[2] == 0x46 &&
        headerBytes[3] == 0x38) {
      return 'image/gif';
    }
    // WebP: RIFF....WEBP
    if (headerBytes.length >= 12 &&
        headerBytes[0] == 0x52 &&
        headerBytes[1] == 0x49 &&
        headerBytes[2] == 0x46 &&
        headerBytes[3] == 0x46 &&
        headerBytes[8] == 0x57 &&
        headerBytes[9] == 0x45 &&
        headerBytes[10] == 0x42 &&
        headerBytes[11] == 0x50) {
      return 'image/webp';
    }
  }

  final lower = filename.trim().toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'application/octet-stream';
}

/// Scoped draft state for profile edits.
/// Always bound to a specific [userId] so draft PII is never leaked across accounts.
class ProfileDraftData {
  final String userId;
  final String fullName;
  final String phone;
  final String bio;
  final String location;
  final String dreamDestination;
  final String job;
  final String school;
  final String languages;
  final String avatarUrl;

  const ProfileDraftData({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.bio,
    required this.location,
    required this.dreamDestination,
    required this.job,
    required this.school,
    required this.languages,
    required this.avatarUrl,
  });

  factory ProfileDraftData.fromUser(User user) {
    return ProfileDraftData(
      userId: user.id,
      fullName: user.fullName,
      phone: user.phoneNumber ?? '',
      bio: user.bio ?? '',
      location: user.location ?? '',
      dreamDestination: user.dreamDestination ?? '',
      job: user.job ?? '',
      school: user.school ?? '',
      languages: user.languages.isNotEmpty ? user.languages.join(', ') : '',
      avatarUrl: user.avatarUrl ?? '',
    );
  }

  List<String> get parsedLanguages => parseLanguagesInput(languages);

  bool hasChangesComparedTo(User user) {
    if (userId != user.id) return false;
    final userLangs =
        user.languages.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final draftLangs = parsedLanguages;
    final sameLanguages = userLangs.length == draftLangs.length &&
        List<int>.generate(userLangs.length, (i) => i)
            .every((i) => userLangs[i] == draftLangs[i]);

    return fullName.trim() != user.fullName.trim() ||
        phone.trim() != (user.phoneNumber ?? '').trim() ||
        bio.trim() != (user.bio ?? '').trim() ||
        location.trim() != (user.location ?? '').trim() ||
        dreamDestination.trim() != (user.dreamDestination ?? '').trim() ||
        job.trim() != (user.job ?? '').trim() ||
        school.trim() != (user.school ?? '').trim() ||
        avatarUrl.trim() != (user.avatarUrl ?? '').trim() ||
        !sameLanguages;
  }

  bool hasSensitiveChangeComparedTo(User user) {
    if (userId != user.id) return false;
    final oldPhone = (user.phoneNumber ?? '').trim();
    final newPhone = phone.trim();
    return oldPhone.isNotEmpty && oldPhone != newPhone;
  }

  ProfileDraftData copyWith({
    String? fullName,
    String? phone,
    String? bio,
    String? location,
    String? dreamDestination,
    String? job,
    String? school,
    String? languages,
    String? avatarUrl,
  }) {
    return ProfileDraftData(
      userId: userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      dreamDestination: dreamDestination ?? this.dreamDestination,
      job: job ?? this.job,
      school: school ?? this.school,
      languages: languages ?? this.languages,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  /// Redacts PII so accidental logging never exposes user name or phone number.
  @override
  String toString() =>
      'ProfileDraftData(userId: $userId, fullName: [REDACTED], phone: [REDACTED])';
}

/// Validation result for profile edits.
class ProfileValidationResult {
  final Map<String, String> fieldErrors;

  const ProfileValidationResult({
    this.fieldErrors = const <String, String>{},
  });

  bool get isValid => fieldErrors.isEmpty;

  String? get firstErrorMessage =>
      fieldErrors.isEmpty ? null : fieldErrors.values.first;
}

/// Validates [ProfileDraftData] against backend `updateProfileSchema` constraints.
ProfileValidationResult validateProfileDraft(ProfileDraftData draft) {
  final errors = <String, String>{};

  final trimmedName = draft.fullName.trim();
  if (trimmedName.isEmpty) {
    errors['fullName'] = 'Họ và tên không được để trống.';
  } else if (trimmedName.length > kMaxFullNameLength) {
    errors['fullName'] =
        'Họ và tên không được vượt quá $kMaxFullNameLength ký tự.';
  }

  final trimmedPhone = draft.phone.trim();
  if (trimmedPhone.isNotEmpty &&
      !kVietnamesePhoneRegex.hasMatch(trimmedPhone)) {
    errors['phone'] =
        'Số điện thoại không hợp lệ (ví dụ: 0912345678 hoặc +84912345678).';
  }

  final trimmedAvatarUrl = draft.avatarUrl.trim();
  if (trimmedAvatarUrl.isNotEmpty && !isValidHttpUrl(trimmedAvatarUrl)) {
    errors['avatarUrl'] =
        'URL ảnh đại diện phải bắt đầu bằng http:// hoặc https://.';
  } else if (trimmedAvatarUrl.length > 500) {
    errors['avatarUrl'] = 'URL ảnh đại diện không được vượt quá 500 ký tự.';
  }

  final trimmedBio = draft.bio.trim();
  if (trimmedBio.length > kMaxBioLength) {
    errors['bio'] =
        'Giới thiệu bản thân không được vượt quá $kMaxBioLength ký tự.';
  }

  if (draft.location.trim().length > kMaxProfileTextFieldLength) {
    errors['location'] =
        'Nơi sinh sống không được vượt quá $kMaxProfileTextFieldLength ký tự.';
  }

  if (draft.dreamDestination.trim().length > kMaxProfileTextFieldLength) {
    errors['dreamDestination'] =
        'Điểm đến mơ ước không được vượt quá $kMaxProfileTextFieldLength ký tự.';
  }

  if (draft.job.trim().length > kMaxProfileTextFieldLength) {
    errors['job'] =
        'Công việc không được vượt quá $kMaxProfileTextFieldLength ký tự.';
  }

  if (draft.school.trim().length > kMaxProfileTextFieldLength) {
    errors['school'] =
        'Trường học không được vượt quá $kMaxProfileTextFieldLength ký tự.';
  }

  final langs = draft.parsedLanguages;
  if (langs.length > kMaxLanguagesCount) {
    errors['languages'] =
        'Chỉ được nhập tối đa $kMaxLanguagesCount ngôn ngữ giao tiếp.';
  } else if (langs.any((l) => l.length > kMaxLanguageItemLength)) {
    errors['languages'] =
        'Mỗi ngôn ngữ không được vượt quá $kMaxLanguageItemLength ký tự.';
  }

  return ProfileValidationResult(fieldErrors: errors);
}

/// Represents a local image file selected for avatar upload.
class AvatarPickedFile {
  final String name;
  final String mimeType;
  final int sizeBytes;
  final Uint8List bytes;
  final String? path;

  const AvatarPickedFile({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.bytes,
    this.path,
  });
}

enum AvatarPickErrorCode {
  permissionDenied,
  fileTooLarge,
  invalidMimeType,
  readError,
}

class AvatarPickException implements Exception {
  final AvatarPickErrorCode code;
  final String message;

  const AvatarPickException({
    required this.code,
    required this.message,
  });

  factory AvatarPickException.permissionDenied([String? detail]) {
    return AvatarPickException(
      code: AvatarPickErrorCode.permissionDenied,
      message: detail ??
          'Ứng dụng chưa được cấp quyền truy cập thư viện ảnh. Vui lòng cấp quyền trong Cài đặt thiết bị.',
    );
  }

  factory AvatarPickException.fileTooLarge(int sizeBytes) {
    final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
    return AvatarPickException(
      code: AvatarPickErrorCode.fileTooLarge,
      message:
          'Ảnh đã chọn có dung lượng $sizeMb MB, vượt quá giới hạn tối đa 5MB.',
    );
  }

  factory AvatarPickException.invalidMimeType(String mimeType) {
    return AvatarPickException(
      code: AvatarPickErrorCode.invalidMimeType,
      message:
          'Định dạng tệp "$mimeType" không được hỗ trợ. Vui lòng chọn ảnh JPG, PNG, WebP hoặc GIF.',
    );
  }

  factory AvatarPickException.readError([String? detail]) {
    return AvatarPickException(
      code: AvatarPickErrorCode.readError,
      message: detail ?? 'Không thể đọc tệp ảnh đã chọn. Vui lòng thử lại.',
    );
  }

  @override
  String toString() => message;
}

/// Validates an [AvatarPickedFile] against size (<= 5MB) and MIME type rules.
String? validateAvatarPickedFile(AvatarPickedFile file) {
  if (file.bytes.isEmpty || file.sizeBytes <= 0) {
    return 'Tệp ảnh rỗng hoặc không hợp lệ.';
  }
  if (file.sizeBytes > kMaxAvatarFileSizeBytes) {
    return AvatarPickException.fileTooLarge(file.sizeBytes).message;
  }
  final resolvedMime = file.mimeType.trim().isNotEmpty &&
          file.mimeType != 'application/octet-stream'
      ? file.mimeType.trim().toLowerCase()
      : resolveAvatarMimeType(file.name, headerBytes: file.bytes);
  if (!kAllowedAvatarMimeTypes.contains(resolvedMime)) {
    return AvatarPickException.invalidMimeType(resolvedMime).message;
  }
  return null;
}

/// Presigned R2 upload metadata returned by `POST /api/uploads/presign`.
class AvatarR2PresignResult {
  final String uploadUrl;
  final String publicUrl;
  final String key;
  final int expiresIn;

  const AvatarR2PresignResult({
    required this.uploadUrl,
    required this.publicUrl,
    required this.key,
    this.expiresIn = 300,
  });

  factory AvatarR2PresignResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final uploadUrl = (data['uploadUrl'] ?? '').toString().trim();
    final publicUrl = (data['publicUrl'] ?? '').toString().trim();
    final key = (data['key'] ?? data['objectKey'] ?? '').toString().trim();
    final expiresIn = data['expiresIn'] is num
        ? (data['expiresIn'] as num).toInt()
        : (int.tryParse('${data['expiresIn'] ?? 300}') ?? 300);

    if (!isValidHttpUrl(uploadUrl)) {
      throw const FormatException('Máy chủ không trả về uploadUrl hợp lệ.');
    }
    if (!isValidHttpUrl(publicUrl)) {
      throw const FormatException('Máy chủ không trả về publicUrl hợp lệ.');
    }
    if (key.isEmpty) {
      throw const FormatException('Máy chủ không trả về khóa lưu trữ hợp lệ.');
    }

    return AvatarR2PresignResult(
      uploadUrl: uploadUrl,
      publicUrl: publicUrl,
      key: key,
      expiresIn: expiresIn,
    );
  }
}
