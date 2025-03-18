import 'dart:math' as math;
import 'dart:isolate';
import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter_code_editor/src/code/string.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/code_controller.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/helpers/formatter/sql_formatter.dart';

/// Data class for isolate communication
class _SuggestionRequest {
  
  _SuggestionRequest({
    required this.text,
    required this.prefix,
    required this.customWords,
    required this.suggestions,
  });
  final String text;
  final String prefix;
  final List<String> customWords;
  final Map<String, List<String>> suggestions;
}

/// Data class for isolate results
class _SuggestionResult {
  
  _SuggestionResult({this.prefixInfo, this.suggestions});
  final Map<String, dynamic>? prefixInfo;
  final Set<String>? suggestions;
}

/// Helper class for handling autocomplete suggestions logic
class SuggestionHelper {
  /// Create a suggestion helper for a specific code controller
  SuggestionHelper(this.controller);
  final CodeController controller;
  
  // Cache for running isolates
  Isolate? _isolate;
  SendPort? _sendPort;
  Completer<SendPort>? _portCompleter;
  
  /// Gets or creates a send port for the suggestions isolate
  Future<SendPort> _getSendPort() async {
    if (_sendPort != null) return _sendPort!;
    
    // If we're already creating a port, wait for that to complete
    if (_portCompleter != null) return _portCompleter!.future;
    
    // Create a new port
    _portCompleter = Completer<SendPort>();
    
    // Create a receive port for the initial communication
    final receivePort = ReceivePort();
    
    // Create the isolate
    _isolate = await Isolate.spawn(
      _suggestionsIsolateEntryPoint,
      receivePort.sendPort,
    );
    
    // The first message from the isolate will be the send port we can use for communication
    _sendPort = await receivePort.first as SendPort;
    _portCompleter!.complete(_sendPort);
    return _sendPort!;
  }
  
