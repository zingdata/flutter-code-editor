// ignore: deprecated_member_use
import 'dart:js' as js;

import 'package:flutter/foundation.dart';

// Returns true if the browser is Chrome
bool isChromeBrowser() {
  if (kIsWeb) {
    try {
      final userAgent = js.context['navigator']['userAgent'].toString().toLowerCase();
      return userAgent.contains('chrome') &&
          !userAgent.contains('edge') &&
          !userAgent.contains('opr') &&
          !userAgent.contains('firefox');
    } catch (e) {
      // If there's an error in JS detection, default to non-Chrome
      return false;
    }
  }
  return false;
}
