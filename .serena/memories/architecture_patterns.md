# Flutter Code Editor - Architecture & Design Patterns

## Overall Architecture

This package follows a **modular, feature-based architecture** where functionality is organized by feature/concern rather than by layer.

## Key Architectural Patterns

### 1. Controller Pattern

**CodeController** is the central controller that:
- Extends Flutter's `TextEditingController`
- Manages the code state, folding, highlighting, and analysis
- Acts as the interface between the UI and the business logic
- Provides methods for code manipulation (folding, hiding sections, etc.)

```dart
final controller = CodeController(
  text: '...',
  language: java,
  analyzer: DefaultLocalAnalyzer(),
);
```

### 2. Widget Composition

The package uses heavy widget composition:
- **CodeField**: Main widget that composes multiple sub-widgets
- **CodeTheme**: Theme provider using inherited widget pattern
- Separate widgets for gutter, line numbers, folding handles, etc.

### 3. Pluggable Analyzers

The analyzer system uses a **plugin architecture**:
- `Analyzer` abstract class defines the contract
- Multiple implementations: `DefaultLocalAnalyzer`, `DartPadAnalyzer`
- Users can implement custom analyzers
- Note: This is experimental and may have breaking changes

### 4. Parser Pattern

**Named Section Parsing** uses the Strategy pattern:
- `AbstractNamedSectionParser` defines the interface
- `BracketsStartEndNamedSectionParser` is the built-in implementation
- Allows custom parsing strategies by subclassing

### 5. Immutable Data Structures

The codebase heavily uses immutable data:
- Code state is represented as immutable objects
- Updates create new instances rather than mutating
- Uses `equatable` package for value equality
- Simplifies state management and debugging

### 6. Separation of Concerns

Each module has a specific responsibility:

- **code/**: Core data models (Code, TextRange, etc.)
- **code_field/**: UI rendering and user interaction
- **folding/**: Code block detection and folding logic
- **highlight/**: Syntax highlighting integration
- **analyzer/**: Code analysis and error detection
- **autocomplete/**: Autocompletion logic and UI
- **gutter/**: Line numbers, errors, and folding handles rendering
- **named_sections/**: Section parsing and management
- **history/**: Undo/redo functionality
- **hidden_ranges/**: Hide/show code sections

## Data Flow

```
User Input (CodeField)
    ↓
CodeController (manages state)
    ↓
Code (immutable data model)
    ↓
Rendering (CodeField + sub-widgets)
```

### Text Editing Flow

1. User types in CodeField
2. TextEditingController receives input
3. CodeController processes changes
4. Syntax highlighter parses code
5. Analyzer checks for errors (if enabled)
6. Folding detector updates foldable blocks
7. UI re-renders with updated state

## Key Design Decisions

### 1. Extends TextEditingController

CodeController extends Flutter's built-in `TextEditingController`:
- **Pros**: Compatible with existing Flutter text editing infrastructure
- **Cons**: Must manage visible vs. full text separately (for folding/hiding)

### 2. Three Text Representations

- `text`: Visible text (excludes folded/hidden blocks)
- `fullText`: Complete text including folded/hidden code
- `value`: TextEditingValue with visible text and selection

### 3. Service Comments

Hidden markers in the text track folding/section boundaries:
- Not visible to users
- Included in `fullText`
- Filtered from `text` and display

### 4. Read-Only Sections

Named sections can be locked:
- Prevents user edits to specific code regions
- Useful for educational/tutorial scenarios
- Must use `fullText` to programmatically modify locked sections

### 5. Highlight Package Integration

Uses the `highlight` package for parsing:
- Supports 100+ languages out of the box
- Language-agnostic code folding for major languages
- Themes from `flutter_highlight` package

## Widget Tree Structure

```
CodeTheme (provides theme data)
  └─ CodeField
      ├─ Gutter
      │   ├─ LineNumbers
      │   ├─ ErrorMarkers
      │   └─ FoldingHandles
      ├─ TextField (actual text input)
      └─ AutocompletePopup
```

## State Management

- **Local State**: Widget state using StatefulWidget
- **Controller State**: CodeController holds the code state
- **Theme State**: InheritedWidget for theme propagation
- No external state management library (Redux, Bloc, Riverpod, etc.)

## Extension Points

The package is designed for extensibility:

1. **Custom Analyzers**: Implement `Analyzer` interface
2. **Custom Section Parsers**: Subclass `AbstractNamedSectionParser`
3. **Custom Themes**: Provide custom `CodeThemeData`
4. **Custom Languages**: Use any language from `highlight` package

## Testing Strategy

- Unit tests for business logic
- Widget tests for UI components
- Tests mirror `lib/src/` structure in `test/src/`
- Issue-specific tests in `test/issues/`
- Mock external dependencies with `mocktail`

## Performance Considerations

- Use `const` constructors to reduce rebuilds
- Lazy evaluation of folding blocks
- Efficient text diffing for syntax highlighting
- Virtualized scrolling for large files (via `scrollable_positioned_list`)
- Linked scroll controllers for synchronized scrolling

## Multi-Platform Support

The package is designed to work on:
- iOS
- Android  
- Web
- Desktop (Linux, macOS, Windows)

No platform-specific code that would limit portability.
