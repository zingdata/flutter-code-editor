# Word Insertion Helper

This document explains the Word Insertion Helper implementation in the Flutter Code Editor, which handles the insertion of autocomplete suggestions into the editor.

## Overview

The `WordInsertionHelper` class is responsible for inserting selected autocomplete suggestions into the code editor at the appropriate position. It encapsulates the complex logic of:

1. Determining the correct insertion position
2. Formatting the inserted text according to SQL syntax rules
3. Maintaining the cursor position after insertion
4. Triggering appropriate follow-up suggestions (like showing columns after inserting a table name)

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

### SQL Formatting Integration

The helper leverages the SQL formatter to handle SQL-specific formatting concerns:

- For SQL keywords, functions, and identifiers
- Adds appropriate spaces, quotes, or parentheses based on context
- Sets proper cursor position (e.g., inside parentheses for functions)

## Process Flow

1. **Insertion Triggered**
   - User selects a suggestion or presses Enter/Tab on a highlighted suggestion
   - `insertSelectedWord()` method is called

2. **Prepare for Insertion**
   - Sets a flag to prevent triggering suggestion generation during insertion
   - Gets the selected word from the popup controller

3. **Determine Insertion Mode**
   - If prefix start index is available, use normal insertion
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

## Future Extensibility

The design allows for future enhancements:

1. Support for different formatting strategies for different languages
2. More sophisticated context detection
3. Custom insertion behavior for specific types of suggestions
4. Better handling of multi-word suggestions or snippets

This helper is a key component in providing a rich autocompletion experience for SQL and other languages in the Flutter Code Editor. 