import 'package:flutter/rendering.dart';

bool isChromeBrowser() {
  return false;
}

Map<String, dynamic> getChromeTextSelectionFixes() {
  return {
    'useCustomSelectionStyle': false,
  };
}
