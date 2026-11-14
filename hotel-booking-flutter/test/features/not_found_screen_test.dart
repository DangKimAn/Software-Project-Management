import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/router/not_found_screen.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/l10n/generated/app_localizations.dart';

void main() {
  group('sanitizeNotFoundDisplayPath', () {
    test('strips sensitive query parameters and fragments from display path',
        () {
      expect(
        sanitizeNotFoundDisplayPath(
          '/villa/khong-ton-tai?token=secret_jwt_123&otp=999999#frag',
        ),
        '/villa/khong-ton-tai',
      );
    });

    test('normalizes duplicate slashes, trailing slash, and empty/root paths',
        () {
      expect(sanitizeNotFoundDisplayPath(null), isNull);
      expect(sanitizeNotFoundDisplayPath('   '), isNull);
      expect(sanitizeNotFoundDisplayPath('/'), isNull);
      expect(sanitizeNotFoundDisplayPath('/?redirectTo=/admin'), isNull);
      expect(
        sanitizeNotFoundDisplayPath('///cam-nang//bai-viet-cu/'),
        '/cam-nang/bai-viet-cu',
      );
    });

    test('truncates overly long paths safely with ellipsis', () {
      final result = sanitizeNotFoundDisplayPath(
        '/chuyen-muc/biet-thu-nghi-duong-vung-tau-bai-sau-nguyen-can-2026',
        maxLength: 28,
      );
      expect(result, isNotNull);
      expect(result!.length, 28);
      expect(result.endsWith('…'), isTrue);
    });
  });

  group('NotFoundScreen — Modern Light Luxury UI, Routing & Compliance', () {
    testWidgets(
      'renders sanitized path without leaking query secrets, enforces neutral icons, and passes tap-target & label guidelines',
      (tester) async {
        final semanticsHandle = tester.ensureSemantics();
        await tester.binding.setSurfaceSize(const Size(1280, 820));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: const NotFoundScreen(
                requestedLocation:
                    '/biet-thu-404?access_token=top_secret_value_999',
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('404 — Không tìm thấy trang'), findsOneWidget);
          expect(find.text('/biet-thu-404'), findsOneWidget);
          expect(find.textContaining('top_secret_value_999'), findsNothing);

          // First icon must remain monochrome muted for router_and_icon_rules_test parity
          final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
          expect(icons, isNotEmpty);
          expect(icons.first.color, AppColors.iconMuted);

          for (final icon in icons) {
            expect(
              icon.color == AppColors.iconMuted ||
                  icon.color == AppColors.iconStrong ||
                  icon.color == Colors.white,
              isTrue,
              reason: 'Unexpected non-neutral icon color: ${icon.color}',
            );
          }

          // Verify >= 48dp touch target heights on primary & secondary CTAs
          final homeSize =
              tester.getSize(find.byKey(const ValueKey('not-found-home-btn')));
          final backSize =
              tester.getSize(find.byKey(const ValueKey('not-found-back-btn')));
          expect(homeSize.height, greaterThanOrEqualTo(48));
          expect(backSize.height, greaterThanOrEqualTo(48));

          // Verify Flutter accessibility tap target & labeled target guidelines
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        } finally {
          semanticsHandle.dispose();
        }
      },
    );

    testWidgets(
      'navigates cleanly via touch and keyboard Tab/Enter across Home, Search, Blog, and Contact',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 840));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final router = GoRouter(
          initialLocation: '/duong-dan-sai',
          errorBuilder: (context, state) => NotFoundScreen(
            requestedLocation: state.uri.toString(),
          ),
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('HOME_DEST')),
            ),
            GoRoute(
              path: '/tim-kiem',
              builder: (_, __) => const Scaffold(body: Text('SEARCH_DEST')),
            ),
            GoRoute(
              path: '/cam-nang',
              builder: (_, __) => const Scaffold(body: Text('BLOG_DEST')),
            ),
            GoRoute(
              path: '/lien-he',
              builder: (_, __) => const Scaffold(body: Text('CONTACT_DEST')),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('404 — Không tìm thấy trang'), findsOneWidget);

        // Tap primary CTA -> '/'
        await tester.tap(find.byKey(const ValueKey('not-found-home-btn')));
        await tester.pumpAndSettle();
        expect(find.text('HOME_DEST'), findsOneWidget);

        // Go back to 404 and use keyboard Tab -> Tab -> Tab + Enter to activate 'Nơi lưu trú'
        router.go('/khong-co-trang-nay');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Primary CTA
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Secondary CTA
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Stays tile
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('SEARCH_DEST'), findsOneWidget);

        // Go back to 404 and tap quick destination 'Cẩm nang' -> '/cam-nang'
        router.go('/sai-dia-chi-blog');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cẩm nang'));
        await tester.pumpAndSettle();
        expect(find.text('BLOG_DEST'), findsOneWidget);

        // Go back to 404 and tap quick destination 'Liên hệ' -> '/lien-he'
        router.go('/sai-dia-chi');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Liên hệ'));
        await tester.pumpAndSettle();
        expect(find.text('CONTACT_DEST'), findsOneWidget);
      },
    );

    testWidgets(
      'supports English and Korean localizations without glyph/layout issues',
      (tester) async {
        for (final entry in const <(Locale, String)>[
          (Locale('en'), '404 — Page not found'),
          (Locale('ko'), '404 — 페이지를 찾을 수 없습니다'),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              locale: entry.$1,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const NotFoundScreen(requestedLocation: '/missing-villa'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(entry.$2), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'renders with zero RenderFlex overflow across 320..1280dp and textScale 1.0..2.0x',
      (tester) async {
        for (final width in const <double>[320, 360, 390, 430, 768, 1280]) {
          for (final scale in const <double>[1.0, 1.3, 1.6, 2.0]) {
            await tester.binding.setSurfaceSize(Size(width, 844));
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: Size(width, 844),
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: const NotFoundScreen(
                  requestedLocation:
                      '/villa/biet-thu-bien-bai-sau-khong-ton-tai-kiem-tra-responsive',
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Overflow detected at width=${width}dp, scale=${scale}x',
            );
          }
        }
        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}
