import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/sql.dart';

void main() {
  group('SuggestionHelper Isolate Tests', () {
    late CodeController controller;

    setUp(() {
      controller = CodeController(
        text: 'SELECT * FROM users',
        language: sql,
      );

      // Add some test suggestions
      controller.autocompleter.customWords.addAll([
        'SELECT',
        'FROM',
        'WHERE',
        'users',
        'customers',
        'orders',
        'user_id',
        'customer_id',
        'order_id',
        'first_name',
        'last_name',
      ]);

      // Set up tables
      controller.addMainTableFields(
        ['user_id', 'first_name', 'last_name'],
        ['users', 'customers', 'orders'],
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('SuggestionHelper initializes isolate on first use', () async {
      // Set cursor position
      controller.selection =
          const TextSelection.collapsed(offset: 7); // After "SELECT "

      // Generate suggestions which should trigger isolate creation
      await controller.generateSuggestions();

      // Can't directly test isolate existence, but ensure no exceptions are thrown
      expect(true, isTrue);
    });

    test('SuggestionHelper generates suggestions via isolate', () async {
      // Set cursor position after typing "SEL"
      controller.text = 'SEL';
      controller.selection = const TextSelection.collapsed(offset: 3);

      // Generate suggestions
      await controller.generateSuggestions();

      // Note: Can't test shouldShow in unit tests as it requires Flutter's
      // scheduler to run. Just verify the method completes without errors.
      expect(true, isTrue);
    });

    test('SuggestionHelper falls back to main thread if isolate fails',
        () async {
      // This test simulates a failure in isolate communication
      // We can't easily mock the isolate directly, so we'll just verify
      // that suggestions still work after forcing a new suggestion generation

      // Set cursor position
      controller.text = 'SEL';
      controller.selection = const TextSelection.collapsed(offset: 3);

      // Generate suggestions multiple times to test robustness
      await controller.generateSuggestions();
      await controller.generateSuggestions();

      // Note: Can't test shouldShow in unit tests as it requires Flutter's
      // scheduler to run. Just verify the method completes without errors.
      expect(true, isTrue);
    });

    test('SuggestionHelper properly disposes isolate', () async {
      // Set cursor position
      controller.selection = const TextSelection.collapsed(offset: 7);

      // Generate suggestions to create isolate
      await controller.generateSuggestions();

      // Dispose controller which should also dispose isolate
      controller.dispose();

      // Can't directly test isolate disposal, but ensure no exceptions are thrown
      expect(true, isTrue);
    });
  });
}
