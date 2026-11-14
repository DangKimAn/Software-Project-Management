import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/security/url_security_validator.dart';
import '../domain/host_models.dart';
// CONFLICT-RESOLVED: Giữ đồng thời export `HostPickedFile` từ nhánh refactor và `HostKycFileSource` từ `origin/develop`.
import '../onboarding/host_onboarding_services.dart';

export '../domain/host_models.dart' show HostPickedFile;
export '../onboarding/host_onboarding_services.dart' show HostKycFileSource;
import 'host_file_picker_web_stub.dart'
    if (dart.library.js_interop) 'host_file_picker_web.dart';

/// Xác định kiểu MIME chính tắc của tệp dựa trên byte chữ ký đầu tệp (`headerBytes`) và phần mở rộng của `filename`.
///
/// Giải thuật nhận diện chữ ký nhị phân (Magic-Byte MIME Sniffing):
/// Ưu tiên đối chiếu các byte đầu tiên (`FF D8 FF` cho JPEG, `89 50 4E 47` cho PNG,
/// `47 49 46 38` cho GIF, `25 50 44 46` cho PDF, `RIFF....WEBP` cho WebP) nhằm chống
/// giả mạo phần mở rộng tệp trước khi fallback về đuôi tệp của `filename`.
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

/// Hợp đồng dịch vụ chọn tệp thực tế từ thiết bị cho phân hệ Chủ nhà (KYC, ảnh chỗ nghỉ, ảnh đại diện).
abstract class HostFilePickerService {
  /// Chọn một chứng từ xác minh KYC (`JPG`, `PNG`, `WebP` hoặc `PDF`, dung lượng tối đa 5MB).
  ///
  /// Khi `imageOnly` là `true` (giấy tờ định danh cá nhân), giới hạn chỉ cho phép chọn ảnh `JPG`, `PNG`, `WebP`.
  Future<HostPickedFile?> pickKycDocument({
    BuildContext? context,
    String title = 'Chọn tài liệu xác minh',
    // CONFLICT-RESOLVED: Kết hợp cờ giới hạn ảnh định danh `imageOnly` với nguồn chọn tệp `source` (camera, thư viện ảnh, tệp thiết bị).
    bool imageOnly = false,
    HostKycFileSource source = HostKycFileSource.deviceFile,
  });

  /// Chọn một hoặc nhiều ảnh chỗ nghỉ (`JPG`, `PNG`, `WebP`, `GIF`, tối đa `maxImages` ảnh, mỗi ảnh tối đa 5MB).
  Future<List<HostPickedFile>> pickListingImages({
    BuildContext? context,
    int maxImages = kMaxListingImagesCount,
  });

  /// Chọn một ảnh đại diện cá nhân (`JPG`, `PNG`, `WebP`, `GIF`, tối đa 5MB).
  Future<HostPickedFile?> pickAvatarImage({
    BuildContext? context,
  });

  /// Đọc trực tiếp nội dung và chữ ký MIME của tệp từ đường dẫn tuyệt đối `filePath` trên ổ đĩa cục bộ.
  Future<HostPickedFile> readFromFilePath(String filePath);
}

/// Triển khai mặc định của `HostFilePickerService` hỗ trợ đa nền tảng (Web, Mobile, Desktop).
///
/// Giải thuật chọn tệp đa tầng chịu lỗi (Multi-Tier Fallback File Selection):
/// 1. Ưu tiên gọi plugin `FilePicker` (tự động dự phòng sang `ImagePicker` nếu chỉ chọn ảnh).
/// 2. Trên Desktop (Windows PowerShell WinForms, macOS `osascript`, Linux `zenity`), tự động mở hộp thoại hệ điều hành nếu plugin không khả dụng.
/// 3. Cuối cùng dự phòng bằng hộp thoại nhập đường dẫn hoặc mở lại trình chọn tệp ngay trong ứng dụng.
class DefaultHostFilePickerService implements HostFilePickerService {
  /// Khởi tạo bộ chọn tệp mặc định cho Host.
  const DefaultHostFilePickerService();

