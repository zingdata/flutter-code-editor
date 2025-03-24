import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
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
  
  /// Flag to check if we should use isolates or not
  bool get _canUseIsolates => !kIsWeb;
  
  /// Gets or creates a send port for the suggestions isolate
  Future<SendPort> _getSendPort() async {
    // If we can't use isolates (web platform), throw an error
    // to trigger the fallback to main thread implementation
    if (!_canUseIsolates) {
      throw UnsupportedError('Isolates are not supported on this platform');
    }
    
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
    if (_canUseIsolates) {
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      _sendPort = null;
      _portCompleter = null;
    }
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
  
  /// Version of fetchSuggestions that runs in an isolate with enhanced multi-word support
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
            
            if (wordWithoutQuotes.toLowerCase().startsWith(variation.toLowerCase())) {
              result.add(word);
              break;
            }
          }
          
          // Check if we're matching a partial word within the multi-word identifier
          // This allows matching "Name" in "Customer Name" or "cat" in "Product Category"
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
            
            if (wordWithoutQuotes.toLowerCase().startsWith(variation.toLowerCase())) {
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
          if (!tokenMatch && wordWithoutQuotes.toLowerCase().contains(prefix.toLowerCase())) {
            result.add(word);
          }
        } 
        // Standard matching for single-word identifiers
        else if (wordWithoutQuotes.toLowerCase().contains(prefix.toLowerCase())) {
          result.add(word);
        }
      }
      
      // Sort results by relevance - exact matches first, then by length
      final sortedResults = result.toList()
        ..sort((a, b) {
          final aWithoutQuotes = _getStringWithoutQuotes(a);
          final bWithoutQuotes = _getStringWithoutQuotes(b);
          
          // Exact matches get priority
          final aExactMatch = aWithoutQuotes.toLowerCase() == prefix.toLowerCase();
          final bExactMatch = bWithoutQuotes.toLowerCase() == prefix.toLowerCase();
          
          if (aExactMatch && !bExactMatch) return -1;
          if (!aExactMatch && bExactMatch) return 1;
          
          // Then starts-with matches
          final aStartsWith = aWithoutQuotes.toLowerCase().startsWith(prefix.toLowerCase());
          final bStartsWith = bWithoutQuotes.toLowerCase().startsWith(prefix.toLowerCase());
          
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
  
  /// Helper function to extract string without quotes
  static String _getStringWithoutQuotes(String input) {
    if ((input.startsWith('"') && input.endsWith('"')) ||
        (input.startsWith("'") && input.endsWith("'"))) {
      return input.substring(1, input.length - 1);
    }
    return input;
  }
  
  /// Helper method to find the start of a multi-word phrase
  static int _findMultiWordPhraseStart(String text, int currentWordStart) {
    // Start looking from before the current word
    int phraseStart = currentWordStart;
    
    // SQL identifiers might be quoted
    bool inQuotes = false;
    String? quoteChar;
    
    // Check if we're dealing with SQL keywords
    bool potentialSqlContext = false;
    final commonSqlKeywords = ['SELECT', 'FROM', 'WHERE', 'GROUP', 'ORDER', 'JOIN', 'HAVING', 'INSERT', 'UPDATE', 'DELETE'];
    
    // Look for SQL context by checking if any keywords appear before the current position
    for (final keyword in commonSqlKeywords) {
      if (text.toUpperCase().contains(keyword)) {
        potentialSqlContext = true;
        break;
      }
    }
    
    // Look backward for the start of a phrase, with special handling for SQL contexts
    int i = currentWordStart - 1;
    int lastWordStart = currentWordStart;
    int lastNonSpaceCharPos = -1;
    bool foundSpace = false;
    
    while (i >= 0) {
      final char = text[i];
      
      // Track non-space characters for SQL multi-word detection
      if (char != ' ' && lastNonSpaceCharPos == -1) {
        lastNonSpaceCharPos = i;
      }
      
      // Handle quotes
      if ((char == '"' || char == "'") && (quoteChar == null || char == quoteChar)) {
        inQuotes = !inQuotes;
        if (quoteChar == null && inQuotes) {
          quoteChar = char;
        } else if (!inQuotes) {
          quoteChar = null;
        }
        
        // If we just entered quotes, this might be the start of an identifier
        if (inQuotes && i > 0 && (text[i-1] == ' ' || text[i-1] == '=' || text[i-1] == ',')) {
          phraseStart = i;
          break;
        }
      }
      
      // If we're in quotes, keep going
      if (inQuotes) {
        i--;
        continue;
      }
      
      // If we hit a significant boundary, stop looking unless in SQL context
      if ('.;:,(){}[]'.contains(char)) {
        // In SQL context, we can cross some boundaries for multi-word keywords
        if (potentialSqlContext && (char == '(' || char == ')')) {
          i--;
          continue;
        }
        break;
      }
      
      // Special handling for SQL contexts - more aggressively track multi-word phrases
      if (potentialSqlContext) {
        // If we find a space, note it for SQL multi-word detection
        if (char == ' ') {
          foundSpace = true;
          
          // If we've already found a space and now hit another word, check if it's
          // the start of a multi-word phrase (like "ORDER BY" or "GROUP BY")
          if (lastNonSpaceCharPos > i) {
            // Calculate the potential word start before this space
            int potentialWordStart = i - 1;
            while (potentialWordStart >= 0 && !_isWordBoundaryChar(text[potentialWordStart])) {
              potentialWordStart--;
            }
            potentialWordStart++; // Adjust to the actual start
            
            // Extract the potential word before this space
            if (potentialWordStart < i) {
              final previousWord = text.substring(potentialWordStart, i).trim().toUpperCase();
              
              // If this looks like a SQL keyword that might precede a field name, update phraseStart
              if (commonSqlKeywords.contains(previousWord) || 
                  previousWord == "BY" || previousWord == "AS" || previousWord == "ON") {
                lastWordStart = i + 1; // After the space
                // Continue looking for more context
              }
            }
          }
          
          // Always track where the last word started
          if (i + 1 < text.length && !_isWordBoundaryChar(text[i + 1])) {
            lastWordStart = i + 1;
          }
        }
        
        // If we've found a space and now we're at a word boundary before the space
        if (foundSpace && (i == 0 || _isWordBoundaryChar(text[i-1]))) {
          // In SQL context, often we want to include preceding words in autocomplete
          // E.g., "SELECT Order da" -> suggest "Order Date" (replace "Order da" with "Order Date")
          phraseStart = lastWordStart;
          break;
        }
      }
      
      // Standard multi-word phrase detection (unchanged from before)
      if (char == ' ' && i > 0 && !_isWordBoundaryChar(text[i-1])) {
        phraseStart = i - 1;
        
        // Look backward for the start of this word
        while (phraseStart > 0 && !_isWordBoundaryChar(text[phraseStart-1])) {
          phraseStart--;
        }
      }
      
      i--;
    }
    
    // Special SQL context case: if we found spaces but didn't identify a clear phrase start,
    // try to use the last word start we tracked
    if (potentialSqlContext && foundSpace && phraseStart == currentWordStart) {
      return lastWordStart;
    }
    
    return phraseStart;
  }
  
  /// Helper to check if a character is a word boundary
  static bool _isWordBoundaryChar(String char) {
    return ' ,.;:(){}[]"\'`=+-*/\\'.contains(char);
  }
  
  /// Enhanced version of getLongestMatchingPrefix that runs in an isolate
  /// with improved support for multi-word identifiers
  static Future<Map<String, dynamic>?> _isolateGetLongestMatchingPrefix(
    String text,
    List<String> customWords,
    Map<String, List<String>> suggestions,
  ) async {
    if (text.isEmpty) {
      return null;
    }
    
    final cursorPosition = text.length;
    
    // Enhanced word boundary characters
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
      
      // 0. Check if we're in SQL context - if so, we prioritize multi-word matching
      bool sqlContext = false;
      final commonSqlKeywords = ['SELECT', 'FROM', 'WHERE', 'GROUP', 'ORDER', 'JOIN', 'HAVING'];
      for (final keyword in commonSqlKeywords) {
        if (text.toUpperCase().contains(keyword)) {
          sqlContext = true;
          break;
        }
      }
      
      // For SQL context, try multi-word matching first
      if (sqlContext) {
        // 1. Look for multi-word phrases first in SQL context
        final multiWordStart = _findMultiWordPhraseStart(text, wordStart);
        if (multiWordStart != wordStart) {
          final multiWordPhrase = text.substring(multiWordStart, cursorPosition);
          final phraseMatches = await _isolateFetchSuggestions(
            multiWordPhrase,
            customWords,
            suggestions,
          );
          
          if (phraseMatches.isNotEmpty) {
            return {
              'prefix': multiWordPhrase,
              'startIndex': multiWordStart,
              'suggestions': phraseMatches,
            };
          }
        }
        
        // 2. Try to match complete word if multi-word matching didn't find anything
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
      } else {
        // For non-SQL context, try word matching first
        // 1. Try to find suggestions for the complete word
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
        
        // 2. Then try to match multi-word phrases 
        final multiWordStart = _findMultiWordPhraseStart(text, wordStart);
        if (multiWordStart != wordStart) {
          final multiWordPhrase = text.substring(multiWordStart, cursorPosition);
          final phraseMatches = await _isolateFetchSuggestions(
            multiWordPhrase,
            customWords,
            suggestions,
          );
          
          if (phraseMatches.isNotEmpty) {
            return {
              'prefix': multiWordPhrase,
              'startIndex': multiWordStart,
              'suggestions': phraseMatches,
            };
          }
        }
      }
      
      // 3. Look for partial token matches within multi-word identifiers
      final tokenMatches = <Map<String, dynamic>>[];
      
      // Get all potential suggestion strings
      final allSuggestionStrings = <String>[];
      for (final category in suggestions.entries) {
        allSuggestionStrings.addAll(category.value);
      }
      allSuggestionStrings.addAll(customWords);
      
      // Find tokens within multi-word suggestions that match our current word
      for (final suggestion in allSuggestionStrings) {
        final suggestionWithoutQuotes = _getStringWithoutQuotes(suggestion);
        
        // Only process multi-word suggestions
        if (suggestionWithoutQuotes.contains(' ')) {
          final tokens = suggestionWithoutQuotes.split(' ');
          
          for (int i = 0; i < tokens.length; i++) {
            final token = tokens[i];
            
            // If the token starts with our current word
            if (token.toLowerCase().startsWith(currentWord.toLowerCase())) {
              // If this is a good match, add to token matches
              tokenMatches.add({
                'prefix': currentWord,
                'startIndex': wordStart,
                'suggestions': <String>{suggestion},
                'priority': i, // Lower index = higher priority
                'length': currentWord.length,
              });
            }
          }
        }
      }
      
      // 4. Check spaces within the current word for additional multi-word support
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
              tokenMatches.add({
                'prefix': subWord,
                'startIndex': i,
                'suggestions': subWordSuggestions,
                'priority': 100, // Lower priority than exact token matches
                'length': subWord.length,
              });
            }
          }
        }
      }
      
      // 5. Check for context before the current word
      final checkLimit = math.max(0, wordStart - 30); // Extend look-behind range
      for (int i = wordStart - 1; i >= checkLimit; i--) {
        // Look for potential phrase start points
        if (i == 0 || isWordBoundary(text[i - 1])) {
          final potentialPrefix = text.substring(i, cursorPosition);
          if (potentialPrefix.isNotEmpty && !potentialPrefix.startsWith(' ')) {
            final prefixSuggestions = await _isolateFetchSuggestions(
              potentialPrefix,
              customWords,
              suggestions,
            );
            
            if (prefixSuggestions.isNotEmpty) {
              tokenMatches.add({
                'prefix': potentialPrefix,
                'startIndex': i,
                'suggestions': prefixSuggestions,
                'priority': 200, // Lowest priority
                'length': potentialPrefix.length,
              });
            }
          }
        }
      }
      
      // 6. Sort token matches by priority then length
      if (tokenMatches.isNotEmpty) {
        tokenMatches.sort((a, b) {
          // First sort by priority (lower is better)
          final aPriority = a['priority'] as int;
          final bPriority = b['priority'] as int;
          final priorityCompare = aPriority.compareTo(bPriority);
          
          if (priorityCompare != 0) return priorityCompare;
          
          // Then sort by length (longer is better)
          final aLength = a['length'] as int;
          final bLength = b['length'] as int;
          return bLength.compareTo(aLength);
        });
        
        final bestMatch = tokenMatches.first;
        return {
          'prefix': bestMatch['prefix'],
          'startIndex': bestMatch['startIndex'],
          'suggestions': bestMatch['suggestions'],
        };
      }
      
      // 7. If no matches found, just use the whole word to ensure
      // we don't get partial word replacements
      return {
        'prefix': currentWord,
        'startIndex': wordStart,
        'suggestions': <String>{},  // Empty suggestions will hide the popup
      };
    }
    
    // 8. Fallback to basic search for edge cases
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
          final columnWithoutQuotes = _getStringWithoutQuotes(column);
          
          // For multi-word columns, check if any token starts with the prefix
          if (columnWithoutQuotes.contains(' ')) {
            final tokens = columnWithoutQuotes.split(' ');
            
            // Check if the whole column name starts with prefix
            if (columnWithoutQuotes.toLowerCase().startsWith(prefix.toLowerCase())) {
              result.add(column);
              continue;
            }
            
            // Check if any token starts with prefix
            for (final token in tokens) {
              if (token.toLowerCase().startsWith(prefix.toLowerCase())) {
                result.add(column);
                break;
              }
            }
          } 
          // For single-word columns, use normal prefix matching
          else if (columnWithoutQuotes.toLowerCase().startsWith(prefix.toLowerCase())) {
            result.add(column);
          }
        }
      }
    }
    
    // Also check mainTableFields for backward compatibility
    for (final field in controller.mainTableFields) {
      final fieldWithoutQuotes = _getStringWithoutQuotes(field);
      
      // Handle multi-word fields
      if (fieldWithoutQuotes.contains(' ')) {
        final tokens = fieldWithoutQuotes.split(' ');
        
        // Check if the whole field name starts with prefix
        if (fieldWithoutQuotes.toLowerCase().startsWith(prefix.toLowerCase())) {
          result.add(field);
          continue;
        }
        
        // Check if any token starts with prefix
        for (final token in tokens) {
          if (token.toLowerCase().startsWith(prefix.toLowerCase())) {
            result.add(field);
            break;
          }
        }
      } 
      // Single-word field handling
      else if (fieldWithoutQuotes.toLowerCase().startsWith(prefix.toLowerCase())) {
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

  /// Find the longest matching prefix for suggestion purposes
  /// Uses isolate for heavy computation on mobile platforms,
  /// falls back to main thread implementation on web
  Future<Map<String, dynamic>?> getLongestMatchingPrefix(String text) async {
    final cursorPosition = controller.selection.baseOffset;
    if (cursorPosition <= 0 || text.isEmpty) {
      return null;
    }
    
    // Check if we can use isolates
    if (_canUseIsolates) {
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
        // If an error occurs with the isolate, fall back to the main thread implementation
        return _getLongestMatchingPrefixOnMainThread(text);
      }
    } else {
      // Web platform or other environment where isolates aren't supported
      return _getLongestMatchingPrefixOnMainThread(text);
    }
  }
  
  /// Fallback implementation that runs on the main thread if isolate fails
  /// or on web platform where isolates aren't supported
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
      
      // 0. Check if we're in SQL context - if so, we prioritize multi-word matching
      bool sqlContext = false;
      final commonSqlKeywords = ['SELECT', 'FROM', 'WHERE', 'GROUP', 'ORDER', 'JOIN', 'HAVING'];
      for (final keyword in commonSqlKeywords) {
        if (text.toUpperCase().contains(keyword)) {
          sqlContext = true;
          break;
        }
      }
      
      // For SQL context, try multi-word matching first
      if (sqlContext) {
        // 1. Look for multi-word phrases first in SQL context
        final multiWordStart = _findMultiWordPhraseStart(text, wordStart);
        if (multiWordStart != wordStart) {
          final multiWordPhrase = text.substring(multiWordStart, cursorPosition);
          final phraseMatches = await fetchSuggestions(multiWordPhrase);
          
          if (phraseMatches.isNotEmpty) {
            return {
              'prefix': multiWordPhrase,
              'startIndex': multiWordStart,
              'suggestions': phraseMatches,
            };
          }
        }
        
        // 2. Try to match complete word if multi-word matching didn't find anything
        final wordSuggestions = await fetchSuggestions(currentWord);
        
        if (wordSuggestions.isNotEmpty) {
          return {
            'prefix': currentWord,
            'startIndex': wordStart,
            'suggestions': wordSuggestions,
          };
        }
      } else {
        // For non-SQL context, try word matching first
        // 1. Try to find suggestions for the complete word
        final wordSuggestions = await fetchSuggestions(currentWord);
        
        if (wordSuggestions.isNotEmpty) {
          return {
            'prefix': currentWord,
            'startIndex': wordStart,
            'suggestions': wordSuggestions,
          };
        }
        
        // 2. Then try to match multi-word phrases 
        final multiWordStart = _findMultiWordPhraseStart(text, wordStart);
        if (multiWordStart != wordStart) {
          final multiWordPhrase = text.substring(multiWordStart, cursorPosition);
          final phraseMatches = await fetchSuggestions(multiWordPhrase);
          
          if (phraseMatches.isNotEmpty) {
            return {
              'prefix': multiWordPhrase,
              'startIndex': multiWordStart,
              'suggestions': phraseMatches,
            };
          }
        }
      }
      
      // 3. Look for partial token matches within multi-word identifiers
      final tokenMatches = <Map<String, dynamic>>[];
      
      // Get all potential suggestion strings
      final allSuggestionStrings = <String>[];
      for (final category in controller.popupController.suggestionCategories) {
        allSuggestionStrings.addAll(category.values.first);
      }
      allSuggestionStrings.addAll(controller.autocompleter.customWords);
      
      // Find tokens within multi-word suggestions that match our current word
      for (final suggestion in allSuggestionStrings) {
        final suggestionWithoutQuotes = _getStringWithoutQuotes(suggestion);
        
        // Only process multi-word suggestions
        if (suggestionWithoutQuotes.contains(' ')) {
          final tokens = suggestionWithoutQuotes.split(' ');
          
          for (int i = 0; i < tokens.length; i++) {
            final token = tokens[i];
            
            // If the token starts with our current word
            if (token.toLowerCase().startsWith(currentWord.toLowerCase())) {
              // If this is a good match, add to token matches
              tokenMatches.add({
                'prefix': currentWord,
                'startIndex': wordStart,
                'suggestions': <String>{suggestion},
                'priority': i, // Lower index = higher priority
                'length': currentWord.length,
              });
            }
          }
        }
      }
      
      // 4. Check spaces within the current word for additional multi-word support
      for (int i = wordStart + 1; i < cursorPosition; i++) {
        if (text[i - 1] == ' ') {
          final subWord = text.substring(i, cursorPosition);
          if (subWord.isNotEmpty) {
            final subWordSuggestions = await fetchSuggestions(subWord);
            
            if (subWordSuggestions.isNotEmpty) {
              tokenMatches.add({
                'prefix': subWord,
                'startIndex': i,
                'suggestions': subWordSuggestions,
                'priority': 100, // Lower priority than exact token matches
                'length': subWord.length,
              });
            }
          }
        }
      }
      
      // 5. Check for context before the current word
      final checkLimit = math.max(0, wordStart - 30); // Extend look-behind range
      for (int i = wordStart - 1; i >= checkLimit; i--) {
        // Look for potential phrase start points
        if (i == 0 || isWordBoundary(text[i - 1])) {
          final potentialPrefix = text.substring(i, cursorPosition);
          if (potentialPrefix.isNotEmpty && !potentialPrefix.startsWith(' ')) {
            final prefixSuggestions = await fetchSuggestions(potentialPrefix);
            
            if (prefixSuggestions.isNotEmpty) {
              tokenMatches.add({
                'prefix': potentialPrefix,
                'startIndex': i,
                'suggestions': prefixSuggestions,
                'priority': 200, // Lowest priority
                'length': potentialPrefix.length,
              });
            }
          }
        }
      }
      
      // 6. Sort token matches by priority then length
      if (tokenMatches.isNotEmpty) {
        tokenMatches.sort((a, b) {
          // First sort by priority (lower is better)
          final aPriority = a['priority'] as int;
          final bPriority = b['priority'] as int;
          final priorityCompare = aPriority.compareTo(bPriority);
          
          if (priorityCompare != 0) return priorityCompare;
          
          // Then sort by length (longer is better)
          final aLength = a['length'] as int;
          final bLength = b['length'] as int;
          return bLength.compareTo(aLength);
        });
        
        final bestMatch = tokenMatches.first;
        return {
          'prefix': bestMatch['prefix'],
          'startIndex': bestMatch['startIndex'],
          'suggestions': bestMatch['suggestions'],
        };
      }
      
      // 7. If no matches found, just use the whole word to ensure
      // we don't get partial word replacements
      return {
        'prefix': currentWord,
        'startIndex': wordStart,
        'suggestions': <String>{},  // Empty suggestions will hide the popup
      };
    }
    
    // 8. Fallback to basic search for edge cases
    final fallbackSuggestions = await fetchSuggestions(
      text.substring(math.max(0, cursorPosition - 10), cursorPosition)
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

  /// Fetch suggestions for a specific prefix
  /// Uses isolate for heavy computation on mobile platforms,
  /// falls back to main thread implementation on web
  Future<Set<String>> fetchSuggestions(String prefix) async {
    if (prefix.isEmpty) {
      return {};
    }
    
    // Check if we can use isolates
    if (_canUseIsolates) {
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
        // If an error occurs with the isolate, fall back to the main thread implementation
        return _fetchSuggestionsOnMainThread(prefix);
      }
    } else {
      // Web platform or other environment where isolates aren't supported
      return _fetchSuggestionsOnMainThread(prefix);
    }
  }
  
  /// Fallback implementation that runs on the main thread if isolate fails
  /// or on web platform where isolates aren't supported
  Future<Set<String>> _fetchSuggestionsOnMainThread(String prefix) async {
    final suggestions = <String>{};
    
    // Process with variations for case-insensitivity
    final variations = [
      prefix,
      prefix.toLowerCase(),
      prefix.toUpperCase(),
      prefix.isNotEmpty ? prefix[0].toUpperCase() + prefix.substring(1).toLowerCase() : '',
    ];
    
    // Get suggestions from autocompleter with each variation
    for (final variation in variations) {
      if (variation.isEmpty) continue;
      
      final variationSuggestions = await controller.autocompleter.getSuggestions(variation);
      suggestions.addAll(variationSuggestions);
    }

    // If no direct matches, look for token matches in multi-word fields
    if (suggestions.isEmpty) {
      for (final word in controller.autocompleter.customWords) {
        final wordWithoutQuotes = _getStringWithoutQuotes(word);
        
        // For multi-word fields, check each token
        if (wordWithoutQuotes.contains(' ')) {
          final tokens = wordWithoutQuotes.split(' ');
          
          for (final token in tokens) {
            if (token.toLowerCase().startsWith(prefix.toLowerCase())) {
              suggestions.add(word);
              break;
            }
          }
        } 
        // For single-word fields, use contains for more flexible matching
        else if (wordWithoutQuotes.toLowerCase().contains(prefix.toLowerCase())) {
          suggestions.add(word);
        }
      }
    }

    return suggestions;
  }
} 