**Repo Overview**
- Entry: `lib/main.dart` (providers wired; routeObserver added)
- Key state: `lib/providers/settings_provider.dart`
  - Provider configs persisted (API keys, base URL, models, overrides, proxy)
  - Current model selection: `setCurrentModel(providerKey, modelId)`
  - Favorites (pinned models): `togglePinModel(providerKey, modelId)`
- Model metadata: `lib/providers/model_provider.dart`
  - Types: `ModelType`, `Modality`, `ModelAbility`
  - Inference tags: `ModelRegistry.infer(...)`
  - HTTP proxy: `_Http.clientFor(cfg)` (respects per-provider proxy)
  - ProviderManager:
    - `listModels(cfg)` implemented for OpenAI/Claude/Google
    - `testConnection(cfg, modelId)` implemented (minimal POSTs per provider)

**UI Key Pieces**
- Home screen: `lib/ui/home_page.dart`
  - AppBar shows title + current model subtitle (“Model (Provider)”, small)
  - `ChatInputBar` at bottom (model picker button, search toggle, more, send)
  - Keyboard behavior fixed with `RouteObserver` and controlled `FocusNode`
  - Current model icon shown (vendor SVG mapping; fallback initial; 28×28)
- Model selection (Reused Component): `lib/ui/model_select_sheet.dart`
  - `Future<ModelSelection?> showModelSelector(BuildContext context, {String? li
    mitProviderKey})`
    - Full selector: groups (Favorites + Providers), search, badges, vendor icon
    - Limit mode: only a specific provider’s added models
  - `Future<void> showModelSelectSheet(BuildContext context)` persists selected
  model to Settings
- Providers UI
  - List: `lib/ui/providers_page.dart` (cards reflect enabled, model count)
  - Detail: `lib/ui/provider_detail_page.dart`
    - Tabs: Config / Models / Network
    - Models: reorderable list, slidable delete (confirm + undo), add model
    - Per-model overrides dialog: `lib/ui/model_detail_sheet.dart` (Basic/Advanc
    ed/Tools)
    - Test connection dialog: `_ConnectionTestDialog` (select model via shared s
    elector, loading, result)
- Shared styles
  - Snackbar themed (floating, rounded, inverseSurface for contrast)
  - Input capsules (dark/light parity, subtle shadows)
  - Icon mapping for vendors (OpenAI, Gemini, SiliconFlow, OpenRouter, etc.) via
   regex

**Data & Persistence**
- ProviderConfig fields (stored in SharedPreferences under `provider_configs_v1`
  ):
  - id, enabled, name, apiKey, baseUrl
  - chatPath/useResponseApi (OpenAI), vertexAI/location/projectId (Google)
  - models: List<String> (user-added)
  - modelOverrides: Map<String,dynamic> (name, type, input[], output[], abilitie
  s[])
  - proxyEnabled/Host/Port/Username/Password
- SettingsProvider extras:
  - `pinnedModels` (Set<String> "provider::model")
  - `currentModelProvider` / `currentModelId` and `setCurrentModel()`
  - `hasAnyActiveModel` (used to hide/show “未配置” warning)
  - Defaults: only OpenAI/Gemini/SiliconFlow/OpenRouter enabled

**Network & Proxy**
- Use `_Http.clientFor(cfg)` to create `http.Client` with optional proxy:
  - `findProxy = 'PROXY host:port'`; supports basic credentials
- Implemented calls:
  - OpenAI: GET `/models`; POST to `/chat/completions` or `/responses`
  - Claude: GET `/models`; POST to `/messages` (anthropic-version header)
  - Google: GET list; POST to `...:generateContent`; Vertex AI variant supported

**Model Tags (UI consistency)**
- Rendered tags (type, modality, abilities) use consistent capsules:
  - Type: “聊天/嵌入” pill with primary color
  - Modality: icons (T/Image) with chevron
  - Abilities: tool (hammer), reasoning (deepthink.svg)
- Model selection and provider pages both apply overrides before rendering tags

**Reorder/Delete Models**
- Models tab: `ReorderableListView.builder` with `proxyDecorator` animation
- Delete: `flutter_slidable` action with confirm dialog + SnackBar Undo
- Persist new order and deletions to ProviderConfig.models and modelOverrides

**Test Connection**
- Dialog states: idle -> loading -> success/error
- Model selection reuses shared selector (limited to current provider’s added mo
dels)
- Calls `ProviderManager.testConnection(cfg, modelId)` with minimal prompt

**Where to implement “Real Chat”**
- Input: `lib/widgets/chat_input_bar.dart`
  - Props: `onSend(String)`, `onSelectModel()`, `onToggleSearch(bool)`, `onMore(
  )`
- Likely new provider/service:
  - Reuse `ProviderManager.forConfig(cfg)` to branch by provider
  - Add a `generateText` method per provider (non-stream and/or stream)
  - Use `_Http.clientFor(cfg)` for all HTTP; respect overrides if needed
- State:
  - Use or extend `lib/providers/chat_provider.dart` to manage chat list/message
  s
  - Persist titles/pinned already present; add message history persistence if re
  quired
- Model selection:
  - Use `SettingsProvider.currentModelProvider/Id` to pick the model for chat
  - Optional: fallback if not selected (open selector)

**Paths to touch for chat**
- New: `lib/providers/chat_service.dart` (recommended) or extend `model_provider
.dart`
- Wire send:
  - In `HomePage`, pass `onSend` into `ChatInputBar` and call your chat service
  with current model
  - Update ChatProvider to append user/assistant messages; consider streaming up
  dates
- Respect overrides:
  - If you plan to enforce per-model overrides (type/modality), read from `Provi
  derConfig.modelOverrides[modelId]`

**Dependencies of note**
- flutter_svg, flutter_slidable, reorderable_grid_view, http, shared_preferences
, provider, dynamic_color

This is the minimal high-signal context to continue with the chat implementation
: where the current model is stored, how to get provider config + proxy, where t
o hook the send action, how to render tags/icons, and existing network patterns
to follow.