# Repository Guidelines

This guide explains how to work on the `kelivo_demo` Flutter app. Keep changes small, tested, and consistent with the existing style.

## Project Structure & Modules
- `lib/`: App source (entry: `lib/main.dart`). Add features in small files by domain.
- `test/`: Unit/widget tests mirroring `lib/` (suffix: `_test.dart`).
- Platforms: `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`.
- Config: `pubspec.yaml` (deps, assets), `analysis_options.yaml` (lints).

## Build, Test, and Development Commands
- `flutter pub get`: Install/resolve dependencies.
- `flutter run -d <device>`: Run locally (e.g., `-d chrome`).
- `flutter test`: Run all tests; add `--coverage` to generate `coverage/lcov.info`.
- `flutter analyze`: Static analysis per configured lints.
- `dart format .`: Format Dart code (run before committing).
- Release builds: `flutter build apk --release`, `flutter build ios`, `flutter build web`.

## Coding Style & Naming Conventions
- Lints: Uses `flutter_lints` via `analysis_options.yaml`.
- Indentation: 2 spaces; prefer trailing commas for better diffs/formatting.
- Naming: UpperCamelCase for classes/widgets; lowerCamelCase for vars/methods; `lower_snake_case.dart` for files (e.g., `home_page.dart`).
- Prefer `const` constructors/vals where possible; avoid `print` in production code.
- Organize imports: SDK → packages → relative; remove unused imports.

## Testing Guidelines
- Framework: `flutter_test` with `testWidgets` for UI and `test` for logic.
- Structure: Mirror `lib/` and use descriptive names (e.g., `home_page_test.dart`).
- Deterministic tests: use `pumpWidget`, `pump`, and explicit finders.
- Coverage: Optional, but keep meaningful widget coverage (`flutter test --coverage`).

## Commit & Pull Request Guidelines
- Commits: Follow Conventional Commits (e.g., `feat(counter): add increment button`, `fix(home): null check state`).
- PRs: Include summary, linked issues, test steps, and screenshots/GIFs for UI changes.
- Quality gate: Ensure `dart format .`, `flutter analyze`, and `flutter test` pass.

## Security & Configuration Tips
- Do not commit secrets; pass config via `--dart-define=KEY=VALUE` and read with `String.fromEnvironment('KEY')`.
- Manage assets via `pubspec.yaml` if added (e.g., `assets/`), and keep `pubspec.lock` in version control.
