// ignore_for_file: implementation_imports, depend_on_referenced_packages
import 'package:file_picker/_internal/file_picker_web.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Ensures `FilePickerWeb` and `ImagePickerPlugin` are registered on Flutter Web,
/// even when hot-reloading an existing debug session.
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

