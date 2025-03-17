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

    // Check if we need to add a space after the inserted text
    bool addSpace = !suffixText.startsWith(' ') &&
        !suffixText.startsWith(')') &&
        !suffixText.startsWith(',') &&
        suffixText.isNotEmpty;

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
        needsQuotes: needsQuotes,
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
      );
    } else if (needsQuotes && !sqlKeywords.contains(selectedWord.toUpperCase())) {
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
  }) {
    // Don't add quotes here since we're in column context
    String insertionText = selectedWord;

    // Add space only if needed and we're not in the middle of an expression
    if (addSpace && !isInSqlExpression(suffixText)) {
      insertionText += ' ';
    }

    final formattedText = originalText.replaceRange(startIndex, endIndex, insertionText);
    return SqlFormatResult(
      formattedText: formattedText,
      adjustedOffset: startIndex + insertionText.length,
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
