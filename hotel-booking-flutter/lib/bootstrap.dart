import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/di/providers.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';
import 'core/storage/preferences_service.dart';

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
  AppLogger.i(
    'Starting The Palm Villa Mobile in [$resolvedExpectedEnv] environment.',
  );

  // 2. Initialize local preferences
  final prefsService = await PreferencesService.create();

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
