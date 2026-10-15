import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Colors.white,
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.primary,
      onSecondary: Colors.white,
      secondaryContainer: Colors.white,
      onSecondaryContainer: AppColors.primary,
      surface: AppColors.surfaceBase,
      onSurface: AppColors.textStrong,
      surfaceTint: Colors.transparent,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.borderSoft,
      error: AppColors.errorRed,
      onError: Colors.white,
      errorContainer: Colors.white,
      onErrorContainer: AppColors.errorRed,
    );

    final baseTextTheme = ThemeData.light().textTheme.apply(
          fontFamily: AppTypography.primaryFontFamily,
          fontFamilyFallback: AppTypography.fontFallbacks,
          bodyColor: AppColors.textStrong,
          displayColor: AppColors.textStrong,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.primaryFontFamily,
      fontFamilyFallback: AppTypography.fontFallbacks,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,

      // Global Icon Theme: strictly neutral monochrome
      iconTheme: const IconThemeData(
        color: AppColors.iconStrong,
        size: 20,
      ),

      // IconButton Theme: transparent hit target, no decorative background or splash fill
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStatePropertyAll(AppColors.iconStrong),
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          padding: WidgetStatePropertyAll(EdgeInsets.all(8)),
        ),
      ),

      // NavigationBar Theme: no pill indicator background behind icons, neutral monochrome icons
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceBase,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return const IconThemeData(
            color: AppColors.iconStrong,
            size: 20,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return AppTypography.caption.copyWith(
            color: isSelected ? AppColors.textStrong : AppColors.textMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          );
        }),
      ),

      // ExpansionTile Theme: neutral monochrome chevron in both states
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.iconStrong,
        collapsedIconColor: AppColors.iconStrong,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
      ),

      // AppBar Theme
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

      // Card Theme (no full border or shadow)
      cardTheme: const CardThemeData(
        color: AppColors.surfaceBase,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.roundedCard,
        ),
        margin: EdgeInsets.zero,
      ),

      // Dialog / Modal Theme (--radius-modal: 1.5rem = 24px)
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.roundedModal,
        ),
      ),

      // BottomSheet Theme (rounded-t-[32px])
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.roundedBottomSheet,
        ),
      ),

      // Input Decoration Theme (horizontal underline divider instead of box border)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceBase,
        prefixIconColor: AppColors.iconMuted,
        suffixIconColor: AppColors.iconMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.textStrong, width: 1.5),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.errorRed),
        ),
        hintStyle:
            AppTypography.bodyMuted.copyWith(color: AppColors.textTertiary),
      ),

      // Filled Button Theme (rounded-full: 9999px)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          overlayColor: Colors.transparent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: const StadiumBorder(),
          textStyle: AppTypography.buttonText,
          elevation: 0,
        ),
      ),

      // Elevated Button Theme (rounded-full: 9999px)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textStrong,
          foregroundColor: Colors.white,
          overlayColor: Colors.transparent,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: AppTypography.buttonText,
          elevation: 0,
        ),
      ),

      // Outlined Button Theme (rounded-full: 9999px, white background, no full border)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceBase,
          foregroundColor: AppColors.textStrong,
          overlayColor: Colors.transparent,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          side: BorderSide.none,
          textStyle:
              AppTypography.buttonText.copyWith(color: AppColors.textStrong),
        ),
      ),

      // Text Button Theme (no pinkish press overlay)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          overlayColor: Colors.transparent,
          shape: const StadiumBorder(),
        ),
      ),

      // Chip Theme (rounded-2xl: 16px, white background, no pinkish fill)
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: Colors.white,
        disabledColor: AppColors.surfaceVariant,
        surfaceTintColor: Colors.transparent,
        checkmarkColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: WidgetStateBorderSide.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          );
        }),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textStrong,
        ),
        secondaryLabelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 1,
        space: 24,
      ),

      textTheme: baseTextTheme.copyWith(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        headlineMedium: AppTypography.sectionHeading,
        titleMedium: AppTypography.cardTitle,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.caption,
        labelLarge: AppTypography.buttonText,
      ),
    );
  }
}
