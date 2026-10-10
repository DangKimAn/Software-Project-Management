import 'package:flutter/material.dart';

abstract final class AppRadii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double card = 18.0;
  static const double bottomSheetTop = 32.0;
  static const double pill = 999.0;

  static const BorderRadius roundedCard =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius roundedPill =
      BorderRadius.all(Radius.circular(pill));
  static const BorderRadius roundedBottomSheet = BorderRadius.vertical(
    top: Radius.circular(bottomSheetTop),
  );
}
