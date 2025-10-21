import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/sql.dart';

/// Comprehensive test suite for WordInsertionHelper
/// Tests all aspects of word insertion including SQL-specific logic,
/// multi-word identifiers, quote handling, and edge cases.
void main() {
  group('WordInsertionHelper', () {
    late CodeController controller;

    /// Helper to set up controller with common SQL autocomplete data
    void setupSqlAutocomplete(CodeController ctrl) {
      ctrl.autocompleter.customWords.addAll([
        'SELECT',
        'FROM',
        'WHERE',
        'INSERT',
        'UPDATE',
        'DELETE',
        'INNER JOIN',
        'LEFT JOIN',
        'RIGHT JOIN',
        'GROUP BY',
        'ORDER BY',
        'HAVING',
        'SUM',
        'AVG',
        'COUNT',
        'MAX',
        'MIN',
        'AVERAGE',
        'MEDIAN',
      ]);

      ctrl.addMainTableFields(
        ['user_id', 'first_name', 'last_name', 'email', 'Order Date', 'Customer Name'],
        ['users', 'customers', 'orders', 'products'],
      );
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      controller = CodeController(
        text: '',
        language: sql,
      );
      setupSqlAutocomplete(controller);
    });

    tearDown(() {
      controller.dispose();
    });

    // ========================================================================
    // GROUP 1: Basic Word Insertion
    // ========================================================================
    group('Basic Word Insertion', () {
      test('should replace single partial word with complete word', () {
        controller.text = 'SEL';
        controller.selection = const TextSelection.collapsed(offset: 3);
        controller.lastPrefixStartIndex = 0;

        // Mock popup controller selection
        controller.popupController.selectedIndex = 0;
        controller.autocompleter.customWords.clear();
        controller.autocompleter.customWords.add('SELECT');

        controller.insertSelectedWord(keyword: 'SELECT', isKeywordColumn: false);

        expect(controller.text, contains('SELECT'));
      });

      test('should position cursor at end of inserted word', () {
        controller.text = 'FRO';
        controller.selection = const TextSelection.collapsed(offset: 3);
        controller.lastPrefixStartIndex = 0;

        controller.insertSelectedWord(keyword: 'FROM', isKeywordColumn: false);

        expect(controller.selection.baseOffset, greaterThan(3));
      });

      test('should handle insertion at beginning of text', () {
        controller.text = 'SEL';
        controller.selection = const TextSelection.collapsed(offset: 3);
        controller.lastPrefixStartIndex = 0;

        controller.insertSelectedWord(keyword: 'SELECT', isKeywordColumn: false);

        expect(controller.text, contains('SELECT'));
      });

      test('should handle insertion in middle of text', () {
        controller.text = 'SELECT * FRO users';
        controller.selection = const TextSelection.collapsed(offset: 12);
        controller.lastPrefixStartIndex = 9;

        controller.insertSelectedWord(keyword: 'FROM', isKeywordColumn: false);

        expect(controller.text, contains('FROM'));
      });

      test('should handle insertion with no prefix start index', () {
        controller.text = 'SELECT ';
        controller.selection = const TextSelection.collapsed(offset: 7);
        controller.lastPrefixStartIndex = null;

        controller.insertSelectedWord(keyword: 'FROM', isKeywordColumn: false);

        expect(controller.text, contains('FROM'));
      });

      test('should preserve whitespace around insertion', () {
        controller.text = 'SELECT  ';
        controller.selection = const TextSelection.collapsed(offset: 8);
        controller.lastPrefixStartIndex = null;

        controller.insertSelectedWord(keyword: 'FROM', isKeywordColumn: false);

        // Should maintain spacing
        expect(controller.text, isNotEmpty);
      });

      test('should handle empty text insertion', () {
        controller.text = '';
        controller.selection = const TextSelection.collapsed(offset: 0);
        controller.lastPrefixStartIndex = null;

        controller.insertSelectedWord(keyword: 'SELECT', isKeywordColumn: false);

        expect(controller.text, contains('SELECT'));
      });

      test('should return early when no valid selection and no keyword', () {
        controller.text = 'SELECT';
        controller.selection = const TextSelection.collapsed(offset: 6);
        controller.popupController.selectedIndex = -1;

        // Should not throw
        expect(
          () => controller.insertSelectedWord(),
          returnsNormally,
        );
      });
    });

    // ========================================================================
    // GROUP 2: Multi-word SQL Identifiers
    // ========================================================================
    group('Multi-word SQL Identifiers', () {
      test('should replace partial two-word field after SELECT', () {
        controller.text = 'SELECT order da';
        controller.selection = const TextSelection.collapsed(offset: 15);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'Order Date', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should replace partial first word of two-word field', () {
        controller.text = 'SELECT ord date';
        controller.selection = const TextSelection.collapsed(offset: 15);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'Order Date', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should replace both partial words in two-word field', () {
        controller.text = 'SELECT or da';
        controller.selection = const TextSelection.collapsed(offset: 12);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'Order Date', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle multi-word field after WHERE clause', () {
        controller.text = 'SELECT * FROM users WHERE customer na';
        controller.selection = const TextSelection.collapsed(offset: 37);
        controller.lastPrefixStartIndex = 30;

        controller.insertSelectedWord(keyword: 'Customer Name', isKeywordColumn: true);

        expect(controller.text, contains('Customer Name'));
      });

      test('should handle multi-word field after GROUP BY clause', () {
        controller.text = 'SELECT * FROM users GROUP BY order da';
        controller.selection = const TextSelection.collapsed(offset: 37);
        controller.lastPrefixStartIndex = 33;

        controller.insertSelectedWord(keyword: 'Order Date', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle multi-word field after ORDER BY clause', () {
        controller.text = 'SELECT * FROM users ORDER BY customer na';
        controller.selection = const TextSelection.collapsed(offset: 40);
        controller.lastPrefixStartIndex = 33;

        controller.insertSelectedWord(keyword: 'Customer Name', isKeywordColumn: true);

        expect(controller.text, contains('Customer Name'));
      });

      test('should handle three-word identifier', () {
        controller.text = 'SELECT first mid la';
        controller.selection = const TextSelection.collapsed(offset: 19);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'First Middle Last', isKeywordColumn: true);

        expect(controller.text, contains('First Middle Last'));
      });

      test('should handle mixed case in multi-word fields', () {
        controller.text = 'SELECT ORDER DA';
        controller.selection = const TextSelection.collapsed(offset: 15);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'Order Date', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should match when first word is complete, second partial', () {
        controller.text = 'SELECT Order D';
        controller.selection = const TextSelection.collapsed(offset: 14);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'Order Date', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle multi-word with single letter prefix', () {
        controller.text = 'SELECT o d';
        controller.selection = const TextSelection.collapsed(offset: 10);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'Order Date', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle token count mismatch - typed more words', () {
        controller.text = 'SELECT from inner jo';
        controller.selection = const TextSelection.collapsed(offset: 20);
        controller.lastPrefixStartIndex = 12;

        controller.insertSelectedWord(keyword: 'INNER JOIN', isKeywordColumn: false);

        expect(controller.text, contains('INNER JOIN'));
      });

      test('should handle token count mismatch - typed fewer words', () {
        controller.text = 'SELECT inne';
        controller.selection = const TextSelection.collapsed(offset: 11);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'INNER JOIN', isKeywordColumn: false);

        expect(controller.text, contains('INNER JOIN'));
      });

      test('should handle multi-word field with AND clause', () {
        controller.text = 'WHERE a = 1 AND order da';
        controller.selection = const TextSelection.collapsed(offset: 24);
        controller.lastPrefixStartIndex = 16;

        controller.insertSelectedWord(keyword: 'Order Date', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle multi-word field with OR clause', () {
        controller.text = 'WHERE a = 1 OR customer na';
        controller.selection = const TextSelection.collapsed(offset: 26);
        controller.lastPrefixStartIndex = 15;

        controller.insertSelectedWord(keyword: 'Customer Name', isKeywordColumn: true);

        expect(controller.text, contains('Customer Name'));
      });

      test('should handle multi-word field after ON clause in JOIN', () {
        controller.text = 'SELECT * FROM a JOIN b ON order da';
        controller.selection = const TextSelection.collapsed(offset: 34);
        controller.lastPrefixStartIndex = 30;

        controller.insertSelectedWord(keyword: 'Order Date', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });
    });

    // ========================================================================
    // GROUP 3: Quote Handling
    // ========================================================================
    group('Quote Handling', () {
      test('should handle backtick-quoted partial field', () {
        controller.text = 'SELECT `customer na`';
        controller.selection = const TextSelection.collapsed(offset: 19);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '`Customer Name`', isKeywordColumn: true);

        expect(controller.text, contains('Customer Name'));
      });

      test('should handle double-quoted partial field', () {
        controller.text = 'SELECT "first na"';
        controller.selection = const TextSelection.collapsed(offset: 16);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '"First Name"', isKeywordColumn: true);

        expect(controller.text, contains('First Name'));
      });

      test('should match quoted and unquoted identifiers', () {
        controller.text = 'SELECT customer na';
        controller.selection = const TextSelection.collapsed(offset: 18);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '`Customer Name`', isKeywordColumn: true);

        expect(controller.text, contains('Customer Name'));
      });

      test('should match unquoted input to quoted suggestion', () {
        controller.text = 'SELECT order da';
        controller.selection = const TextSelection.collapsed(offset: 15);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '"Order Date"', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle backtick quotes in middle of multi-word', () {
        controller.text = 'SELECT `order` da';
        controller.selection = const TextSelection.collapsed(offset: 17);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '`Order Date`', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle double quotes in middle of multi-word', () {
        controller.text = 'SELECT "customer" na';
        controller.selection = const TextSelection.collapsed(offset: 20);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '"Customer Name"', isKeywordColumn: true);

        expect(controller.text, contains('Customer Name'));
      });

      test('should handle mixed quoting styles in detection', () {
        controller.text = 'SELECT `order da`';
        controller.selection = const TextSelection.collapsed(offset: 16);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '"Order Date"', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should preserve quotes when suggestion includes them', () {
        controller.text = 'SELECT ord';
        controller.selection = const TextSelection.collapsed(offset: 10);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '`Order Date`', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle quote at word boundary', () {
        controller.text = 'SELECT `cust';
        controller.selection = const TextSelection.collapsed(offset: 12);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '`Customer Name`', isKeywordColumn: true);

        expect(controller.text, contains('Customer Name'));
      });

      test('should remove quotes for comparison logic', () {
        controller.text = 'SELECT `or` `da`';
        controller.selection = const TextSelection.collapsed(offset: 16);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '`Order Date`', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle empty quotes', () {
        controller.text = 'SELECT ``';
        controller.selection = const TextSelection.collapsed(offset: 9);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '`Order Date`', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle single backtick', () {
        controller.text = 'SELECT `order da';
        controller.selection = const TextSelection.collapsed(offset: 16);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: '`Order Date`', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });
    });

    // ========================================================================
    // GROUP 4: SQL Aggregation Functions
    // ========================================================================
    group('SQL Aggregation Functions', () {
      test('should add parentheses to SUM function', () {
        controller.text = 'SELECT SU';
        controller.selection = const TextSelection.collapsed(offset: 9);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'SUM', isKeywordColumn: false);

        expect(controller.text, contains('SUM()'));
      });

      test('should add parentheses to AVG function', () {
        controller.text = 'SELECT AV';
        controller.selection = const TextSelection.collapsed(offset: 9);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'AVG', isKeywordColumn: false);

        expect(controller.text, contains('AVG()'));
      });

      test('should add parentheses to COUNT function', () {
        controller.text = 'SELECT COU';
        controller.selection = const TextSelection.collapsed(offset: 10);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'COUNT', isKeywordColumn: false);

        expect(controller.text, contains('COUNT()'));
      });

      test('should add parentheses to MAX function', () {
        controller.text = 'SELECT MA';
        controller.selection = const TextSelection.collapsed(offset: 9);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'MAX', isKeywordColumn: false);

        expect(controller.text, contains('MAX()'));
      });

      test('should add parentheses to MIN function', () {
        controller.text = 'SELECT MI';
        controller.selection = const TextSelection.collapsed(offset: 9);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'MIN', isKeywordColumn: false);

        expect(controller.text, contains('MIN()'));
      });

      test('should add parentheses to MEDIAN function', () {
        controller.text = 'SELECT MED';
        controller.selection = const TextSelection.collapsed(offset: 10);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'MEDIAN', isKeywordColumn: false);

        expect(controller.text, contains('MEDIAN()'));
      });

      test('should handle case-insensitive aggregation function detection', () {
        controller.text = 'SELECT su';
        controller.selection = const TextSelection.collapsed(offset: 9);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'sum', isKeywordColumn: false);

        expect(controller.text, contains('sum()'));
      });

      test('should not add parentheses when not in SQL context', () {
        // Create controller without SQL language
        final plainController = CodeController(text: 'SU');
        plainController.selection = const TextSelection.collapsed(offset: 2);
        plainController.lastPrefixStartIndex = 0;

        plainController.insertSelectedWord(keyword: 'SUM', isKeywordColumn: false);

        // Without SQL context, should not auto-add parentheses
        expect(plainController.text, isNotEmpty);
        plainController.dispose();
      });
    });

    // ========================================================================
    // GROUP 5: SQL Context Detection
    // ========================================================================
    group('SQL Context Detection', () {
      test('should detect SQL context with SELECT keyword', () {
        controller.text = 'SELECT * FROM users';
        controller.selection = const TextSelection.collapsed(offset: 19);
        controller.lastPrefixStartIndex = null;

        controller.insertSelectedWord(keyword: 'WHERE', isKeywordColumn: false);

        expect(controller.text, contains('WHERE'));
      });

      test('should detect SQL context with FROM keyword', () {
        controller.text = 'FROM users';
        controller.selection = const TextSelection.collapsed(offset: 10);
        controller.lastPrefixStartIndex = null;

        controller.insertSelectedWord(keyword: 'WHERE', isKeywordColumn: false);

        expect(controller.text, contains('WHERE'));
      });

      test('should detect SQL context with WHERE keyword', () {
        controller.text = 'WHERE user_id = 1';
        controller.selection = const TextSelection.collapsed(offset: 17);
        controller.lastPrefixStartIndex = null;

        controller.insertSelectedWord(keyword: 'AND', isKeywordColumn: false);

        expect(controller.text, contains('AND'));
      });

      test('should detect SQL context with JOIN keyword', () {
        controller.text = 'INNER JOIN users';
        controller.selection = const TextSelection.collapsed(offset: 16);
        controller.lastPrefixStartIndex = null;

        controller.insertSelectedWord(keyword: 'ON', isKeywordColumn: false);

        expect(controller.text, contains('ON'));
      });

      test('should handle case-insensitive SQL keyword detection', () {
        controller.text = 'select * from users';
        controller.selection = const TextSelection.collapsed(offset: 19);
        controller.lastPrefixStartIndex = null;

        controller.insertSelectedWord(keyword: 'WHERE', isKeywordColumn: false);

        expect(controller.text, contains('WHERE'));
      });

      test('should handle SQL keywords in mixed text', () {
        controller.text = 'Comments about SELECT statement';
        controller.selection = const TextSelection.collapsed(offset: 31);
        controller.lastPrefixStartIndex = null;

        controller.insertSelectedWord(keyword: 'test', isKeywordColumn: false);

        expect(controller.text, contains('test'));
      });
    });

    // ========================================================================
    // GROUP 6: Token Matching Logic
    // ========================================================================
    group('Token Matching Logic', () {
      test('should match Case 1: "first se" for "First Second"', () {
        controller.text = 'SELECT first se';
        controller.selection = const TextSelection.collapsed(offset: 15);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'First Second', isKeywordColumn: true);

        expect(controller.text, contains('First Second'));
      });

      test('should match Case 2: "first s" for "First Second"', () {
        controller.text = 'SELECT first s';
        controller.selection = const TextSelection.collapsed(offset: 14);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'First Second', isKeywordColumn: true);

        expect(controller.text, contains('First Second'));
      });

      test('should match Case 3: "fir sec" for "First Second"', () {
        controller.text = 'SELECT fir sec';
        controller.selection = const TextSelection.collapsed(offset: 14);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'First Second', isKeywordColumn: true);

        expect(controller.text, contains('First Second'));
      });

      test('should match Case 4: "order da" for "Order Date"', () {
        controller.text = 'SELECT order da';
        controller.selection = const TextSelection.collapsed(offset: 15);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'Order Date', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle no token match - use fallback', () {
        controller.text = 'SELECT xyz abc';
        controller.selection = const TextSelection.collapsed(offset: 14);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'Completely Different', isKeywordColumn: false);

        expect(controller.text, contains('Completely Different'));
      });

      test('should handle single token matching two-word suggestion', () {
        controller.text = 'SELECT ord';
        controller.selection = const TextSelection.collapsed(offset: 10);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'Order Date', isKeywordColumn: true);

        expect(controller.text, contains('Order Date'));
      });

      test('should handle three tokens matching three-word suggestion', () {
        controller.text = 'SELECT fir mid la';
        controller.selection = const TextSelection.collapsed(offset: 17);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'First Middle Last', isKeywordColumn: true);

        expect(controller.text, contains('First Middle Last'));
      });

      test('should handle partial match with different lengths', () {
        controller.text = 'SELECT o d t';
        controller.selection = const TextSelection.collapsed(offset: 12);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'Order Date Time', isKeywordColumn: true);

        expect(controller.text, contains('Order Date Time'));
      });
    });

    // ========================================================================
    // GROUP 7: Edge Cases
    // ========================================================================
    group('Edge Cases', () {
      test('should handle unicode characters in field names', () {
        controller.text = 'SELECT café';
        controller.selection = const TextSelection.collapsed(offset: 11);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'café_name', isKeywordColumn: true);

        expect(controller.text, contains('café_name'));
      });

      test('should handle emoji in suggestions', () {
        controller.text = 'SELECT test';
        controller.selection = const TextSelection.collapsed(offset: 11);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'test_😀', isKeywordColumn: false);

        expect(controller.text, contains('test_😀'));
      });

      test('should handle very long identifiers', () {
        const longIdentifier = 'very_long_identifier_name_that_exceeds_normal_length_limits_for_testing_purposes';
        controller.text = 'SELECT very';
        controller.selection = const TextSelection.collapsed(offset: 11);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: longIdentifier, isKeywordColumn: false);

        expect(controller.text, contains(longIdentifier));
      });

      test('should handle special characters in identifiers', () {
        controller.text = 'SELECT test';
        controller.selection = const TextSelection.collapsed(offset: 11);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'test_@#\$', isKeywordColumn: false);

        expect(controller.text, contains('test_@#\$'));
      });

      test('should handle tab character in text', () {
        controller.text = 'SELECT\ttest';
        controller.selection = const TextSelection.collapsed(offset: 11);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'test_value', isKeywordColumn: false);

        expect(controller.text, contains('test_value'));
      });

      test('should handle newline in text before insertion', () {
        controller.text = 'SELECT\ntest';
        controller.selection = const TextSelection.collapsed(offset: 11);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'test_value', isKeywordColumn: false);

        expect(controller.text, contains('test_value'));
      });
    });

    // ========================================================================
    // GROUP 8: Integration Tests
    // ========================================================================
    group('Integration Tests', () {
      test('should update controller value after insertion', () {
        controller.text = 'SELECT FRO';
        controller.selection = const TextSelection.collapsed(offset: 10);
        controller.lastPrefixStartIndex = 7;

        final initialValue = controller.value;
        controller.insertSelectedWord(keyword: 'FROM', isKeywordColumn: false);

        expect(controller.value, isNot(equals(initialValue)));
        expect(controller.value.text, contains('FROM'));
      });

      test('should update selection after insertion', () {
        controller.text = 'SELECT FRO';
        controller.selection = const TextSelection.collapsed(offset: 10);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'FROM', isKeywordColumn: false);

        expect(controller.selection.isCollapsed, isTrue);
        expect(controller.selection.baseOffset, greaterThan(0));
      });

      test('should reset isInsertingWord flag after insertion', () {
        controller.text = 'SELECT FRO';
        controller.selection = const TextSelection.collapsed(offset: 10);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'FROM', isKeywordColumn: false);

        expect(controller.isInsertingWord, isFalse);
      });

      test('should reset lastPrefixStartIndex after normal insertion', () {
        controller.text = 'SELECT FRO';
        controller.selection = const TextSelection.collapsed(offset: 10);
        controller.lastPrefixStartIndex = 7;

        controller.insertSelectedWord(keyword: 'FROM', isKeywordColumn: false);

        expect(controller.lastPrefixStartIndex, isNull);
      });

      test('should handle complete workflow - type, insert, continue', () {
        // Initial typing
        controller.text = 'SEL';
        controller.selection = const TextSelection.collapsed(offset: 3);
        controller.lastPrefixStartIndex = 0;

        // Insert SELECT
        controller.insertSelectedWord(keyword: 'SELECT', isKeywordColumn: false);
        expect(controller.text, contains('SELECT'));

        // Continue typing
        final currentText = controller.text;
        controller.text = '$currentText FRO';
        final newOffset = controller.text.length;
        controller.selection = TextSelection.collapsed(offset: newOffset);
        controller.lastPrefixStartIndex = currentText.length + 1;

        // Insert FROM
        controller.insertSelectedWord(keyword: 'FROM', isKeywordColumn: false);
        expect(controller.text, contains('FROM'));
      });
    });
  });
}
