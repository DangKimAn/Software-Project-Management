import 'package:flutter/material.dart';

/// Shared light luxury radii. Fullscreen media and system bars stay square.
abstract final class AppRadii {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double button = 999.0;
  static const double input = 24.0;
  static const double search = pill;
  static const double chip = pill;
  static const double table = 16.0;
  static const double card = 24.0;
  static const double modal = 28.0;
  static const double dropdown = 24.0;
  static const double panel = 24.0;
  static const double popover = 30.0;
  static const double bottomSheetTop = 32.0;
  static const double heroCardMobile = 32.0;
  static const double heroCardDesktop = 32.0;
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
