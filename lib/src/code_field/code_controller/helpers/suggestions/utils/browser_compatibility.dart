import 'package:flutter/foundation.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/helpers/suggestions/utils/logger.dart';

/// Browser compatibility check results
class BrowserCompatibilityResult {
  const BrowserCompatibilityResult({
    required this.isCompatible,
    required this.issues,
    required this.warnings,
    required this.recommendations,
  });

  /// Whether the browser is compatible with Squadron workers
  final bool isCompatible;

  /// List of compatibility issues that prevent workers from functioning
  final List<String> issues;

  /// List of warnings that may affect performance or functionality
  final List<String> warnings;

  /// List of recommendations for optimal performance
  final List<String> recommendations;
}

/// Utility class for checking browser compatibility with Squadron web workers
class BrowserCompatibility {
  /// Checks if the current browser supports Squadron web workers
  ///
  /// Returns a [BrowserCompatibilityResult] with detailed information
  /// about compatibility, issues, warnings, and recommendations.
  static Future<BrowserCompatibilityResult> checkCompatibility() async {
    if (!kIsWeb) {
      // Non-web platforms are always compatible (use native isolates)
      return const BrowserCompatibilityResult(
        isCompatible: true,
        issues: [],
        warnings: [],
        recommendations: [],
      );
    }

    final issues = <String>[];
    final warnings = <String>[];
    final recommendations = <String>[];

    // Check if running in secure context (HTTPS or localhost)
    final isSecureContext = _isSecureContext();
    if (!isSecureContext) {
      warnings.add('Not running in a secure context (HTTPS/localhost)');
      recommendations
          .add('Use HTTPS or localhost for optimal worker performance');
    }

    // Check for file:// protocol
    if (Uri.base.scheme == 'file') {
      issues.add('Running from file:// protocol is not supported');
      recommendations.add('Serve the application over HTTP/HTTPS');
    }

    // Basic web worker support check
    // Note: In Flutter web, we can't directly access JavaScript APIs
    // but Squadron will handle worker loading automatically
    if (Uri.base.scheme.isEmpty) {
      warnings.add('Unable to determine URL scheme');
    }

    final isCompatible = issues.isEmpty;

    return BrowserCompatibilityResult(
      isCompatible: isCompatible,
      issues: issues,
      warnings: warnings,
      recommendations: recommendations,
    );
  }

  /// Checks if the current environment is a secure context
  static bool _isSecureContext() {
    try {
      return Uri.base.scheme == 'https' ||
          Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1';
    } catch (e) {
      return false;
    }
  }

  /// Logs compatibility results to the console
  static void logResults(BrowserCompatibilityResult result) {
    if (!kIsWeb) {
      infoLog('Platform: Native (Dart VM isolates)');
      return;
    }

    infoLog('=== Browser Compatibility Check ===');
    infoLog('Compatible: ${result.isCompatible}');

    if (result.issues.isNotEmpty) {
      errorLog('Issues:');
      for (final issue in result.issues) {
        errorLog('  - $issue');
      }
    }

    if (result.warnings.isNotEmpty) {
      warnLog('Warnings:');
      for (final warning in result.warnings) {
        warnLog('  - $warning');
      }
    }

    if (result.recommendations.isNotEmpty) {
      infoLog('Recommendations:');
      for (final rec in result.recommendations) {
        infoLog('  - $rec');
      }
    }
  }

  /// Returns a map of supported features
  static Map<String, bool> getFeatureSupport() {
    if (!kIsWeb) {
      return {
        'workers': true,
        'isolates': true,
        'wasm': false,
        'secureContext': true,
      };
    }

    return {
      'workers': true, // Squadron handles worker detection
      'isolates': false, // Web doesn't support Dart isolates
      'wasm': true, // Assume WASM support in modern browsers
      'secureContext': _isSecureContext(),
    };
  }
}
