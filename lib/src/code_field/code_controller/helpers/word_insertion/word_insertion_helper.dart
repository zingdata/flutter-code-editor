import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_code_editor/src/code/string.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/code_controller.dart';

/// Helper class for handling word insertion from autocomplete
class WordInsertionHelper {
  /// Create a word insertion helper for a specific code controller
  WordInsertionHelper(this.controller);
  final CodeController controller;

  /// List of SQL aggregation functions that should have brackets after them
  final List<String> _sqlAggregationFunctions = [
    'SUM',
    'AVG',
    'COUNT',
    'MAX',
    'MIN',
    'AVERAGE',
    'FIRST',
    'LAST',
    'MEDIAN',
    'STDDEV',
    'VARIANCE'
  ];

  /// Inserts the currently selected word from autocomplete popup
  /// into the code editor at the appropriate position
  void insertSelectedWord({
    String? keyword,
    bool? isKeywordColumn,
  }) {
    // Safety check - return if no valid selection
    if (controller.popupController.selectedIndex < 0 && keyword == null) {
      return;
    }
    // Mark that we're inserting a word to prevent triggering other listeners
    controller.isInsertingWord = true;

    final previousSelection = controller.selection;
    final selectedWord =
        keyword ?? controller.popupController.getSelectedWord();
    final isColumn = isKeywordColumn ?? controller.popupController.isColumn();

    try {
      // Handle case where we don't have a defined prefix start index
      if (controller.lastPrefixStartIndex == null) {
        _handleInsertionWithoutPrefixIndex(
            previousSelection, isColumn, selectedWord);
        return;
      }

      // Get the start and end indices for the replacement
      int startIndex = controller.lastPrefixStartIndex!;
      final endIndex = previousSelection.baseOffset;

      // Get the current text being typed/replaced
      final textBeingReplaced = controller.text.substring(startIndex, endIndex);

      // Check if we should do special handling for multi-word identifiers
      if (selectedWord.contains(' ') || textBeingReplaced.contains(' ')) {
        startIndex = _determineMultiWordReplacementStart(
            startIndex, endIndex, selectedWord, textBeingReplaced);
      }

      // Normal insertion with adjusted start index
      _handleNormalInsertion(
          previousSelection, isColumn, selectedWord, startIndex, endIndex);
    } finally {
      // Always reset insertion flag when done, even if exception occurs
      controller.isInsertingWord = false;
    }
  }