  @override
  Future<HostPickedFile> readFromFilePath(String filePath) async {
    final trimmed = filePath.trim().replaceAll('"', '');
    if (trimmed.isEmpty) {
      throw const FileSystemException('Đường dẫn tệp trống.');
    }
    if (kIsWeb) {
      throw const FileSystemException(
        'Trên trình duyệt web, vui lòng nhấn "Chọn tệp" để chọn tệp trực tiếp từ hộp thoại của trình duyệt.',
      );
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

  Future<HostPickedFile?> _convertPlatformFile(PlatformFile pf) async {
    final Uint8List? memBytes = pf.bytes;
    if (memBytes != null && memBytes.isNotEmpty) {
      final safeName =
          pf.name.trim().isNotEmpty ? pf.name.trim() : 'upload_file';
      final mimeType = resolveHostFileMimeType(safeName, headerBytes: memBytes);
      return HostPickedFile(
        name: safeName,
        mimeType: mimeType,
        sizeBytes: memBytes.length,
        bytes: memBytes,
        path: kIsWeb ? null : pf.path,
      );
    }
    if (!kIsWeb) {
      final nativePath = pf.path;
      if (nativePath != null && nativePath.trim().isNotEmpty) {
        return readFromFilePath(nativePath);
      }
    }
    return null;
  }

  // Giải thuật chọn tệp qua `FilePicker.platform.pickFiles` kèm nhánh dự phòng `ImagePicker`:
  // Trả về `null` khi plugin lỗi khởi tạo để luồng ngoài chuyển sang hộp thoại hệ điều hành,
  // hoặc trả về danh sách rỗng khi người dùng chủ động nhấn Hủy hộp thoại.
  Future<List<HostPickedFile>?> _tryPickWithFilePickerPlugin({
    required bool allowMultiple,
    required String dialogTitle,
    required List<String> extensions,
    bool isImageOnly = false,
  }) async {
    try {
      ensureWebFilePickerRegistered();
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: allowMultiple,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return const <HostPickedFile>[];
      }
      final picked = <HostPickedFile>[];
      for (final pf in result.files) {
        final converted = await _convertPlatformFile(pf);
        if (converted != null) {
          picked.add(converted);
        }
      }
      return picked;
    } catch (_) {
      if (isImageOnly) {
        try {
          ensureWebFilePickerRegistered();
          final imagePicker = ImagePicker();
          if (allowMultiple) {
            final xFiles = await imagePicker.pickMultiImage();
            if (xFiles.isEmpty) return const <HostPickedFile>[];
            final picked = <HostPickedFile>[];
            for (final xf in xFiles) {
              final bytes = await xf.readAsBytes();
              if (bytes.isEmpty) continue;
              final name =
                  xf.name.trim().isNotEmpty ? xf.name.trim() : 'image.jpg';
              picked.add(
                HostPickedFile(
                  name: name,
                  mimeType: resolveHostFileMimeType(name, headerBytes: bytes),
                  sizeBytes: bytes.length,
                  bytes: bytes,
                  path: kIsWeb ? null : xf.path,
                ),
              );
            }
            return picked;
          } else {
            final xf = await imagePicker.pickImage(source: ImageSource.gallery);
            if (xf == null) return const <HostPickedFile>[];
            final bytes = await xf.readAsBytes();
            if (bytes.isEmpty) return const <HostPickedFile>[];
            final name =
                xf.name.trim().isNotEmpty ? xf.name.trim() : 'image.jpg';
            return [
              HostPickedFile(
                name: name,
                mimeType: resolveHostFileMimeType(name, headerBytes: bytes),
                sizeBytes: bytes.length,
                bytes: bytes,
                path: kIsWeb ? null : xf.path,
              ),
            ];
          }
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  Future<List<String>> _openNativeFileDialog({
    required bool allowMultiple,
    required String filterDescription,
    required List<String> extensions,
  }) async {
    if (kIsWeb) return const [];
    try {
      if (Platform.isWindows) {
        final extPattern = extensions.map((e) => '*.$e').join(';');
        final multiFlag = allowMultiple ? r'$true' : r'$false';
        final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$topForm = New-Object System.Windows.Forms.Form -Property @{TopMost = \$true}
\$dlg = New-Object System.Windows.Forms.OpenFileDialog
\$dlg.Filter = "Supported Files ($extPattern)|$extPattern"
\$dlg.Multiselect = $multiFlag
if (\$dlg.ShowDialog(\$topForm) -eq [System.Windows.Forms.DialogResult]::OK) {
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

  Future<List<HostPickedFile>> _promptFilePathDialog(
    BuildContext context, {
    required String title,
    required String hint,
    required bool allowMultiple,
    required List<String> extensions,
    required bool isImageOnly,
  }) async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<List<HostPickedFile>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hint,
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('host_file_path_dialog_input'),
                    controller: controller,
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: allowMultiple
                          ? 'Đường dẫn tệp trên thiết bị (phân cách bằng dấu ;)'
                          : 'Đường dẫn tệp trên thiết bị',
                      hintText: r'Ví dụ: C:\Users\Public\Pictures\photo.jpg',
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(const <HostPickedFile>[]),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  key: const Key('host_file_path_dialog_confirm'),
                  onPressed: () async {
                    final raw = controller.text.trim();
                    if (raw.isEmpty) {
                      // When text field is empty, clicking "Chọn tệp" opens the native/browser file picker directly
                      final pluginFiles = await _tryPickWithFilePickerPlugin(
                        allowMultiple: allowMultiple,
                        dialogTitle: title,
                        extensions: extensions,
                        isImageOnly: isImageOnly,
                      );
                      if (pluginFiles != null && pluginFiles.isNotEmpty) {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(pluginFiles);
                        }
                        return;
                      }
                      if (!kIsWeb) {
                        final nativePaths = await _openNativeFileDialog(
                          allowMultiple: allowMultiple,
                          filterDescription: title,
                          extensions: extensions,
                        );
                        if (nativePaths.isNotEmpty) {
                          final readFiles = <HostPickedFile>[];
                          for (final p in nativePaths) {
                            readFiles.add(await readFromFilePath(p));
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(readFiles);
                          }
                          return;
                        }
                      }
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          errorText =
                              'Vui lòng chọn tệp từ hộp thoại thiết bị hoặc nhập đường dẫn tệp hợp lệ.';
                        });
                      }
                      return;
                    }

                    final paths = allowMultiple
                        ? raw
                            .split(';')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList()
                        : [raw];
                    try {
                      final readFiles = <HostPickedFile>[];
                      for (final p in paths) {
                        readFiles.add(await readFromFilePath(p));
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(readFiles);
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          errorText = kIsWeb
                              ? 'Trình duyệt không cho phép đọc đường dẫn trực tiếp. Hãy xóa ô nhập và nhấn "Chọn tệp" để mở hộp thoại tệp.'
                              : 'Không tìm thấy hoặc không thể đọc tệp tại đường dẫn đã nhập.';
                        });
                      }
                    }
                  },
                  child: const Text('Chọn tệp'),
                ),
              ],
            );
          },
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
    // CONFLICT-RESOLVED: Hợp nhất nhánh chụp ảnh trực tiếp (`cameraScan`) và chọn thư viện ảnh (`photoLibrary`) từ `origin/develop` với lọc định dạng `imageOnly` của nhánh refactor.
    bool imageOnly = false,
    HostKycFileSource source = HostKycFileSource.deviceFile,
  }) async {
    if (source == HostKycFileSource.cameraScan) {
      try {
        final imagePicker = ImagePicker();
        final xf = await imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 95,
        );
        if (xf == null) return null;
        final bytes = await xf.readAsBytes();
        if (bytes.isEmpty) return null;
        final name = xf.name.trim().isNotEmpty
            ? xf.name.trim()
            : 'kyc_camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
        return HostPickedFile(
          name: name,
          mimeType: resolveHostFileMimeType(name, headerBytes: bytes),
          sizeBytes: bytes.length,
          bytes: bytes,
          path: kIsWeb ? null : xf.path,
        );
      } catch (e) {
        AppLogger.e('Failed to capture photo from camera',
            tag: 'HostFilePicker', error: e);
        rethrow;
      }
    }

    if (source == HostKycFileSource.photoLibrary) {
      try {
        final imagePicker = ImagePicker();
        final xf = await imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 95,
        );
        if (xf == null) return null;
        final bytes = await xf.readAsBytes();
        if (bytes.isEmpty) return null;
        final name = xf.name.trim().isNotEmpty
            ? xf.name.trim()
            : 'kyc_gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
        return HostPickedFile(
          name: name,
          mimeType: resolveHostFileMimeType(name, headerBytes: bytes),
          sizeBytes: bytes.length,
          bytes: bytes,
          path: kIsWeb ? null : xf.path,
        );
      } catch (e) {
        AppLogger.e('Failed to pick photo from gallery',
            tag: 'HostFilePicker', error: e);
        rethrow;
      }
    }

    // Giải thuật giới hạn định dạng chọn tệp KYC theo loại chứng từ:
    // Giấy tờ định danh (imageOnly = true) chỉ cho phép ảnh JPG, PNG, WebP khớp image/* của Backend.
    final extensions = imageOnly
        ? const ['jpg', 'jpeg', 'png', 'webp']
        : const ['jpg', 'jpeg', 'png', 'webp', 'pdf'];
    final pluginFiles = await _tryPickWithFilePickerPlugin(
      allowMultiple: false,
      dialogTitle: title,
      extensions: extensions,
      isImageOnly: imageOnly,
    );
    if (pluginFiles != null) {
      return pluginFiles.isEmpty ? null : pluginFiles.first;
    }

    final paths = await _openNativeFileDialog(
      allowMultiple: false,
      filterDescription:
          imageOnly ? 'Ảnh giấy tờ định danh KYC' : 'Tài liệu xác minh KYC',
      extensions: extensions,
    );
    if (paths.isNotEmpty) {
      return readFromFilePath(paths.first);
    }

    if (context != null && context.mounted) {
      final dialogFiles = await _promptFilePathDialog(
        context,
        title: title,
        hint: imageOnly
            ? 'Chọn ảnh thật từ thiết bị (JPG, PNG hoặc WebP, tối đa 5MB).'
            : 'Chọn tệp thật từ thiết bị (JPG, PNG, WebP hoặc PDF, tối đa 5MB).',
        allowMultiple: false,
        extensions: extensions,
        isImageOnly: imageOnly,
      );
      return dialogFiles.isEmpty ? null : dialogFiles.first;
    }
    return null;
  }

  @override
  Future<List<HostPickedFile>> pickListingImages({
    BuildContext? context,
    int maxImages = kMaxListingImagesCount,
  }) async {
    const extensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
    final pluginFiles = await _tryPickWithFilePickerPlugin(
      allowMultiple: true,
      dialogTitle: 'Chọn ảnh chỗ nghỉ từ thiết bị',
      extensions: extensions,
      isImageOnly: true,
    );
    if (pluginFiles != null) {
      return pluginFiles.take(maxImages).toList();
    }

    final paths = await _openNativeFileDialog(
      allowMultiple: true,
      filterDescription: 'Ảnh chỗ nghỉ',
      extensions: extensions,
    );
    if (paths.isNotEmpty) {
      final picked = <HostPickedFile>[];
      for (final path in paths.take(maxImages)) {
        picked.add(await readFromFilePath(path));
      }
      return picked;
    }

    if (context != null && context.mounted) {
      final dialogFiles = await _promptFilePathDialog(
        context,
        title: 'Chọn ảnh chỗ nghỉ từ thiết bị',
        hint:
            'Hỗ trợ JPG, PNG, WebP, GIF (tối đa $maxImages ảnh, mỗi ảnh tối đa 5MB).',
        allowMultiple: true,
        extensions: extensions,
        isImageOnly: true,
      );
      return dialogFiles.take(maxImages).toList();
    }
    return const [];
  }

  @override
  Future<HostPickedFile?> pickAvatarImage({BuildContext? context}) async {
    const extensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
    final pluginFiles = await _tryPickWithFilePickerPlugin(
      allowMultiple: false,
      dialogTitle: 'Chọn ảnh đại diện',
      extensions: extensions,
      isImageOnly: true,
    );
    if (pluginFiles != null) {
      return pluginFiles.isEmpty ? null : pluginFiles.first;
    }

    final paths = await _openNativeFileDialog(
      allowMultiple: false,
      filterDescription: 'Ảnh đại diện',
      extensions: extensions,
    );
    if (paths.isNotEmpty) {
      return readFromFilePath(paths.first);
    }

    if (context != null && context.mounted) {
      final dialogFiles = await _promptFilePathDialog(
        context,
        title: 'Chọn ảnh đại diện',
        hint: 'Hỗ trợ JPG, PNG, WebP, GIF (tối đa 5MB).',
        allowMultiple: false,
        extensions: extensions,
        isImageOnly: true,
      );
      return dialogFiles.isEmpty ? null : dialogFiles.first;
    }
    return null;
  }
}

