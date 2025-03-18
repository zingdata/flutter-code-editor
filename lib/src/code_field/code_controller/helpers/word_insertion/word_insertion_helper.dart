import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:flutter_code_editor/src/code_field/code_controller/code_controller.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/helpers/formatter/sql_formatter.dart';

/// Helper class for handling word insertion from autocomplete
class WordInsertionHelper {
  /// Create a word insertion helper for a specific code controller
  WordInsertionHelper(this.controller);
  final CodeController controller;

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
    final selectedWord = keyword ?? controller.popupController.getSelectedWord();
    final isColumn = isKeywordColumn ?? controller.popupController.isColumn();

    try {
      // Handle case where we don't have a defined prefix start index
      if (controller.lastPrefixStartIndex == null) {
        _handleInsertionWithoutPrefixIndex(previousSelection, isColumn, selectedWord);
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
          startIndex, 
          endIndex, 
          selectedWord, 
          textBeingReplaced
        );
      }

      // Normal insertion with adjusted start index
      _handleNormalInsertion(previousSelection, isColumn, selectedWord, startIndex, endIndex);
    } finally {
      // Always reset insertion flag when done, even if exception occurs
      controller.isInsertingWord = false;
    }
  }

  /// Determines the appropriate start index for multi-word identifier replacements
  int _determineMultiWordReplacementStart(
    int startIndex, 
    int endIndex, 
    String selectedWord, 
    String textBeingReplaced
  ) {
    // If what's being typed doesn't contain spaces, we should only replace that word
    if (!textBeingReplaced.contains(' ')) {
      // This is a simple case, just replace what's been typed
      return startIndex;
    }
    
    // Split both strings into word tokens for comparison
    final selectedTokens = selectedWord.split(' ');
    final replacedTokens = textBeingReplaced.split(' ');
    
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
            selectedTokens[i].toLowerCase() == replacedTokens[i].toLowerCase()) {
          matchingTokens++;
        } else {
          break;
        }
      }
      
      // If at least the first word matches and we typed part of a multi-word phrase,
      // replace from the start of the matching phrase
      if (matchingTokens > 0 || 
          (replacedTokens.length == 1 && 
           selectedTokens.length > 1 && 
           selectedTokens[0].toLowerCase().startsWith(replacedTokens[0].toLowerCase()))) {
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

  /// Handles insertion when we don't have a valid prefix start index
  void _handleInsertionWithoutPrefixIndex(
      TextSelection previousSelection, bool isColumn, String selectedWord) {
    final cursorPosition = previousSelection.baseOffset;

    // Format the text and adjust the cursor offset
    var formatResult = controller.formatAndAdjustOffset(
      originalText: controller.text,
      selectedWord: selectedWord,
      startIndex: cursorPosition,
      endIndex: cursorPosition,
      isColumn: isColumn,
    );

    // Update the controller's value
    controller.value = TextEditingValue(
      text: formatResult.formattedText,
      selection: TextSelection.collapsed(offset: formatResult.adjustedOffset),
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
    // Format the text and adjust the cursor offset
    var formatResult = controller.formatAndAdjustOffset(
      originalText: controller.text,
      selectedWord: selectedWord,
      startIndex: startIndex,
      endIndex: endIndex,
      isColumn: isColumn,
    );

    // Update the controller's value
    controller.value = TextEditingValue(
      text: formatResult.formattedText,
      selection: TextSelection.collapsed(offset: formatResult.adjustedOffset),
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
      controller.popupController.show(null, controller.mainTableFields);
    });
  }
}
