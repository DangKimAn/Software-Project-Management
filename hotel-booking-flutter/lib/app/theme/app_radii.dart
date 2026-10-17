import 'package:flutter/material.dart';

/// Design tokens for border-radius matching `Source goc/frontend/src/index.css`:
/// - `--radius-button`: 1rem (16px)
/// - `--radius-input`: 1rem (16px)
/// - `--radius-table`: 1rem (16px)
/// - `--radius-card`: 1.5rem (24px / Tailwind `rounded-3xl`)
/// - `--radius-modal`: 1.5rem (24px)
/// - `--radius-dropdown`: 1.5rem (24px)
/// - `--radius-panel`: 1.5rem (24px)
/// - `--radius-badge`: 9999px (`rounded-full`)
abstract final class AppRadii {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double button = 999.0;
  static const double input = 16.0;
  static const double table = 16.0;
  static const double card = 24.0;
  static const double modal = 28.0;
  static const double dropdown = 24.0;
  static const double panel = 24.0;
  static const double popover = 30.0;
  static const double bottomSheetTop = 32.0;
  static const double heroCardMobile = 34.0;
  static const double heroCardDesktop = 40.0;
  static const double pill = 999.0;

  static const BorderRadius roundedButton =
      BorderRadius.all(Radius.circular(button));
  static const BorderRadius roundedInput =
      BorderRadius.all(Radius.circular(input));
  static const BorderRadius roundedCard =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius roundedModal =
      BorderRadius.all(Radius.circular(modal));
  static const BorderRadius roundedPopover =
      BorderRadius.all(Radius.circular(popover));
  static const BorderRadius roundedPill =
      BorderRadius.all(Radius.circular(pill));
  static const BorderRadius roundedBottomSheet = BorderRadius.vertical(
    top: Radius.circular(bottomSheetTop),
  );
}
