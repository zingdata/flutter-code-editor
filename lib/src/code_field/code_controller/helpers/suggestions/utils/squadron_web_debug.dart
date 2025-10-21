import 'package:flutter/foundation.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/helpers/suggestions/utils/logger.dart';

/// Debug utility for Squadron web workers
///
/// Provides logging and diagnostic functions specifically for
/// Squadron worker operations on the web platform.
class SquadronWebDebug {
  /// Logs Squadron initialization status
  static void logInitialization({
    required bool success,
    required Duration duration,
    String? error,
    Map<String, dynamic>? workerStats,
  }) {
    if (!kIsWeb || !printLogs) return;

    if (success) {
      infoLog(
          '✅ Squadron initialized successfully in ${duration.inMilliseconds}ms');
    } else {
      errorLog(
          '❌ Squadron initialization failed after ${duration.inMilliseconds}ms');
      if (error != null) {
        errorLog('Error: $error');
      }
      if (workerStats != null) {
        errorLog('Worker stats: $workerStats');
      }
    }
  }

  /// Logs worker pool configuration
  static void logWorkerPoolConfig({
    required int minWorkers,
    required int maxWorkers,
    required int maxParallel,
  }) {
    if (!kIsWeb || !printLogs) return;

    infoLog('📊 Worker pool configured:');
    infoLog('   - Min workers: $minWorkers');
    infoLog('   - Max workers: $maxWorkers');
    infoLog('   - Max parallel: $maxParallel');
  }

  /// Logs task execution status
  static void logTaskExecution({
    required String taskId,
    required String taskType,
    required bool started,
    bool completed = false,
    Duration? duration,
    String? error,
  }) {
    if (!kIsWeb || !printLogs) return;

    if (started && !completed) {
      infoLog('🚀 Task started: $taskId ($taskType)');
    } else if (completed && error == null) {
      infoLog(
          '✅ Task completed: $taskId in ${duration?.inMilliseconds ?? 0}ms');
    } else if (error != null) {
      errorLog(
          '❌ Task failed: $taskId after ${duration?.inMilliseconds ?? 0}ms');
      errorLog('   Error: $error');
    }
  }

  /// Logs browser environment information
  static void logBrowserEnvironment() {
    if (!kIsWeb || !printLogs) return;

    infoLog('🌐 Browser environment:');
    infoLog('   - Base URL: ${Uri.base}');
    infoLog('   - Scheme: ${Uri.base.scheme}');
    infoLog('   - Host: ${Uri.base.host}');
    infoLog('   - Debug mode: $kDebugMode');
    infoLog('   - Profile mode: $kProfileMode');
    infoLog('   - Release mode: $kReleaseMode');
  }

  /// Prints debugging instructions for Squadron web workers
  static void printDebugInstructions() {
    if (!kIsWeb || !printLogs) return;

    infoLog('=== Squadron Web Worker Debugging ===');
    infoLog('1. Open browser DevTools console');
    infoLog('2. Check Network tab for worker file loading');
    infoLog('3. Look for files in web/workers/');
    infoLog('4. Check for CORS or security errors');
    infoLog('5. Verify worker files are being served correctly');
    infoLog('=====================================');
  }

  /// Starts monitoring worker communication
  static void startCommunicationMonitor() {
    if (!kIsWeb || !printLogs) return;

    infoLog('📡 Squadron communication monitoring started');
    infoLog('   Watch for Squadron.* logs in browser console');
  }

  /// Runs quick diagnostics on Squadron setup
  static Future<void> runQuickDiagnostics() async {
    if (!kIsWeb || !printLogs) return;

    infoLog('🔍 Running Squadron quick diagnostics...');

    // Check base URL
    try {
      final baseUrl = Uri.base;
      infoLog('✅ Base URL accessible: $baseUrl');
    } catch (e) {
      errorLog('❌ Base URL check failed: $e');
    }

    // Check secure context
    try {
      final isSecure = Uri.base.scheme == 'https' ||
          Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1';
      if (isSecure) {
        infoLog('✅ Secure context detected');
      } else {
        warnLog('⚠️ Not in secure context (may affect worker loading)');
      }
    } catch (e) {
      errorLog('❌ Secure context check failed: $e');
    }

    // Check protocol
    try {
      if (Uri.base.scheme == 'file') {
        errorLog('❌ file:// protocol detected - workers will not load');
      } else if (Uri.base.scheme.isEmpty) {
        warnLog('⚠️ Unable to determine URL scheme');
      } else {
        infoLog('✅ URL scheme: ${Uri.base.scheme}');
      }
    } catch (e) {
      errorLog('❌ Protocol check failed: $e');
    }

    infoLog('✅ Quick diagnostics completed');
  }

  /// Logs worker operation statistics
  static void logWorkerStats({
    required int activeWorkers,
    required int totalTasks,
    required int completedTasks,
    required int failedTasks,
  }) {
    if (!kIsWeb || !printLogs) return;

    infoLog('📊 Worker statistics:');
    infoLog('   - Active workers: $activeWorkers');
    infoLog('   - Total tasks: $totalTasks');
    infoLog('   - Completed: $completedTasks');
    infoLog('   - Failed: $failedTasks');
  }
}
