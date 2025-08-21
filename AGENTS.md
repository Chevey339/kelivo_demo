# Repository Guidelines

## Project Structure & Module Organization
- `lib/`: App source. Entry: `lib/main.dart` (providers and `RouteObserver`).
- `lib/providers/`: State and network (`settings_provider.dart`, `model_provider.dart`, `chat_provider.dart`).
- `lib/ui/`: Screens/components (`home_page.dart`, `providers_page.dart`, `provider_detail_page.dart`, `model_select_sheet.dart`).
- `lib/widgets/`: Reusable UI (`chat_input_bar.dart`).
- `test/`: Unit/widget tests mirroring `lib/` (suffix `_test.dart`).
- `pubspec.yaml`: Dependencies, assets, and lints.

## Build, Test, and Development Commands
```sh
flutter pub get           # Install/resolve deps
flutter analyze           # Static analysis (flutter_lints)
flutter test              # Run tests
flutter test --coverage   # Generate coverage/lcov.info
dart format .             # Format code
flutter run -d V1923A     # Run in browser (or other device)
flutter build apk --release  # Release build
```

## Coding Style & Naming Conventions
- Dart/Flutter; 2-space indent; prefer trailing commas.
- Naming: UpperCamelCase (classes/widgets), lowerCamelCase (vars/methods), `lower_snake_case.dart` (files).
- Imports: SDK → packages → relative. Remove unused. Avoid `print` in production.
- Keep changes minimal and aligned with existing patterns.

## Testing Guidelines
- Frameworks: `flutter_test` and `test`. Place tests under `test/` mirroring `lib/`.
- Name tests: `file_name_test.dart`; use `pumpWidget`/`pump` explicitly.
- Keep tests deterministic; add coverage where valuable.

## Commit & Pull Request Guidelines
- Conventional Commits (e.g., `feat(home): add model selector`, `fix(ui): handle null state`).
- PRs: clear summary, linked issues, test steps, and screenshots/GIFs for UI.
- Quality gate: run `dart format .`, `flutter analyze`, and `flutter test` locally.

## Security & Configuration Tips
- Do not commit secrets. Pass config via `--dart-define=KEY=VALUE` and read with `String.fromEnvironment`.
- Provider configs persist in SharedPreferences (`provider_configs_v1`). Use `_Http.clientFor(cfg)` to respect per-provider proxy.

## Architecture Notes
- Current model: `SettingsProvider.currentModelProvider/Id` with `setCurrentModel()`.
- Network: `ProviderManager` lists models and tests connections for OpenAI/Claude/Google.
- Chat entry point: wire `ChatInputBar.onSend` via a chat service (e.g., `lib/providers/chat_service.dart`) reusing `ProviderManager` and the proxy-aware HTTP client.

