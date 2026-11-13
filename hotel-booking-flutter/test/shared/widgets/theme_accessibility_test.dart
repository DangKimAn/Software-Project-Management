import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_button.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_card.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_dialog.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_empty_view.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_error_view.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_loading.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_text_field.dart';

Widget host(Widget child,
        {double scale = 1, EdgeInsets insets = EdgeInsets.zero}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, body) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            viewInsets: insets),
        child: body!,
      ),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('loading blocks repeated taps and preserves button dimensions',
      (tester) async {
    var count = 0;
    var loading = false;
    await tester.pumpWidget(host(StatefulBuilder(
        builder: (context, setState) => AppButton(
              text: 'Gửi yêu cầu tư vấn',
              isLoading: loading,
              onPressed: () {
                count++;
                setState(() => loading = true);
              },
            ))));
    final before = tester.getSize(find.byType(AppButton));
    await tester.tap(find.byType(AppButton));
    await tester.pump();
    await tester.tap(find.byType(AppButton));
    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(count, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(AppButton)), before);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Gửi yêu cầu tư vấn'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('icon action has label, 48dp target and keyboard activation',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var count = 0;
    await tester.pumpWidget(host(Center(
        child: AppIconButton(
      size: 24,
      tooltip: 'Đóng cửa sổ',
      icon: const Icon(LucideIcons.x),
      onPressed: () => count++,
    ))));
    expect(tester.getSize(find.byType(AppIconButton)), const Size(48, 48));
    expect(find.bySemanticsLabel('Đóng cửa sổ'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(count, 1);
    await tester.tap(find.byType(AppIconButton));
    expect(count, 2);
    semantics.dispose();
  });

  testWidgets('shared widgets inherit customized theme', (tester) async {
    final custom = AppTheme.lightTheme.copyWith(
      cardTheme: const CardThemeData(
          color: Colors.amber,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(30)))),
      inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.amber,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(22)))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(backgroundColor: Colors.amber)),
    );
    await tester.pumpWidget(MaterialApp(
        theme: custom,
        home: Scaffold(
            body: Column(children: [
          const AppCard(child: Text('Card')),
          const AppTextField(labelText: 'Họ tên'),
          AppButton(text: 'Gửi', onPressed: () {}),
        ]))));
    final cardMaterial = tester
        .widgetList<Material>(find.descendant(
            of: find.byType(Card), matching: find.byType(Material)))
        .first;
    expect(cardMaterial.color, Colors.amber);
    expect((cardMaterial.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(30));
    final input = tester.widget<InputDecorator>(find.byType(InputDecorator));
    expect(input.decoration.fillColor, Colors.amber);
    expect((input.decoration.border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(22));
    final buttonMaterial = tester
        .widgetList<Material>(find.descendant(
            of: find.byType(FilledButton), matching: find.byType(Material)))
        .first;
    expect(buttonMaterial.color, Colors.amber);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets(
          'shared states at width $width scale $scale stay bounded and retry works',
          (tester) async {
        tester.view.reset();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 640);
        addTearDown(tester.view.reset);
        var retry = 0;
        final states = <Widget>[
          AppButton(
              text: 'Liên hệ tư vấn và kiểm tra tình trạng biệt thự',
              onPressed: () {}),
          const AppTextField(
              labelText: 'Thông tin liên hệ của khách hàng',
              hintText: 'Nhập nội dung'),
          const AppCard(child: Text('Thông tin biệt thự')),
          const AppLoading(
              message: 'Đang tải danh sách biệt thự, vui lòng chờ'),
          AppErrorView(
              message: 'Máy chủ đang bận. Vui lòng thử lại sau.',
              onRetry: () => retry++),
          AppEmptyView(
              title: 'Chưa có kết quả',
              description: 'Thử thay đổi điều kiện tìm kiếm.',
              actionText: 'Thay đổi điều kiện tìm kiếm',
              onAction: () => retry++),
        ];
        for (final state in states) {
          await tester.pumpWidget(host(
              Center(child: SizedBox(width: width, height: 240, child: state)),
              scale: scale));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '${state.runtimeType} at $width/$scale');
          if (state is AppErrorView || state is AppEmptyView) {
            await tester.ensureVisible(find.byType(AppButton));
            await tester.tap(find.byType(AppButton));
          }
        }
        expect(retry, 2);
      });
      testWidgets('dialog SafeArea and keyboard at width $width scale $scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 760);
        addTearDown(tester.view.reset);
        bool? result;
        await tester.pumpWidget(host(
            Builder(
                builder: (context) => TextButton(
                      onPressed: () async {
                        result = await AppDialog.show(context,
                            title: 'Xác nhận yêu cầu tư vấn',
                            message:
                                List.filled(20, 'Nội dung tư vấn biệt thự.')
                                    .join(' '),
                            confirmText: 'Xác nhận gửi yêu cầu',
                            cancelText: 'Quay lại chỉnh sửa');
                      },
                      child: const Text('Mở'),
                    )),
            scale: scale,
            insets: const EdgeInsets.only(bottom: 260)));
        await tester.tap(find.text('Mở'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final rect = tester.getRect(find
            .descendant(
                of: find.byType(AlertDialog), matching: find.byType(Material))
            .first);
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.bottom, lessThanOrEqualTo(500));
        await tester.ensureVisible(find.text('Xác nhận gửi yêu cầu'));
        await tester.tap(find.text('Xác nhận gửi yêu cầu'));
        await tester.pumpAndSettle();
        expect(result, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