/// Provider cung cấp thể hiện `HostFilePickerService` cho toàn bộ phân hệ Host.
final hostFilePickerProvider = Provider<HostFilePickerService>((ref) {
  return const DefaultHostFilePickerService();
});

/// Kết quả cấp phát liên kết tải lên trực tiếp Cloudflare R2 (`POST /api/uploads/presign` + `PUT <uploadUrl>`).
class HostR2UploadResult {
  final String uploadUrl;
  final String publicUrl;
  final String key;
  final int expiresIn;

  /// Khởi tạo thông tin presigned URL phục vụ tải tệp trực tiếp lên R2.
  const HostR2UploadResult({
    required this.uploadUrl,
    required this.publicUrl,
    required this.key,
    this.expiresIn = 300,
  });

  /// Giải mã và thẩm định an toàn bảo mật (`UrlSecurityValidator`) cho phản hồi presign từ Backend.
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

    if (!UrlSecurityValidator.isSafeUploadOrMediaUrl(uploadUrl)) {
      throw const FormatException(
        'Backend không trả về uploadUrl R2 hợp lệ.',
      );
    }
    if (!UrlSecurityValidator.isSafeUploadOrMediaUrl(publicUrl)) {
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

/// Bộ tải tệp nhị phân trực tiếp lên Cloudflare R2 qua giao thức `PUT` presigned URL.
///
/// Sử dụng thể hiện `Dio` sạch độc lập nhằm đảm bảo tuyệt đối không đính kèm header
/// `Authorization: Bearer` của API ứng dụng sang miền lưu trữ đám mây bên ngoài.
class HostR2DirectUploader {
  final Dio _cleanDio;

  /// Khởi tạo bộ tải trực tiếp R2 với tùy chọn `cleanDio` không chứa interceptor xác thực nội bộ.
  HostR2DirectUploader({Dio? cleanDio})
      : _cleanDio = cleanDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 60),
              ),
            );

  /// Đẩy luồng byte của `file` trực tiếp lên `presigned` (`uploadUrl`) bằng phương thức HTTP `PUT` kèm cơ chế thử lại tối đa `maxRetries` lần.
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
