import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../host/services/host_file_picker_web_stub.dart'
    if (dart.library.js_interop) '../../host/services/host_file_picker_web.dart';
import '../domain/account_profile_models.dart';

/// Interface for picking an avatar image from the user's device.
abstract class AvatarPickerService {
  /// Returns the selected [AvatarPickedFile], or `null` if the user cancelled.
  /// Throws [AvatarPickException] if permission is denied, the file exceeds 5MB,
  /// or the file format is unsupported.
  Future<AvatarPickedFile?> pickAvatarFromDevice({
    ImageSource source = ImageSource.gallery,
  });
}

/// Production implementation backed by `image_picker`.
class DefaultAvatarPickerService implements AvatarPickerService {
  final ImagePicker _picker;

  DefaultAvatarPickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  static bool _isPermissionDeniedCode(String code) {
    final normalized = code.trim().toLowerCase();
    return normalized.contains('denied') ||
        normalized.contains('permission') ||
        normalized.contains('restricted') ||
        normalized == 'photo_access_denied' ||
        normalized == 'camera_access_denied';
  }

  @override
  Future<AvatarPickedFile?> pickAvatarFromDevice({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      if (kIsWeb) {
        ensureWebFilePickerRegistered();
      }
      XFile? picked;
      try {
        picked = await _picker.pickImage(source: source);
      } on PlatformException {
        rethrow;
      } catch (_) {
        // Fallback to FilePicker when ImagePicker plugin channel is unavailable
        final fpResult = await FilePicker.platform.pickFiles(
          dialogTitle: 'Chọn ảnh đại diện',
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
          allowMultiple: false,
          withData: true,
        );
        if (fpResult == null || fpResult.files.isEmpty) {
          return null;
        }
        final pf = fpResult.files.first;
        picked = pf.bytes != null
            ? XFile.fromData(pf.bytes!, name: pf.name)
            : (!kIsWeb && pf.path != null
                ? XFile(pf.path!, name: pf.name)
                : null);
      }
      if (picked == null) {
        // User cancelled the picker — not an error.
        return null;
      }

      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw AvatarPickException.readError(
            'Tệp ảnh đã chọn không có dữ liệu.');
      }

      if (bytes.length > kMaxAvatarFileSizeBytes) {
        throw AvatarPickException.fileTooLarge(bytes.length);
      }

      final filename = picked.name.trim().isNotEmpty
          ? picked.name.trim()
          : picked.path.split(RegExp(r'[/\\]')).last;
      final resolvedMime = resolveAvatarMimeType(filename, headerBytes: bytes);
      final effectiveMime = resolvedMime != 'application/octet-stream'
          ? resolvedMime
          : (picked.mimeType?.trim().toLowerCase() ?? resolvedMime);

      if (!kAllowedAvatarMimeTypes.contains(effectiveMime)) {
        throw AvatarPickException.invalidMimeType(effectiveMime);
      }

      return AvatarPickedFile(
        name: filename,
        mimeType: effectiveMime,
        sizeBytes: bytes.length,
        bytes: bytes,
        path: picked.path,
      );
    } on AvatarPickException {
      rethrow;
    } on PlatformException catch (e) {
      if (_isPermissionDeniedCode(e.code)) {
        throw AvatarPickException.permissionDenied();
      }
      throw AvatarPickException.readError(
        'Không thể mở thư viện ảnh trên thiết bị (${e.code}).',
      );
    } catch (_) {
      throw AvatarPickException.readError();
    }
  }
}

/// Service that uploads a validated [AvatarPickedFile] via `POST /api/uploads/presign`
/// (`folder: 'avatars'`) and raw `PUT` to Cloudflare R2 without leaking the API Bearer token.
class AvatarUploadService {
  final Dio _apiDio;
  final Dio _cleanR2Dio;

  AvatarUploadService({
    required Dio apiDio,
    Dio? cleanR2Dio,
  })  : _apiDio = apiDio,
        _cleanR2Dio = cleanR2Dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 60),
              ),
            );

  /// Validates [file], requests a presigned URL for `folder: 'avatars'`,
  /// and uploads raw image bytes directly to R2 via HTTP `PUT`.
  Future<AvatarR2PresignResult> uploadAvatarToR2(AvatarPickedFile file) async {
    if (file.bytes.isEmpty || file.sizeBytes <= 0) {
      throw AvatarPickException.readError('Tệp ảnh rỗng hoặc không hợp lệ.');
    }
    if (file.sizeBytes > kMaxAvatarFileSizeBytes) {
      throw AvatarPickException.fileTooLarge(file.sizeBytes);
    }

    final resolvedMime = file.mimeType.trim().isNotEmpty &&
            file.mimeType != 'application/octet-stream'
        ? file.mimeType.trim().toLowerCase()
        : resolveAvatarMimeType(file.name, headerBytes: file.bytes);

    if (!kAllowedAvatarMimeTypes.contains(resolvedMime)) {
      throw AvatarPickException.invalidMimeType(resolvedMime);
    }

    final AvatarR2PresignResult presigned;
    try {
      final presignResponse = await _apiDio.post<Map<String, dynamic>>(
        '/api/uploads/presign',
        data: <String, dynamic>{
          'folder': 'avatars',
          'filename':
              file.name.trim().isNotEmpty ? file.name.trim() : 'avatar.jpg',
          'contentType': resolvedMime,
        },
      );
      final body = presignResponse.data ?? const <String, dynamic>{};
      presigned = AvatarR2PresignResult.fromJson(body);
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw DioClient.handleError(e);
    }

    try {
      final putHeaders = <String, dynamic>{
        Headers.contentTypeHeader: resolvedMime,
        Headers.contentLengthHeader: file.sizeBytes,
      };
      // Explicitly ensure Authorization header is never sent to R2 presigned URL
      putHeaders.remove('Authorization');
      putHeaders.remove('authorization');

      final putResponse = await _cleanR2Dio.put<dynamic>(
        presigned.uploadUrl,
        data: file.bytes,
        options: Options(
          headers: putHeaders,
          responseType: ResponseType.plain,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      if (putResponse.statusCode == null ||
          putResponse.statusCode! < 200 ||
          putResponse.statusCode! >= 300) {
        throw const ServerFailure(
          'Tải tệp ảnh đại diện lên kho lưu trữ thất bại. Vui lòng thử lại.',
          code: 'R2_UPLOAD_FAILED',
        );
      }

      return presigned;
    } on AppFailure {
      rethrow;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkFailure(
          'Mất kết nối mạng khi đang tải ảnh đại diện lên. Vui lòng kiểm tra mạng và thử lại.',
        );
      }
      throw const ServerFailure(
        'Tải tệp ảnh đại diện lên kho lưu trữ thất bại. Vui lòng thử lại.',
        code: 'R2_UPLOAD_FAILED',
      );
    } catch (_) {
      throw const ServerFailure(
        'Không thể tải ảnh đại diện lên. Vui lòng thử lại sau.',
        code: 'R2_UPLOAD_FAILED',
      );
    }
  }
}

final avatarPickerServiceProvider = Provider<AvatarPickerService>((ref) {
  return DefaultAvatarPickerService();
});

final avatarUploadServiceProvider = Provider<AvatarUploadService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AvatarUploadService(apiDio: dioClient.dio);
});
