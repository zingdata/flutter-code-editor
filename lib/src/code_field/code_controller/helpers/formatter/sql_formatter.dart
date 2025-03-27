/// Result of formatting a SQL fragment
class SqlFormatResult {
  SqlFormatResult({
    required this.formattedText,
    required this.adjustedOffset,
    required this.isTable,
  });
  final String formattedText;
  final int adjustedOffset;
  final bool isTable;
}

/// Helper class for SQL formatting operations
/// Provides utilities for formatting SQL expressions and handling
/// SQL-specific notation like table.column patterns and function calls
class SqlFormatter {
  /// List of SQL aggregation functions that should have brackets
  static const List<String> aggregationsWithBrackets = ['SUM', 'COUNT', 'MIN', 'MAX', 'AVG'];

  /// List of SQL keywords that should not be quoted
  static const List<String> sqlKeywords = [
    'SELECT',
    'FROM',
    'GROUP BY',
    'WHERE',
    'DISTINCT',
    'JOIN',
    'INNER JOIN',
    'LEFT JOIN',
    'RIGHT JOIN',
    'HAVING',
    'LIMIT',
    'ORDER BY',
    'AS',
    'ON',
    'AND',
    'OR',
    'IN',
    'NOT',
    'IS NULL',
    'IS NOT NULL',
    'BETWEEN',
    'LIKE',
  ];

  /// Formats SQL text for insertion based on context
  ///
  /// Handles SQL-specific patterns like:
  /// - Adding parentheses to function calls
  /// - Adding quotes to identifiers
  /// - Smart handling of table.column notation
  /// - Context-aware space insertion
  /// - Properly handling multi-word identifiers with spaces
  static SqlFormatResult formatSql({
    required String originalText,
    required String selectedWord,
    required int startIndex,
    required int endIndex,
    required bool needsQuotes,
    required bool needDotForTable,
    required List<String> mainTables,
    bool isColumn = false,
  }) {
    // Check surrounding context before and after insertion point
    final prefixText = startIndex > 0 ? originalText.substring(0, startIndex) : '';
    final suffixText = endIndex < originalText.length ? originalText.substring(endIndex) : '';

    // Check if we're in a specific SQL context (after table.)
    final inColumnContext = isInColumnContext(prefixText);
    final tableName = inColumnContext ? extractTableNameFromPrefix(prefixText) : null;

    // Detect if we're continuing an existing function call
    final isInFunctionContext = isInsideFunctionCall(prefixText);

    // Detect if the selectedWord contains spaces (multi-word identifier)
    final containsSpaces = selectedWord.contains(' ');

    final isSqlKeyword = sqlKeywords.contains(selectedWord.toUpperCase());

    final isAggregationFunction =
        aggregationsWithBrackets.contains(selectedWord.replaceAll('(', '').replaceAll(')', ''));

    // Determine if a space should be added based on SQL element type and context
    bool addSpace = isAggregationFunction
        ? false
        : shouldAddSpace(
            selectedWord: selectedWord,
            suffixText: suffixText,
            isSqlKeyword: isSqlKeyword,
            isColumn: isColumn,
            inColumnContext: inColumnContext,
          );

    // Handle SQL-specific patterns
    if (aggregationsWithBrackets.contains(selectedWord)) {
      return _formatAggregationFunction(
        originalText: originalText,
        selectedWord: selectedWord,
        startIndex: startIndex,
        endIndex: endIndex,
        isInsideFunctionCall: isInFunctionContext,
        suffixText: suffixText,
      );
    } else if (mainTables.contains(selectedWord)) {
      return _formatTableName(
        originalText: originalText,
        selectedWord: selectedWord,
        startIndex: startIndex,
        endIndex: endIndex,
        needsQuotes: needsQuotes || containsSpaces, // Always quote multi-word tables
        needDotForTable: needDotForTable,
        inColumnContext: inColumnContext,
        suffixText: suffixText,
      );
    } else if ((inColumnContext && tableName != null) || isColumn) {
      return _formatColumnName(
        originalText: originalText,
        selectedWord: selectedWord,
        startIndex: startIndex,
        endIndex: endIndex,
        addSpace: addSpace,
        suffixText: suffixText,
        needsQuotes: containsSpaces, // Auto-quote columns with spaces
      );
    } else if ((containsSpaces && !isSqlKeyword) || (needsQuotes && !isSqlKeyword)) {
      // Always quote identifiers with spaces, regardless of the needsQuotes setting
      return _formatQuotedIdentifier(
        originalText: originalText,
        selectedWord: selectedWord,
        startIndex: startIndex,
        endIndex: endIndex,
        addSpace: addSpace,
      );
    } else {
      return _formatSqlKeywordOrLiteral(
        originalText: originalText,
        selectedWord: selectedWord,
        startIndex: startIndex,
        endIndex: endIndex,
        addSpace: addSpace,
        suffixText: suffixText,
      );
    }
  }

