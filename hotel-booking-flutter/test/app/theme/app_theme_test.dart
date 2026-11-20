import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/app/theme/app_radii.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';

void main() {
  test('semantic colors retain contrast and distinct surfaces', () {
    final theme = AppTheme.lightTheme;
    double contrast(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    expect(contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5));
    for (final color in [
      AppColors.success,
      AppColors.error,
      AppColors.warning,
      AppColors.textMuted,
      AppColors.textDisabled
    ]) {
      expect(contrast(color, AppColors.surfaceBase), greaterThanOrEqualTo(4.5));
    }
    expect(theme.colorScheme.errorContainer, AppColors.errorSoft);
    expect(
        theme.colorScheme.surfaceContainer, isNot(theme.colorScheme.surface));
    expect(theme.datePickerTheme.rangeSelectionBackgroundColor,
        AppColors.rangeBackground);
    expect(AppColors.skeleton, isNot(AppColors.surfaceBase));
    expect(contrast(AppColors.textDisabled, AppColors.surfaceMuted),
        greaterThanOrEqualTo(4.5));
    expect(AppColors.surfaceOverlay.a, 1);
    expect(AppColors.surfaceFrosted.a, 1);
  });
  test('theme uses pill buttons and chips, rounded inputs/cards/sheets', () {
    final theme = AppTheme.lightTheme;
    expect(theme.filledButtonTheme.style!.shape!.resolve({}),
        isA<StadiumBorder>());
    expect(theme.chipTheme.shape, isA<StadiumBorder>());
    expect(AppRadii.heroCardMobile, inInclusiveRange(24, 32));
    expect(AppRadii.heroCardDesktop, inInclusiveRange(24, 32));
    expect((theme.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
        AppRadii.roundedCard);
    expect(
        (theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder)
            .borderRadius,
        AppRadii.roundedInput);
    expect(
        (theme.bottomSheetTheme.shape! as RoundedRectangleBorder).borderRadius,
        AppRadii.roundedBottomSheet);
    final style = theme.iconButtonTheme.style!;
    for (final states in <Set<WidgetState>>[
      {},
      {WidgetState.disabled},
      {WidgetState.pressed},
      {WidgetState.focused}
    ]) {
      expect(style.backgroundColor!.resolve(states), Colors.transparent);
      expect(style.minimumSize!.resolve(states), const Size(48, 48));
    }
  });
}
