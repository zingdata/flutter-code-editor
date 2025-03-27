// Use different implementations for web vs non-web platforms
import 'package:flutter/rendering.dart';
import 'package:flutter_code_editor/src/code_field/browser_detection_web.dart'
    if (dart.library.io) 'browser_detection_io.dart' as detection;

// Function to determine if we need to use specific Chrome text selection fixes
Map<String, dynamic> getChromeTextSelectionFixes() {
  return detection.getChromeTextSelectionFixes();
}

// Legacy function kept for backward compatibility
// Now returns null to use the default line height
@deprecated
double? getChromeLineHeight() {
  return null;
}

// Function to get appropriate top padding based on browser
double getGutterTopPadding() {
  return 16.0;
}
