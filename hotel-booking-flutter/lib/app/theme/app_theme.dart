import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get lightTheme {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.textStrong,
      primaryContainer: AppColors.brandSoft,
      onPrimaryContainer: AppColors.textStrong,
      secondary: AppColors.textStrong,
      onSecondary: AppColors.textInverse,
      secondaryContainer: AppColors.surfaceMuted,
      onSecondaryContainer: AppColors.textStrong,
      surface: AppColors.surfaceBase,
      onSurface: AppColors.textStrong,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.surfaceBase,
      surfaceContainerLow: AppColors.surfaceWarmSand,
      surfaceContainer: AppColors.surfaceMuted,
      surfaceContainerHigh: AppColors.surfaceSecondary,
      surfaceContainerHighest: AppColors.skeleton,
      surfaceTint: Colors.transparent,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.borderSoft,
      error: AppColors.error,
      onError: AppColors.textInverse,
      errorContainer: AppColors.errorSoft,
      onErrorContainer: AppColors.error,
    );
    final text = ThemeData.light().textTheme.apply(
          fontFamily: AppTypography.primaryFontFamily,
          fontFamilyFallback: AppTypography.fontFallbacks,
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    ButtonStyle buttonStyle(Color background, Color foreground,
        {bool outlined = false}) {
      return ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        elevation: const WidgetStatePropertyAll(0),
        animationDuration: const Duration(milliseconds: 180),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? AppColors.surfaceMuted
                : background),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textDisabled;
          }
          if (states.contains(WidgetState.pressed)) {
            return foreground.withValues(alpha: .9);
          }
          return foreground;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStateProperty.resolveWith((states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? AppColors.borderFocus
                  : outlined
                      ? AppColors.border
                      : Colors.transparent,
            )),
        textStyle: WidgetStatePropertyAll(
            AppTypography.buttonText.copyWith(color: foreground)),
      );
    }

    const input = OutlineInputBorder(
        borderRadius: AppRadii.roundedInput,
        borderSide: BorderSide(color: AppColors.border));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      disabledColor: AppColors.textDisabled,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      fontFamily: AppTypography.primaryFontFamily,
      fontFamilyFallback: AppTypography.fontFallbacks,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      iconTheme: const IconThemeData(color: AppColors.iconStrong, size: 20),
      iconButtonTheme: IconButtonThemeData(
          style: buttonStyle(Colors.transparent, AppColors.iconStrong).copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      )),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        iconTheme: const WidgetStatePropertyAll(
            IconThemeData(color: AppColors.iconStrong, size: 20)),
        labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => AppTypography.caption.copyWith(
                  color: states.contains(WidgetState.selected)
                      ? scheme.onSurface
                      : AppColors.textMuted,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w700,
                )),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.iconStrong,
        collapsedIconColor: AppColors.iconStrong,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceBase,
        foregroundColor: AppColors.textStrong,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.sectionHeading,
        iconTheme: IconThemeData(color: AppColors.iconStrong, size: 22),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: AppRadii.roundedCard,
            side: BorderSide(color: AppColors.borderSoft)),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedModal),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: AppRadii.roundedBottomSheet),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        prefixIconColor: AppColors.iconMuted,
        suffixIconColor: AppColors.iconMuted,
        contentPadding: const EdgeInsets.all(16),
        border: input,
        enabledBorder: input,
        focusedBorder: input.copyWith(
            borderSide: const BorderSide(color: AppColors.borderFocus)),
        errorBorder:
            input.copyWith(borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder:
            input.copyWith(borderSide: BorderSide(color: scheme.error)),
        hintStyle: AppTypography.bodyMuted,
        errorStyle: AppTypography.caption.copyWith(color: scheme.error),
        errorMaxLines: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: buttonStyle(AppColors.primary, AppColors.textInverse)),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: buttonStyle(AppColors.primary, AppColors.textInverse)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: buttonStyle(scheme.surface, scheme.onSurface, outlined: true)),
      textButtonTheme: TextButtonThemeData(
          style: buttonStyle(Colors.transparent, scheme.onSurface)),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        checkmarkColor: AppColors.textInverse,
        showCheckmark: false,
        shape: const StadiumBorder(),
        side: WidgetStateBorderSide.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : AppColors.border)),
        labelStyle: WidgetStateTextStyle.resolveWith((states) => states.contains(WidgetState.selected) ? AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textInverse) : AppTypography.bodyMedium),
        secondaryLabelStyle:
            AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textInverse),
      ),
      datePickerTheme: const DatePickerThemeData(
          rangeSelectionBackgroundColor: AppColors.rangeBackground,
          surfaceTintColor: Colors.transparent),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      dividerTheme: const DividerThemeData(
          color: AppColors.borderSoft, thickness: 1, space: 24),
      textTheme: text.copyWith(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        headlineMedium: AppTypography.sectionHeading,
        titleMedium: AppTypography.cardTitle,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.caption,
        labelLarge: AppTypography.buttonText.copyWith(color: scheme.onSurface),
      ),
    );
  }
}
