import 'package:flutter/material.dart';

/// Centralized Design System Colors for Minh Thanh Villa.
///
/// Strictly adheres to FLUTTER_RULES.md (Airbnb Luxury × Apple Clean Minimalist).
/// Hardcoding random hex colors across screens is strictly forbidden.
abstract final class AppColors {
  // Brand Colors
  static const primary = Color(0xFFFF385C);
  static const primaryPressed = Color(0xFFE00B41);
  static const brandSoft = Color(0xFFFFE8EC);
  static const rangeBackground = Color(0xFFFFF1F3);

  // Typography Colors
  static const textStrong = Color(0xFF222222);
  static const textMuted = Color(0xFF717171);
  static const textTertiary = Color(0xFFB0B0B0);

  // Surfaces & Backgrounds
  static const surfaceBase = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF8FAFC);
  static const surfaceSecondary = Color(0xFFF1F5F9);

  // Borders
  static const borderSoft = Color(0xFFEBEBEB);
  static const borderStrong = Color(0xFFDDDDDD);

  // Accent / Status
  static const starAmber = Color(0xFFF59E0B);
  static const successGreen = Color(0xFF10B981);
  static const errorRed = Color(0xFFEF4444);

  // Icons
  static const iconStrong = Color(0xFF000000);
  static const iconOnBrand = Color(0xFFFFFFFF);
  static const iconMuted = Color(0xFF717171);

  // Shadows
  static const shadowSoft = BoxShadow(
    color: Color(0x0F000000), // 6% opacity black
    blurRadius: 16,
    offset: Offset(0, 4),
  );

  static const shadowGlass = BoxShadow(
    color: Color(0x0A000000), // 4% opacity black
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const shadowModal = BoxShadow(
    color: Color(0x1F000000), // 12% opacity black
    blurRadius: 24,
    offset: Offset(0, -4),
  );
}
