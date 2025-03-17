
// Use different implementations for web vs non-web platforms
import 'package:flutter_code_editor/src/code_field/browser_detection_web.dart' if (dart.library.io) 'browser_detection_io.dart' as detection;

// Function to determine the line height based on platform
double getLineHeight() {
  return detection.isChromeBrowser() ? 1.15 : 1.3;
}

// Function to get appropriate top padding based on line height
double getGutterTopPadding() {
  return getLineHeight() == 1.15 ? 13.0 : 16.0;
} 