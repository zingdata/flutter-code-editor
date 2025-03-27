// ignore: deprecated_member_use
import 'dart:js' as js;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

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

// Optimizes text selection in Chrome by adjusting selection behavior
// instead of modifying line height
Map<String, dynamic> getChromeTextSelectionFixes() {
  if (!isChromeBrowser()) {
    return {
      'useCustomSelectionStyle': false,
    };
  }
  
  return {
    'useCustomSelectionStyle': true,
    'selectionHeightFix': true,
    'leadingDistribution': TextLeadingDistribution.even,
    'selectionAlignmentFix': true,
  };
}
