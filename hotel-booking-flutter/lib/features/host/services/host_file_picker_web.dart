// ignore_for_file: implementation_imports, depend_on_referenced_packages
import 'package:file_picker/_internal/file_picker_web.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Đảm bảo `FilePickerWeb` và `ImagePickerPlugin` luôn được đăng ký trên Flutter Web.
///
/// Giải thuật tự phục hồi đăng ký plugin (Idempotent Web Plugin Registration):
/// Thử truy cập `FilePicker.platform` và kiểm tra kiểu thể hiện của `ImagePickerPlatform.instance`;
/// nếu ném ngoại lệ chưa khởi tạo (thường xảy ra khi hot-reload phiên gỡ lỗi đang chạy),
/// hàm tự động đăng ký lại với `webPluginRegistrar` để tránh lỗi chọn tệp trên trình duyệt.
void ensureWebFilePickerRegistered() {
  try {
    FilePicker.platform;
  } catch (_) {
    FilePickerWeb.registerWith(webPluginRegistrar);
  }
  try {
    final current = ImagePickerPlatform.instance;
    if (current is! ImagePickerPlugin) {
      ImagePickerPlugin.registerWith(webPluginRegistrar);
    }
  } catch (_) {
    ImagePickerPlugin.registerWith(webPluginRegistrar);
  }
}
