import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/di/providers.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';
import 'core/storage/preferences_service.dart';

Future<void> bootstrap({required String expectedEnvironment}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Validate environment configuration and HTTPS enforcement
  AppConfig.validate(expectedEnvironment: expectedEnvironment);
  AppLogger.i(
      'Starting Minh Thanh Villa Mobile in [$expectedEnvironment] environment.');

  // 2. Initialize local preferences
  final prefsService = await PreferencesService.create();

  // 3. Launch application inside Riverpod ProviderScope
  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(prefsService),
      ],
      child: const MinhThanhVillaApp(),
    ),
  );
}
