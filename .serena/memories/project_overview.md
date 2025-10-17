# Flutter Code Editor - Project Overview

## Project Purpose
Flutter Code Editor is a multi-platform code editor package for Flutter applications that provides:
- Syntax highlighting for over 100 languages
- Code blocks folding (Dart, Go, Java, Python, Scala)
- Autocompletion
- Read-only code blocks
- Hiding specific code blocks
- Named sections for code manipulation
- Themes customization
- Code analysis (experimental feature)

This is a published package on pub.dev (version 0.3.2) maintained by Akvelon.

## Repository Information
- Repository: https://github.com/akvelon/flutter-code-editor
- Main Branch: main
- Current Branch: improve-editor
- Package Name: flutter_code_editor

## Tech Stack

### Core Dependencies
- **Flutter SDK**: >=3.29.0
- **Dart SDK**: >=3.5.0 <4.0.0
- **Key Packages**:
  - `highlight` (0.7.0) - Syntax highlighting parsing
  - `flutter_highlight` (0.7.0) - Flutter themes for highlighting
  - `autotrie` (2.0.0) - Autocompletion trie data structure
  - `scrollable_positioned_list` (0.3.8) - Advanced scrolling
  - `linked_scroll_controller` (0.2.0) - Synced scrolling
  - `equatable` (2.0.7) - Value equality
  - `http` (1.1.0) - Network requests (for DartPad analyzer)
  - `mocktail` (1.0.1) - Mocking in tests

### Development Tools
- `flutter_test` - Testing framework
- `flutter_lints` (3.0.1) - Dart linting rules
- `fake_async` (1.3.1) - Testing async code

## Project Type
This is a Flutter package (library), not an application. It's designed to be integrated into other Flutter applications as a dependency.
