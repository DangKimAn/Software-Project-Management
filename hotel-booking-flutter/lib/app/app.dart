import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/view_models/auth_notifier.dart';
import 'di/providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MinhThanhVillaApp extends ConsumerStatefulWidget {
  const MinhThanhVillaApp({super.key});

  @override
  ConsumerState<MinhThanhVillaApp> createState() => _MinhThanhVillaAppState();
}

class _MinhThanhVillaAppState extends ConsumerState<MinhThanhVillaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authNotifierProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
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
