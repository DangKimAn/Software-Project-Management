import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/features/trips/presentation/widgets/payment_result_card.dart';

void main() {
  testWidgets(
      'payment receipt fits small screens and large text; actions remain usable',
      (tester) async {
    var rechecks = 0;
    var trips = 0;
    for (final width in [320.0, 390.0, 640.0]) {
      for (final scale in [1.0, 1.6, 2.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
                size: Size(width, 844), textScaler: TextScaler.linear(scale)),
            child: Scaffold(
                body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PaymentResultCard(
                icon: LucideIcons.clock,
                title: 'Giao dịch đang chờ xác nhận',
                subtitle:
                    'Kết quả thanh toán sẽ tự động cập nhật sau khi được xác nhận.',
                isVerifying: false,
                details: const {
                  'Mã đặt phòng': '#5',
                  'Mã giao dịch': '892',
                  'Phương thức': 'VNPAY',
                  'Đơn đặt phòng': 'Chờ thanh toán',
                  'Số tiền': '4.100.000 đ'
                },
                onRecheck: () => rechecks++,
                onViewTrips: () => trips++,
                onGoHome: () {},
              ),
            )),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'width=$width scale=$scale');
        final check = find.text('Kiểm tra lại trạng thái');
        await tester.ensureVisible(check);
        await tester.tap(check);
        final view = find.text('Xem chuyến đi của tôi');
        await tester.ensureVisible(view);
        await tester.tap(view);
        expect(find.text('4.100.000 đ'), findsOneWidget);
      }
    }
    expect(rechecks, 9);
    expect(trips, 9);
    await tester.binding.setSurfaceSize(null);
  });
}