  /// Determines the appropriate start index for multi-word identifier replacements
  int _determineMultiWordReplacementStart(int startIndex, int endIndex,
      String selectedWord, String textBeingReplaced) {
    // Check for SQL context - this changes how we handle replacements
    final fullContext = controller.text.substring(0, endIndex);
    final isSqlContext = _isInSqlContext(fullContext);

    // Get text before the replacement to better understand context
    final contextBefore = startIndex > 0
        ? controller.text.substring(0, startIndex).trim().toUpperCase()
        : '';

    // Remove quotes for comparison operations
    final selectedWordWithoutQuotes = selectedWord.stringWithoutQuotes;
    final textBeingReplacedWithoutQuotes =
        textBeingReplaced.stringWithoutQuotes;

    // For SQL multi-word field names that were identified in the suggestion helper
    if (isSqlContext && selectedWordWithoutQuotes.contains(' ')) {
      // Check if this is a SQL keyword or a field name with spaces
      bool isSqlKeyword = _isSqlKeyword(selectedWord);

      if (!isSqlKeyword) {
        // This is likely a field name with spaces - we need to find the real start
        // Look for SQL clauses that would be followed by field names
        final clausesBeforeFields = [
          'SELECT',
          'WHERE',
          'GROUP BY',
          'ORDER BY',
          'HAVING',
          'AND',
          'OR',
          'ON'
        ];
        String textUpToCursor = fullContext.toUpperCase();

        // Look for the last SQL clause in the text
        int lastClausePos = -1;
        String foundClause = '';

        for (final clause in clausesBeforeFields) {
          int pos = textUpToCursor.lastIndexOf(clause);
          if (pos > lastClausePos) {
            lastClausePos = pos;
            foundClause = clause;
          }
        }

        if (lastClausePos >= 0) {
          // Extract the text between the SQL clause and our cursor
          int fieldStart = lastClausePos + foundClause.length;
          String afterClause =
              fullContext.substring(fieldStart, endIndex).trim();

          if (afterClause.isNotEmpty) {
            // Check if what's been typed matches the beginning of our selected word
            // accounting for case differences and removing quotes
            final selectedLower = selectedWordWithoutQuotes.toLowerCase();
            final afterClauseLower =
                afterClause.stringWithoutQuotes.toLowerCase();

            // Handle special cases where only part of a field name was typed
            // For example: "SELECT order da" should match "Order Date"
            if (selectedLower.contains(' ')) {
              // Split both into tokens
              final selectedTokens = selectedLower.split(' ');
              final typedTokens = afterClauseLower.split(' ');

              // Check if the typed tokens match the beginning of the selected word
              bool isPartialMatch = false;

              // Case 1: Typed "first se" for "First Second"
              if (typedTokens.length == 2 &&
                  selectedTokens.length == 2 &&
                  typedTokens[0]
                      .startsWith(selectedTokens[0].substring(0, 1)) &&
                  typedTokens[1]
                      .startsWith(selectedTokens[1].substring(0, 1))) {
                isPartialMatch = true;
              }

              // Case 2: Typed "first s" for "First Second"
              else if (typedTokens.length == 2 &&
                  selectedTokens.length == 2 &&
                  typedTokens[0]
                      .startsWith(selectedTokens[0].substring(0, 1)) &&
                  selectedTokens[1].startsWith(typedTokens[1])) {
                isPartialMatch = true;
              }

              // Case 3: Typed "fir sec" for "First Second"
              else if (typedTokens.length == 2 &&
                  selectedTokens.length == 2 &&
                  selectedTokens[0].startsWith(typedTokens[0]) &&
                  selectedTokens[1].startsWith(typedTokens[1])) {
                isPartialMatch = true;
              }

              // Case 4: Simple case: "order da" for "Order Date"
              else if (typedTokens.length == 2 &&
                  selectedTokens.length == 2 &&
                  typedTokens[0].toLowerCase() ==
                      selectedTokens[0]
                          .toLowerCase()
                          .substring(0, typedTokens[0].length) &&
                  typedTokens[1].toLowerCase() ==
                      selectedTokens[1]
                          .toLowerCase()
                          .substring(0, typedTokens[1].length)) {
                isPartialMatch = true;
              }

              if (isPartialMatch) {
                // Find the start position of this phrase in the text
                // First try with the original text (with quotes if present)
                int phraseStart = -1;

                // Try to find the start position by accounting for possible quoting styles
                String typedFirstToken = typedTokens[0].toUpperCase();

                // Try without quotes first
                phraseStart =
                    textUpToCursor.lastIndexOf(typedFirstToken, endIndex);

                // If not found, try with double quotes
                if (phraseStart < 0) {
                  phraseStart = textUpToCursor.lastIndexOf(
                      "\"$typedFirstToken\"", endIndex);
                }

                // If still not found, try with backticks
                if (phraseStart < 0) {
                  phraseStart = textUpToCursor.lastIndexOf(
                      "`$typedFirstToken`", endIndex);
                }

                if (phraseStart >= 0) {
                  // We found a valid start position - ensure it's at the beginning of a word
                  if (phraseStart == 0 ||
                      _isWordBoundary(fullContext[phraseStart - 1])) {
                    return phraseStart;
                  }
                }
              }
            }

            // Handle the case where the entire phrase matches partially
            // Example: "Ord Da" should match "Order Date"
            if (selectedLower
                .replaceAll(' ', '')
                .startsWith(afterClauseLower.replaceAll(' ', ''))) {
              // Find where this text actually starts in the full context
              int realStart = fullContext.indexOf(afterClause, lastClausePos);
              if (realStart >= 0) {
                return realStart;
              }
            }

            // Also check if the whole phrase as typed matches the start of our suggestion
            if (selectedLower.startsWith(afterClauseLower)) {
              int realStart = fullContext.indexOf(afterClause, lastClausePos);
              if (realStart >= 0) {
                return realStart;
              }
            }
          }
        }
      }
    }

    // If what's being typed doesn't contain spaces, we should look for
    // multi-word field name candidates in SQL context
    if (!textBeingReplacedWithoutQuotes.contains(' ') &&
        isSqlContext &&
        selectedWordWithoutQuotes.contains(' ')) {
      // Look backward from the cursor for a potential phrase start
      // Example: For "SELECT order da" when replacing with "Order Date"

      String textUpToCursor = fullContext;
      // Find the last SQL clause
      final sqlClauses = [
        'SELECT',
        'FROM',
        'WHERE',
        'GROUP BY',
        'ORDER BY',
        'HAVING',
        'AND',
        'OR'
      ];
      int lastClausePos = -1;

      for (final clause in sqlClauses) {
        int pos = textUpToCursor.toUpperCase().lastIndexOf(clause);
        if (pos > lastClausePos) {
          lastClausePos = pos + clause.length;
        }
      }

      if (lastClausePos >= 0) {
        // Get text between clause and cursor
        String afterClause =
            textUpToCursor.substring(lastClausePos, endIndex).trim();

        // Remove quotes for comparison
        afterClause = afterClause.stringWithoutQuotes;

        // If there are words before what's currently being typed, check if they form
        // part of a multi-word identifier
        if (afterClause.contains(' ')) {
          final words = afterClause.split(' ');
          if (words.length >= 2) {
            // Check if the typed phrase could match our suggestion
            final selectedWords =
                selectedWordWithoutQuotes.toLowerCase().split(' ');

            // Case: "order da" for "Order Date"
            if (words.length == 2 && selectedWords.length == 2) {
              if (words[0].toLowerCase() ==
                      selectedWords[0]
                          .toLowerCase()
                          .substring(0, words[0].length) &&
                  words[1].toLowerCase() ==
                      selectedWords[1]
                          .toLowerCase()
                          .substring(0, words[1].length)) {
                // Find the actual start of this phrase
                int phraseStart = -1;

                // Try different quoting styles
                String word0 = words[0];
                phraseStart = textUpToCursor.lastIndexOf(word0, endIndex);

                if (phraseStart < 0) {
                  phraseStart =
                      textUpToCursor.lastIndexOf("\"$word0\"", endIndex);
                }

                if (phraseStart < 0) {
                  phraseStart =
                      textUpToCursor.lastIndexOf("`$word0`", endIndex);
                }

                if (phraseStart >= 0) {
                  return phraseStart;
                }
              }
            }
          }
        }
      }
    }

    // Split both strings into word tokens for comparison
    final selectedTokens = selectedWordWithoutQuotes.toLowerCase().split(' ');
    final replacedTokens =
        textBeingReplacedWithoutQuotes.toLowerCase().split(' ');

    // Handle SQL clause context specially
    if (isSqlContext &&
        (contextBefore.endsWith("SELECT") ||
            contextBefore.endsWith("WHERE") ||
            contextBefore.endsWith("GROUP BY") ||
            contextBefore.endsWith("ORDER BY"))) {
      // This is a clause that should be followed by a field name
      // Replace the entire typed text with the suggestion
      return startIndex;
    }

    // Case 1: User typed same or more words than the suggestion
    // Example: Typed "SELECT FROM INN", selecting "INNER JOIN"
    // We should only replace "INN" with "INNER JOIN"
    if (replacedTokens.length >= selectedTokens.length) {
      // Only replace the last word that was typed - this handles cases like:
      // "SELECT FROM INN" -> only replace "INN" with "INNER JOIN"
      final lastWordIndex = textBeingReplaced.lastIndexOf(' ');
      if (lastWordIndex >= 0) {
        return startIndex + lastWordIndex + 1; // +1 to skip the space
      }
      return startIndex;
    }

    // Case 2: User typed partial multi-word suggestion
    // Example: Typed "INNER JO", selecting "INNER JOIN"
    // We should replace the entire "INNER JO" with "INNER JOIN"
    else {
      // Find how many of the beginning words match
      int matchingTokens = 0;
      for (int i = 0; i < replacedTokens.length - 1; i++) {
        if (i < selectedTokens.length &&
            selectedTokens[i] == replacedTokens[i]) {
          matchingTokens++;
        } else {
          break;
        }
      }

      // Check if the last token is a partial match of the corresponding selected token
      bool lastTokenIsPartial = false;
      if (replacedTokens.length > 0 &&
          selectedTokens.length > replacedTokens.length - 1) {
        final lastReplacedToken = replacedTokens.last;
        final correspondingSelectedToken =
            selectedTokens[replacedTokens.length - 1];
        lastTokenIsPartial =
            correspondingSelectedToken.startsWith(lastReplacedToken);
      }

      // If at least the first word matches and we typed part of a multi-word phrase,
      // replace from the start of the matching phrase
      if (matchingTokens > 0 ||
          lastTokenIsPartial ||
          (replacedTokens.length == 1 &&
              selectedTokens.length > 1 &&
              selectedTokens[0].startsWith(replacedTokens[0]))) {
        return startIndex;
      }

      // For cases where we typed something unrelated, just replace the last word
      final lastWordIndex = textBeingReplaced.lastIndexOf(' ');
      if (lastWordIndex >= 0) {
        return startIndex + lastWordIndex + 1; // +1 to skip the space
      }
      return startIndex;
    }
  }