  /// Determines if a space should be added after the inserted text
  /// based on SQL context and element type
  static bool shouldAddSpace({
    required String selectedWord,
    required String suffixText,
    required bool isSqlKeyword,
    required bool isColumn,
    required bool inColumnContext,
  }) {
    // First, handle cases based primarily on the selected word
    final upperWord = selectedWord.toUpperCase();

    // Always add space after SQL keywords (SELECT, FROM, WHERE, etc.)
    if (isSqlKeyword) {
      return true;
    }

    // Handle aggregation functions - don't add space unless there's content after
    if (aggregationsWithBrackets.contains(upperWord)) {
      return false; // No space before parentheses
    }

    // Add space after columns in a SELECT clause
    if (isColumn) {
      return true;
    }

    // Now, only if suffixText is not empty, consider it
    if (suffixText.isNotEmpty) {
      // Don't add space if there's already a space
      if (suffixText.startsWith(' ')) {
        return false;
      }

      // Don't add space before these punctuation marks
      if (suffixText.startsWith(')') || suffixText.startsWith(',') || suffixText.startsWith('.')) {
        return false;
      }

      // Don't add space before operators
      if (suffixText.startsWith('=') ||
          suffixText.startsWith('<') ||
          suffixText.startsWith('>') ||
          suffixText.startsWith('+') ||
          suffixText.startsWith('-') ||
          suffixText.startsWith('*') ||
          suffixText.startsWith('/')) {
        return false;
      }
    }

    // For table names that might be followed by a dot
    if (inColumnContext) {
      return false;
    }

    // Default behavior: add space after most words that aren't followed by punctuation
    return true;
  }

  /// Format an aggregation function (SUM, COUNT, etc.)
  static SqlFormatResult _formatAggregationFunction({
    required String originalText,
    required String selectedWord,
    required int startIndex,
    required int endIndex,
    required bool isInsideFunctionCall,
    required String suffixText,
  }) {
    // Don't add parentheses if we're already inside a function call
    // or if the next character is already an opening parenthesis
    if (isInsideFunctionCall || suffixText.startsWith('(')) {
      final formattedText = originalText.replaceRange(startIndex, endIndex, selectedWord);
      return SqlFormatResult(
        formattedText: formattedText,
        adjustedOffset: startIndex + selectedWord.length,
        isTable: false,
      );
    } else {
      final insertionText = '$selectedWord()';
      final formattedText = originalText.replaceRange(startIndex, endIndex, insertionText);
      return SqlFormatResult(
        formattedText: formattedText,
        adjustedOffset: startIndex + insertionText.length - 1, // Position cursor inside parentheses
        isTable: false,
      );
    }
  }

  /// Format a table name, optionally with quotes and/or trailing dot
  static SqlFormatResult _formatTableName({
    required String originalText,
    required String selectedWord,
    required int startIndex,
    required int endIndex,
    required bool needsQuotes,
    required bool needDotForTable,
    required bool inColumnContext,
    required String suffixText,
  }) {
    // Check if we should add quotes and dot
    bool shouldAddQuotes =
        needsQuotes && !selectedWord.startsWith('"') && !selectedWord.endsWith('"');

    // Don't add dot if we're already in a dot context or the next char is a dot
    bool shouldAddDot = needDotForTable && !suffixText.startsWith('.') && !inColumnContext;

    String insertionText;
    int adjustedOffset;

    if (shouldAddQuotes) {
      insertionText = '"$selectedWord"${shouldAddDot ? '.' : ''}';
      adjustedOffset = startIndex + selectedWord.length + 2 + (shouldAddDot ? 1 : 0);
    } else {
      insertionText = '$selectedWord${shouldAddDot ? '.' : ''}';
      adjustedOffset = startIndex + selectedWord.length + (shouldAddDot ? 1 : 0);
    }

    final formattedText = originalText.replaceRange(startIndex, endIndex, insertionText);
    return SqlFormatResult(
      formattedText: formattedText,
      adjustedOffset: adjustedOffset,
      isTable: true,
    );
  }

