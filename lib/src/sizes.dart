// TODO(nausharipov): where to store constants?

import 'package:flutter/material.dart';

class Sizes {
  static const double autocompletePopupMaxHeight = 160;
  static const double autocompletePopupMaxWidth = 320;
  static const caretPadding = 10;
}

class ScreenSize {
  static const isMobileWidth = 600;
  static const isExtraWideWidth = 1440;

  static bool isMobile(BuildContext context) => MediaQuery.sizeOf(context).width < isMobileWidth;
  static bool isExtraWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width > isExtraWideWidth;
}
