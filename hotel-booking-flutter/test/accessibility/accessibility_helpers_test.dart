import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';
import 'package:hotel_booking_flutter/shared/accessibility/app_accessibility.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('WCAG 2.1 Contrast Ratio Audit (AppContrast & AppColors)', () {
    test('Core typography and icon tokens meet WCAG AA/AAA on #FFFFFF surface',
        () {
      // textStrong (#222222) on surfaceBase (#FFFFFF) -> ~15.91:1 (AAA)
      final strongRatio = AppContrast.contrastRatio(
        AppColors.textStrong,
        AppColors.surfaceBase,
      );
      expect(strongRatio, greaterThan(15.0));
      expect(
        AppContrast.meetsWcagAAA(AppColors.textStrong, AppColors.surfaceBase),
        isTrue,
      );

      // textMuted (#717171) on surfaceBase (#FFFFFF) -> ~4.83:1 (AA normal text >= 4.5:1)
      final mutedRatio = AppContrast.contrastRatio(
        AppColors.textMuted,
        AppColors.surfaceBase,
      );
      expect(mutedRatio, greaterThanOrEqualTo(4.5));
      expect(
        AppContrast.meetsWcagAA(AppColors.textMuted, AppColors.surfaceBase),
        isTrue,
      );

      // textSecondary (#5E5E5E) on surfaceBase (#FFFFFF) -> ~6.47:1 (AA normal text)
      final secondaryRatio = AppContrast.contrastRatio(
        AppColors.textSecondary,
        AppColors.surfaceBase,
      );
      expect(secondaryRatio, greaterThanOrEqualTo(6.0));
      expect(
        AppContrast.meetsWcagAA(AppColors.textSecondary, AppColors.surfaceBase),
        isTrue,
      );

      // Coral primary (#FF385C) with white (#FFFFFF) -> ~3.62:1 (meets AA Large/Bold UI >= 3.0:1)
      final coralWhiteRatio = AppContrast.contrastRatio(
        Colors.white,
        AppColors.primary,
      );
      expect(coralWhiteRatio, greaterThanOrEqualTo(3.0));
      expect(
        AppContrast.meetsWcagAA(
          Colors.white,
          AppColors.primary,
          isLargeText: true,
        ),
        isTrue,
      );

      // textTertiary (#B0B0B0) is ~2.15:1 -> must NOT pass normal text AA,
      // and ensureReadableForeground must upgrade it to #222222 when readability is required.
      expect(
        AppContrast.meetsWcagAA(AppColors.textTertiary, AppColors.surfaceBase),
        isFalse,
      );
      expect(
        AppContrast.ensureReadableForeground(
          AppColors.textTertiary,
          AppColors.surfaceBase,
        ),
        AppColors.textStrong,
      );
    });
  });

  group('Touch Targets (>= 48x48dp), Bare Icon Semantics & Reduced Motion', () {
    testWidgets(
        'AccessibleIconButton enforces >= 48x48dp transparent hit target and Semantics',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AccessibleIconButton(
                icon: LucideIcons.heart,
                semanticLabel: 'Lưu vào danh sách yêu thích',
                semanticHint: 'Nhấn đúp để lưu biệt thự',
                isSelected: false,
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(AccessibleIconButton);
      final size = tester.getSize(buttonFinder);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      // Verify monochrome neutral icon color (#222222) and zero CircleAvatar/background fill
      final iconWidget = tester.widget<Icon>(find.byType(Icon));
      expect(iconWidget.color, AppColors.iconStrong);
      expect(find.byType(CircleAvatar), findsNothing);

      // Verify semantics node
      final node = tester.getSemantics(buttonFinder);
      final flags = node.getSemanticsData().flagsCollection;
      expect(node.label, contains('Lưu vào danh sách yêu thích'));
      expect(flags.isButton, isTrue);
      expect(flags.isEnabled, Tristate.isTrue);

      await tester.tap(buttonFinder);
      expect(tapped, isTrue);
      semanticsHandle.dispose();
    });

    testWidgets(
        'AppAccessibility.shouldReduceMotion honors MediaQuery disableAnimations',
        (tester) async {
      late bool reduceMotionActive;
      late Duration resolvedDuration;
      late double resolvedScale;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Builder(
              builder: (context) {
                reduceMotionActive =
                    AppAccessibility.shouldReduceMotion(context);
                resolvedDuration = AppAccessibility.effectiveDuration(
                  context,
                  const Duration(milliseconds: 250),
                );
                resolvedScale = AppAccessibility.effectiveScale(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(reduceMotionActive, isTrue);
      expect(resolvedDuration, Duration.zero);
      expect(resolvedScale, 1.0);
    });
  });

  group('TalkBack / VoiceOver Traversal Order & Modal Focus Restoration', () {
    testWidgets(
        'AccessibleTraversalItem enforces deterministic screen reader & keyboard order',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final focus1 = FocusNode(debugLabel: 'First');
      final focus2 = FocusNode(debugLabel: 'Second');
      final focus3 = FocusNode(debugLabel: 'Third');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                children: [
                  // Placed out of visual order to prove NumericFocusOrder + OrdinalSortKey work
                  AccessibleTraversalItem(
                    order: 2.0,
                    semanticLabel: 'Bước 2: Chọn ngày nhận phòng',
                    child: ElevatedButton(
                      focusNode: focus2,
                      onPressed: () {},
                      child: const Text('Chọn ngày'),
                    ),
                  ),
                  AccessibleTraversalItem(
                    order: 1.0,
                    semanticLabel: 'Bước 1: Chọn điểm đến Vũng Tàu',
                    child: ElevatedButton(
                      focusNode: focus1,
                      onPressed: () {},
                      child: const Text('Điểm đến'),
                    ),
                  ),
                  AccessibleTraversalItem(
                    order: 3.0,
                    semanticLabel: 'Bước 3: Chọn số khách',
                    child: ElevatedButton(
                      focusNode: focus3,
                      onPressed: () {},
                      child: const Text('Số khách'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      focus1.requestFocus();
      await tester.pump();
      expect(focus1.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focus2.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focus3.hasFocus, isTrue);

      focus1.dispose();
      focus2.dispose();
      focus3.dispose();
      semanticsHandle.dispose();
    });

    testWidgets(
        'AccessibleModalScope traps route semantics and restores focus on close',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      final triggerFocus = FocusNode(debugLabel: 'TriggerButton');
      final modalInputFocus = FocusNode(debugLabel: 'ModalFirstControl');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  focusNode: triggerFocus,
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (dialogCtx) => Dialog(
                        child: AccessibleModalScope(
                          modalTitle: 'Bộ lọc tìm kiếm biệt thự',
                          restoreFocusNode: triggerFocus,
                          initialFocusNode: modalInputFocus,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                focusNode: modalInputFocus,
                                decoration: const InputDecoration(
                                  labelText: 'Từ khóa',
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                                child: const Text('Đóng bộ lọc'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Mở bộ lọc'),
                ),
              ),
            ),
          ),
        ),
      );

      triggerFocus.requestFocus();
      await tester.pump();
      expect(triggerFocus.hasFocus, isTrue);

      // Open modal -> focus moves inside modal
      await tester.tap(find.text('Mở bộ lọc'));
      await tester.pumpAndSettle();
      expect(modalInputFocus.hasFocus, isTrue);

      final modalScopeSemantics = tester.getSemantics(
        find.byType(AccessibleModalScope),
      );
      final modalFlags = modalScopeSemantics.getSemanticsData().flagsCollection;
      expect(modalFlags.scopesRoute, isTrue);
      expect(modalFlags.namesRoute, isTrue);

      // Close modal -> focus restores to triggerFocus
      await tester.tap(find.text('Đóng bộ lọc'));
      await tester.pumpAndSettle();
      expect(triggerFocus.hasFocus, isTrue);

      triggerFocus.dispose();
      modalInputFocus.dispose();
      semanticsHandle.dispose();
    });
  });

  group('Privacy-Safe Calendar Day Cell Semantics (FLUTTER_RULES.md 9.2)', () {
    testWidgets(
        'Booked day announces localized dateBooked and blocks selection without guest PII',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      var bookedTapped = false;
      const bookedDate = BookingDate(year: 2026, month: 10, day: 16);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Center(
              child: AccessibleCalendarDayCell(
                date: bookedDate,
                isBooked: true,
                onTap: () => bookedTapped = true,
              ),
            ),
          ),
        ),
      );

      final finder = find.byType(AccessibleCalendarDayCell);
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      final semantics = tester.getSemantics(finder);
      final cellFlags = semantics.getSemanticsData().flagsCollection;
      expect(semantics.label, '16/10/2026, Ngày này đã kín');
      expect(cellFlags.isEnabled, Tristate.isFalse);

      await tester.tap(finder);
      expect(bookedTapped, isFalse);
      semanticsHandle.dispose();
    });
  });
}