  /// Format a column name after a table.
  static SqlFormatResult _formatColumnName({
    required String originalText,
    required String selectedWord,
    required int startIndex,
    required int endIndex,
    required bool addSpace,
    required String suffixText,
    bool needsQuotes = false,
  }) {
    // Add quotes for multi-word column names
    String insertionText;
    int adjustedOffset;

    if (needsQuotes && !selectedWord.startsWith('"') && !selectedWord.endsWith('"')) {
      insertionText = '"$selectedWord"';
      adjustedOffset = startIndex + selectedWord.length + 2; // +2 for quotes
    } else {
      insertionText = selectedWord;
      adjustedOffset = startIndex + selectedWord.length;
    }

    // Add space only if needed and we're not in the middle of an expression
    if (addSpace && !isInSqlExpression(suffixText)) {
      insertionText += ' ';
      adjustedOffset += 1;
    }

    final formattedText = originalText.replaceRange(startIndex, endIndex, insertionText);
    return SqlFormatResult(
      formattedText: formattedText,
      adjustedOffset: adjustedOffset,
      isTable: false,
    );
  }

  /// Format an identifier that needs quotes
  static SqlFormatResult _formatQuotedIdentifier({
    required String originalText,
    required String selectedWord,
    required int startIndex,
    required int endIndex,
    required bool addSpace,
  }) {
    final insertionText = '"$selectedWord"${addSpace ? ' ' : ''}';
    final formattedText = originalText.replaceRange(startIndex, endIndex, insertionText);
    return SqlFormatResult(
      formattedText: formattedText,
      adjustedOffset: startIndex + selectedWord.length + 2 + (addSpace ? 1 : 0), // +2 for quotes
      isTable: false,
    );
  }

  /// Format an SQL keyword or literal
  static SqlFormatResult _formatSqlKeywordOrLiteral({
    required String originalText,
    required String selectedWord,
    required int startIndex,
    required int endIndex,
    required bool addSpace,
    required String suffixText,
  }) {
    String insertionText = selectedWord;

    // Only add space after keywords and before identifiers
    if (addSpace &&
        (sqlKeywords.contains(selectedWord.toUpperCase()) ||
            shouldAddSpaceAfter(selectedWord, suffixText))) {
      insertionText += ' ';
    }

    final formattedText = originalText.replaceRange(startIndex, endIndex, insertionText);
    return SqlFormatResult(
      formattedText: formattedText,
      adjustedOffset: startIndex + insertionText.length,
      isTable: false,
    );
  }

  /// Checks if we're in a column context (right after table.)
  static bool isInColumnContext(String prefixText) {
    if (prefixText.isEmpty) return false;

    // Look for pattern where the last non-whitespace character is a dot
    final trimmedPrefix = prefixText.trimRight();
    return trimmedPrefix.isNotEmpty && trimmedPrefix.endsWith('.');
  }

  /// Extract table name from prefix like "SELECT * FROM users."
  static String? extractTableNameFromPrefix(String prefixText) {
    if (!isInColumnContext(prefixText)) return null;

    final dotIndex = prefixText.lastIndexOf('.');
    if (dotIndex <= 0) return null;

    return extractPotentialTableName(prefixText, dotIndex);
  }

  /// Extracts a potential table name from text before a dot
  static String extractPotentialTableName(String text, int dotIndex) {
    // Start from the dot and move backward to find the start of the table name
    int startIndex = dotIndex - 1;

    // Skip trailing whitespace
    while (startIndex >= 0 && text[startIndex] == ' ') {
      startIndex--;
    }

    if (startIndex < 0) return '';

    // Check if we're dealing with a quoted identifier
    if (startIndex >= 0 && text[startIndex] == '"') {
      // Find the opening quote
      int openQuoteIndex = text.lastIndexOf('"', startIndex - 1);
      if (openQuoteIndex >= 0) {
        // Extract the quoted identifier (including quotes)
        return text.substring(openQuoteIndex, startIndex + 1);
      }
    }

    // Find the beginning of the word
    int wordStart = startIndex;
    while (wordStart >= 0 && (isLetterOrDigit(text[wordStart]) || text[wordStart] == '_')) {
      wordStart--;
    }

    // Extract the word
    String tableName = text.substring(wordStart + 1, startIndex + 1);

    // If the table name is in quotes, remove them
    if (tableName.startsWith('"') && tableName.endsWith('"')) {
      tableName = tableName.substring(1, tableName.length - 1);
    }

    return tableName;
  }

