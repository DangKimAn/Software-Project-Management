import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_semantic_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('AppSemanticIcons Cross-Role Synchronization', () {
    test('maps all 17 shared Guest/Host/Admin semantic constants accurately',
        () {
      expect(AppSemanticIcons.logout, equals(LucideIcons.doorOpen));
      expect(AppSemanticIcons.dashboard, equals(LucideIcons.layoutDashboard));
      expect(AppSemanticIcons.home, equals(LucideIcons.house));
      expect(AppSemanticIcons.becomeHost, equals(LucideIcons.housePlus));
      expect(AppSemanticIcons.adminPortal, equals(LucideIcons.shieldCheck));
      expect(AppSemanticIcons.bookings, equals(LucideIcons.calendarCheck));
      expect(AppSemanticIcons.revenue, equals(LucideIcons.chartColumn));
      expect(AppSemanticIcons.hostApplications, equals(LucideIcons.fileCheck));
      expect(AppSemanticIcons.userProfile, equals(LucideIcons.userRound));
      expect(AppSemanticIcons.changeAvatar, equals(LucideIcons.camera));
      expect(AppSemanticIcons.messageHost, equals(LucideIcons.messageSquare));
      expect(AppSemanticIcons.zaloSupport, equals(LucideIcons.messageCircle));
      expect(AppSemanticIcons.supportCenter, equals(LucideIcons.lifeBuoy));
      expect(AppSemanticIcons.errorAlert, equals(LucideIcons.circleAlert));
      expect(AppSemanticIcons.retry, equals(LucideIcons.refreshCw));
      expect(AppSemanticIcons.checkIn, equals(LucideIcons.keyRound));
      expect(AppSemanticIcons.checkOut, equals(LucideIcons.clock));
    });

    test('prevents semantic icon collisions across distinct actions', () {
      expect(AppSemanticIcons.home, isNot(equals(AppSemanticIcons.becomeHost)));
      expect(
        AppSemanticIcons.messageHost,
        isNot(equals(AppSemanticIcons.zaloSupport)),
      );
      expect(
        AppSemanticIcons.checkIn,
        isNot(equals(AppSemanticIcons.checkOut)),
      );
      expect(AppSemanticIcons.checkIn, isNot(equals(LucideIcons.logIn)));
      expect(AppSemanticIcons.revenue, isNot(equals(LucideIcons.dollarSign)));
      expect(AppSemanticIcons.adminPortal, isNot(equals(LucideIcons.shield)));
    });

    testWidgets('AppBrandIcon defaults to monochrome AppColors.iconStrong',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AppBrandIcon.minhThanhLogo(),
                AppBrandIcon.google(),
                AppBrandIcon.facebook(),
                AppBrandIcon.youtube(),
                AppBrandIcon.tiktok(),
                AppBrandIcon.threads(),
                AppBrandIcon.instagram(),
              ],
            ),
          ),
        ),
      );

      final brands =
          tester.widgetList<AppBrandIcon>(find.byType(AppBrandIcon)).toList();
      expect(brands, hasLength(7));
      for (final brand in brands) {
        expect(brand.color, equals(AppColors.iconStrong));
      }
    });
  });

  group('Guest / Host / Admin Source Synchronization Guardrails', () {
    test('zero deprecated Lucide aliases remain in Host screens', () {
      final hostOnboarding = File(
        'lib/features/host/presentation/screens/host_onboarding_screens.dart',
      ).readAsStringSync();
      final addProperty = File(
        'lib/features/host/presentation/screens/them_cho_nghi_screen.dart',
      ).readAsStringSync();

      expect(hostOnboarding.contains('LucideIcons.alertTriangle'), isFalse);
      expect(hostOnboarding.contains('LucideIcons.rotateCcw'), isFalse);
      expect(hostOnboarding.contains('0xFF2563EB'), isFalse);
      expect(addProperty.contains('LucideIcons.home'), isFalse);
    });

    test(
        'HostPortalScreen enforces monochrome icons, NotificationBell, Logout, and zero CircleAvatar/IconButton.filled',
        () {
      final hostPortal = File(
        'lib/features/host/presentation/screens/host_portal_screens.dart',
      ).readAsStringSync();

      expect(hostPortal.contains('NotificationBell()'), isTrue);
      expect(hostPortal.contains("Key('host_portal_home_btn')"), isTrue);
      expect(hostPortal.contains("Key('host_portal_logout_btn')"), isTrue);
      expect(hostPortal.contains('AppSemanticIcons.logout'), isTrue);
      expect(hostPortal.contains('AppSemanticIcons.changeAvatar'), isTrue);
      expect(hostPortal.contains('CircleAvatar('), isFalse);
      expect(hostPortal.contains('IconButton.filled('), isFalse);
      expect(hostPortal.contains('minWidth: 32'), isFalse);
      expect(hostPortal.contains('minHeight: 32'), isFalse);
    });

    test(
        'AdminPortalScreen and BookingActionBar use canonical AppSemanticIcons without dollarSign or Zalo collision',
        () {
      final adminPortal = File(
        'lib/features/admin/presentation/screens/admin_portal_screens.dart',
      ).readAsStringSync();
      final bookingBar = File(
        'lib/features/villa_detail/presentation/widgets/booking_action_bar.dart',
      ).readAsStringSync();

      expect(adminPortal.contains('AppSemanticIcons.dashboard'), isTrue);
      expect(adminPortal.contains('AppSemanticIcons.hostApplications'), isTrue);
      expect(adminPortal.contains('AppSemanticIcons.revenue'), isTrue);
      expect(adminPortal.contains('AppSemanticIcons.bookings'), isTrue);
      expect(adminPortal.contains('AppSemanticIcons.home'), isTrue);
      expect(adminPortal.contains('AppSemanticIcons.logout'), isTrue);
      expect(adminPortal.contains('LucideIcons.dollarSign'), isFalse);
      expect(adminPortal.contains('LucideIcons.layoutGrid'), isFalse);

      expect(bookingBar.contains('AppSemanticIcons.messageHost'), isTrue);
      expect(bookingBar.contains('LucideIcons.messageCircle'), isFalse);
    });
  });
}
