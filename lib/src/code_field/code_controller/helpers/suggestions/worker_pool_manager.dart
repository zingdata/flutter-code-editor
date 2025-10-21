import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/helpers/suggestions/suggestion_worker_pool.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/helpers/suggestions/utils/browser_compatibility.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/helpers/suggestions/utils/logger.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/helpers/suggestions/utils/squadron_web_debug.dart';
import 'package:squadron/squadron.dart';

/// Squadron-based service for managing worker tasks with cancellation support
/// Provides thread-safe operations using Squadron's WorkerPool
class WorkerPoolManager {
  /// Default configuration - optimized for performance
  /// 2-8 workers with 4 concurrent tasks each = up to 32 parallel operations
  static WorkerManagerConfig _config = const WorkerManagerConfig();

  // Service start time for accurate uptime reporting
  static DateTime? _serviceStartTime;

  // Squadron worker pool for handling tasks
  static SuggestionWorkerPoolWorkerPool? _workerPool;

  // Track active tasks for monitoring (Squadron handles cancellation internally)
  static final Set<String> _activeTasks = {};

  // Track if service is initialized
  static bool _isInitialized = false;

  // Flag to prevent operations during disposal
  static bool _isDisposing = false;

  /// Converts raw result from Squadron to properly typed Dart collections
  // ignore: unintended_html_in_doc_comment
  /// This ensures web workers return Map<String, dynamic> instead of JsLinkedHashMap
  static dynamic _convertJsonToDartTypes(dynamic value) {
    if (value == null) {
      return null;
    } else if (value is Map) {
      // Convert any Map to Map<String, dynamic> and recursively process values
      final Map<String, dynamic> convertedMap = <String, dynamic>{};
      value.forEach((key, val) {
        convertedMap[key.toString()] = _convertJsonToDartTypes(val);
      });
      return convertedMap;
    } else if (value is List) {
      // Convert List and recursively process elements
      return value.map((item) => _convertJsonToDartTypes(item)).toList();
    } else {
      // Primitive values (String, num, bool) don't need conversion
      return value;
    }
  }

  /// Initializes the service and creates the Squadron worker pool
  static Future<void> initialize({WorkerManagerConfig? config}) async {
    final initStartTime = DateTime.now();

    // Platform detection logging
    if (printLogs)
      infoLog('🚀 Starting WorkerManagerService initialization...');
    if (printLogs)
      infoLog(
          '📱 Platform: ${kIsWeb ? 'Web' : 'Native'} (Debug: $kDebugMode, Profile: $kProfileMode, Release: $kReleaseMode)');

    if (_isInitialized) {
      if (printLogs) infoLog('✅ WorkerManagerService already initialized');
      return;
    }

    if (config != null) {
      _config = config;
      if (printLogs) infoLog('⚙️ Using custom config: ${_config.toJson()}');
    } else {
      if (printLogs) infoLog('⚙️ Using default config: ${_config.toJson()}');
    }

    _serviceStartTime = DateTime.now();

    try {
      // Create Squadron WorkerPool with concurrency settings
      if (printLogs) infoLog('🔧 Creating Squadron WorkerPool...');
      final concurrencySettings = ConcurrencySettings(
        minWorkers: _config.minWorkers,
        maxWorkers: _config.maxWorkers,
        maxParallel: _config.maxParallel,
      );

      if (printLogs)
        infoLog(
            '📊 Concurrency settings: Min=${_config.minWorkers}, Max=${_config.maxWorkers}, Parallel=${_config.maxParallel}');

      if (kIsWeb && printLogs) {
        infoLog('🌐 Web platform detected - Squadron will use JS/WASM workers');
        infoLog('🔍 Squadron Platform Type: ${Squadron.platformType}');
        infoLog('🎯 Expected worker file selection:');
        infoLog('   - JS workers: ./workers/suggestion_worker_pool.web.g.dart.js');
        infoLog(
            '   - WASM workers: ./workers/suggestion_worker_pool.web.g.dart.wasm');
        infoLog(
            '   - MJS module: ./workers/suggestion_worker_pool.web.g.dart.mjs');
        infoLog(
            '   - Support JS: ./workers/suggestion_worker_pool.web.g.dart.support.js');

        // Additional web debugging info
        infoLog('🌍 User agent: ${Squadron.platformType.toString()}');
        infoLog(
            '🔒 Security context info: Running in ${kIsWeb ? 'web' : 'native'} mode');
      } else {
        infoLog('📱 Native platform detected - Squadron will use VM isolates');
      }

      if (printLogs) infoLog('⏳ Creating Squadron WorkerPool instance...');
      final poolCreateStart = DateTime.now();

      _workerPool = SuggestionWorkerPoolWorkerPool(
        concurrencySettings: concurrencySettings,
      );

      final poolCreateDuration = DateTime.now().difference(poolCreateStart);
      if (printLogs)
        infoLog(
            '✅ Squadron worker pool instance created in ${poolCreateDuration.inMilliseconds}ms');
      if (printLogs)
        infoLog('📋 Pool will auto-start workers on first method call');

      // Squadron pools don't need explicit start() - they auto-start when used
      final poolStartTime = DateTime.now();
      final poolStartDuration = DateTime.now().difference(poolStartTime);

      _isInitialized = true;
      _isDisposing = false;

      final totalInitDuration = DateTime.now().difference(initStartTime);

      if (printLogs)
        infoLog('✅ WorkerManagerService initialized successfully!');
      if (printLogs)
        infoLog('⏱️ Pool startup time: ${poolStartDuration.inMilliseconds}ms');
      if (printLogs)
        infoLog('⏱️ Total init time: ${totalInitDuration.inMilliseconds}ms');

      if (kIsWeb) {
        if (printLogs) infoLog('🌐 Web workers ready for JS/WASM execution');

        // Web-specific logging and diagnostics
        SquadronWebDebug.logInitialization(
          success: true,
          duration: totalInitDuration,
        );

        SquadronWebDebug.logWorkerPoolConfig(
          minWorkers: _config.minWorkers,
          maxWorkers: _config.maxWorkers,
          maxParallel: _config.maxParallel,
        );

        // Print debugging instructions in debug and profile mode
        if (kDebugMode || kProfileMode) {
          SquadronWebDebug.printDebugInstructions();
          SquadronWebDebug.startCommunicationMonitor();

          // Check browser compatibility first
          unawaited(_checkBrowserCompatibility());

          // Run quick diagnostics (fire and forget)
          unawaited(SquadronWebDebug.runQuickDiagnostics());

          // Test worker initialization immediately after creation
          if (printLogs)
            infoLog('🧪 Running immediate worker initialization test...');
          unawaited(_runWorkerInitializationTest());

          // Add profile-specific logging
          if (printLogs) {
            infoLog('📊 Profile mode Squadron debugging enabled');
            infoLog('💡 Check browser console for Squadron.* logs');
          }
        }
      }
    } catch (e, stackTrace) {
      final totalInitDuration = DateTime.now().difference(initStartTime);
      errorLog(
          '❌ Failed to initialize WorkerManagerService after ${totalInitDuration.inMilliseconds}ms');
      errorLog('💥 Error type: ${e.runtimeType}');
      errorLog('📝 Error details: $e');
      errorLog('🔍 Stack trace: $stackTrace');

      if (kIsWeb) {
        errorLog('🌐 Web-specific debugging information:');
        errorLog('   📱 Platform type: ${Squadron.platformType}');
        errorLog(
            '   🎯 Expected activator result: ${_getActivatorDebugInfo()}');
        errorLog('   📂 Worker files should be in: web/workers/');
        errorLog('   🔒 Security context: ${_getSecurityDebugInfo()}');
        errorLog('   🌍 Current URL: ${Uri.base}');
        errorLog('   📊 Available memory: ${_getMemoryDebugInfo()}');

        // Detailed error analysis
        if (e.toString().contains('Failed to load worker')) {
          errorLog('🚫 WORKER LOAD FAILURE - Possible causes:');
          errorLog('   - Worker files missing from web/workers/');
          errorLog('   - CORS policy blocking worker loading');
          errorLog('   - Incorrect worker file paths');
          errorLog('   - Network security restrictions');
        } else if (e.toString().contains('SecurityError')) {
          errorLog('🔒 SECURITY ERROR - Possible causes:');
          errorLog('   - Cross-origin restrictions');
          errorLog('   - Mixed content (HTTP/HTTPS) issues');
          errorLog('   - CSP (Content Security Policy) blocking workers');
        } else if (e.toString().contains('TypeError')) {
          errorLog('🔧 TYPE ERROR - Possible causes:');
          errorLog('   - Worker compilation failed');
          errorLog('   - Missing Squadron dependencies');
          errorLog('   - Dart to JS compilation issues');
        }

        // Web-specific error logging
        SquadronWebDebug.logInitialization(
          success: false,
          duration: totalInitDuration,
          error: e.toString(),
          workerStats: {
            'errorType': e.runtimeType.toString(),
            'platformType': Squadron.platformType.toString(),
            'isSecureContext': _isSecureContext(),
            'baseUrl': Uri.base.toString(),
          },
        );

        // Print debugging instructions on error
        SquadronWebDebug.printDebugInstructions();

        // Additional web debugging
        _performWebDiagnostics();
      }

      rethrow;
    }
  }

