import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/di/providers.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';
import 'core/storage/preferences_service.dart';

/// Khởi tạo hạ tầng cốt lõi, kiểm định an toàn cấu hình và khởi chạy ứng dụng Flutter.
///
/// Giải thuật khởi tạo ba pha (3-Phase Application Bootstrap):
/// 1. Kiểm định môi trường và bảo mật: Khởi tạo `WidgetsFlutterBinding`, phân giải môi trường kỳ vọng
///    từ tham số `expectedEnvironment` hoặc `appFlavor`, gọi `AppConfig.validate` để chặn sớm các lỗi
///    lệch môi trường hoặc thiếu HTTPS trên bản phát hành, đồng thời ghi nhận cảnh báo từ `AppConfig.auditConfiguration`.
/// 2. Khởi tạo lưu trữ tùy chọn chịu lỗi: Tải `PreferencesService` từ `SharedPreferences`; nếu kênh
///    lưu trữ bản địa gặp sự cố thì tự động chuyển sang bộ nhớ tạm `PreferencesService.inMemory` để không làm sập ứng dụng.
/// 3. Bơm phụ thuộc và gắn kết giao diện: Khởi chạy `ThePalmVillaApp` bên trong `ProviderScope`
///    với `preferencesServiceProvider` đã được ghi đè bằng thể hiện vừa khởi tạo.
Future<void> bootstrap({String? expectedEnvironment}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final resolvedExpectedEnv = AppConfig.resolveExpectedEnvironment(
    explicitExpectedEnvironment: expectedEnvironment,
  );

  // 1. Validate environment configuration, native flavor alignment, and HTTPS enforcement
  AppConfig.validate(
    expectedEnvironment: resolvedExpectedEnv,
    buildFlavor: appFlavor,
  );

  final configWarnings = AppConfig.auditConfiguration(
    currentEnvironment: resolvedExpectedEnv,
    buildFlavor: appFlavor,
  );
  for (final warning in configWarnings) {
    AppLogger.w(warning);
  }

  AppLogger.i(
    'Starting The Palm Villa Mobile in [$resolvedExpectedEnv] environment.',
  );

  // 2. Initialize local preferences with graceful fallback
  PreferencesService prefsService;
  try {
    prefsService = await PreferencesService.create();
  } catch (e) {
    AppLogger.w(
      'SharedPreferences initialization failed; using in-memory fallback: $e',
    );
    prefsService = PreferencesService.inMemory();
  }

  // 3. Launch application inside Riverpod ProviderScope
  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(prefsService),
      ],
      child: const ThePalmVillaApp(),
    ),
  );
}
