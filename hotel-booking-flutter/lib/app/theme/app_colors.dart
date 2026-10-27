import 'package:flutter/material.dart';

/// Centralized Design System Colors for Minh Thanh Villa.
///
/// Strictly adheres to FLUTTER_RULES.md & Source goc palette tokens.
/// Hardcoding random hex colors across screens is strictly forbidden.
abstract final class AppColors {
  // Brand Colors
  static const primary = Color(0xFFFF385C);
  static const primaryPressed = Color(0xFFE00B41);
  static const primaryHover = Color(0xFFE00B41);
  static const brandSoft = Color(0xFFFFF1F3);
  static const rangeBackground = Color(0xFFFFF1F3);
  static const accent = primary;

  // Typography Colors
  static const textStrong = Color(0xFF222222);
  static const textPrimary = textStrong;
  static const textMuted = Color(0xFF717171);
  static const textSecondary = Color(0xFF5E5E5E);
  static const textTertiary = Color(0xFFB0B0B0);
  static const textDisabled = textSecondary;
  static const textInverse = Color(0xFFFFFFFF);

  // Surfaces & Backgrounds
  static const surfaceBase = Color(0xFFFFFFFF);
  static const surfacePrimary = surfaceBase;
  static const background = surfaceBase;
  static const surfaceMuted = Color(0xFFF1F5F9);
  static const surfaceSecondary = Color(0xFFF1F5F9);
  static const surfaceVariant = surfaceSecondary;
  static const skeleton = Color(0xFFE2E8F0);
  static const surfaceWarmSand = Color(0xFFF7F6F3);
  static const surfaceWarmCard = Color(0xFFFFFFFF);
  static const surfaceFooter = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceOverlay = surfaceElevated;
  static const surfaceFrosted = surfaceElevated;
  static const scrim = Color(0x61111111);

  // Borders & Dividers
  static const borderSoft = Color(0xFFEBEBEB);
  static const border = Color(0xFFDDDDDD);
  static const divider = borderSoft;
  static const borderStrong = Color(0xFFB0B0B0);
  static const borderFocus = Color(0xFF222222);
  static const borderWarm = Color(0xFFE8DDD1);

  // Accent / Status
  static const starAmber = Color(0xFFF59E0B);
  static const ratingStar = Color(0xFF222222);
  static const warningAmber = Color(0xFF925900);
  static const warning = warningAmber;
  static const warningSoft = Color(0xFFFFFBEB);
  static const warningLight = warningSoft;
  static const successGreen = Color(0xFF047857);
  static const success = successGreen;
  static const successSoft = Color(0xFFECFDF5);
  static const successLight = successSoft;
  static const errorRed = Color(0xFFB42318);
  static const error = errorRed;
  static const errorSoft = Color(0xFFFFF1F2);
  static const errorLight = errorSoft;

  // Icons (Strictly neutral monochrome per Section 2 Icon Rules)
  static const iconStrong = Color(0xFF222222);
  static const iconDefault = Color(0xFF484848);
  static const iconOnBrand = Color(0xFFFFFFFF);
  static const iconMuted = Color(0xFF717171);

  // Shadows (Disabled — using horizontal dividers instead)
  static const shadowSoft = BoxShadow(
    color: Color(0x00000000),
    blurRadius: 0,
    offset: Offset.zero,
  );

  static const shadowGlass = BoxShadow(
    color: Color(0x00000000),
    blurRadius: 0,
    offset: Offset.zero,
  );

  static const shadowModal = BoxShadow(
    color: Color(0x00000000),
    blurRadius: 0,
    offset: Offset.zero,
  );
}
