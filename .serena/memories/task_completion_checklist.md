# Flutter Code Editor - Task Completion Checklist

When completing a task in this codebase, follow this checklist to ensure quality:

## 1. Code Quality Checks

### Format Code
```bash
dart format .
```
Ensure all Dart files are properly formatted according to Dart standards.

### Run Static Analysis
```bash
dart analyze --fatal-infos
```
Fix all analyzer issues including:
- Errors
- Warnings  
- Info-level issues (treated as fatal in CI)

## 2. Testing

### Run All Tests
```bash
flutter test
```
Ensure all existing tests pass.

### Add Tests for New Features
- Write unit tests for new functionality
- Place tests in `test/src/` mirroring the `lib/src/` structure
- Test edge cases and error conditions

### Check Test Coverage (Optional)
```bash
flutter test --coverage
```
Maintain or improve code coverage.

## 3. Code Style Compliance

### Verify Code Follows Conventions
- Type declarations on all variables/functions
- PascalCase for classes
- camelCase for functions/variables
- underscores_case for file names
- Boolean variables start with verbs (is/has/can)
- Functions start with verbs
- No blank lines within functions
- Short functions (< 20 instructions)
- `const` constructors where possible

### Lint Rules
Check that code complies with `analysis_options.yaml` rules:
- Return types declared
- No unawaited futures
- Package imports (not relative)
- Final fields where appropriate
- Const constructors where possible

## 4. Documentation

### Update Documentation
- Add/update dartdoc comments for public APIs
- Update README.md if adding new features
- Add examples if introducing new functionality

### Update CHANGELOG.md
If this is a release-worthy change, add entry to CHANGELOG.md.

## 5. Dependencies

### Check for Issues
```bash
flutter pub get
flutter pub outdated
```

## 6. Git

### Commit with Clear Message
Follow conventional commit format:
```
type(scope): description

Examples:
feat(folding): add support for TypeScript folding
fix(autocomplete): resolve crash when typing special characters
docs(readme): update installation instructions
refactor(gutter): simplify line number rendering
test(analyzer): add tests for DartPad analyzer
```

### Before Pushing
Run the CI checks locally:
```bash
flutter clean
flutter pub get
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
flutter test
```

## 7. Pre-Commit Checklist

- [ ] Code is formatted (`dart format .`)
- [ ] No analyzer errors (`dart analyze --fatal-infos`)
- [ ] All tests pass (`flutter test`)
- [ ] New tests added for new features
- [ ] Code follows style conventions
- [ ] Public APIs have dartdoc comments
- [ ] No debug print statements or commented code
- [ ] README updated if needed
- [ ] Git commit message is clear and follows conventions

## 8. Platform-Specific

Since this is macOS (Darwin):
- Ensure example app builds on available platforms
- Check that no platform-specific code breaks multi-platform support
- This package supports web, mobile, and desktop

## Notes

- This is a published package, so maintain backward compatibility
- The analyzer feature is experimental and may have breaking changes
- Code coverage results are sent to codecov.io
- CI uses Flutter 3.19.6 but package supports >=3.29.0
