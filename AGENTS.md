# Repository Guidelines

## Project Structure & Module Organization
- `lib/`: App source. Entry: `lib/main.dart` wires providers and a `RouteObserver`.
- `lib/providers/`: State + network (e.g., `settings_provider.dart`, `model_provider.dart`, `chat_provider.dart`). Add chat services in `lib/providers/chat_service.dart`.
- `lib/ui/`: Screens/components (`home_page.dart`, `providers_page.dart`, `provider_detail_page.dart`, `model_select_sheet.dart`).
- `lib/widgets/`: Reusable UI (`chat_input_bar.dart`).
- `test/`: Unit/widget tests mirroring `lib/` with `_test.dart` suffix.
- `pubspec.yaml`: Dependencies, assets, and lints.

## Build, Test, and Development Commands
- `flutter pub get`: Install/resolve dependencies.
- `flutter analyze`: Static analysis (`flutter_lints`).
- `flutter test`: Run unit and widget tests.
- `flutter test --coverage`: Generate coverage at `coverage/lcov.info`.
- `dart format .`: Format the codebase.
- `flutter run -d V1923A`: Run locally (replace device as needed).
- `flutter build apk --release`: Build a release APK.

## Coding Style & Naming Conventions
- Dart/Flutter; 2-space indent; prefer trailing commas for cleaner diffs.
- Naming: UpperCamelCase (classes/widgets), lowerCamelCase (vars/methods), `lower_snake_case.dart` (files).
- Imports: SDK → packages → relative; remove unused; avoid `print` in production.

## Testing Guidelines
- Frameworks: `flutter_test` and `test`.
- Place tests under `test/` mirroring `lib/`; name as `file_name_test.dart`.
- Use `pumpWidget`/`pump` explicitly; keep tests deterministic.
- Run via `flutter test`; add coverage via `flutter test --coverage` when needed.

## Commit & Pull Request Guidelines
- Conventional Commits: e.g., `feat(home): add model selector`, `fix(ui): handle null state`.
- PRs: clear summary, linked issues, test steps, and UI screenshots/GIFs.
- Quality gate: run `dart format .`, `flutter analyze`, and `flutter test` before pushing.

## Security & Configuration Tips
- Do not commit secrets. Pass via `--dart-define=KEY=VALUE` and read with `String.fromEnvironment('KEY')`.
- Provider configs persist in `SharedPreferences` (key: `provider_configs_v1`).
- Use the proxy-aware HTTP client via `_Http.clientFor(cfg)`.

## Architecture Overview
- Current model tracked via `SettingsProvider.currentModelProvider/Id` and `setCurrentModel()`.
- `ProviderManager` lists models and tests connections (OpenAI/Claude/Google).
- Wire `ChatInputBar.onSend` to a chat service (`lib/providers/chat_service.dart`) that reuses `ProviderManager` and the proxy-aware client.

