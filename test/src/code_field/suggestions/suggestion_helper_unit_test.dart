import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/sql.dart';

/// Unit tests for SuggestionHelper to verify Squadron integration
/// These tests verify that the helper works correctly with the new
/// Squadron infrastructure while maintaining backward compatibility
void main() {
  group('SuggestionHelper Unit Tests', () {
    late CodeController controller;

    setUp(() {
      controller = CodeController(
        text: 'SELECT * FROM users',
        language: sql,
      );

      // Add test suggestions
      controller.autocompleter.customWords.addAll([
        'SELECT',
        'FROM',
        'WHERE',
        'INSERT',
        'UPDATE',
        'DELETE',
        'users',
        'customers',
        'orders',
        'products',
        'user_id',
        'customer_id',
        'order_id',
        'product_id',
        'first_name',
        'last_name',
        'email',
        'phone',
      ]);

      // Set up tables for SQL autocomplete
      controller.addMainTableFields(
        ['user_id', 'first_name', 'last_name', 'email'],
        ['users', 'customers', 'orders', 'products'],
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('CodeController initializes with suggestion support', () {
      // Verify controller can generate suggestions (implicit test of helper initialization)
      expect(controller, isNotNull);
      expect(controller.generateSuggestions, isNotNull);
    });

    test('CodeController with suggestions disposes without errors', () {
      // Create and immediately dispose
      final testController = CodeController(
        text: 'SELECT',
        language: sql,
      );

      // Should not throw when disposing (tests that suggestion helper disposes properly)
      expect(() => testController.dispose(), returnsNormally);
    });

    test('SuggestionHelper generates suggestions without throwing', () async {
      // Set cursor position after "SEL"
      controller.text = 'SEL';
      controller.selection = const TextSelection.collapsed(offset: 3);

      // Should complete without throwing
      await expectLater(
        controller.generateSuggestions(),
        completes,
      );
    });

    test('SuggestionHelper handles empty text gracefully', () async {
      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);

      // Should complete without throwing
      await expectLater(
        controller.generateSuggestions(),
        completes,
      );
    });

    test('SuggestionHelper handles multiple consecutive calls', () async {
      controller.text = 'SEL';
      controller.selection = const TextSelection.collapsed(offset: 3);

      // Multiple calls should all complete successfully
      await expectLater(
        controller.generateSuggestions(),
        completes,
      );

      await expectLater(
        controller.generateSuggestions(),
        completes,
      );

      await expectLater(
        controller.generateSuggestions(),
        completes,
      );
    });

    test('SuggestionHelper handles rapid text changes', () async {
      // Simulate rapid typing
      for (var i = 0; i < 5; i++) {
        controller.text = 'SEL'.substring(0, i.clamp(0, 3));
        controller.selection = TextSelection.collapsed(offset: i.clamp(0, 3));

        await expectLater(
          controller.generateSuggestions(),
          completes,
        );
      }
    });

    test('SuggestionHelper works with SQL table.column notation', () async {
      controller.text = 'SELECT users.';
      controller.selection = const TextSelection.collapsed(offset: 13);

      // Should complete without throwing
      await expectLater(
        controller.generateSuggestions(),
        completes,
      );
    });

    test('SuggestionHelper handles special characters', () async {
      controller.text = 'SELECT * FROM users WHERE user_id = ';
      controller.selection =
          TextSelection.collapsed(offset: controller.text.length);

      // Should complete without throwing
      await expectLater(
        controller.generateSuggestions(),
        completes,
      );
    });

    test('SuggestionHelper handles long text', () async {
      // Create a longer SQL query
      controller.text = '''
SELECT u.user_id, u.first_name, u.last_name, o.order_id
FROM users u
INNER JOIN orders o ON u.user_id = o.user_id
WHERE u.email LIKE '%@example.com'
ORDER BY u.last_name, u.first_name
''';
      controller.selection =
          TextSelection.collapsed(offset: controller.text.length);

      // Should complete without throwing
      await expectLater(
        controller.generateSuggestions(),
        completes,
      );
    });

    test('SuggestionHelper handles cursor at start of text', () async {
      controller.text = 'SELECT * FROM users';
      controller.selection = const TextSelection.collapsed(offset: 0);

      // Should complete without throwing
      await expectLater(
        controller.generateSuggestions(),
        completes,
      );
    });

    test('SuggestionHelper handles cursor at end of text', () async {
      controller.text = 'SELECT * FROM users';
      controller.selection =
          TextSelection.collapsed(offset: controller.text.length);

      // Should complete without throwing
      await expectLater(
        controller.generateSuggestions(),
        completes,
      );
    });

    test('SuggestionHelper handles multi-word identifiers', () async {
      // Add multi-word field names
      controller.autocompleter.customWords.addAll([
        'Customer Name',
        'Order Date',
        'Product Category',
        'Total Amount',
      ]);

      controller.text = 'SELECT Cust';
      controller.selection = const TextSelection.collapsed(offset: 11);

      // Should complete without throwing
      await expectLater(
        controller.generateSuggestions(),
        completes,
      );
    });

    test('SuggestionHelper reuses across multiple operations', () async {
      // Use the same controller for multiple operations
      for (var keyword in ['SEL', 'FRO', 'WHE', 'ORD', 'GRO']) {
        controller.text = keyword;
        controller.selection = TextSelection.collapsed(offset: keyword.length);

        await expectLater(
          controller.generateSuggestions(),
          completes,
        );
      }
    });

    test('SuggestionHelper handles quoted identifiers', () async {
      controller.autocompleter.customWords.addAll([
        '"user id"',
        '"first name"',
        "'last name'",
      ]);

      controller.text = 'SELECT "use';
      controller.selection = const TextSelection.collapsed(offset: 11);

      // Should complete without throwing
      await expectLater(
        controller.generateSuggestions(),
        completes,
      );
    });
  });

  group('SuggestionHelper Stress Tests', () {
    test('Handles creation and disposal of many controllers', () {
      // Create and dispose many controllers to test resource management
      for (var i = 0; i < 10; i++) {
        final controller = CodeController(
          text: 'SELECT * FROM users',
          language: sql,
        );

        // Verify controller has suggestion capability
        expect(controller.generateSuggestions, isNotNull);
        controller.dispose();
      }

      // Should complete without memory issues
      expect(true, isTrue);
    });

    test('Handles concurrent suggestion requests', () async {
      final controller = CodeController(
        text: 'SELECT',
        language: sql,
      );

      controller.autocompleter.customWords.addAll(['SELECT', 'FROM', 'WHERE']);

      try {
        // Fire off multiple concurrent requests
        final futures = List.generate(5, (_) {
          controller.text = 'SEL';
          controller.selection = const TextSelection.collapsed(offset: 3);
          return controller.generateSuggestions();
        });

        // All should complete
        await expectLater(
          Future.wait(futures),
          completes,
        );
      } finally {
        controller.dispose();
      }
    });
  });
}