  /// Checks if we're in an SQL context based on the text
  bool _isInSqlContext(String text) {
    final upperText = text.toUpperCase();
    final sqlKeywords = [
      'SELECT',
      'FROM',
      'WHERE',
      'GROUP BY',
      'ORDER BY',
      'HAVING',
      'JOIN',
      'INNER JOIN',
      'LEFT JOIN',
      'INSERT',
      'UPDATE'
    ];

    for (final keyword in sqlKeywords) {
      if (upperText.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if the given word is an SQL keyword
  bool _isSqlKeyword(String word) {
    // Remove quotes for comparison
    final upperWord = word.stringWithoutQuotes.toUpperCase();
    final sqlKeywords = [
      'SELECT',
      'FROM',
      'WHERE',
      'GROUP BY',
      'ORDER BY',
      'HAVING',
      'JOIN',
      'INNER JOIN',
      'LEFT JOIN',
      'INSERT',
      'UPDATE',
      'DELETE',
      'AND',
      'OR',
      'NOT',
      'IN',
      'BETWEEN',
      'LIKE',
      'AS',
      'ON'
    ];

    return sqlKeywords.contains(upperWord);
  }

  /// Checks if the given word is an SQL aggregation function
  bool _isSqlAggregationFunction(String word) {
    return _sqlAggregationFunctions.contains(word.toUpperCase());
  }

  /// Checks if a character is a word boundary
  bool _isWordBoundary(String char) {
    return ' ,.;:(){}[]"\'`=+-*/\\'.contains(char);
  }

  /// Handles insertion when we don't have a valid prefix start index
  void _handleInsertionWithoutPrefixIndex(
      TextSelection previousSelection, bool isColumn, String selectedWord) {
    final cursorPosition = previousSelection.baseOffset;
    String wordToInsert = selectedWord;
    int cursorAdjustment = 0;

    // Check if this is an aggregation function and add brackets if needed
    if (_isInSqlContext(controller.text) &&
        _isSqlAggregationFunction(selectedWord)) {
      wordToInsert = "$selectedWord()";
      cursorAdjustment = -1; // Position cursor inside the brackets
    }

    // Format the text and adjust the cursor offset
    var formatResult = controller.formatAndAdjustOffset(
      originalText: controller.text,
      selectedWord: wordToInsert,
      startIndex: cursorPosition,
      endIndex: cursorPosition,
      isColumn: isColumn,
    );

    // Apply additional cursor adjustment for aggregation functions
    int finalOffset = formatResult.adjustedOffset;
    if (cursorAdjustment != 0) {
      finalOffset += cursorAdjustment;
    }

    // Update the controller's value
    controller.value = TextEditingValue(
      text: formatResult.formattedText,
      selection: TextSelection.collapsed(offset: finalOffset),
    );

    controller.popupController.hide();

    // Show column suggestions if we inserted a table name
    _showColumnSuggestionsIfTable(formatResult.isTable, selectedWord);
  }

  /// Handles normal insertion with a valid prefix start index
  void _handleNormalInsertion(
    TextSelection previousSelection,
    bool isColumn,
    String selectedWord,
    int startIndex,
    int endIndex,
  ) {
    String wordToInsert = selectedWord;
    int cursorAdjustment = 0;

    // Check if this is an aggregation function and add brackets if needed
    if (_isInSqlContext(controller.text) &&
        _isSqlAggregationFunction(selectedWord)) {
      wordToInsert = "$selectedWord()";
      cursorAdjustment = -1; // Position cursor inside the brackets
    }

    // Format the text and adjust the cursor offset
    var formatResult = controller.formatAndAdjustOffset(
      originalText: controller.text,
      selectedWord: wordToInsert,
      startIndex: startIndex,
      endIndex: endIndex,
      isColumn: isColumn,
    );

    // Apply additional cursor adjustment for aggregation functions
    int finalOffset = formatResult.adjustedOffset;
    if (cursorAdjustment != 0) {
      finalOffset += cursorAdjustment;
    }

    // Update the controller's value
    controller.value = TextEditingValue(
      text: formatResult.formattedText,
      selection: TextSelection.collapsed(offset: finalOffset),
    );

    // Show or hide the popup based on conditions
    if (formatResult.formattedText.contains('$selectedWord()') &&
        controller.mainTableFields.isNotEmpty) {
      _showMainTableFields();
    } else {
      controller.popupController.hide();
    }

    controller.lastPrefixStartIndex = null;

    // Show column suggestions if we inserted a table name
    _showColumnSuggestionsIfTable(formatResult.isTable, selectedWord);
  }

  /// Shows column suggestions for a table if needed
  void _showColumnSuggestionsIfTable(bool isTable, String tableName) {
    if (isTable) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        controller.popupController.showOnlyColumnsOfTable(tableName);
      });
    }
  }

  /// Shows suggestions for main table fields
  void _showMainTableFields() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      print('showMainTableFields');
      controller.popupController.show(null, controller.mainTableFields);
    });
  }
}