  /// Dispose of the isolate when no longer needed
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _portCompleter = null;
  }
  
  /// Isolate entry point that handles suggestion processing
  static void _suggestionsIsolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    
    // Send the port to the main isolate so it can send us messages
    mainSendPort.send(receivePort.sendPort);
    
    // Process messages from the main isolate
    receivePort.listen((message) async {
      if (message is List) {
        // First element is the request, second is the response port
        final request = message[0] as _SuggestionRequest;
        final responsePort = message[1] as SendPort;
        
        if (request.prefix.isNotEmpty) {
          // Handle fetching suggestions for a prefix
          final suggestions = await _isolateFetchSuggestions(
            request.prefix,
            request.customWords,
            request.suggestions,
          );
          responsePort.send(_SuggestionResult(suggestions: suggestions));
        } else {
          // Handle finding longest matching prefix
          final prefixInfo = await _isolateGetLongestMatchingPrefix(
            request.text,
            request.customWords,
            request.suggestions,
          );
          responsePort.send(_SuggestionResult(prefixInfo: prefixInfo));
        }
      } else if (message == 'shutdown') {
        Isolate.exit();
      }
    });
  }
  
  /// Version of fetchSuggestions that runs in an isolate
  static Future<Set<String>> _isolateFetchSuggestions(
    String prefix,
    List<String> customWords,
    Map<String, List<String>> suggestions,
  ) async {
    final result = <String>{};
    
    // Add suggestions with case variations
    final variations = [
      prefix,
      prefix.toLowerCase(),
      prefix.toUpperCase(),
      prefix.isNotEmpty ? prefix[0].toUpperCase() + prefix.substring(1).toLowerCase() : '',
    ];
    
    for (final variation in variations) {
      if (variation.isEmpty) continue;
      
      // Check all suggestion categories
      for (final category in suggestions.entries) {
        for (final word in category.value) {
          if (word.toLowerCase().startsWith(variation.toLowerCase())) {
            result.add(word);
          }
        }
      }
    }
    
    // Check custom words
    if (result.isEmpty) {
      final customMatches = customWords
          .where((element) => element.stringWithoutQuotes.toLowerCase().contains(prefix.toLowerCase()))
          .toList()
        ..sort();
      result.addAll(customMatches);
    }
    
    return result;
  }
  
  /// Version of getLongestMatchingPrefix that runs in an isolate
  static Future<Map<String, dynamic>?> _isolateGetLongestMatchingPrefix(
    String text,
    List<String> customWords,
    Map<String, List<String>> suggestions,
  ) async {
    if (text.isEmpty) {
      return null;
    }
    
    final cursorPosition = text.length;
    
    // Word boundary characters
    bool isWordBoundary(String char) {
      return ' ,.;:(){}[]"\'`=+-*/\\'.contains(char);
    }
    
    // Find the current word at cursor position
    var wordStart = cursorPosition;
    while (wordStart > 0) {
      final char = text[wordStart - 1];
      if (isWordBoundary(char)) {
        break;
      }
      wordStart--;
    }
    
    // If we have identified a complete word
    if (wordStart < cursorPosition) {
      final currentWord = text.substring(wordStart, cursorPosition);
      
      // Try to find suggestions for the complete word
      final wordSuggestions = await _isolateFetchSuggestions(
        currentWord,
        customWords,
        suggestions,
      );
      
      if (wordSuggestions.isNotEmpty) {
        return {
          'prefix': currentWord,
          'startIndex': wordStart,
          'suggestions': wordSuggestions,
        };
      }
      
      // If no suggestions for the complete word, ONLY look for prefixes that
      // start at word boundaries, not partial matches within the word
      final partialMatches = <Map<String, dynamic>>[];
   
      // Check spaces within the current word for multi-word identifiers
      for (int i = wordStart + 1; i < cursorPosition; i++) {
        if (text[i - 1] == ' ') {
          final subWord = text.substring(i, cursorPosition);
          if (subWord.isNotEmpty) {
            final subWordSuggestions = await _isolateFetchSuggestions(
              subWord,
              customWords,
              suggestions,
            );
            
            if (subWordSuggestions.isNotEmpty) {
              partialMatches.add({
                'prefix': subWord,
                'startIndex': i,
                'suggestions': subWordSuggestions,
                'length': subWord.length,
              });
            }
          }
        }
      }
      
      // Check positions before the word start for context
      final checkLimit = math.max(0, wordStart - 20);
      for (int i = wordStart - 1; i >= checkLimit; i--) {
        if (i == 0 || isWordBoundary(text[i - 1])) {
          final potentialPrefix = text.substring(i, cursorPosition);
          if (potentialPrefix.isNotEmpty && !potentialPrefix.startsWith(' ')) {
            final prefixSuggestions = await _isolateFetchSuggestions(
              potentialPrefix,
              customWords,
              suggestions,
            );
            
            if (prefixSuggestions.isNotEmpty) {
              partialMatches.add({
                'prefix': potentialPrefix,
                'startIndex': i,
                'suggestions': prefixSuggestions,
                'length': potentialPrefix.length,
              });
            }
          }
        }
      }
      
      // Sort by length (prefer longer matches)
      partialMatches.sort((a, b) {
        final aLength = a['length'] as int;
        final bLength = b['length'] as int;
        return bLength.compareTo(aLength);
      });
      
      if (partialMatches.isNotEmpty) {
        final bestMatch = partialMatches.first;
        return {
          'prefix': bestMatch['prefix'],
          'startIndex': bestMatch['startIndex'],
          'suggestions': bestMatch['suggestions'],
        };
      }
      
      // If no matches found, just use the whole word to ensure
      // we don't get partial word replacements
      return {
        'prefix': currentWord,
        'startIndex': wordStart,
        'suggestions': <String>{},  // Empty suggestions will hide the popup
      };
    }
    
    // Fallback to basic search
    final fallbackSuggestions = await _isolateFetchSuggestions(
      text.substring(math.max(0, cursorPosition - 10), cursorPosition),
      customWords,
      suggestions,
    );
    
    if (fallbackSuggestions.isNotEmpty) {
      return {
        'prefix': text.substring(math.max(0, cursorPosition - 10), cursorPosition),
        'startIndex': math.max(0, cursorPosition - 10),
        'suggestions': fallbackSuggestions,
      };
    }
    
    return null;
  }
  
  /// Generates and displays appropriate suggestions based on current cursor position and text
  Future<void> generateSuggestions() async {
    controller.tableNameBeforeDot = null;
    try {
      final textBeforeCursor = controller.value.text.substring(0, controller.selection.baseOffset);
      if (textBeforeCursor.isEmpty) {
        controller.popupController.hide();
        return;
      }

      // Check if there's a dot in the text before cursor
      final dotIndex = textBeforeCursor.lastIndexOf('.');
      
      // If we found a dot, try to extract table name before it
      if (dotIndex > 0) {
        final potentialTableName = SqlFormatter.extractPotentialTableName(textBeforeCursor, dotIndex);
        
        // Check if it's a known table
        if (_isTableName(potentialTableName)) {
          controller.tableNameBeforeDot = potentialTableName;
          
          // If cursor is right after the dot, show all columns for this table
          if (dotIndex == textBeforeCursor.length - 1) {
            _showTableColumns(potentialTableName, dotIndex);
            return;
          } 
          // Otherwise, use text after dot as filter for columns
          else if (dotIndex < textBeforeCursor.length - 1) {
            final columnPrefix = textBeforeCursor.substring(dotIndex + 1).trim();
            
            // Only process if there's valid column text to filter by
            if (columnPrefix.isNotEmpty) {
              final handled = await _handleColumnFiltering(potentialTableName, columnPrefix, dotIndex);
              if (handled) return;
            }
          }
        }
      } 
      else {
        // No dot found, try to detect table context from SQL context
        controller.tableNameBeforeDot = _detectTableContext(textBeforeCursor);
      }

      // Fall back to standard prefix matching for normal autocomplete
      await _fallbackToStandardSuggestions(textBeforeCursor);
      
    // ignore: empty_catches
    } catch (e) {}
  }

  /// Checks if the given name is a table name
  bool _isTableName(String name) {
    // First check mainTables for backward compatibility
    if (controller.mainTables.contains(name)) {
      return true;
    }

    // Check in suggestionCategories for entries with 'Table' key
    for (final category in controller.popupController.suggestionCategories) {
      // Look for the 'Table' category or any category containing the word 'Table'
      if (category.keys.first == 'Table' || category.keys.first.contains('Table')) {
        if (category.values.first.contains(name)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Shows all columns for a specific table
  void _showTableColumns(String tableName, int dotIndex) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      controller.popupController.showOnlyColumnsOfTable(tableName);
    });
    controller.lastPrefixStartIndex = dotIndex + 1;
  }

  /// Handles the case where user is typing after table.
  /// Returns true if suggestions were shown, false otherwise
  Future<bool> _handleColumnFiltering(String tableName, String columnPrefix, int dotIndex) async {
    // Get filtered column suggestions based on what's been typed after dot
    Set<String> columnSuggestions = await _getFilteredColumnSuggestions(
      tableName, 
      columnPrefix
    );
    
    if (columnSuggestions.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        controller.popupController.show(tableName, columnSuggestions.toList());
      });
      // Set start index to position right after dot
      controller.lastPrefixStartIndex = dotIndex + 1;
      return true;
    }
    return false;
  }

  /// Get column suggestions filtered by prefix for a specific table
  Future<Set<String>> _getFilteredColumnSuggestions(String tableName, String prefix) async {
    final result = <String>{};
    
    // Check columns in suggestionCategories
    for (final category in controller.popupController.suggestionCategories) {
      final key = category.keys.first;
      
      // Find categories related to columns of this table
      if (key == 'Column in $tableName' || key == 'Columns') {
        for (final column in category.values.first) {
          // Add columns that match the prefix
          if (column.toLowerCase().startsWith(prefix.toLowerCase())) {
            result.add(column);
          }
        }
      }
    }
    
    // Also check mainTableFields for backward compatibility
    for (final field in controller.mainTableFields) {
      if (field.toLowerCase().startsWith(prefix.toLowerCase())) {
        result.add(field);
      }
    }
    
    return result;
  }

  /// Attempts to detect which table the cursor is currently working with
  /// based on context like FROM clauses, JOIN statements, etc.
  String? _detectTableContext(String text) {
    // Simple detection - find the most recently referenced table
    for (final table in controller.mainTables) {
      // Check for common SQL patterns where a table name appears
      // Find the last occurrence of patterns like "FROM table", "JOIN table", "table."
      final fromPattern = RegExp(r'FROM\s+' + table + r'\b', caseSensitive: false);
      final joinPattern = RegExp(r'JOIN\s+' + table + r'\b', caseSensitive: false);
      final aliasPattern = RegExp(r'FROM\s+' + table + r'\s+AS\s+\w+', caseSensitive: false);

      if (fromPattern.hasMatch(text) || joinPattern.hasMatch(text) || aliasPattern.hasMatch(text)) {
        return table;
      }
    }

    // If we couldn't detect a specific table, check if any table appears in the text
    for (final table in controller.mainTables) {
      if (text.contains(table)) {
        return table;
      }
    }

    return null;
  }

  /// Fallback to standard suggestion mechanism when no specific context is detected
  Future<void> _fallbackToStandardSuggestions(String textBeforeCursor) async {
    final prefixInfo = await getLongestMatchingPrefix(textBeforeCursor);

    if (prefixInfo == null) {
      controller.popupController.hide();
      return;
    }

    final startIndex = prefixInfo['startIndex'] as int;
    final suggestions = prefixInfo['suggestions'] as Set<String>;

    if (suggestions.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        controller.popupController.show(controller.tableNameBeforeDot, suggestions.toList());
      });
    } else {
      controller.popupController.hide();
    }
    controller.lastPrefixStartIndex = startIndex;
  }

  /// Find the longest matching prefix for suggestion purposes using isolate for heavy computation
  Future<Map<String, dynamic>?> getLongestMatchingPrefix(String text) async {
    final cursorPosition = controller.selection.baseOffset;
    if (cursorPosition <= 0 || text.isEmpty) {
      return null;
    }
    
    try {
      // Get a send port to communicate with the isolate
      final sendPort = await _getSendPort();
      
      // Create a receive port for the response
      final responsePort = ReceivePort();
      
      // Prepare customWords and suggestions for isolate
      final customWords = controller.autocompleter.customWords.toList();
      
      // Convert suggestion categories to a simple map for isolate
      final Map<String, List<String>> suggestionMap = {};
      for (final category in controller.popupController.suggestionCategories) {
        suggestionMap[category.keys.first] = category.values.first.toList();
      }
      
      // Send the request to the isolate
      sendPort.send([
        _SuggestionRequest(
          text: text.substring(0, cursorPosition),
          prefix: '', // Empty prefix indicates we want longest matching prefix
          customWords: customWords,
          suggestions: suggestionMap,
        ),
        responsePort.sendPort // Send the response port so isolate knows where to reply
      ]);
      
      // Wait for the response
      final result = await responsePort.first as _SuggestionResult;
      responsePort.close();
      
      // Return the result
      return result.prefixInfo;
    } catch (e) {
      // If an error occurs with the isolate, fall back to the original implementation
      return _getLongestMatchingPrefixOnMainThread(text);
    }
  }
  
  /// Fallback implementation that runs on the main thread if isolate fails
  Future<Map<String, dynamic>?> _getLongestMatchingPrefixOnMainThread(String text) async {
    final cursorPosition = controller.selection.baseOffset;
    if (cursorPosition <= 0 || text.isEmpty) {
      return null;
    }
    
    // Word boundary characters
    bool isWordBoundary(String char) {
      return ' ,.;:(){}[]"\'`=+-*/\\'.contains(char);
    }
    
    // 1. First find the complete current word at cursor position
    var wordStart = cursorPosition;
    while (wordStart > 0) {
      final char = text[wordStart - 1];
      if (isWordBoundary(char)) {
        break;
      }
      wordStart--;
    }
    
    // If we have identified a complete word
    if (wordStart < cursorPosition) {
      final currentWord = text.substring(wordStart, cursorPosition);
      
      // 2. Try to find suggestions for the complete word
      final wordSuggestions = await fetchSuggestions(currentWord);
      if (wordSuggestions.isNotEmpty) {
        return {
          'prefix': currentWord,
          'startIndex': wordStart,
          'suggestions': wordSuggestions,
        };
      }
      
      // 3. If no suggestions for the complete word, ONLY look for prefixes that
      // start at word boundaries, not partial matches within the word
      final partialMatches = <Map<String, dynamic>>[];
   
      // Add additional checks at spaces within the current word
      for (int i = wordStart + 1; i < cursorPosition; i++) {
        if (text[i - 1] == ' ') {
          final subWord = text.substring(i, cursorPosition);
          if (subWord.isNotEmpty) {
            final subWordSuggestions = await fetchSuggestions(subWord);
            if (subWordSuggestions.isNotEmpty) {
              partialMatches.add({
                'prefix': subWord,
                'startIndex': i,
                'suggestions': subWordSuggestions,
                'length': subWord.length,
              });
            }
          }
        }
      }
      
      // 4. Check a few positions before the word start to handle edge cases
      final checkLimit = math.max(0, wordStart - 20);
      for (int i = wordStart - 1; i >= checkLimit; i--) {
        if (i == 0 || isWordBoundary(text[i - 1])) {
          final potentialPrefix = text.substring(i, cursorPosition);
          if (potentialPrefix.isNotEmpty && !potentialPrefix.startsWith(' ')) {
            final suggestions = await fetchSuggestions(potentialPrefix);
            if (suggestions.isNotEmpty) {
              partialMatches.add({
                'prefix': potentialPrefix,
                'startIndex': i,
                'suggestions': suggestions,
                'length': potentialPrefix.length,
              });
            }
          }
        }
      }
      
      // 5. Sort by length (prefer longer matches)
      partialMatches.sort((a, b) {
        final aLength = a['length'] as int;
        final bLength = b['length'] as int;
        return bLength.compareTo(aLength);
      });
      
      if (partialMatches.isNotEmpty) {
        final bestMatch = partialMatches.first;
        return {
          'prefix': bestMatch['prefix'],
          'startIndex': bestMatch['startIndex'],
          'suggestions': bestMatch['suggestions'],
        };
      }
      
      // If no matches found, just use the whole word to ensure
      // we don't get partial word replacements
      return {
        'prefix': currentWord,
        'startIndex': wordStart,
        'suggestions': <String>{},  // Empty suggestions will hide the popup
      };
    }
    
    // If no word found at cursor (rare case), fall back to basic search
    // This should almost never happen, but we keep it as a fallback
    final fallbackSuggestions = await fetchSuggestions(text.substring(math.max(0, cursorPosition - 10), cursorPosition));
    if (fallbackSuggestions.isNotEmpty) {
      return {
        'prefix': text.substring(math.max(0, cursorPosition - 10), cursorPosition),
        'startIndex': math.max(0, cursorPosition - 10),
        'suggestions': fallbackSuggestions,
      };
    }
    
    return null;
  }

  /// Fetch suggestions for a specific prefix using isolate for heavy computation
  Future<Set<String>> fetchSuggestions(String prefix) async {
    if (prefix.isEmpty) {
      return {};
    }
    
    try {
      // Get a send port to communicate with the isolate
      final sendPort = await _getSendPort();
      
      // Create a receive port for the response
      final responsePort = ReceivePort();
      
      // Prepare customWords and suggestions for isolate
      final customWords = controller.autocompleter.customWords.toList();
      
      // Convert suggestion categories to a simple map for isolate
      final Map<String, List<String>> suggestionMap = {};
      for (final category in controller.popupController.suggestionCategories) {
        suggestionMap[category.keys.first] = category.values.first.toList();
      }
      
      // Send the request to the isolate
      sendPort.send([
        _SuggestionRequest(
          text: '',
          prefix: prefix,
          customWords: customWords,
          suggestions: suggestionMap,
        ),
        responsePort.sendPort // Send the response port so isolate knows where to reply
      ]);
      
      // Wait for the response
      final result = await responsePort.first as _SuggestionResult;
      responsePort.close();
      
      // Return the result
      return result.suggestions ?? {};
    } catch (e) {
      // If an error occurs with the isolate, fall back to the original implementation
      return _fetchSuggestionsOnMainThread(prefix);
    }
  }
  
  /// Fallback implementation that runs on the main thread if isolate fails
  Future<Set<String>> _fetchSuggestionsOnMainThread(String prefix) async {
    final suggestions = <String>{
      ...await controller.autocompleter.getSuggestions(prefix),
      ...await controller.autocompleter.getSuggestions(prefix.toLowerCase()),
      ...await controller.autocompleter.getSuggestions(prefix.toUpperCase()),
      ...await controller.autocompleter.getSuggestions(
        prefix[0].toUpperCase() + prefix.substring(1).toLowerCase(),
      ),
    };

    if (suggestions.isEmpty) {
      final suggestions0 = controller.autocompleter.customWords
          .where(
            (element) => element.stringWithoutQuotes.toLowerCase().contains(prefix.toLowerCase()),
          )
          .toList()
        ..sort();
      suggestions.addAll(suggestions0);
    }

    return suggestions;
  }
} 