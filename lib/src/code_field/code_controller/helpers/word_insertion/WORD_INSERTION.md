# Word Insertion Helper

This document explains the Word Insertion Helper implementation in the Flutter Code Editor, which handles the insertion of autocomplete suggestions into the editor.

## Overview

The `WordInsertionHelper` class is responsible for inserting selected autocomplete suggestions into the code editor at the appropriate position. It encapsulates the complex logic of:

1. Determining the correct insertion position
2. Formatting the inserted text according to SQL syntax rules
3. Maintaining the cursor position after insertion
4. Triggering appropriate follow-up suggestions (like showing columns after inserting a table name)
5. Handling multi-word identifiers (like "Customer Address" or "Order Date")

## Key Components

### WordInsertionHelper Class

The primary class responsible for handling word insertion. It:

- Takes a reference to the CodeController
- Provides methods to insert autocomplete selections
- Handles different insertion scenarios
- Manages suggestion popup visibility

### Two Main Insertion Paths

The helper handles two distinct insertion scenarios:

1. **With Prefix Index**: When we have a clear start position for the word being replaced
   - Used when the user has typed part of a word and then selected a suggestion
   - Replaces the text from the prefix start to the current cursor position

2. **Without Prefix Index**: When we don't have a defined start position
   - Used as a fallback when the system can't identify the prefix
   - Inserts the word at the current cursor position without replacing existing text

### Multi-Word Identifier Handling

A critical feature is properly handling multi-word identifiers that are common in SQL:

- **Complete Phrase Replacement**: When a user types partial text like "pet ty" and selects "Pet Type", the entire phrase "pet ty" is replaced, not just "ty"
- **Word Boundary Detection**: Uses word boundary analysis to identify the start of multi-word phrases
- **Space-Aware Matching**: Recognizes spaces as part of identifiers in specific contexts
- **Coherent Replacement**: Ensures the entire semantic unit is replaced, maintaining code correctness

### SQL Formatting Integration

The helper leverages the SQL formatter to handle SQL-specific formatting concerns:

- For SQL keywords, functions, and identifiers
- Adds appropriate spaces, quotes, or parentheses based on context
- Sets proper cursor position (e.g., inside parentheses for functions)
- Properly formats multi-word identifiers with appropriate quoting

## Process Flow

1. **Insertion Triggered**
   - User selects a suggestion or presses Enter/Tab on a highlighted suggestion
   - `insertSelectedWord()` method is called

2. **Prepare for Insertion**
   - Sets a flag to prevent triggering suggestion generation during insertion
   - Gets the selected word from the popup controller

3. **Determine Insertion Mode and Range**
   - If prefix start index is available, use normal insertion
   - For multi-word identifiers, extend the start index backward to include the entire phrase
   - Otherwise, fall back to insertion without prefix

4. **Format and Insert**
   - Format the word using SQL formatter
   - Calculate appropriate cursor position
   - Update the editor text and selection

5. **Handle Follow-up Suggestions**
   - If the inserted word is a table name, show column suggestions
   - If the inserted word is a function with parentheses, show parameter suggestions

6. **Clean Up**
   - Reset flags and prepare for next interaction

## Multi-Word Identifier Example

When working with an identifier like "Pet Type":

1. User types "pet ty"
2. Suggestion system shows "Pet Type" as an option
3. User selects the suggestion
4. System analyzes and identifies "pet ty" as a multi-word partial match
5. The entire "pet ty" is replaced with "Pet Type" (with appropriate formatting)
6. Cursor is positioned after the inserted text

## Integration with CodeController

The `WordInsertionHelper` is instantiated by the `CodeController` and maintained as a private field. The controller delegates word insertion logic to the helper, maintaining a clean separation of concerns:

```dart
void insertSelectedWord() {
  _wordInsertionHelper.insertSelectedWord();
}
```

## Design Benefits

This refactoring provides several advantages:

1. **Separation of Concerns**: Word insertion logic is isolated from the main controller
2. **Improved Testability**: The helper can be tested independently
3. **Better Error Handling**: Ensures flags are reset even if exceptions occur
4. **More Maintainable**: Changes to word insertion logic only affect the helper class
5. **Cleaner Code**: Reduces the size and complexity of the CodeController class
6. **Better Multi-Word Support**: Handles complex identifiers that contain spaces

## Future Extensibility

The design allows for future enhancements:

1. Support for different formatting strategies for different languages
2. More sophisticated context detection
3. Custom insertion behavior for specific types of suggestions
4. Improved handling of multi-word suggestions in various programming contexts
5. Support for quoted identifiers with special characters

This helper is a key component in providing a rich autocompletion experience for SQL and other languages in the Flutter Code Editor. 