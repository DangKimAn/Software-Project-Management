import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/router/app_router.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';
import 'package:hotel_booking_flutter/features/auth/domain/repositories/auth_repository.dart';
import 'package:hotel_booking_flutter/features/auth/presentation/view_models/auth_notifier.dart';
import 'package:hotel_booking_flutter/shared/animations/source_animations.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_semantic_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _ControllableAuthRepository implements AuthRepository {
  Completer<User?> getCurrentUserCompleter = Completer<User?>();

  @override
  Future<User?> getCurrentUser() => getCurrentUserCompleter.future;

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
  Future<void> logout() async {}
}

void main() {
  group('Icon Design Rules & Theme Compliance (Section 11)', () {
    test('Icon tokens are strictly monochrome neutral colors', () {
      expect(AppColors.iconStrong, const Color(0xFF222222));
      expect(AppColors.iconMuted, const Color(0xFF717171));
    });

    test('AppTheme enforces transparent splash/highlight for interactive icons',
        () {
      final theme = AppTheme.lightTheme;
      expect(theme.splashColor, Colors.transparent);
      expect(theme.highlightColor, Colors.transparent);
      expect(theme.hoverColor, Colors.transparent);
      expect(theme.iconTheme.color, AppColors.iconStrong);
    });

    test(
        'AppSemanticIcons maps each amenity and sort option to its distinct semantic icon',
        () {
      expect(AppSemanticIcons.resolveAmenityIcon('Wifi tốc độ cao'),
          LucideIcons.wifi);
      expect(AppSemanticIcons.resolveAmenityIcon('Hồ bơi riêng'),
          LucideIcons.waves);
      expect(AppSemanticIcons.resolveAmenityIcon('Khu vực BBQ'),
          LucideIcons.flame);
      expect(AppSemanticIcons.resolveAmenityIcon('Bếp đầy đủ'),
          LucideIcons.utensils);
      expect(AppSemanticIcons.resolveAmenityIcon('Điều hòa'),
          LucideIcons.snowflake);
      expect(AppSemanticIcons.resolveAmenityIcon('Máy giặt'),
          LucideIcons.washingMachine);
      expect(AppSemanticIcons.resolveAmenityIcon('Chỗ đậu xe miễn phí'),
          LucideIcons.car);
      expect(AppSemanticIcons.resolveAmenityIcon('Cho phép thú cưng'),
          LucideIcons.pawPrint);
      expect(AppSemanticIcons.resolveAmenityIcon('Gần biển'),
          LucideIcons.umbrella);
      expect(
          AppSemanticIcons.resolveAmenityIcon('Karaoke'), LucideIcons.micVocal);
      expect(AppSemanticIcons.resolveSortIcon('price_asc'),
          LucideIcons.trendingUp);
      expect(AppSemanticIcons.resolveSortIcon('price_desc'),
          LucideIcons.trendingDown);
      expect(AppSemanticIcons.resolveSortIcon('rating_desc'), LucideIcons.star);
    });

    testWidgets(
        'AppBrandIcon renders YouTube, Facebook, TikTok, Threads, Google, and MinhThanhLogo',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppBrandIcon.youtube(),
                AppBrandIcon.facebook(),
                AppBrandIcon.tiktok(),
                AppBrandIcon.threads(),
                AppBrandIcon.google(),
                AppBrandIcon.minhThanhLogo(),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(AppBrandIcon), findsNWidgets(6));
    });
  });

  group(
      'BUG-15, BUG-16, BUG-17 & BUG-35: Router Guards, Redirect Safety & Deep Link Normalization',
      () {
    test(
        'AuthNotifier.isSafeRedirectPath blocks external URLs, protocol-relative paths, and auth loops',
        () {
      expect(AuthNotifier.isSafeRedirectPath('/villa/101'), isTrue);
      expect(
          AuthNotifier.isSafeRedirectPath(
              '/thanh-toan/ket-qua?bookingId=12&status=pending'),
          isTrue);
      expect(
          AuthNotifier.isSafeRedirectPath('/ai-search?q=villa+bien'), isTrue);

      // Untrusted / unsafe URLs must be rejected
      expect(
          AuthNotifier.isSafeRedirectPath('https://evil.com/phish'), isFalse);
      expect(AuthNotifier.isSafeRedirectPath('http://evil.com'), isFalse);
      expect(AuthNotifier.isSafeRedirectPath('//evil.com/path'), isFalse);
      expect(AuthNotifier.isSafeRedirectPath(r'/\evil.com'), isFalse);
      expect(AuthNotifier.isSafeRedirectPath('javascript:alert(1)'), isFalse);
      expect(AuthNotifier.isSafeRedirectPath(''), isFalse);
      expect(AuthNotifier.isSafeRedirectPath(null), isFalse);

      // Auth entry paths must be rejected to prevent redirect loops
      expect(AuthNotifier.isSafeRedirectPath('/dang-nhap'), isFalse);
      expect(AuthNotifier.isSafeRedirectPath('/login'), isFalse);
      expect(AuthNotifier.isSafeRedirectPath('/dang-ky'), isFalse);
      expect(AuthNotifier.isSafeRedirectPath('/quen-mat-khau'), isFalse);
    });

    test(
        'AuthNotifier.resolvePostAuthRedirectPath enforces verified role boundaries',
        () {
      const guest = User(
        id: '1',
        email: 'guest@test.com',
        firstName: 'Guest',
        lastName: 'User',
        role: 'guest',
      );
      const pendingHost = User(
        id: '2',
        email: 'new@test.com',
        firstName: 'New',
        lastName: 'Host',
        role: 'host new',
      );
      const approvedHost = User(
        id: '3',
        email: 'host@test.com',
        firstName: 'Host',
        lastName: 'User',
        role: 'host',
      );
      const admin = User(
        id: '4',
        email: 'admin@test.com',
        firstName: 'Admin',
        lastName: 'User',
        role: 'admin',
      );

      // Guest cannot redirect to /admin or /chu-nha
      expect(
        AuthNotifier.resolvePostAuthRedirectPath(guest, redirectTo: '/admin'),
        '/account/profile',
      );
      expect(
        AuthNotifier.resolvePostAuthRedirectPath(guest,
            redirectTo: '/chu-nha/cho-nghi'),
        '/account/profile',
      );
      expect(
        AuthNotifier.resolvePostAuthRedirectPath(guest,
            redirectTo: '/gio-cho-dat'),
        '/gio-cho-dat',
      );

      // Pending host ('host new') defaults to /tro-thanh-host/trang-thai and cannot access /chu-nha
      expect(
        AuthNotifier.resolvePostAuthRedirectPath(pendingHost),
        '/tro-thanh-host/trang-thai',
      );
      expect(
        AuthNotifier.resolvePostAuthRedirectPath(
          pendingHost,
          redirectTo: '/chu-nha/cho-nghi',
        ),
        '/tro-thanh-host/trang-thai',
      );

      // Approved host can redirect to /chu-nha/* or /host/*, but not /admin
      expect(
        AuthNotifier.resolvePostAuthRedirectPath(
          approvedHost,
          redirectTo: '/chu-nha/dat-phong',
        ),
        '/chu-nha/dat-phong',
      );
      expect(
        AuthNotifier.resolvePostAuthRedirectPath(
          approvedHost,
          redirectTo: '/admin/nguoi-dung',
        ),
        '/chu-nha/cho-nghi',
      );

      // Admin can redirect to /admin/*, but not /chu-nha/* (HostRoute rule)
      expect(
        AuthNotifier.resolvePostAuthRedirectPath(
          admin,
          redirectTo: '/admin/ho-so-host',
        ),
        '/admin/ho-so-host',
      );
      expect(
        AuthNotifier.resolvePostAuthRedirectPath(
          admin,
          redirectTo: '/chu-nha/cho-nghi',
        ),
        '/admin',
      );
    });

    test(
        'normalizeIncomingDeepLinkUri normalizes minhthanhvilla:// scheme and payment callbacks',
        () {
      final paymentUri = Uri.parse(
        'minhthanhvilla://thanh-toan/ket-qua?bookingId=555&paymentId=777&status=pending&provider=vnpay',
      );
      expect(
        normalizeIncomingDeepLinkUri(paymentUri),
        '/thanh-toan/ket-qua?bookingId=555&paymentId=777&status=pending&provider=vnpay',
      );

      final villaUri = Uri.parse('minhthanhvilla://villa/42');
      expect(normalizeIncomingDeepLinkUri(villaUri), '/villa/42');

      final normalInternal = Uri.parse('/tim-kiem');
      expect(normalizeIncomingDeepLinkUri(normalInternal), isNull);
    });

    testWidgets(
        'RouteAuthGuard blocks protected content while session is unverified and NotFoundScreen renders for 404',
        (tester) async {
      final controllableRepo = _ControllableAuthRepository();
      final authNotifier = AuthNotifier(controllableRepo);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((_) => authNotifier),
          ],
          child: const MaterialApp(
            home: RouteAuthGuard(
              accessLevel: RouteAccessLevel.authenticated,
              child: Scaffold(body: Text('SECRET_PROTECTED_SCREEN')),
            ),
          ),
        ),
      );
      await tester.pump();

      // While authState.isLoading is true, protected child MUST NOT be rendered
      expect(find.text('SECRET_PROTECTED_SCREEN'), findsNothing);
      expect(find.byType(SessionVerificationLoadingView), findsOneWidget);

      // Complete verification as unauthenticated -> still must not render protected child
      controllableRepo.getCurrentUserCompleter.complete(null);
      await tester.pump();
      expect(find.text('SECRET_PROTECTED_SCREEN'), findsNothing);

      // Verify NotFoundScreen renders monochrome neutral icon and 48px button
      await tester.pumpWidget(
        const MaterialApp(
          home: NotFoundScreen(requestedLocation: '/khong-ton-tai'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('404 — Không tìm thấy trang'), findsOneWidget);
      final iconWidget = tester.widget<Icon>(find.byType(Icon).first);
      expect(iconWidget.color, AppColors.iconMuted);
    });
  });

  group('BookingDate & User Domain Helpers', () {
    test('BookingDate formats ISO and Vietnamese dates accurately', () {
      const date = BookingDate(year: 2026, month: 10, day: 14);
      expect(date.toIsoDate(), '2026-10-14');
      expect(date.toDisplayVi(), '14/10/2026');
      expect(date.toDateTimeUtc(), DateTime.utc(2026, 10, 14));
      expect(BookingDate.tryParseIso('2026-10-14'), date);
    });

    test(
        'User.splitFullName splits Vietnamese full name into firstName and lastName',
        () {
      final (:firstName, :lastName) = User.splitFullName('Nguyễn Văn An');
      expect(firstName, 'Nguyễn Văn');
      expect(lastName, 'An');
    });
  });

  group('BookingQueueItem & SearchHistoryEntry Serialization', () {
    test(
        'BookingQueueItem preserves all pricing and guest fields across JSON round-trip',
        () {
      const item = BookingQueueItem(
        listingId: '101',
        title: 'Villa Biển Xanh Vũng Tàu',
        imageUrl: 'assets/images/villa_bien.jpg',
        location: 'Phường 2, TP. Vũng Tàu',
        pricePerNight: 4500000,
        weekendSurcharge: 1000000,
        cleaningFee: 300000,
        serviceFee: 200000,
        extraGuestFee: 250000,
        includedGuests: 10,
        maxGuests: 15,
        checkIn: '2026-11-01',
        checkOut: '2026-11-03',
        guestsCount: 12,
      );

      final decoded = BookingQueueItem.fromJson(item.toJson());
      expect(decoded.listingId, '101');
      expect(decoded.title, 'Villa Biển Xanh Vũng Tàu');
      expect(decoded.location, 'Phường 2, TP. Vũng Tàu');
      expect(decoded.pricePerNight, 4500000);
      expect(decoded.weekendSurcharge, 1000000);
      expect(decoded.guestsCount, 12);
      expect(decoded.guests, 12);
    });
  });

  group('Source Animations Widget Rendering', () {
    testWidgets(
        'CalFadeIn, SearchPopIn, MonthInSwitcher, and MapMarkerPulse render cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CalFadeIn(child: Text('Calendar Content')),
                SearchPopIn(child: Text('Popover Content')),
                MonthInSwitcher(
                  monthKey: '2026-10',
                  child: Text('October 2026'),
                ),
                MapMarkerPulse(
                  size: 32,
                  child: Text('4.5M'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Calendar Content'), findsOneWidget);
      expect(find.text('Popover Content'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('4.5M'), findsOneWidget);
    });
  });
}
