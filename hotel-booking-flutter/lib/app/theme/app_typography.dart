import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  // Font Family Fallbacks for Vietnamese, English, and Korean safety
  static const List<String> fontFallbacks = [
    'Be Vietnam Pro',
    'Noto Sans KR',
    'Roboto',
    'Apple SD Gothic Neo',
    'sans-serif',
  ];

  static const TextStyle display = displayLarge;
  static const TextStyle body = bodyMedium;

  static const TextStyle displayLarge = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.25,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.3,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.35,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.35,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.07,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
    height: 1.45,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.05,
    color: AppColors.textMuted,
    fontFamilyFallback: fontFallbacks,
    height: 1.45,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: Colors.white,
    fontFamilyFallback: fontFallbacks,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.0,
    color: AppColors.textMuted,
    fontFamilyFallback: fontFallbacks,
    height: 1.35,
  );

  static const TextStyle priceHighlight = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textStrong,
    fontFamilyFallback: fontFallbacks,
  );
}