  /// Find the start of a multi-word phrase in text
  /// This is useful for detecting when the user has typed part of a multi-word identifier
  static int findMultiWordPhraseStart(String text, int endPosition) {
    if (endPosition <= 0 || text.isEmpty) return endPosition;

    // Start from the end position and move backward
    int position = endPosition;
    bool foundSpace = false;

    // Check if we're in the middle of a quoted identifier
    int quotePos = text.lastIndexOf('"', position - 1);
    if (quotePos >= 0) {
      int closingQuote = text.indexOf('"', quotePos + 1);
      // If we're between quotes, return the position of the opening quote
      if (closingQuote == -1 || closingQuote >= position) {
        return quotePos;
      }
    }

    // Otherwise, try to find a phrase with spaces
    while (position > 0) {
      position--;

      // Check for word boundary characters that would end our search
      if (",.;:(){}[]\"\'`=+-*/\\".contains(text[position])) {
        return position + 1; // Start after the boundary character
      }

      // Track if we've seen a space
      if (text[position] == ' ') {
        foundSpace = true;
      }

      // If we've found a space and then a non-space, we might be in a multi-word phrase
      if (foundSpace && text[position] != ' ' && position > 0 && text[position - 1] == ' ') {
        // Check if previous word is part of the same phrase or a boundary
        int prevWordStart = position - 1;
        while (prevWordStart > 0 && text[prevWordStart - 1] == ' ') {
          prevWordStart--;
        }

        int wordBoundary = prevWordStart;
        while (wordBoundary > 0 && !",;:(){}[]\"\'`=+-*/\\".contains(text[wordBoundary - 1])) {
          wordBoundary--;
        }

        // If we found a word before our space, include it in the phrase
        if (wordBoundary < prevWordStart) {
          position = wordBoundary;
        }
      }
    }

    return position;
  }

  /// Check if we're inside a function call like "COUNT("
  static bool isInsideFunctionCall(String prefixText) {
    final trimmedPrefix = prefixText.trimRight();

    // Check if we're inside an open parenthesis
    int openParens = 0;
    int closeParens = 0;

    for (int i = 0; i < trimmedPrefix.length; i++) {
      if (trimmedPrefix[i] == '(') openParens++;
      if (trimmedPrefix[i] == ')') closeParens++;
    }

    return openParens > closeParens;
  }

  /// Check if the suffix is part of an SQL expression
  static bool isInSqlExpression(String suffixText) {
    if (suffixText.isEmpty) return false;

    // Operators or characters that indicate we're in an expression
    const expressionChars = ['+', '-', '*', '/', '=', '<', '>', '!', ')', ','];

    // Check the first non-whitespace character
    for (int i = 0; i < suffixText.length; i++) {
      if (suffixText[i].trim().isEmpty) continue;
      return expressionChars.contains(suffixText[i]);
    }

    return false;
  }

  /// Determine if we should add a space after this word
  static bool shouldAddSpaceAfter(String word, String suffix) {
    // Always add space after SQL keywords
    if (sqlKeywords.contains(word.toUpperCase())) {
      return true;
    }

    // Don't add space if followed by punctuation
    if (suffix.startsWith('.') ||
        suffix.startsWith(',') ||
        suffix.startsWith(')') ||
        suffix.startsWith(';')) {
      return false;
    }

    // Default to adding a space
    return true;
  }

  /// Check if a character is a letter or digit
  static bool isLetterOrDigit(String char) {
    if (char.isEmpty) return false;

    final codeUnit = char.codeUnitAt(0);
    return (codeUnit >= 48 && codeUnit <= 57) || // 0-9
        (codeUnit >= 65 && codeUnit <= 90) || // A-Z
        (codeUnit >= 97 && codeUnit <= 122); // a-z
  }
}
