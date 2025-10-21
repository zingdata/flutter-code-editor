import 'package:flutter/foundation.dart';

/// Simple logging utility for Squadron workers and suggestion helpers
///
/// Provides consistent logging across the codebase with the ability
/// to enable/disable logs globally.

/// Global flag to control logging output
/// Set to false in production to disable all logging
const bool printLogs = kDebugMode;

/// Logs informational messages
///
/// Only outputs when [printLogs] is true and running in debug mode
void infoLog(String message) {
  if (printLogs) {
    debugPrint('[INFO] $message');
  }
}

/// Logs error messages
///
/// Only outputs when [printLogs] is true and running in debug mode
void errorLog(String message) {
  if (printLogs) {
    debugPrint('[ERROR] $message');
  }
}

/// Logs warning messages
///
/// Only outputs when [printLogs] is true and running in debug mode
void warnLog(String message) {
  if (printLogs) {
    debugPrint('[WARN] $message');
  }
}

/// Logs debug messages with detailed information
///
/// Only outputs when [printLogs] is true and running in debug mode
void debugLog(String message) {
  if (printLogs) {
    debugPrint('[DEBUG] $message');
  }
}
