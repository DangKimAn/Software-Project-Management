import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brandSoft,
      onPrimaryContainer: AppColors.primaryPressed,
      surface: AppColors.surfaceBase,
      onSurface: AppColors.textStrong,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.borderSoft,
      error: AppColors.errorRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceBase,
      fontFamilyFallback: AppTypography.fontFallbacks,

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceBase,
        foregroundColor: AppColors.textStrong,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: AppTypography.sectionHeading,
        iconTheme: IconThemeData(color: AppColors.textStrong, size: 22),
      ),

      // Card Theme
      cardTheme: const CardThemeData(
        color: AppColors.surfaceBase,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.roundedCard,
          side: BorderSide(color: AppColors.borderSoft),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceBase,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: const OutlineInputBorder(
          borderRadius: AppRadii.roundedPill,
          borderSide: BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadii.roundedPill,
          borderSide: BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadii.roundedPill,
          borderSide: BorderSide(color: AppColors.textStrong, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadii.roundedPill,
          borderSide: BorderSide(color: AppColors.errorRed),
        ),
        hintStyle:
            AppTypography.bodyMuted.copyWith(color: AppColors.textTertiary),
      ),

      // Filled Button Theme (Primary Coral Pill)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: AppTypography.buttonText,
          elevation: 0,
        ),
      ),

      // Outlined Button Theme (Secondary White Pill with Border)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceBase,
          foregroundColor: AppColors.textStrong,
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.borderStrong),
          textStyle:
              AppTypography.buttonText.copyWith(color: AppColors.textStrong),
          elevation: 0,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceBase,
        modalBackgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: AppRadii.roundedBottomSheet),
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
