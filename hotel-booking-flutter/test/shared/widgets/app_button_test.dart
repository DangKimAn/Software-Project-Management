import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_button.dart';

void main() {
  group('AppButton Widget Tests', () {
    testWidgets('renders button text and triggers callback when tapped',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Đặt phòng ngay',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Đặt phòng ngay'), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows loading spinner when isLoading is true and ignores taps',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Đang gửi',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(tapped, isFalse);
    });
  });
}
