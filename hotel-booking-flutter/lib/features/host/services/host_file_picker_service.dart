import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/host_models.dart';

/// Resolves the canonical MIME type from a file name and optional magic header bytes.
String resolveHostFileMimeType(String filename, {Uint8List? headerBytes}) {
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
    // PDF: 25 50 44 46 (%PDF)
    if (headerBytes[0] == 0x25 &&
        headerBytes[1] == 0x50 &&
        headerBytes[2] == 0x44 &&
        headerBytes[3] == 0x46) {
      return 'application/pdf';
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

  final lower = filename.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'application/octet-stream';
}

/// Service interface for selecting real files from the device.
abstract class HostFilePickerService {
  /// Picks a single KYC document (`JPG`, `PNG`, `WebP`, or `PDF`, max 5MB).
  Future<HostPickedFile?> pickKycDocument({
    BuildContext? context,
    String title = 'Chọn tài liệu xác minh',
  });

  /// Picks one or more listing images (`JPG`, `PNG`, `WebP`, `GIF`, max 5MB each).
  Future<List<HostPickedFile>> pickListingImages({
    BuildContext? context,
    int maxImages = kMaxListingImagesCount,
  });

  /// Picks a single image for avatar upload (`JPG`, `PNG`, `WebP`, `GIF`, max 5MB).
  Future<HostPickedFile?> pickAvatarImage({
    BuildContext? context,
  });

  /// Reads a real file from an absolute file path on disk.
  Future<HostPickedFile> readFromFilePath(String filePath);
}

/// Default implementation that reads real files from the device filesystem
/// using native OS file dialogs on desktop or a local path selector modal when
/// no platform file_picker plugin is registered in `pubspec.yaml`.
class DefaultHostFilePickerService implements HostFilePickerService {
  const DefaultHostFilePickerService();

  @override
  Future<HostPickedFile> readFromFilePath(String filePath) async {
    final trimmed = filePath.trim().replaceAll('"', '');
    if (trimmed.isEmpty) {
      throw const FileSystemException('Đường dẫn tệp trống.');
    }
    final file = File(trimmed);
    if (!await file.exists()) {
      throw FileSystemException('Không tìm thấy tệp trên thiết bị', trimmed);
    }
    final bytes = await file.readAsBytes();
    final name = trimmed.split(RegExp(r'[/\\]')).last;
    final mimeType = resolveHostFileMimeType(name, headerBytes: bytes);
    return HostPickedFile(
      name: name,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      bytes: bytes,
      path: trimmed,
    );
  }

  Future<List<String>> _openNativeFileDialog({
    required bool allowMultiple,
    required String filterDescription,
    required List<String> extensions,
  }) async {
    try {
      if (Platform.isWindows) {
        final extPattern = extensions.map((e) => '*.$e').join(';');
        final multiFlag = allowMultiple ? r'$true' : r'$false';
        final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$dlg = New-Object System.Windows.Forms.OpenFileDialog
\$dlg.Filter = "$filterDescription ($extPattern)|$extPattern"
\$dlg.Multiselect = $multiFlag
if (\$dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  \$dlg.FileNames | ForEach-Object { Write-Output \$_ }
}
''';
        final result = await Process.run(
          'powershell',
          ['-NoProfile', '-STA', '-Command', script],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        if (result.exitCode == 0) {
          final lines = (result.stdout?.toString() ?? '')
              .split(RegExp(r'\r?\n'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          return lines;
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run('osascript', [
          '-e',
          'POSIX path of (choose file)',
        ]);
        if (result.exitCode == 0) {
          final line = (result.stdout?.toString() ?? '').trim();
          if (line.isNotEmpty) return [line];
        }
      } else if (Platform.isLinux) {
        final result = await Process.run('zenity', [
          '--file-selection',
          if (allowMultiple) '--multiple',
          '--separator=\n',
        ]);
        if (result.exitCode == 0) {
          return (result.stdout?.toString() ?? '')
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {
      // Fallback to path entry dialog if native shell command is unavailable
    }
    return const [];
  }

  Future<List<String>> _promptFilePathDialog(
    BuildContext context, {
    required String title,
    required String hint,
    required bool allowMultiple,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hint,
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('host_file_path_dialog_input'),
                controller: controller,
                decoration: InputDecoration(
                  labelText: allowMultiple
                      ? 'Đường dẫn tệp trên thiết bị (phân cách bằng dấu ;)'
                      : 'Đường dẫn tệp trên thiết bị',
                  hintText: r'Ví dụ: C:\Users\Public\Pictures\photo.jpg',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(const <String>[]),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              key: const Key('host_file_path_dialog_confirm'),
              onPressed: () {
                final raw = controller.text.trim();
                if (raw.isEmpty) {
                  Navigator.of(dialogContext).pop(const <String>[]);
                  return;
                }
                final paths = allowMultiple
                    ? raw
                        .split(';')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList()
                    : [raw];
                Navigator.of(dialogContext).pop(paths);
              },
              child: const Text('Chọn tệp'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result ?? const [];
  }

  @override
  Future<HostPickedFile?> pickKycDocument({
    BuildContext? context,
    String title = 'Chọn tài liệu xác minh',
  }) async {
    var paths = await _openNativeFileDialog(
      allowMultiple: false,
      filterDescription: 'Tài liệu xác minh KYC',
      extensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (paths.isEmpty && context != null && context.mounted) {
      paths = await _promptFilePathDialog(
        context,
        title: title,
        hint:
            'Chọn tệp thật từ thiết bị (JPG, PNG, WebP hoặc PDF, tối đa 5MB).',
        allowMultiple: false,
      );
    }
    if (paths.isEmpty) return null;
    return readFromFilePath(paths.first);
  }

  @override
  Future<List<HostPickedFile>> pickListingImages({
    BuildContext? context,
    int maxImages = kMaxListingImagesCount,
  }) async {
    var paths = await _openNativeFileDialog(
      allowMultiple: true,
      filterDescription: 'Ảnh chỗ nghỉ',
      extensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
    );
    if (paths.isEmpty && context != null && context.mounted) {
      paths = await _promptFilePathDialog(
        context,
        title: 'Chọn ảnh chỗ nghỉ từ thiết bị',
        hint:
            'Hỗ trợ JPG, PNG, WebP, GIF (tối đa $maxImages ảnh, mỗi ảnh tối đa 5MB).',
        allowMultiple: true,
      );
    }
    if (paths.isEmpty) return const [];
    final picked = <HostPickedFile>[];
    for (final path in paths.take(maxImages)) {
      picked.add(await readFromFilePath(path));
    }
    return picked;
  }

  @override
  Future<HostPickedFile?> pickAvatarImage({BuildContext? context}) async {
    var paths = await _openNativeFileDialog(
      allowMultiple: false,
      filterDescription: 'Ảnh đại diện',
      extensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
    );
    if (paths.isEmpty && context != null && context.mounted) {
      paths = await _promptFilePathDialog(
        context,
        title: 'Chọn ảnh đại diện',
        hint: 'Hỗ trợ JPG, PNG, WebP, GIF (tối đa 5MB).',
        allowMultiple: false,
      );
    }
    if (paths.isEmpty) return null;
    return readFromFilePath(paths.first);
  }
}

final hostFilePickerProvider = Provider<HostFilePickerService>((ref) {
  return const DefaultHostFilePickerService();
});

/// Result of a presigned R2 upload (`POST /api/uploads/presign` + `PUT <uploadUrl>`).
class HostR2UploadResult {
  final String uploadUrl;
  final String publicUrl;
  final String key;
  final int expiresIn;

  const HostR2UploadResult({
    required this.uploadUrl,
    required this.publicUrl,
    required this.key,
    this.expiresIn = 300,
  });

  factory HostR2UploadResult.fromPresignJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final uploadUrl = (data['uploadUrl'] ?? '').toString().trim();
    final publicUrl = (data['publicUrl'] ?? '').toString().trim();
    final key = (data['key'] ?? data['objectKey'] ?? '').toString().trim();
    final expiresIn = data['expiresIn'] is num
        ? (data['expiresIn'] as num).toInt()
        : (int.tryParse('${data['expiresIn'] ?? 300}') ?? 300);

    final uploadUri = Uri.tryParse(uploadUrl);
    final publicUri = Uri.tryParse(publicUrl);
    if (uploadUri == null ||
        !uploadUri.hasScheme ||
        (uploadUri.scheme != 'http' && uploadUri.scheme != 'https')) {
      throw const FormatException(
        'Backend không trả về uploadUrl R2 hợp lệ.',
      );
    }
    if (publicUri == null ||
        !publicUri.hasScheme ||
        (publicUri.scheme != 'http' && publicUri.scheme != 'https')) {
      throw const FormatException(
        'Backend không trả về publicUrl R2 hợp lệ.',
      );
    }
    if (key.isEmpty) {
      throw const FormatException(
        'Backend không trả về object key R2 hợp lệ.',
      );
    }

    return HostR2UploadResult(
      uploadUrl: uploadUrl,
      publicUrl: publicUrl,
      key: key,
      expiresIn: expiresIn,
    );
  }
}

/// Dedicated R2 uploader that sends raw bytes via `PUT` to the presigned URL
/// WITHOUT attaching the API `Authorization: Bearer` header.
class HostR2DirectUploader {
  final Dio _cleanDio;

  HostR2DirectUploader({Dio? cleanDio})
      : _cleanDio = cleanDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 60),
              ),
            );

  /// Uploads [file] bytes directly to [presigned.uploadUrl] using HTTP `PUT`.
  /// Never attaches `Authorization` header so API Bearer token is never leaked to R2.
  Future<HostR2UploadResult> putBytesToPresignedUrl({
    required HostPickedFile file,
    required HostR2UploadResult presigned,
    void Function(int sent, int total)? onSendProgress,
    int maxRetries = 1,
  }) async {
    final validationErr = validateListingImagePickedFile(file);
    if (validationErr != null) {
      throw ArgumentError(validationErr);
    }

    int attempt = 0;
    Object? lastError;

    while (attempt <= maxRetries) {
      attempt += 1;
      try {
        final headers = <String, dynamic>{
          Headers.contentTypeHeader: file.mimeType,
          Headers.contentLengthHeader: file.sizeBytes,
        };

        final response = await _cleanDio.put<dynamic>(
          presigned.uploadUrl,
          data: file.bytes,
          options: Options(
            headers: headers,
            responseType: ResponseType.plain,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 300,
          ),
          onSendProgress: onSendProgress,
        );

        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          return presigned;
        }
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'R2 trả về mã trạng thái ${response.statusCode}.',
        );
      } catch (e) {
        lastError = e;
        if (attempt > maxRetries) break;
      }
    }

    throw Exception(
      'Tải ảnh "${file.name}" lên R2 thất bại: $lastError',
    );
  }
}
