/// Application configuration constants for Squadron workers
library;

/// Global flag to control logging output
///
/// Exported from logger.dart for convenience.
/// Set to false in production to disable all logging.
export 'package:flutter_code_editor/src/code_field/code_controller/helpers/suggestions/utils/logger.dart'
    show printLogs;

/// Configuration for Squadron worker pool
class SquadronConfig {
  const SquadronConfig._();

  /// Minimum number of workers in the pool
  static const int minWorkers = 2;

  /// Maximum number of workers in the pool
  static const int maxWorkers = 8;

  /// Maximum number of parallel tasks per worker
  static const int maxParallel = 4;

  /// Worker timeout in milliseconds
  static const int workerTimeoutMs = 30000; // 30 seconds

  /// Maximum JSON size for worker processing (in characters)
  static const int maxJsonSize = 1000000; // 1MB worth of characters
}
