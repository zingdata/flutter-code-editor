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

      // Check if the selected word contains spaces (multi-word identifier)
      final containsSpaces = selectedWord.contains(' ');

      // For multi-word identifiers, we need to extend the prefix start to include
      // any partial words before the current start index
      int startIndex = controller.lastPrefixStartIndex!;
      final endIndex = previousSelection.baseOffset;

      if (containsSpaces && startIndex < endIndex) {
        // Get the text before the cursor
        final textBeforeCursor = controller.text.substring(0, endIndex);

        // Check if we're already in the middle of typing a multi-word phrase
        if (startIndex > 0 && textBeforeCursor[startIndex - 1] == ' ') {
          // Find the start of the entire phrase by looking for word boundaries
          int phraseStart = SqlFormatter.findMultiWordPhraseStart(textBeforeCursor, startIndex);
          if (phraseStart < startIndex) {
            // Update the start index to include the entire phrase
            startIndex = phraseStart;
          }
        }

        // Also handle case where the user has typed the first word and part of the second
        // For example "pet ty" for "Pet Type"
        final partialTyped = textBeforeCursor.substring(startIndex, endIndex);
        if (partialTyped.contains(' ')) {
          // User has typed something with a space, ensure we find the real start
          int phraseStart = SqlFormatter.findMultiWordPhraseStart(textBeforeCursor, endIndex);
          if (phraseStart < startIndex) {
            startIndex = phraseStart;
          }
        }
      }

      // Normal insertion with adjusted start index
      _handleNormalInsertion(previousSelection, isColumn, selectedWord, startIndex, endIndex);
    } finally {
      // Always reset insertion flag when done, even if exception occurs
      controller.isInsertingWord = false;
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
