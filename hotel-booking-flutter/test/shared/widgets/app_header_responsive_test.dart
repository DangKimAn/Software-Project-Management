import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/view_models/trips_view_model.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header.dart';
import 'package:hotel_booking_flutter/shared/widgets/currency_language_selector.dart';

class _HeaderAuthRepository implements AuthRepository {
  User? currentUser;
  int logoutCount = 0;

  _HeaderAuthRepository({this.currentUser});

  @override
  Future<User?> getCurrentUser() async => currentUser;

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> loginWithGoogle({required String idToken}) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> forgotPassword({required String identifier}) async {}

  @override
  Future<void> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {}

  @override
  Future<User> updateProfile({
    String? fullName,
    String? phone,
    String? bio,
    String? location,
    String? job,
    String? dreamDestination,
    String? school,
    List<String>? languages,
    String? avatarUrl,
  }) =>
      throw UnimplementedError();

  @override
  Future<User> updateAvatar({required String url, String? key}) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {
    logoutCount++;
    currentUser = null;
  }
}

void main() {
  group(
      'AppTopHeader & AppSearchHeader Responsive + i18n QA (DEF-FE-01, TC-005, TC-006, TC-065)',
      () {
    testWidgets(
      'DEF-FE-01: AppTopHeader & AppSearchHeader render without overflow at 1120px, 1160px, 1200px with 1.2x text scale across vi/en/ko',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final widths = <double>[1120, 1160, 1200];
        final locales = <String>['vi', 'en', 'ko'];

        for (final localeCode in locales) {
          for (final width in widths) {
            await tester.binding.setSurfaceSize(Size(width, 900));
            final prefs = PreferencesService.inMemory();
            await prefs.setLocale(localeCode);
            final repo = _HeaderAuthRepository();

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  preferencesServiceProvider.overrideWithValue(prefs),
                  fxFeatureEnabledProvider.overrideWithValue(false),
                  activePendingBookingProvider.overrideWithValue(null),
                  authNotifierProvider.overrideWith(
                    (_) => AuthNotifier(repo, prefs: prefs),
                  ),
                ],
                child: MaterialApp(
                  locale: Locale(localeCode),
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('vi'),
                    Locale('en'),
                    Locale('ko'),
                  ],
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 900),
                      textScaler: const TextScaler.linear(1.2),
                    ),
                    child: const Scaffold(
                      body: Column(
                        children: [
                          AppTopHeader(
                            currentPath: '/',
                            hidePendingBanner: true,
                          ),
                          AppSearchHeader(
                            currentPath: '/tim-kiem',
                            hidePendingBanner: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason:
                  'Unexpected layout exception at width=$width, locale=$localeCode, scale=1.2',
            );
            expect(
              find.byKey(const Key('header_become_host_button')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('header_currency_language_button')),
              findsOneWidget,
            );
          }
        }
      },
    );

    testWidgets(
      'TC-006: HeaderCurrencyLanguageButton opens selector sheet and switches locale live without reload',
      (tester) async {
        final prefs = PreferencesService.inMemory();
        final repo = _HeaderAuthRepository();

        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesServiceProvider.overrideWithValue(prefs),
              fxFeatureEnabledProvider.overrideWithValue(false),
              activePendingBookingProvider.overrideWithValue(null),
              authNotifierProvider.overrideWith(
                (_) => AuthNotifier(repo, prefs: prefs),
              ),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                final localeCode = ref.watch(localeProvider);
                return MaterialApp(
                  locale: Locale(localeCode),
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('vi'),
                    Locale('en'),
                    Locale('ko'),
                  ],
                  home: const Scaffold(
                    body: AppTopHeader(
                      currentPath: '/',
                      hidePendingBanner: true,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Khám phá'), findsOneWidget);
        expect(find.text('Trở thành Host'), findsOneWidget);

        await tester
            .tap(find.byKey(const Key('header_currency_language_button')));
        await tester.pumpAndSettle();
        expect(find.byType(CurrencyLanguageSheetContent), findsOneWidget);

        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();

        expect(find.text('Discover'), findsOneWidget);
        expect(find.text('Become a Host'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-005 & TC-065: Logged-in header displays avatar badge and requires confirmation dialog before logout',
      (tester) async {
        final prefs = PreferencesService.inMemory();
        const user = User(
          id: 'u-guest-1',
          email: 'thanh@example.com',
          firstName: 'Đặng Minh',
          lastName: 'Thành',
          role: 'guest',
        );
        final repo = _HeaderAuthRepository(currentUser: user);

        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final router = GoRouter(
          initialLocation: '/tim-kiem',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(
                body: AppTopHeader(currentPath: '/', hidePendingBanner: true),
              ),
            ),
            GoRoute(
              path: '/tim-kiem',
              builder: (_, __) => const Scaffold(
                body: AppTopHeader(
                  currentPath: '/tim-kiem',
                  hidePendingBanner: true,
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesServiceProvider.overrideWithValue(prefs),
              fxFeatureEnabledProvider.overrideWithValue(false),
              activePendingBookingProvider.overrideWithValue(null),
              authNotifierProvider.overrideWith(
                (_) => AuthNotifier(repo, prefs: prefs),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('vi'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('vi'),
                Locale('en'),
                Locale('ko'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('header_user_avatar_badge')), findsOneWidget);

        await tester.tap(find.byKey(const Key('header_account_menu_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Đăng xuất'));
        await tester.pumpAndSettle();

        // Confirmation dialog appears before logout executes
        expect(repo.logoutCount, 0);
        expect(find.text('Xác nhận đăng xuất'), findsOneWidget);

        // Cancel keeps user logged in
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(repo.logoutCount, 0);

        // Confirm executes logout
        await tester.tap(find.byKey(const Key('header_account_menu_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đăng xuất'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đăng xuất').last);
        await tester.pumpAndSettle();

        expect(repo.logoutCount, 1);
      },
    );
  });
}
