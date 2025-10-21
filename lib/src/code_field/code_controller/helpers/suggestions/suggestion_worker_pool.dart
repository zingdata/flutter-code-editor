import 'dart:async';
import 'dart:convert';

import 'package:flutter_code_editor/src/code_field/code_controller/helpers/suggestions/suggestion_worker_pool.activator.g.dart';
import 'package:squadron/squadron.dart' as sq;

part 'suggestion_worker_pool.worker.g.dart';

const bool showLogs = false;

@sq.SquadronService(
  baseUrl: '~/workers',
  targetPlatform: sq.TargetPlatform.vm | sq.TargetPlatform.js,
)
base class SuggestionWorkerPool {
  @sq.SquadronMethod()
  FutureOr<dynamic> decodeJson(String jsonString) {
    final methodStart = DateTime.now();

    try {
      final rawResult = jsonDecode(jsonString);
      final result = _convertJsonToDartTypes(rawResult);
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(methodStart);

      if (showLogs) {
        print(
            '❌ [WEB WORKER] decodeJson: Failed after ${duration.inMilliseconds}ms');
        print('💥 [WEB WORKER] Error type: ${e.runtimeType}');
        print('📝 [WEB WORKER] Error details: $e');
        print(
            '📊 [WEB WORKER] Input size when failed: ${jsonString.length} chars');

        if (e is FormatException) {
          print('💡 [WEB WORKER] JSON Format Error - check JSON syntax');
        } else if (e.toString().contains('memory')) {
          print('💡 [WEB WORKER] Memory Error - JSON too large for worker');
        }
      }

      throw sq.SquadronException.from(
          'JSON decoding failed: $e', StackTrace.current);
    }
  }

  @sq.SquadronMethod()
  FutureOr<String> encodeJson(dynamic data) {
    final methodStart = DateTime.now();

    try {
      final result = jsonEncode(data);
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(methodStart);

      if (showLogs) {
        print(
            '❌ [WEB WORKER] encodeJson: Failed after ${duration.inMilliseconds}ms - $e');
      }

      throw sq.SquadronException.from(
          'JSON encoding failed: $e', StackTrace.current);
    }
  }

  @sq.SquadronMethod()
  FutureOr<Map<String, dynamic>> processLargeDataSet(
    List<Map<String, dynamic>> data,
    String operation,
  ) {
    final stopwatch = Stopwatch()..start();

    try {
      switch (operation) {
        case 'count':
          final result = {
            'result': data.length,
            'processingTimeMs': stopwatch.elapsedMilliseconds,
          };

          return result;

        case 'sum':
          double sum = 0;
          for (final item in data) {
            final value = item['value'];
            if (value is num) {
              sum += value.toDouble();
            }
          }
          final result = {
            'result': sum,
            'processingTimeMs': stopwatch.elapsedMilliseconds,
          };

          return result;

        case 'group_by':
          final groups = <String, List<Map<String, dynamic>>>{};
          for (final item in data) {
            final key = item['group_key']?.toString() ?? 'unknown';
            groups.putIfAbsent(key, () => []).add(item);
          }
          final result = {
            'result': groups,
            'processingTimeMs': stopwatch.elapsedMilliseconds,
          };

          return result;

        default:
          throw sq.SquadronException.from(
              'Unknown operation: $operation', StackTrace.current);
      }
    } catch (e) {
      if (showLogs) {
        print(
            '❌ [WEB WORKER] processLargeDataSet: Failed after ${stopwatch.elapsedMilliseconds}ms - $e');
      }
      throw sq.SquadronException.from(
          'Data processing failed: $e', StackTrace.current);
    }
  }

  @sq.SquadronMethod()
  FutureOr<Map<String, dynamic>> performHeavyComputation(
    Map<String, dynamic> params,
  ) async {
    final iterations = params['iterations'] as int? ?? 1000000;
    final stepSize = params['stepSize'] as int? ?? 10000;

    final stopwatch = Stopwatch()..start();
    double result = 0;

    for (int i = 0; i < iterations; i++) {
      result += (i * 0.001);

      if (i % stepSize == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    final response = {
      'result': result,
      'iterations': iterations,
      'processingTimeMs': stopwatch.elapsedMilliseconds,
    };

    return response;
  }

  @sq.SquadronMethod()
  Stream<Map<String, dynamic>> processWithProgress(
    Map<String, dynamic> params,
  ) async* {
    final totalSteps = params['totalSteps'] as int? ?? 100;
    final delayMs = params['delayMs'] as int? ?? 50;

    for (int i = 0; i <= totalSteps; i++) {
      await Future.delayed(Duration(milliseconds: delayMs));

      final progressData = {
        'step': i,
        'totalSteps': totalSteps,
        'progress': i / totalSteps,
        'message': 'Processing step $i of $totalSteps',
      };

      yield progressData;
    }
  }

  @sq.SquadronMethod()
  FutureOr<Map<String, dynamic>> validateData(
    List<Map<String, dynamic>> data,
    Map<String, String> schema,
  ) {
    final validItems = <Map<String, dynamic>>[];
    final errors = <Map<String, dynamic>>[];

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final itemErrors = <String>[];

      for (final entry in schema.entries) {
        final fieldName = entry.key;
        final fieldType = entry.value;
        final value = item[fieldName];

        if (value == null) {
          itemErrors.add('Missing required field: $fieldName');
          continue;
        }

        switch (fieldType) {
          case 'string':
            if (value is! String) {
              itemErrors.add('Field $fieldName must be a string');
            }
            break;
          case 'number':
            if (value is! num) {
              itemErrors.add('Field $fieldName must be a number');
            }
            break;
          case 'boolean':
            if (value is! bool) {
              itemErrors.add('Field $fieldName must be a boolean');
            }
            break;
        }
      }

      if (itemErrors.isEmpty) {
        validItems.add(item);
      } else {
        errors.add({
          'index': i,
          'item': item,
          'errors': itemErrors,
        });
      }
    }
    final result = {
      'validItems': validItems,
      'errors': errors,
      'validCount': validItems.length,
      'errorCount': errors.length,
      'totalCount': data.length,
    };

    return result;
  }

  @sq.SquadronMethod()
  FutureOr<List<Map<String, dynamic>>> processSqlSuggestionItems(
    List<Map<String, dynamic>> queryTables,
    String datasourceType,
  ) {
    final methodStart = DateTime.now();

    // Convert input data to proper Dart types (fixes web JsLinkedHashMap issues)
    final convertedQueryTables =
        _convertJsonToDartTypes(queryTables) as List<dynamic>;
    final properQueryTables =
        convertedQueryTables.whereType<Map<String, dynamic>>().toList();

    if (showLogs) {
      print('🚀 [WEB WORKER] processSqlSuggestionItems: Starting processing');
      print('📋 [WEB WORKER] Input parameters:');
      print('   - Datasource type: $datasourceType');
      print('   - Number of tables (original): ${queryTables.length}');
      print('   - Number of tables (converted): ${properQueryTables.length}');
      print(
          '   - Tables: ${properQueryTables.map((t) => t['tableName']).join(', ')}');

      if (properQueryTables.length != queryTables.length) {
        print('   ⚠️ Some tables were filtered out during conversion');
      }
    }

    try {
      final processedSuggestions = <Map<String, dynamic>>[];
      int totalColumnsProcessed = 0;

      for (int tableIndex = 0;
          tableIndex < properQueryTables.length;
          tableIndex++) {
        final table = properQueryTables[tableIndex];
        final tableName = table['tableName'] as String?;
        final isMainTable = table['isMainTable'] as bool? ?? true;
        final queryColumnList =
            table['queryColumnList'] as List<dynamic>? ?? [];

        if (showLogs) {
          print(
              '🔄 [WEB WORKER] Processing table ${tableIndex + 1}/${properQueryTables.length}: $tableName');
          print('   - Is main table: $isMainTable');
          print('   - Column count: ${queryColumnList.length}');
        }

        // Process columns with proper type conversion
        final processedColumns = <Map<String, dynamic>>[];
        for (int columnIndex = 0;
            columnIndex < queryColumnList.length;
            columnIndex++) {
          final columnData = queryColumnList[columnIndex];

          // Convert individual column data to ensure proper types (handles JsLinkedHashMap)
          final convertedColumnData = _convertJsonToDartTypes(columnData);

          if (convertedColumnData is Map<String, dynamic>) {
            final columnName = convertedColumnData['column'] as String? ?? '';
            final originalColumn = columnName;
            final escapedColumn = _escapedString(datasourceType, columnName);

            if (showLogs && columnIndex < 3) {
              // Log first 3 columns to avoid spam
              print(
                  '   - Column ${columnIndex + 1}: "$originalColumn" → "$escapedColumn"');
            }

            // Create processed column with escaped string
            final processedColumn =
                Map<String, dynamic>.from(convertedColumnData);
            processedColumn['column'] = escapedColumn;
            processedColumns.add(processedColumn);
            totalColumnsProcessed++;
          } else {
            if (showLogs) {
              print(
                  '   ⚠️ Skipping invalid column data at index $columnIndex: ${columnData.runtimeType}');
              print('   💡 Original data: $columnData');
              print(
                  '   🔧 Converted data: $convertedColumnData (${convertedColumnData.runtimeType})');
            }
          }
        }

        if (showLogs && queryColumnList.length > 3) {
          print('   - ... and ${queryColumnList.length - 3} more columns');
        }

        // Sort columns alphabetically by the column name
        final sortStart = DateTime.now();
        processedColumns.sort((a, b) {
          final aColumn = a['column'] as String? ?? '';
          final bColumn = b['column'] as String? ?? '';
          return aColumn.compareTo(bColumn);
        });
        final sortDuration = DateTime.now().difference(sortStart);

        if (showLogs) {
          print(
              '   - Sorted ${processedColumns.length} columns in ${sortDuration.inMicroseconds}μs');
        }

        // Create suggestion item
        final suggestion = {
          'tableName': tableName,
          'isMainTable': isMainTable,
          'queryColumnList': processedColumns,
        };

        processedSuggestions.add(suggestion);

        if (showLogs) {
          print('   ✅ Table "$tableName" processed successfully');
        }
      }

      final processingDuration = DateTime.now().difference(methodStart);

      if (showLogs) {
        print(
            '✅ [WEB WORKER] processSqlSuggestionItems: Completed in ${processingDuration.inMilliseconds}ms');
        print('📊 [WEB WORKER] Processing summary:');
        print('   - Tables processed: ${properQueryTables.length}');
        print('   - Total columns processed: $totalColumnsProcessed');
        print(
            '   - Average columns per table: ${totalColumnsProcessed / properQueryTables.length}');
        print(
            '   - Processing rate: ${(totalColumnsProcessed / processingDuration.inMilliseconds * 1000).toStringAsFixed(1)} columns/sec');
        print('   - Output suggestions count: ${processedSuggestions.length}');
      }

      // Convert result to proper Dart types before returning (fixes web JsLinkedHashMap issues)
      final convertedResult =
          _convertJsonToDartTypes(processedSuggestions) as List<dynamic>;
      final properResult =
          convertedResult.whereType<Map<String, dynamic>>().toList();

      if (showLogs && properResult.length != processedSuggestions.length) {
        print(
            '⚠️ [WEB WORKER] Some suggestions were filtered out during return conversion');
        print('   - Original count: ${processedSuggestions.length}');
        print('   - Converted count: ${properResult.length}');
      }

      return properResult;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(methodStart);

      if (showLogs) {
        print(
            '❌ [WEB WORKER] processSqlSuggestionItems: Failed after ${duration.inMilliseconds}ms');
        print('💥 [WEB WORKER] Error details:');
        print('   - Error type: ${e.runtimeType}');
        print('   - Error message: $e');
        print('   - Datasource type: $datasourceType');
        print('   - Input tables count (original): ${queryTables.length}');
        print(
            '   - Input tables count (converted): ${properQueryTables.length}');
        print('📚 [WEB WORKER] Stack trace:');
        print('   ${stackTrace.toString().split('\n').take(5).join('\n   ')}');
      }

      throw sq.SquadronException.from(
          'SQL suggestion processing failed: $e', stackTrace);
    }
  }

  @sq.SquadronMethod()
  FutureOr<Map<String, dynamic>> processTableChunk(
    List<Map<String, dynamic>> chunkData,
    String datasourceType,
    int chunkIndex,
    String taskId,
  ) {
    final methodStart = DateTime.now();

    // Convert input data to proper Dart types (fixes web JsLinkedHashMap issues)
    final convertedChunkData =
        _convertJsonToDartTypes(chunkData) as List<dynamic>;
    final properChunkData =
        convertedChunkData.whereType<Map<String, dynamic>>().toList();

    if (showLogs) {
      print('🚀 [WEB WORKER] processTableChunk: Starting chunk processing');
      print('📋 [WEB WORKER] Input parameters:');
      print('   - Task ID: $taskId');
      print('   - Chunk index: $chunkIndex');
      print('   - Datasource type: $datasourceType');
      print('   - Tables in chunk (original): ${chunkData.length}');
      print('   - Tables in chunk (converted): ${properChunkData.length}');
      print(
          '   - Table names: ${properChunkData.map((t) => t['tableName']).join(', ')}');

      if (properChunkData.length != chunkData.length) {
        print('   ⚠️ Some tables were filtered out during conversion');
      }
    }

    try {
      final processedTables = <Map<String, dynamic>>[];
      int totalColumnsProcessed = 0;

      for (int tableIndex = 0;
          tableIndex < properChunkData.length;
          tableIndex++) {
        final tableData = properChunkData[tableIndex];
        final tableName = tableData['tableName'] as String?;

        if (showLogs) {
          print(
              '🔄 [WEB WORKER] Processing table ${tableIndex + 1}/${properChunkData.length}: $tableName');
        }

        // Convert individual table data to ensure proper types
        final convertedTableData = _convertJsonToDartTypes(tableData);

        if (convertedTableData is Map<String, dynamic>) {
          final columns = convertedTableData['columns'] as List<dynamic>? ?? [];
          final processedColumns = <Map<String, dynamic>>[];

          // Process each column in the table
          for (int columnIndex = 0;
              columnIndex < columns.length;
              columnIndex++) {
            final columnData = columns[columnIndex];
            final convertedColumnData = _convertJsonToDartTypes(columnData);

            if (convertedColumnData is Map<String, dynamic>) {
              final originalColumnName =
                  convertedColumnData['columnName'] as String? ?? '';
              final columnForEscaping =
                  convertedColumnData['column'] as String? ??
                      originalColumnName;
              final escapedColumn =
                  _escapedString(datasourceType, columnForEscaping);

              if (showLogs && columnIndex < 3) {
                // Log first 3 columns to avoid spam
                print(
                    '   - Column ${columnIndex + 1}: "$originalColumnName" → escaped: "$escapedColumn"');
              }

              // Create processed column with original columnName and escaped column field
              final processedColumn =
                  Map<String, dynamic>.from(convertedColumnData);
              processedColumn['columnName'] =
                  originalColumnName; // Keep original name
              processedColumn['column'] =
                  escapedColumn; // Store escaped version
              processedColumns.add(processedColumn);
              totalColumnsProcessed++;
            } else {
              if (showLogs) {
                print(
                    '   ⚠️ Skipping invalid column data at index $columnIndex: ${columnData.runtimeType}');
              }
            }
          }

          if (showLogs && columns.length > 3) {
            print('   - ... and ${columns.length - 3} more columns');
          }

          // Sort columns alphabetically by the original column name
          processedColumns.sort((a, b) {
            final aColumn = a['columnName'] as String? ?? '';
            final bColumn = b['columnName'] as String? ?? '';
            return aColumn.compareTo(bColumn);
          });

          // Create processed table data
          final processedTable = Map<String, dynamic>.from(convertedTableData);
          processedTable['columns'] = processedColumns;
          processedTable['getTablesCalledAtLeastOnce'] = true;
          processedTables.add(processedTable);

          if (showLogs) {
            print(
                '   ✅ Table "$tableName" processed successfully (${processedColumns.length} columns)');
          }
        } else {
          if (showLogs) {
            print(
                '   ⚠️ Skipping invalid table data: ${tableData.runtimeType}');
          }
        }
      }

      final processingDuration = DateTime.now().difference(methodStart);

      if (showLogs) {
        print(
            '✅ [WEB WORKER] processTableChunk: Completed in ${processingDuration.inMilliseconds}ms');
        print('📊 [WEB WORKER] Chunk processing summary:');
        print('   - Task ID: $taskId');
        print('   - Chunk index: $chunkIndex');
        print('   - Tables processed: ${properChunkData.length}');
        print('   - Total columns processed: $totalColumnsProcessed');
        print(
            '   - Processing rate: ${(totalColumnsProcessed / processingDuration.inMilliseconds * 1000).toStringAsFixed(1)} columns/sec');
      }

      // Convert result to proper Dart types before returning
      final result = {
        'processedTables': processedTables,
        'chunkIndex': chunkIndex,
        'taskId': taskId,
        'tablesProcessed': processedTables.length,
        'columnsProcessed': totalColumnsProcessed,
        'processingTimeMs': processingDuration.inMilliseconds,
      };

      final convertedResult =
          _convertJsonToDartTypes(result) as Map<String, dynamic>;

      return convertedResult;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(methodStart);

      if (showLogs) {
        print(
            '❌ [WEB WORKER] processTableChunk: Failed after ${duration.inMilliseconds}ms');
        print('💥 [WEB WORKER] Error details:');
        print('   - Task ID: $taskId');
        print('   - Chunk index: $chunkIndex');
        print('   - Error type: ${e.runtimeType}');
        print('   - Error message: $e');
        print('   - Datasource type: $datasourceType');
        print('   - Input tables count: ${chunkData.length}');
      }

      throw sq.SquadronException.from(
          'Table chunk processing failed: $e', stackTrace);
    }
  }

  /// Processes autocomplete suggestions for the given prefix
  ///
  /// This method handles fetching and filtering suggestions based on the provided
  /// prefix, custom words, and suggestion categories.
  @sq.SquadronMethod()
  FutureOr<Set<String>> processSuggestions(
    String prefix,
    List<String> customWords,
    Map<String, List<String>> suggestions,
  ) {
    final result = <String>{};

    // Add suggestions with case variations
    final variations = [
      prefix,
      prefix.toLowerCase(),
      prefix.toUpperCase(),
      prefix.isNotEmpty
          ? prefix[0].toUpperCase() + prefix.substring(1).toLowerCase()
          : '',
    ];

    // Token-based matching for multi-word fields
    for (final category in suggestions.entries) {
      for (final word in category.value) {
        final wordWithoutQuotes = _getStringWithoutQuotes(word);

        // Check if this is a multi-word identifier
        if (wordWithoutQuotes.contains(' ')) {
          // Split into tokens and check if any token matches the prefix
          final tokens = wordWithoutQuotes.split(' ');

          // Handle full identifier match (starts with whole prefix)
          for (final variation in variations) {
            if (variation.isEmpty) continue;

            if (wordWithoutQuotes
                .toLowerCase()
                .startsWith(variation.toLowerCase())) {
              result.add(word);
              break;
            }
          }

          // Check if we're matching a partial word within the multi-word identifier
          bool tokenMatch = false;
          for (final token in tokens) {
            for (final variation in variations) {
              if (variation.isEmpty) continue;

              if (token.toLowerCase().startsWith(variation.toLowerCase())) {
                result.add(word);
                tokenMatch = true;
                break;
              }
            }
            if (tokenMatch) break;
          }
        }
        // Standard matching for single-word identifiers
        else {
          for (final variation in variations) {
            if (variation.isEmpty) continue;

            if (wordWithoutQuotes
                .toLowerCase()
                .startsWith(variation.toLowerCase())) {
              result.add(word);
              break;
            }
          }
        }
      }
    }

    // Check custom words with similar multi-word awareness
    if (result.isEmpty) {
      for (final word in customWords) {
        final wordWithoutQuotes = _getStringWithoutQuotes(word);

        // Check for token matches in multi-word identifiers
        if (wordWithoutQuotes.contains(' ')) {
          final tokens = wordWithoutQuotes.split(' ');

          bool tokenMatch = false;
          for (final token in tokens) {
            if (token.toLowerCase().contains(prefix.toLowerCase())) {
              result.add(word);
              tokenMatch = true;
              break;
            }
          }

          // Also check if the whole identifier contains the prefix
          if (!tokenMatch &&
              wordWithoutQuotes.toLowerCase().contains(prefix.toLowerCase())) {
            result.add(word);
          }
        }
        // Standard matching for single-word identifiers
        else if (wordWithoutQuotes
            .toLowerCase()
            .contains(prefix.toLowerCase())) {
          result.add(word);
        }
      }

      // Sort results by relevance - exact matches first, then by length
      final sortedResults = result.toList()
        ..sort((a, b) {
          final aWithoutQuotes = _getStringWithoutQuotes(a);
          final bWithoutQuotes = _getStringWithoutQuotes(b);

          // Exact matches get priority
          final aExactMatch =
              aWithoutQuotes.toLowerCase() == prefix.toLowerCase();
          final bExactMatch =
              bWithoutQuotes.toLowerCase() == prefix.toLowerCase();

          if (aExactMatch && !bExactMatch) return -1;
          if (!aExactMatch && bExactMatch) return 1;

          // Then starts-with matches
          final aStartsWith =
              aWithoutQuotes.toLowerCase().startsWith(prefix.toLowerCase());
          final bStartsWith =
              bWithoutQuotes.toLowerCase().startsWith(prefix.toLowerCase());

          if (aStartsWith && !bStartsWith) return -1;
          if (!aStartsWith && bStartsWith) return 1;

          // Then by length (shorter suggestions first)
          return aWithoutQuotes.length.compareTo(bWithoutQuotes.length);
        });

      result.clear();
      result.addAll(sortedResults);
    }

    return result;
  }

  /// Helper method to escape SQL column names based on datasource type
  static String _escapedString(String datasourceType, String columnName) {
    switch (datasourceType) {
      case 'postgres':
        return "\"$columnName\"";
      case 'mysql':
        return "`$columnName`";
      case 'trino':
        return "\"$columnName\"";
      case 'snowflake':
        return "\"$columnName\"";
      case 'google_sheets':
        return "\"$columnName\"";
      case 'google_sheets_live':
        return "\"$columnName\"";
      case 'google_bigquery':
        return "`$columnName`";
      case 'mssql':
        return "\"$columnName\"";
      case 'uploaded_csv':
        return "\"$columnName\"";
      case 'amazon_redshift':
        return "\"$columnName\"";
      case 'databricks':
        return "`$columnName`";
      case 'starburst':
        return "\"$columnName\"";
      case 'clickhouse':
        return "\"$columnName\"";
      default:
        return "\"$columnName\"";
    }
  }

  /// Helper function to extract string without quotes
  static String _getStringWithoutQuotes(String input) {
    if ((input.startsWith('"') && input.endsWith('"')) ||
        (input.startsWith("'") && input.endsWith("'"))) {
      return input.substring(1, input.length - 1);
    }
    return input;
  }

  static dynamic _convertJsonToDartTypes(dynamic value) {
    if (value == null) {
      return null;
    } else if (value is Map) {
      final Map<String, dynamic> convertedMap = <String, dynamic>{};
      value.forEach((key, val) {
        convertedMap[key.toString()] = _convertJsonToDartTypes(val);
      });
      return convertedMap;
    } else if (value is List) {
      return value.map((item) => _convertJsonToDartTypes(item)).toList();
    } else {
      return value;
    }
  }
}
