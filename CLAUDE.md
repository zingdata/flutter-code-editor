# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## MCP Tool Usage

- When using a **library**, first **check the docs with ref** — this matches the tool `context7`.
- When needing to **search the codebase**, use **serena**.
- When needing **past project context or history**, use **serena memories**.

## Project

Flutter Code Editor: multi-platform code editor widget with syntax highlighting (100+ languages), code folding, autocompletion, read-only sections, theming. Published at https://pub.dev/packages/flutter_code_editor.

## Commands

```bash
flutter pub get                                          # Install dependencies
flutter test                                             # Run tests
flutter test --coverage                                  # Run tests with coverage
dart analyze --fatal-infos                               # Code analysis (CI standard)
dart format --output=none --set-exit-if-changed .        # Check formatting (CI)
dart format .                                            # Format code
flutter clean                                            # Clean build artifacts
flutter pub outdated                                     # Check outdated packages

cd example && flutter pub get && flutter run             # Run example app
```

### CI Pipeline (must pass)
1. `flutter clean`
2. `flutter pub get`
3. `flutter pub outdated`
4. `dart analyze --fatal-infos`
5. `dart format --output=none --set-exit-if-changed .`
6. `flutter test --coverage`

## Architecture

### CodeController (central component)
- Extends `TextEditingController`
- Three text representations:
  - `text`: Visible text (excludes folded/hidden)
  - `fullText`: Complete text including folded/hidden
  - `value`: TextEditingValue with visible text + selection

### Widget Structure
```
CodeTheme (InheritedWidget)
  └─ CodeField
      ├─ Gutter (line numbers, errors, folding handles)
      ├─ TextField
      └─ AutocompletePopup
```

### Modules (organized by feature)
- **code/**: Immutable data models (Code, TextRange)
- **code_field/**: Main CodeField widget
- **folding/**: Code block detection and folding
- **highlight/**: Syntax highlighting via `highlight` package
- **analyzer/**: Pluggable analysis (experimental API - breaking changes possible)
- **autocomplete/**: Autocompletion logic + UI
- **gutter/**: Line numbers, error markers, folding handles
- **named_sections/**: Section parsing (`[START name]`/`[END name]`)
- **history/**: Undo/redo
- **hidden_ranges/**: Hide/show sections
- **service_comment_filter/**: Filter hidden service comments
- **single_line_comments/**: Comment/uncomment

### Patterns
- **Pluggable Analyzers**: `Analyzer` abstract class → `DefaultLocalAnalyzer`, `DartPadAnalyzer`
- **Strategy Pattern**: `AbstractNamedSectionParser` → `BracketsStartEndNamedSectionParser`
- **Immutability**: Data structures use `equatable` for value equality
- **Service Comments**: Hidden markers in text (in `fullText`, not visible to users)

### Key Details
- **Read-Only Sections**: Use `fullText` to modify when sections are locked
- **Hiding Text**: `visibleSectionNames` makes editor read-only, preserves line numbers
- **Language Support**: 100+ via `highlight` package. Folding: full (Dart, Go, Java, Python, Scala), experimental (others)

## Code Style

### Naming
- Classes: PascalCase
- Variables/Functions: camelCase
- Files/Directories: underscores_case
- Booleans: Start with verbs (`isLoading`, `hasError`, `canDelete`)
- Functions: Start with verbs (`executeValidation`, `saveState`)

### Rules
- Always declare types (avoid `dynamic`)
- Functions: < 20 instructions, single purpose, no blank lines within
- Classes: < 200 instructions, < 10 public methods, < 10 properties
- SOLID principles, prefer composition over inheritance
- Avoid deeply nested widgets
- Use `const` constructors
- Use `package:` imports (not relative)
- One export per file

### Key Linter Rules
- `prefer_const_constructors`: true
- `prefer_final_fields`: true
- `always_declare_return_types`: true
- `unawaited_futures`: error
- `avoid_relative_lib_imports`: error

## Testing

- Tests mirror `lib/src/` in `test/src/`
- Issue tests in `test/issues/`
- Mock with `mocktail`

## Multi-Platform

Works on iOS, Android, Web, Linux, macOS, Windows. Avoid platform-specific code.