  /// Updates configuration at runtime
  static Future<void> configure(WorkerManagerConfig config) async {
    _config = config;

    // If pool is running and settings changed, recreate it
    if (_isInitialized && _workerPool != null) {
      // Squadron pools are immutable - need to recreate with new settings
      if (true) {
        // Always recreate for configuration changes

        if (printLogs) infoLog('🔄 Reconfiguring WorkerPool with new settings');

        // Squadron pools are immutable - just recreate
        if (printLogs) infoLog('🔄 Recreating Squadron pool with new settings');
        _workerPool = null; // Release reference

        // Create new pool with updated settings
        final concurrencySettings = ConcurrencySettings(
          minWorkers: _config.minWorkers,
          maxWorkers: _config.maxWorkers,
          maxParallel: _config.maxParallel,
        );

        _workerPool = SuggestionWorkerPoolWorkerPool(
          concurrencySettings: concurrencySettings,
        );

        // Squadron pools auto-start, no explicit start needed
      }
    }
  }

  /// Executes a task with Squadron support and cancellation
  static Future<T> executeWithCancellation<T>(
    String taskId,
    Future<T> Function() task, {
    String priority = 'regular',
    Duration? timeout,
    ExistingTaskPolicy existingPolicy = ExistingTaskPolicy.cancelExisting,
  }) async {
    if (_isDisposing) {
      throw StateError('WorkerManagerService is disposing');
    }

    if (!_isInitialized || _workerPool == null) {
      throw StateError('WorkerManagerService not initialized');
    }

    // Handle existing task policy
    if (_activeTasks.contains(taskId)) {
      switch (existingPolicy) {
        case ExistingTaskPolicy.cancelExisting:
          if (printLogs) infoLog('Replacing existing task: $taskId');
          _activeTasks.remove(taskId);
          break;
        case ExistingTaskPolicy.skipIfActive:
          throw StateError('Task $taskId is already active');
      }
    }

    if (printLogs)
      infoLog('🚀 Starting Squadron task: $taskId (priority: $priority)');

    if (kIsWeb && printLogs) {
      infoLog('🌐 Task will execute in web worker (JS/WASM)');
      SquadronWebDebug.logTaskExecution(
        taskId: taskId,
        taskType: 'generic',
        started: true,
      );
    }

    // Track active task
    _activeTasks.add(taskId);

    try {
      // Execute task - Squadron handles worker pool execution internally
      final Future<T> taskFuture;

      if (timeout != null) {
        taskFuture = task().timeout(timeout);
      } else {
        taskFuture = task();
      }

      final result = await taskFuture;
      final executionDuration =
          DateTime.now().difference(DateTime.now().subtract(Duration.zero));
      if (printLogs) infoLog('✅ Squadron task $taskId completed successfully');

      if (kIsWeb && printLogs) {
        SquadronWebDebug.logTaskExecution(
          taskId: taskId,
          taskType: 'generic',
          started: false,
          completed: true,
          duration: executionDuration,
        );
      }

      return result;
    } catch (e) {
      final executionDuration =
          DateTime.now().difference(DateTime.now().subtract(Duration.zero));

      if (e is TimeoutException) {
        errorLog('⏰ Squadron task $taskId timed out');
      } else {
        errorLog('❌ Squadron task $taskId failed with error: $e');
        if (kIsWeb) {
          errorLog(
              '🌐 Web worker error - check browser console for additional details');
        }
      }

      if (kIsWeb) {
        SquadronWebDebug.logTaskExecution(
          taskId: taskId,
          taskType: 'generic',
          started: false,
          completed: false,
          duration: executionDuration,
          error: e.toString(),
        );
      }
      rethrow;
    } finally {
      _activeTasks.remove(taskId);
    }
  }

