# Flutter Code Editor - Essential Commands

## Package Management

### Install Dependencies
```bash
flutter pub get
```

### Check for Outdated Packages
```bash
flutter pub outdated
```

### Clean Build Artifacts
```bash
flutter clean
```

## Development Commands

### Run Tests
```bash
flutter test
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### Code Analysis
```bash
dart analyze --fatal-infos
```
This runs the Dart analyzer with fatal info-level issues (strict mode used in CI).

### Code Formatting

#### Check Format (without changing files)
```bash
dart format --output=none --set-exit-if-changed .
```
This is the CI command that fails if formatting is needed.

#### Format Code
```bash
dart format .
```
This automatically formats all Dart files in the project.

## Version Management

### Check Flutter Version
```bash
flutter --version
```

### Switch Flutter Version (using FVM)
The project uses FVM (Flutter Version Management) as indicated by `.fvm` directory and `.fvmrc` file.
```bash
fvm use
```

## Git Commands (macOS/Darwin)

Standard git commands work on Darwin (macOS):
```bash
git status
git add .
git commit -m "message"
git push
git pull
git branch
git checkout <branch>
```

## System Utilities (macOS/Darwin)

Darwin (macOS) uses standard Unix commands:
- `ls` - List files
- `cd` - Change directory
- `grep` - Search text
- `find` - Find files
- `cat` - Display file contents
- `mkdir` - Create directory
- `rm` - Remove files
- `cp` - Copy files
- `mv` - Move files

## Example App

The example app can be run from the `example/` directory:
```bash
cd example
flutter pub get
flutter run
```

## CI/CD Pipeline Commands

The GitHub Actions workflow (`.github/workflows/dart.yaml`) runs:
1. `flutter clean`
2. `flutter pub get`
3. `flutter pub outdated`
4. `dart analyze --fatal-infos`
5. `dart format --output=none --set-exit-if-changed .`
6. `flutter test --coverage`

These are the standard checks that should pass before committing.
