# Flutter Code Editor - Codebase Structure

## Root Directory Structure

```
/
├── lib/                        # Main source code
├── test/                       # Test files
├── example/                    # Example applications
├── doc/                        # Documentation
├── .github/                    # CI/CD workflows
├── context/                    # Context files
├── .serena/                    # Serena agent configuration
├── pubspec.yaml               # Package metadata and dependencies
├── analysis_options.yaml      # Linter and analyzer configuration
├── README.md                  # Project documentation
├── CHANGELOG.md               # Version history
└── .cursorrules               # Cursor AI coding guidelines
```

## Library Structure (lib/)

```
lib/
├── flutter_code_editor.dart   # Main library export file
└── src/                       # Internal implementation
    ├── analyzer/              # Code analysis (experimental)
    ├── autocomplete/          # Autocompletion functionality
    ├── code/                  # Core code representation
    ├── code_field/            # Main CodeField widget
    ├── code_modifiers/        # Code modification utilities
    ├── code_theme/            # Theme management
    ├── folding/               # Code folding logic
    ├── gutter/                # Line numbers and gutter UI
    ├── hidden_ranges/         # Hidden code blocks
    ├── highlight/             # Syntax highlighting
    ├── history/               # Undo/redo functionality
    ├── line_numbers/          # Line number rendering
    ├── named_sections/        # Named section parsing
    ├── service_comment_filter/ # Comment filtering
    ├── single_line_comments/  # Comment handling
    ├── util/                  # Utility functions
    ├── wip/                   # Work in progress features
    └── sizes.dart             # Size constants
```

## Test Structure (test/)

```
test/
├── src/                       # Unit tests mirroring lib/src
└── issues/                    # Tests for specific issues/bugs
```

## Example Structure (example/)

The example directory contains sample Flutter applications demonstrating the package features:
- `example/lib/` - Example code files
- Platform-specific directories (ios/, android/, linux/)

## Key Files

- **lib/flutter_code_editor.dart**: Main entry point, exports public API
- **pubspec.yaml**: Package configuration, dependencies, metadata
- **analysis_options.yaml**: Linting rules and analyzer settings
- **.cursorrules**: Code style guidelines for AI assistants
- **.github/workflows/dart.yaml**: CI/CD pipeline configuration
