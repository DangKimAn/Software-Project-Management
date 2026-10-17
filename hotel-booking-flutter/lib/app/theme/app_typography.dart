import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static const String primaryFontFamily = 'SF Pro Display';
  static const String textFontFamily = 'SF Pro Text';
  static const String roundedFontFamily = 'SF Pro Rounded';

  // Font Family Fallbacks using bundled SF Pro assets first
  static const List<String> fontFallbacks = [
    'SF Pro Display',
    'SF Pro Text',
    'SF Pro Rounded',
    'SF Pro',
    'Be Vietnam Pro',
    'Roboto',
    'sans-serif',
  ];

  static const TextStyle display = displayLarge;
  static const TextStyle body = bodyMedium;

  static const TextStyle displayLarge = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.28,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.32,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.35,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: textFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: textFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.05,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.48,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: textFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.05,
    color: AppColors.textMuted,
    fontFamilyFallback: fontFallbacks,
    height: 1.48,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: Colors.white,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: textFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.0,
    color: AppColors.textMuted,
    fontFamilyFallback: fontFallbacks,
    height: 1.35,
  );

  static const TextStyle priceHighlight = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
  );
}