  /// Executes a JSON decoding task using Squadron worker
  static Future<dynamic> executeJsonDecoding(
      String taskId, String jsonString) async {
    if (_isDisposing) {
      throw StateError('WorkerManagerService is disposing');
    }

    if (!_isInitialized || _workerPool == null) {
      throw StateError('WorkerManagerService not initialized');
    }

    final taskStartTime = DateTime.now();

    if (printLogs) infoLog('📋 Starting Squadron JSON decoding task: $taskId');
    if (printLogs)
      infoLog('📊 JSON string length: ${jsonString.length} characters');
    if (printLogs)
      infoLog('🎯 Active tasks before start: ${_activeTasks.length}');

    if (kIsWeb && printLogs) {
      infoLog('🌐 Web worker JSON decode - delegating to Squadron pool');
      infoLog('🔍 Platform type: ${Squadron.platformType}');
      infoLog(
          '📋 Worker pool status: ${_workerPool != null ? 'ready' : 'null'}');

      SquadronWebDebug.logTaskExecution(
        taskId: taskId,
        taskType: 'json_decode',
        started: true,
      );
    }

    // Track active task
    _activeTasks.add(taskId);
    if (printLogs)
      infoLog(
          '📝 Task $taskId added to active tasks (total: ${_activeTasks.length})');

    try {
      if (printLogs)
        infoLog('🚀 Calling Squadron worker pool decodeJson method...');
      final callStartTime = DateTime.now();

      // Use Squadron worker pool for JSON decoding
      final rawResult = await _workerPool!.decodeJson(jsonString);

      // Convert result to properly typed Dart collections for web compatibility
      final result = _convertJsonToDartTypes(rawResult);

      final callDuration = DateTime.now().difference(callStartTime);
      final totalDuration = DateTime.now().difference(taskStartTime);

      if (printLogs)
        infoLog('✅ Squadron JSON decoding task $taskId completed successfully');
      if (printLogs)
        infoLog('⏱️ Worker call duration: ${callDuration.inMilliseconds}ms');
      if (printLogs)
        infoLog('⏱️ Total task duration: ${totalDuration.inMilliseconds}ms');

      if (result != null) {
        infoLog('📦 Result type: ${result.runtimeType}');
        if (result is Map) {
          infoLog(
              '📦 Result keys: ${result.keys.take(5).join(', ')}${result.keys.length > 5 ? '...' : ''}');
        } else if (result is List) {
          infoLog('📦 Result length: ${result.length}');
        }
      } else {
        infoLog('⚠️ Result is null');
      }

      if (kIsWeb && printLogs) {
        SquadronWebDebug.logTaskExecution(
          taskId: taskId,
          taskType: 'json_decode',
          started: false,
          completed: true,
        );
      }

      return result;
    } catch (e, stackTrace) {
      final errorDuration = DateTime.now().difference(taskStartTime);

      errorLog(
          '❌ Squadron JSON decoding task $taskId failed after ${errorDuration.inMilliseconds}ms');
      errorLog('💥 Error type: ${e.runtimeType}');
      errorLog('📝 Error details: $e');

      if (kIsWeb) {
        errorLog('🌐 Web JSON decoding error analysis:');

        // Detailed error analysis for web
        if (e.toString().contains('Worker script failed to load')) {
          errorLog('🚫 Worker script load failure - possible causes:');
          errorLog('   - Worker file missing from web/workers/');
          errorLog('   - CORS blocking worker loading');
          errorLog('   - Network error fetching worker');
        } else if (e.toString().contains('SecurityError')) {
          errorLog('🔒 Security error - possible causes:');
          errorLog('   - Cross-origin worker loading blocked');
          errorLog('   - CSP policy preventing worker execution');
        } else if (e.toString().contains('TypeError')) {
          errorLog('🔧 Type error - possible causes:');
          errorLog('   - Worker compilation failed');
          errorLog('   - Invalid worker message format');
        } else if (e.toString().contains('TimeoutError')) {
          errorLog('⏰ Timeout error - possible causes:');
          errorLog('   - JSON too large for worker to process');
          errorLog('   - Worker hung or crashed');
        } else {
          errorLog('❓ Unknown error type - check browser console');
        }

        errorLog('🔍 Debug checklist:');
        errorLog('   1. Check browser console for additional errors');
        errorLog('   2. Verify worker files exist and are loading');
        errorLog('   3. Check Network tab for failed requests');
        errorLog('   4. Test with smaller JSON payload');

        SquadronWebDebug.logTaskExecution(
          taskId: taskId,
          taskType: 'json_decode',
          started: false,
          completed: false,
          duration: errorDuration,
          error: e.toString(),
        );
      }

      // Log stack trace for debugging
      errorLog(
          '🔍 Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');

      rethrow;
    } finally {
      _activeTasks.remove(taskId);
      if (printLogs)
        infoLog(
            '📝 Task $taskId removed from active tasks (remaining: ${_activeTasks.length})');
    }
  }

  /// Executes data processing task using Squadron worker
  static Future<Map<String, dynamic>> processLargeDataSet(
    String taskId,
    List<Map<String, dynamic>> data,
    String operation,
  ) async {
    if (_isDisposing) {
      throw StateError('WorkerManagerService is disposing');
    }

    if (!_isInitialized || _workerPool == null) {
      throw StateError('WorkerManagerService not initialized');
    }

    infoLog(
        '🚀 Starting Squadron data processing task: $taskId (operation: $operation)');
    infoLog('📊 Data set size: ${data.length} items');

    // Track active task
    _activeTasks.add(taskId);

    try {
      // Use Squadron worker pool for data processing
      final result = await _workerPool!.processLargeDataSet(data, operation);

      infoLog('✅ Squadron data processing task $taskId completed successfully');
      return result;
    } catch (e) {
      errorLog('❌ Squadron data processing task $taskId failed with error: $e');
      if (kIsWeb) {
        errorLog('🌐 Web data processing error - verify worker capability');
      }
      rethrow;
    } finally {
      _activeTasks.remove(taskId);
    }
  }

