import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'di/providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MinhThanhVillaApp extends ConsumerWidget {
  const MinhThanhVillaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final currentLanguageCode = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Minh Thanh Villa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: Locale(currentLanguageCode),
      supportedLocales: const [
        Locale('vi'),
        Locale('en'),
        Locale('ko'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