  /// Executes heavy computation using Squadron worker
  static Future<Map<String, dynamic>> performHeavyComputation(
    String taskId,
    Map<String, dynamic> params,
  ) async {
    if (_isDisposing) {
      throw StateError('WorkerManagerService is disposing');
    }

    if (!_isInitialized || _workerPool == null) {
      throw StateError('WorkerManagerService not initialized');
    }

    infoLog('💻 Starting Squadron heavy computation task: $taskId');
    infoLog('📊 Computation params: ${params.keys.join(', ')}');

    // Track active task
    _activeTasks.add(taskId);

    try {
      // Use Squadron worker pool for heavy computation
      final result = await _workerPool!.performHeavyComputation(params);

      infoLog(
          '✅ Squadron heavy computation task $taskId completed successfully');
      return result;
    } catch (e) {
      errorLog(
          '❌ Squadron heavy computation task $taskId failed with error: $e');
      if (kIsWeb) {
        errorLog('🌐 Web heavy computation error - check worker performance');
      }
      rethrow;
    } finally {
      _activeTasks.remove(taskId);
    }
  }

  /// Streams progress updates using Squadron worker
  static Stream<Map<String, dynamic>> processWithProgress(
    String taskId,
    Map<String, dynamic> params,
  ) {
    if (_isDisposing) {
      throw StateError('WorkerManagerService is disposing');
    }

    if (!_isInitialized || _workerPool == null) {
      throw StateError('WorkerManagerService not initialized');
    }

    infoLog('📡 Starting Squadron progress streaming task: $taskId');
    infoLog('📊 Streaming params: ${params.keys.join(', ')}');

    // Track active task
    _activeTasks.add(taskId);

    late StreamController<Map<String, dynamic>> controller;

    controller = StreamController<Map<String, dynamic>>(
      onCancel: () {
        _activeTasks.remove(taskId);
      },
    );

    // Start the streaming task using Squadron worker pool
    _workerPool!.processWithProgress(params).listen(
      controller.add,
      onError: (e) {
        errorLog(
            '❌ Squadron progress streaming task $taskId failed with error: $e');
        if (kIsWeb) {
          errorLog('🌐 Web streaming error - check worker stream capability');
        }
        controller.addError(e);
      },
      onDone: () {
        infoLog(
            '✅ Squadron progress streaming task $taskId completed successfully');
        _activeTasks.remove(taskId);
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Processes SQL suggestion items using Squadron worker
  static Future<List<Map<String, dynamic>>> processSqlSuggestionItems(
    String taskId,
    List<Map<String, dynamic>> queryTables,
    String datasourceType,
  ) async {
    if (_isDisposing) {
      throw StateError('WorkerManagerService is disposing');
    }

    if (!_isInitialized || _workerPool == null) {
      throw StateError('WorkerManagerService not initialized');
    }

    final taskStartTime = DateTime.now();
    final totalColumns = queryTables
        .expand((table) => table['queryColumnList'] as List? ?? [])
        .length;

    if (printLogs)
      infoLog('📋 Starting Squadron SQL suggestion processing task: $taskId');
    if (printLogs)
      infoLog(
          '📊 Processing ${queryTables.length} tables with $totalColumns total columns');
    if (printLogs)
      infoLog('🎯 Active tasks before start: ${_activeTasks.length}');

    if (kIsWeb && printLogs) {
      infoLog('🌐 Web worker SQL processing - delegating to Squadron pool');
      infoLog('🔍 Platform type: ${Squadron.platformType}');
      infoLog(
          '📋 Worker pool status: ${_workerPool != null ? 'ready' : 'null'}');

      SquadronWebDebug.logTaskExecution(
        taskId: taskId,
        taskType: 'sql_suggestion_processing',
        started: true,
      );
    }

    // Track active task
    _activeTasks.add(taskId);
    if (printLogs)
      infoLog(
          '📝 Task $taskId added to active tasks (total: ${_activeTasks.length})');

    try {
      if (printLogs)
        infoLog(
            '🚀 Calling Squadron worker pool processSqlSuggestionItems method...');
      final callStartTime = DateTime.now();

      // Use Squadron worker pool for SQL suggestion processing
      final result = await _workerPool!
          .processSqlSuggestionItems(queryTables, datasourceType);

      final callDuration = DateTime.now().difference(callStartTime);
      final totalDuration = DateTime.now().difference(taskStartTime);

      if (printLogs)
        infoLog(
            '✅ Squadron SQL suggestion processing task $taskId completed successfully');
      if (printLogs)
        infoLog('⏱️ Worker call duration: ${callDuration.inMilliseconds}ms');
      if (printLogs)
        infoLog('⏱️ Total task duration: ${totalDuration.inMilliseconds}ms');

      if (result.isNotEmpty) {
        infoLog('📦 Processed ${result.length} suggestion items');
      } else {
        infoLog('⚠️ No suggestion items returned');
      }

      if (kIsWeb && printLogs) {
        SquadronWebDebug.logTaskExecution(
          taskId: taskId,
          taskType: 'sql_suggestion_processing',
          started: false,
          completed: true,
          duration: totalDuration,
        );
      }

      // Convert worker result to proper Dart types (handles web JsLinkedHashMap issues)
      final convertedResult = _convertJsonToDartTypes(result);

      if (convertedResult is List) {
        // Convert each item to Map<String, dynamic> and filter out invalid items
        final properResult = convertedResult
            .map((item) {
              final convertedItem = _convertJsonToDartTypes(item);
              return convertedItem is Map<String, dynamic>
                  ? convertedItem
                  : null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        if (printLogs) {
          infoLog('🎯 SQL suggestion conversion results:');
          infoLog('   - Original suggestions: ${result.length}');
          infoLog('   - Converted suggestions: ${properResult.length}');

          if (properResult.length != result.length) {
            infoLog(
                '   ⚠️ Some suggestions were filtered out during conversion');
          }

          // Log first few suggestions for debugging
          if (properResult.isNotEmpty && printLogs) {
            final firstSuggestion = properResult.first;
            infoLog(
                '   - Sample suggestion keys: ${firstSuggestion.keys.take(3).join(', ')}');
          }
        }

        return properResult;
      } else {
        errorLog(
            '❌ Worker returned invalid result type: ${convertedResult.runtimeType}');
        errorLog('   - Expected: List<Map<String, dynamic>>');
        errorLog('   - Received: ${convertedResult.runtimeType}');
        errorLog('   - Original result type: ${result.runtimeType}');
        throw StateError(
            'Worker returned invalid result type: expected List, got ${convertedResult.runtimeType}');
      }
    } catch (e, stackTrace) {
      final errorDuration = DateTime.now().difference(taskStartTime);

      errorLog(
          '❌ Squadron SQL suggestion processing task $taskId failed after ${errorDuration.inMilliseconds}ms');
      errorLog('💥 Error type: ${e.runtimeType}');
      errorLog('📝 Error details: $e');

      if (kIsWeb) {
        errorLog('🌐 Web SQL suggestion processing error analysis:');

        // Detailed error analysis for web
        if (e.toString().contains('Worker script failed to load')) {
          errorLog('🚫 Worker script load failure - possible causes:');
          errorLog('   - Worker file missing from web/workers/');
          errorLog('   - CORS blocking worker loading');
          errorLog('   - Network error fetching worker');
        } else if (e.toString().contains('SecurityError')) {
          errorLog('🔒 Security error - possible causes:');
          errorLog('   - Cross-origin worker loading blocked');
          errorLog('   - CSP policy preventing worker execution');
        } else if (e.toString().contains('TypeError')) {
          errorLog('🔧 Type error - possible causes:');
          errorLog('   - Worker compilation failed');
          errorLog('   - Invalid worker message format');
        } else if (e.toString().contains('TimeoutError')) {
          errorLog('⏰ Timeout error - possible causes:');
          errorLog('   - Too many tables/columns for worker to process');
          errorLog('   - Worker hung or crashed');
        } else {
          errorLog('❓ Unknown error type - check browser console');
        }

        errorLog('🔍 Debug checklist:');
        errorLog('   1. Check browser console for additional errors');
        errorLog('   2. Verify worker files exist and are loading');
        errorLog('   3. Check Network tab for failed requests');
        errorLog('   4. Test with smaller dataset');

        SquadronWebDebug.logTaskExecution(
          taskId: taskId,
          taskType: 'sql_suggestion_processing',
          started: false,
          completed: false,
          duration: errorDuration,
          error: e.toString(),
        );
      }

      // Log stack trace for debugging
      errorLog(
          '🔍 Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');

      rethrow;
    } finally {
      _activeTasks.remove(taskId);
      if (printLogs)
        infoLog(
            '📝 Task $taskId removed from active tasks (remaining: ${_activeTasks.length})');
    }
  }

  /// Processes a chunk of tables using Squadron web workers for background processing
  /// This optimizes performance by moving heavy CPU work to background isolates
  static Future<Map<String, dynamic>> processTableChunk(
    String taskId,
    List<Map<String, dynamic>> chunkData,
    String datasourceType,
    int chunkIndex,
  ) async {
    if (_isDisposing) {
      throw StateError('WorkerManagerService is disposing');
    }

    if (!_isInitialized || _workerPool == null) {
      throw StateError('WorkerManagerService not initialized');
    }

    final taskStartTime = DateTime.now();
    final totalColumns =
        chunkData.expand((table) => table['columns'] as List? ?? []).length;

    if (printLogs)
      infoLog('📋 Starting Squadron table chunk processing task: $taskId');
    if (printLogs)
      infoLog(
          '📊 Processing chunk $chunkIndex with ${chunkData.length} tables and $totalColumns total columns');
    if (printLogs)
      infoLog('🎯 Active tasks before start: ${_activeTasks.length}');

    if (kIsWeb && printLogs) {
      infoLog(
          '🌐 Web worker table chunk processing - delegating to Squadron pool');
      infoLog('🔍 Platform type: ${Squadron.platformType}');
      infoLog(
          '📋 Worker pool status: ${_workerPool != null ? 'ready' : 'null'}');

      SquadronWebDebug.logTaskExecution(
        taskId: taskId,
        taskType: 'table_chunk_processing',
        started: true,
      );
    }

    // Track active task
    _activeTasks.add(taskId);
    if (printLogs)
      infoLog(
          '📝 Task $taskId added to active tasks (total: ${_activeTasks.length})');

    try {
      if (printLogs)
        infoLog('🚀 Calling Squadron worker pool processTableChunk method...');
      final callStartTime = DateTime.now();

      // Use Squadron worker pool for table chunk processing
      final result = await _workerPool!
          .processTableChunk(chunkData, datasourceType, chunkIndex, taskId);

      final callDuration = DateTime.now().difference(callStartTime);
      final totalDuration = DateTime.now().difference(taskStartTime);

      if (printLogs)
        infoLog(
            '✅ Squadron table chunk processing task $taskId completed successfully');
      if (printLogs)
        infoLog('⏱️ Worker call duration: ${callDuration.inMilliseconds}ms');
      if (printLogs)
        infoLog('⏱️ Total task duration: ${totalDuration.inMilliseconds}ms');

      if (kIsWeb && printLogs) {
        SquadronWebDebug.logTaskExecution(
          taskId: taskId,
          taskType: 'table_chunk_processing',
          started: false,
          completed: true,
          duration: totalDuration,
        );
      }

      // Convert worker result to proper Dart types (handles web JsLinkedHashMap issues)
      final convertedResult = _convertJsonToDartTypes(result);

      if (convertedResult is Map<String, dynamic>) {
        final processedTables =
            convertedResult['processedTables'] as List<dynamic>? ?? [];
        final tablesProcessed = convertedResult['tablesProcessed'] as int? ?? 0;
        final columnsProcessed =
            convertedResult['columnsProcessed'] as int? ?? 0;

        if (printLogs) {
          infoLog('📊 Worker processing results:');
          infoLog('   - Tables processed: $tablesProcessed');
          infoLog('   - Columns processed: $columnsProcessed');
          infoLog('   - Output tables count: ${processedTables.length}');
        }

        // Convert processed tables to proper Dart types
        final properProcessedTables = processedTables.map((table) {
          final convertedTable = _convertJsonToDartTypes(table);
          return convertedTable is Map<String, dynamic>
              ? convertedTable
              : <String, dynamic>{};
        }).toList();

        final finalResult = Map<String, dynamic>.from(convertedResult);
        finalResult['processedTables'] = properProcessedTables;

        if (printLogs) {
          infoLog('🎯 Final conversion results:');
          infoLog('   - Original processed tables: ${processedTables.length}');
          infoLog(
              '   - Final processed tables: ${properProcessedTables.length}');
        }

        return finalResult;
      } else {
        errorLog(
            '❌ Worker returned invalid result type: ${convertedResult.runtimeType}');
        throw StateError('Worker returned invalid result type');
      }
    } catch (e, stackTrace) {
      final errorDuration = DateTime.now().difference(taskStartTime);

      if (printLogs) {
        errorLog(
            '❌ Squadron table chunk processing task $taskId failed after ${errorDuration.inMilliseconds}ms');
        errorLog('💥 Task details:');
        errorLog('   - Task ID: $taskId');
        errorLog('   - Chunk index: $chunkIndex');
        errorLog('   - Tables in chunk: ${chunkData.length}');
        errorLog('   - Total columns: $totalColumns');
        errorLog('   - Datasource type: $datasourceType');
        errorLog('   - Error type: ${e.runtimeType}');
        errorLog('   - Error message: $e');
      }

      if (kIsWeb && printLogs) {
        errorLog('🌐 Web worker specific diagnostics:');
        errorLog('   - Platform: ${Squadron.platformType}');
        errorLog(
            '   - Pool status: ${_workerPool != null ? 'initialized' : 'null'}');
        errorLog('   - Active tasks: ${_activeTasks.length}');

        if (e.toString().contains('TypeError')) {
          errorLog('🔧 Type error - possible causes:');
          errorLog('   - Worker compilation failed');
          errorLog('   - Invalid worker message format');
          errorLog('   - Type conversion issues with table data');
        } else if (e.toString().contains('TimeoutError')) {
          errorLog('⏰ Timeout error - possible causes:');
          errorLog('   - Too many columns in chunk for worker to process');
          errorLog('   - Worker hung or crashed');
        } else {
          errorLog('❓ Unknown error type - check browser console');
        }

        errorLog('🔍 Debug checklist:');
        errorLog('   1. Check browser console for additional errors');
        errorLog('   2. Verify worker files exist and are loading');
        errorLog('   3. Check Network tab for failed requests');
        errorLog('   4. Test with smaller chunk size');

        SquadronWebDebug.logTaskExecution(
          taskId: taskId,
          taskType: 'table_chunk_processing',
          started: false,
          completed: false,
          duration: errorDuration,
          error: e.toString(),
        );
      }

      // Log stack trace for debugging
      errorLog(
          '🔍 Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');

      rethrow;
    } finally {
      _activeTasks.remove(taskId);
      if (printLogs)
        infoLog(
            '📝 Task $taskId removed from active tasks (remaining: ${_activeTasks.length})');
    }
  }

  /// Cancels a specific task by its ID
  static Future<bool> cancelTask(String taskId) async {
    if (_activeTasks.contains(taskId)) {
      _activeTasks.remove(taskId);
      if (printLogs) infoLog('Cancelled task: $taskId');
      return true;
    }
    return false;
  }

  /// Cancels all active tasks
  static Future<int> cancelAllTasks() async {
    final taskIds = _activeTasks.toList();
    int cancelledCount = 0;

    for (final taskId in taskIds) {
      if (await cancelTask(taskId)) {
        cancelledCount++;
      }
    }

    if (printLogs)
      infoLog('Cancelled $cancelledCount out of ${taskIds.length} tasks');
    return cancelledCount;
  }

  /// Cancels tasks that match a specific pattern
  static Future<int> cancelTasksWithPattern(String pattern) async {
    if (pattern.isEmpty) {
      if (printLogs) infoLog('Empty pattern provided, no tasks cancelled');
      return 0;
    }

    try {
      final regex = RegExp(pattern);
      final matchingTaskIds =
          _activeTasks.where((id) => regex.hasMatch(id)).toList();

      int cancelledCount = 0;
      for (final taskId in matchingTaskIds) {
        if (await cancelTask(taskId)) {
          cancelledCount++;
        }
      }

      if (printLogs)
        infoLog('Cancelled $cancelledCount tasks matching pattern: $pattern');
      return cancelledCount;
    } catch (e) {
      errorLog('Error cancelling tasks with pattern "$pattern": $e');
      return 0;
    }
  }

  /// Gets the list of active task IDs
  static List<String> getActiveTaskIds() {
    return _activeTasks.toList();
  }

  /// Gets the number of active tasks
  static int getActiveTaskCount() {
    return _activeTasks.length;
  }

  /// Checks if a specific task is active
  static bool isTaskActive(String taskId) {
    return _activeTasks.contains(taskId);
  }

  /// Get comprehensive debug information about the service
  static Map<String, dynamic> getDebugInfo() {
    final now = DateTime.now();
    final workerStats =
        <Map<String, dynamic>>[] /* _workerPool?.stats.toList() ?? [] */;

    return {
      'serviceStatus': _isDisposing
          ? 'disposing'
          : (_isInitialized ? 'healthy' : 'not_initialized'),
      'isInitialized': _isInitialized,
      'activeTasksCount': _activeTasks.length,
      'activeTasks': _activeTasks.toList(),
      'workerPoolStats': {
        'activeWorkers': workerStats.length,
        'totalWorkers': 0 /* _workerPool?.fullStats.length ?? 0 */,
        'concurrencySettings': {
          'minWorkers': _config.minWorkers,
          'maxWorkers': _config.maxWorkers,
          'maxParallel': _config.maxParallel,
        },
      },
      'config': _config.toJson(),
      'timestamp': now.toIso8601String(),
    };
  }

  /// Get a health check summary of the service
  static Map<String, dynamic> getHealthCheck() {
    final now = DateTime.now();
    final serviceStart = _serviceStartTime ?? now;

    return {
      'status': _isDisposing
          ? 'disposing'
          : (_isInitialized ? 'healthy' : 'not_initialized'),
      'activeTasks': _activeTasks.length,
      'workerPool': {
        'isInitialized': _workerPool != null,
        'activeWorkers': 0 /* _workerPool?.stats.length ?? 0 */,
      },
      'uptimeSeconds': now.difference(serviceStart).inSeconds,
      'timestamp': now.toIso8601String(),
    };
  }

  /// Cancels tasks that have been running longer than the specified duration
  static Future<int> cancelTasksOlderThan(Duration maxAge) async {
    // Note: Squadron doesn't provide task start times by default
    // This would require additional tracking if needed
    infoLog(
        'cancelTasksOlderThan not implemented - Squadron manages task lifecycles internally');
    return 0;
  }

  /// Disposes all resources
  static Future<void> dispose() async {
    if (_isDisposing) {
      if (printLogs) infoLog('WorkerManagerService is already disposing');
      return;
    }

    if (printLogs) infoLog('Disposing WorkerManagerService...');
    _isDisposing = true;

    try {
      // Cancel all active tasks
      final cancelledCount = await cancelAllTasks();

      // Dispose worker pool (Squadron pools handle cleanup automatically)
      if (_workerPool != null) {
        _workerPool = null; // Release reference
        if (printLogs) infoLog('🧿 Squadron pool reference released');
      }

      _isInitialized = false;
      if (printLogs)
        infoLog(
            'WorkerManagerService disposed successfully (cancelled $cancelledCount tasks)');
    } catch (e) {
      errorLog('Error during WorkerManagerService disposal: $e');
    } finally {
      _isDisposing = false;
    }
  }

  /// Get debug information about Squadron activator
  static String _getActivatorDebugInfo() {
    try {
      return 'SuggestionWorkerPoolActivator configured for ${Squadron.platformType}';
    } catch (e) {
      return 'Failed to get activator info: $e';
    }
  }

  /// Get security context debug information
  static String _getSecurityDebugInfo() {
    try {
      return 'Secure context: ${_isSecureContext()}, Origin: ${Uri.base.origin}';
    } catch (e) {
      return 'Failed to get security info: $e';
    }
  }

  /// Get memory debug information
  static String _getMemoryDebugInfo() {
    try {
      // Basic memory info - in web this is limited
      return 'Available (estimated based on platform)';
    } catch (e) {
      return 'Memory info unavailable: $e';
    }
  }

  /// Check if running in secure context
  static bool _isSecureContext() {
    try {
      // In web, we can check if we're running over HTTPS
      return Uri.base.scheme == 'https' || Uri.base.host == 'localhost';
    } catch (e) {
      return false;
    }
  }

  /// Perform comprehensive web diagnostics
  static void _performWebDiagnostics() {
    if (!kIsWeb) return;

    infoLog('🔍 Running comprehensive web diagnostics...');

    try {
      infoLog('📍 Current location: ${Uri.base}');
      infoLog('🔒 Secure context: ${_isSecureContext()}');
      infoLog('🎯 Platform type: ${Squadron.platformType}');

      // Test basic worker requirements
      _testWorkerRequirements();
    } catch (e) {
      errorLog('❌ Web diagnostics failed: $e');
    }
  }

  /// Test basic worker requirements
  static void _testWorkerRequirements() {
    infoLog('🧪 Testing Squadron worker requirements...');

    // Test 1: Check platform compatibility
    try {
      final platformType = Squadron.platformType;
      infoLog('✅ Platform type detection: $platformType');
    } catch (e) {
      errorLog('❌ Platform type detection failed: $e');
    }

    // Test 2: Check base URL context
    try {
      final baseUrl = Uri.base;
      infoLog('✅ Base URL available: $baseUrl');
      if (baseUrl.scheme == 'file') {
        errorLog('⚠️ Running from file:// - workers may not load correctly');
      }
    } catch (e) {
      errorLog('❌ Base URL check failed: $e');
    }

    // Test 3: Check if we can create a simple Worker-like object
    infoLog('🏁 Worker requirements test completed');
  }

  /// Manually run comprehensive Squadron diagnostics (can be called from DevTools console)
  static Future<void> runDiagnostics() async {
    if (!kIsWeb) {
      infoLog('❌ Squadron diagnostics only available on web platform');
      return;
    }

    infoLog('🔍 Starting manual Squadron diagnostics...');

    try {
      // Browser compatibility check
      await _checkBrowserCompatibility();

      // Squadron web diagnostics
      await SquadronWebDebug.runQuickDiagnostics();

      // Worker initialization test
      await _runWorkerInitializationTest();

      infoLog('✅ Manual Squadron diagnostics completed');
    } catch (e) {
      errorLog('❌ Manual Squadron diagnostics failed: $e');
    }
  }

  /// Test worker functionality manually (can be called from DevTools console)
  static Future<bool> testWorkers() async {
    if (!kIsWeb) {
      infoLog('❌ Worker tests only available on web platform');
      return false;
    }

    return await testWorkerFunctionality();
  }

  /// Check browser compatibility manually (can be called from DevTools console)
  static Future<void> checkCompatibility() async {
    if (!kIsWeb) {
      infoLog('❌ Compatibility check only available on web platform');
      return;
    }

    await _checkBrowserCompatibility();
  }

  /// Get Squadron service debug information
  static Map<String, dynamic> getSquadronDebugInfo() {
    final debugInfo = getDebugInfo();
    final buildMode = kDebugMode
        ? 'DEBUG'
        : kProfileMode
            ? 'PROFILE'
            : 'RELEASE';

    return {
      ...debugInfo,
      'buildMode': buildMode,
      'squadronPlatform': kIsWeb ? Squadron.platformType.toString() : 'VM',
      'lastDiagnosticRun': DateTime.now().toIso8601String(),
    };
  }

  /// Test worker functionality with a simple operation
  static Future<bool> testWorkerFunctionality() async {
    if (!_isInitialized || _workerPool == null) {
      errorLog('❌ Cannot test - WorkerManagerService not initialized');
      return false;
    }

    infoLog('🧪 Testing Squadron worker functionality...');

    try {
      // Test with a simple JSON decode operation
      const testJson = '{"test": true, "value": 42}';
      final result =
          await executeJsonDecoding('test_worker_functionality', testJson);

      if (result != null && result['test'] == true && result['value'] == 42) {
        infoLog('✅ Squadron worker functionality test PASSED');
        return true;
      } else {
        errorLog(
            '❌ Squadron worker functionality test FAILED - unexpected result: $result');
        return false;
      }
    } catch (e) {
      errorLog('❌ Squadron worker functionality test FAILED with error: $e');
      return false;
    }
  }

  /// Check browser compatibility for Squadron workers
  static Future<void> _checkBrowserCompatibility() async {
    if (!kIsWeb) return;

    infoLog('🔍 Checking browser compatibility for Squadron workers...');

    try {
      final result = await BrowserCompatibility.checkCompatibility();

      if (result.isCompatible) {
        infoLog('✅ Browser is compatible with Squadron workers');
      } else {
        errorLog('❌ Browser compatibility issues detected:');
        for (final issue in result.issues) {
          errorLog('   - $issue');
        }
      }

      if (result.warnings.isNotEmpty) {
        for (final warning in result.warnings) {
          errorLog('⚠️ Warning: $warning');
        }
      }

      if (result.recommendations.isNotEmpty) {
        infoLog('💡 Recommendations:');
        for (final rec in result.recommendations) {
          infoLog('   - $rec');
        }
      }

      // Log the results to browser console for debugging
      BrowserCompatibility.logResults(result);

      // Store compatibility info for later reference
      final featureSupport = BrowserCompatibility.getFeatureSupport();
      infoLog('🎯 Feature support summary: $featureSupport');
    } catch (e) {
      errorLog('❌ Browser compatibility check failed: $e');
    }
  }

  /// Run comprehensive worker initialization test
  static Future<void> _runWorkerInitializationTest() async {
    if (!kIsWeb) return;

    infoLog('🧪 Starting comprehensive worker initialization test...');
    final testStartTime = DateTime.now();

    try {
      // Test 1: Basic worker pool health
      infoLog('📋 Test 1: Worker pool health check');
      if (_workerPool == null) {
        errorLog('❌ Worker pool is null - initialization failed');
        return;
      }
      infoLog('✅ Worker pool instance exists');

      // Test 2: Platform detection
      infoLog('📋 Test 2: Platform detection');
      try {
        final platformType = Squadron.platformType;
        infoLog('✅ Platform type: $platformType');

        if (platformType.isJs) {
          infoLog('🌐 JavaScript workers will be used');
        } else if (platformType.isWasm) {
          infoLog('🚀 WebAssembly workers will be used');
        } else {
          errorLog('⚠️ Unknown platform type - this may cause issues');
        }
      } catch (e) {
        errorLog('❌ Platform detection failed: $e');
      }

      // Test 3: Simple worker method call
      infoLog('📋 Test 3: Simple worker method execution');
      try {
        await Future.delayed(const Duration(
            milliseconds: 100)); // Give workers time to initialize

        const testJson =
            '{"initialization_test": true, "timestamp": "2024-01-01T00:00:00Z"}';
        final result =
            await executeJsonDecoding('initialization_test', testJson);

        if (result != null && result['initialization_test'] == true) {
          final testDuration = DateTime.now().difference(testStartTime);
          infoLog(
              '✅ Worker initialization test PASSED in ${testDuration.inMilliseconds}ms');
          infoLog('🎉 Squadron workers are ready and operational!');

          if (kIsWeb) {
            SquadronWebDebug.logBrowserEnvironment();
          }
        } else {
          errorLog('❌ Worker test failed - unexpected result: $result');
        }
      } catch (e) {
        errorLog('❌ Worker method execution failed: $e');
        errorLog(
            '🔍 This indicates workers are not loading/executing properly');

        // Additional debugging for worker loading issues
        if (e.toString().contains('Failed to load worker')) {
          errorLog('🚫 Worker Loading Issue Detected:');
          errorLog('   - Check if worker files exist in web/workers/');
          errorLog('   - Verify CORS headers allow worker loading');
          errorLog('   - Check Network tab in browser DevTools');
        }
      }

      // Test 4: Worker pool statistics (if available)
      infoLog('📋 Test 4: Worker pool statistics');
      try {
        final debugInfo = getDebugInfo();
        infoLog('📊 Active tasks: ${debugInfo['activeTasksCount']}');
        infoLog('📊 Service status: ${debugInfo['serviceStatus']}');
        infoLog(
            '📊 Pool initialized: ${debugInfo['workerPoolStats']['concurrencySettings']}');
      } catch (e) {
        errorLog('⚠️ Could not get worker pool stats: $e');
      }
    } catch (e) {
      errorLog('❌ Worker initialization test failed with error: $e');
    } finally {
      final totalTestDuration = DateTime.now().difference(testStartTime);
      infoLog(
          '🏁 Worker initialization test completed in ${totalTestDuration.inMilliseconds}ms');
    }
  }
}

/// Policy for handling an existing active task with the same [taskId]
enum ExistingTaskPolicy {
  /// Cancel the existing task and start a new one
  cancelExisting,

  /// Skip starting a new task if one is already active
  skipIfActive,
}

/// Runtime configuration for [WorkerPoolManager]
class WorkerManagerConfig {
  const WorkerManagerConfig({
    this.minWorkers = 2, // Keep 2 workers ready for instant response
    this.maxWorkers = 8, // Scale up to 8 workers under load
    this.maxParallel = 4, // Each worker handles 4 concurrent tasks
  });

  /// Minimum number of workers in the pool
  final int minWorkers;

  /// Maximum number of workers in the pool (0 = unlimited)
  final int maxWorkers;

  /// Maximum number of parallel tasks per worker
  final int maxParallel;

  Map<String, dynamic> toJson() {
    return {
      'minWorkers': minWorkers,
      'maxWorkers': maxWorkers,
      'maxParallel': maxParallel,
    };
  }
}
