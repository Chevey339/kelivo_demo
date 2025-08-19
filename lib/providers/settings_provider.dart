import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsProvider extends ChangeNotifier {
  static const String _providersOrderKey = 'providers_order_v1';
  static const String _themeModeKey = 'theme_mode_v1';
  static const String _providerConfigsKey = 'provider_configs_v1';
  static const String _pinnedModelsKey = 'pinned_models_v1';
  static const String _selectedModelKey = 'selected_model_v1';
  static const String _titleModelKey = 'title_model_v1';
  static const String _titlePromptKey = 'title_prompt_v1';
  static const String _thinkingBudgetKey = 'thinking_budget_v1';
  static const String _displayShowUserAvatarKey = 'display_show_user_avatar_v1';
  static const String _displayShowModelIconKey = 'display_show_model_icon_v1';
  static const String _displayShowTokenStatsKey = 'display_show_token_stats_v1';
  static const String _displayAutoCollapseThinkingKey = 'display_auto_collapse_thinking_v1';
  static const String _displayNewChatOnLaunchKey = 'display_new_chat_on_launch_v1';
  static const String _displayChatFontScaleKey = 'display_chat_font_scale_v1';

  List<String> _providersOrder = const [];
  List<String> get providersOrder => _providersOrder;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Map<String, ProviderConfig> _providerConfigs = {};
  Map<String, ProviderConfig> get providerConfigs => Map.unmodifiable(_providerConfigs);
  bool get hasAnyActiveModel => _providerConfigs.values.any((c) => c.enabled && c.models.isNotEmpty);
  ProviderConfig getProviderConfig(String key, {String? defaultName}) {
    final existed = _providerConfigs[key];
    if (existed != null) return existed;
    final cfg = ProviderConfig.defaultsFor(key, displayName: defaultName);
    _providerConfigs[key] = cfg;
    return cfg;
  }

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _providersOrder = prefs.getStringList(_providersOrderKey) ?? [];
    final m = prefs.getString(_themeModeKey);
    switch (m) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    final cfgStr = prefs.getString(_providerConfigsKey);
    if (cfgStr != null && cfgStr.isNotEmpty) {
      try {
        final raw = jsonDecode(cfgStr) as Map<String, dynamic>;
        _providerConfigs = raw.map((k, v) => MapEntry(k, ProviderConfig.fromJson(v as Map<String, dynamic>)));
      } catch (_) {}
    }
    // load pinned models
    final pinned = prefs.getStringList(_pinnedModelsKey) ?? const <String>[];
    _pinnedModels
      ..clear()
      ..addAll(pinned);
    // load selected model
    final sel = prefs.getString(_selectedModelKey);
    if (sel != null && sel.contains('::')) {
      final parts = sel.split('::');
      if (parts.length >= 2) {
        _currentModelProvider = parts[0];
        _currentModelId = parts.sublist(1).join('::');
      }
    }
    // load title model
    final titleSel = prefs.getString(_titleModelKey);
    if (titleSel != null && titleSel.contains('::')) {
      final parts = titleSel.split('::');
      if (parts.length >= 2) {
        _titleModelProvider = parts[0];
        _titleModelId = parts.sublist(1).join('::');
      }
    }
    // load title prompt
    final tp = prefs.getString(_titlePromptKey);
    _titlePrompt = (tp == null || tp.trim().isEmpty) ? defaultTitlePrompt : tp;
    // load thinking budget (reasoning strength)
    _thinkingBudget = prefs.getInt(_thinkingBudgetKey);

    // display settings
    _showUserAvatar = prefs.getBool(_displayShowUserAvatarKey) ?? true;
    _showModelIcon = prefs.getBool(_displayShowModelIconKey) ?? true;
    _showTokenStats = prefs.getBool(_displayShowTokenStatsKey) ?? true;
    _autoCollapseThinking = prefs.getBool(_displayAutoCollapseThinkingKey) ?? true;
    _newChatOnLaunch = prefs.getBool(_displayNewChatOnLaunchKey) ?? true;
    _chatFontScale = prefs.getDouble(_displayChatFontScaleKey) ?? 1.0;
    notifyListeners();
  }

  Future<void> setProvidersOrder(List<String> order) async {
    _providersOrder = List.unmodifiable(order);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_providersOrderKey, _providersOrder);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final v = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await prefs.setString(_themeModeKey, v);
  }

  Future<void> toggleTheme() => setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> followSystem() => setThemeMode(ThemeMode.system);

  Future<void> setProviderConfig(String key, ProviderConfig config) async {
    _providerConfigs[key] = config;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final map = _providerConfigs.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_providerConfigsKey, jsonEncode(map));
  }

  // Favorites (pinned models)
  final Set<String> _pinnedModels = <String>{};
  Set<String> get pinnedModels => Set.unmodifiable(_pinnedModels);
  bool isModelPinned(String providerKey, String modelId) => _pinnedModels.contains('$providerKey::$modelId');
  Future<void> togglePinModel(String providerKey, String modelId) async {
    final k = '$providerKey::$modelId';
    if (_pinnedModels.contains(k)) {
      _pinnedModels.remove(k);
    } else {
      _pinnedModels.add(k);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedModelsKey, _pinnedModels.toList());
  }

  // Selected model for chat
  String? _currentModelProvider;
  String? _currentModelId;
  String? get currentModelProvider => _currentModelProvider;
  String? get currentModelId => _currentModelId;
  String? get currentModelKey => (_currentModelProvider != null && _currentModelId != null)
      ? '${_currentModelProvider!}::${_currentModelId!}'
      : null;
  Future<void> setCurrentModel(String providerKey, String modelId) async {
    _currentModelProvider = providerKey;
    _currentModelId = modelId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, '$providerKey::$modelId');
  }

  // Title model and prompt
  String? _titleModelProvider;
  String? _titleModelId;
  String? get titleModelProvider => _titleModelProvider;
  String? get titleModelId => _titleModelId;
  String? get titleModelKey => (_titleModelProvider != null && _titleModelId != null)
      ? '${_titleModelProvider!}::${_titleModelId!}'
      : null;

  static const String defaultTitlePrompt = '''I will give you some dialogue content in the `<content>` block.
You need to summarize the conversation between user and assistant into a short title.
1. The title language should be consistent with the user's primary language
2. Do not use punctuation or other special symbols
3. Reply directly with the title
4. Summarize using {locale} language
5. The title should not exceed 10 characters

<content>
{content}
</content>''';

  String _titlePrompt = defaultTitlePrompt;
  String get titlePrompt => _titlePrompt;

  Future<void> setTitleModel(String providerKey, String modelId) async {
    _titleModelProvider = providerKey;
    _titleModelId = modelId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_titleModelKey, '$providerKey::$modelId');
  }

  Future<void> setTitlePrompt(String prompt) async {
    _titlePrompt = prompt.trim().isEmpty ? defaultTitlePrompt : prompt;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_titlePromptKey, _titlePrompt);
  }

  Future<void> resetTitlePrompt() async => setTitlePrompt(defaultTitlePrompt);

  // Reasoning strength / thinking budget
  int? _thinkingBudget; // null = not set, use provider defaults; -1 = auto; 0 = off; >0 = budget tokens
  int? get thinkingBudget => _thinkingBudget;
  Future<void> setThinkingBudget(int? budget) async {
    _thinkingBudget = budget;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (budget == null) {
      await prefs.remove(_thinkingBudgetKey);
    } else {
      await prefs.setInt(_thinkingBudgetKey, budget);
    }
  }

  // Display settings: user avatar and model icon visibility
  bool _showUserAvatar = true;
  bool get showUserAvatar => _showUserAvatar;
  Future<void> setShowUserAvatar(bool v) async {
    if (_showUserAvatar == v) return;
    _showUserAvatar = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowUserAvatarKey, v);
  }

  bool _showModelIcon = true;
  bool get showModelIcon => _showModelIcon;
  Future<void> setShowModelIcon(bool v) async {
    if (_showModelIcon == v) return;
    _showModelIcon = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowModelIconKey, v);
  }

  // Display: token/context stats
  bool _showTokenStats = true;
  bool get showTokenStats => _showTokenStats;
  Future<void> setShowTokenStats(bool v) async {
    if (_showTokenStats == v) return;
    _showTokenStats = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowTokenStatsKey, v);
  }

  // Display: auto-collapse reasoning/thinking section
  bool _autoCollapseThinking = true;
  bool get autoCollapseThinking => _autoCollapseThinking;
  Future<void> setAutoCollapseThinking(bool v) async {
    if (_autoCollapseThinking == v) return;
    _autoCollapseThinking = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayAutoCollapseThinkingKey, v);
  }

  // Display: create a new chat on app launch
  bool _newChatOnLaunch = true;
  bool get newChatOnLaunch => _newChatOnLaunch;
  Future<void> setNewChatOnLaunch(bool v) async {
    if (_newChatOnLaunch == v) return;
    _newChatOnLaunch = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayNewChatOnLaunchKey, v);
  }

  // Display: chat font scale (0.8 - 1.5, default 1.0)
  double _chatFontScale = 1.0;
  double get chatFontScale => _chatFontScale;
  Future<void> setChatFontScale(double scale) async {
    final s = scale.clamp(0.8, 1.5);
    if (_chatFontScale == s) return;
    _chatFontScale = s;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_displayChatFontScaleKey, _chatFontScale);
  }
}

enum ProviderKind { openai, google, claude }

class ProviderConfig {
  final String id;
  final bool enabled;
  final String name;
  final String apiKey;
  final String baseUrl;
  final String? chatPath; // openai only
  final bool? useResponseApi; // openai only
  final bool? vertexAI; // google only
  final String? location; // google vertex ai only
  final String? projectId; // google vertex ai only
  final List<String> models; // placeholder for future model management
  // Per-model overrides (by model id)
  // {'<modelId>': {'name': String?, 'type': 'chat'|'embedding', 'input': ['text','image'], 'output': [...], 'abilities': ['tool','reasoning']}}
  final Map<String, dynamic> modelOverrides;
  // Per-provider proxy
  final bool? proxyEnabled;
  final String? proxyHost;
  final String? proxyPort;
  final String? proxyUsername;
  final String? proxyPassword;

  ProviderConfig({
    required this.id,
    required this.enabled,
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    this.chatPath,
    this.useResponseApi,
    this.vertexAI,
    this.location,
    this.projectId,
    this.models = const [],
    this.modelOverrides = const {},
    this.proxyEnabled,
    this.proxyHost,
    this.proxyPort,
    this.proxyUsername,
    this.proxyPassword,
  });

  ProviderConfig copyWith({
    String? id,
    bool? enabled,
    String? name,
    String? apiKey,
    String? baseUrl,
    String? chatPath,
    bool? useResponseApi,
    bool? vertexAI,
    String? location,
    String? projectId,
    List<String>? models,
    Map<String, dynamic>? modelOverrides,
    bool? proxyEnabled,
    String? proxyHost,
    String? proxyPort,
    String? proxyUsername,
    String? proxyPassword,
  }) => ProviderConfig(
        id: id ?? this.id,
        enabled: enabled ?? this.enabled,
        name: name ?? this.name,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        chatPath: chatPath ?? this.chatPath,
        useResponseApi: useResponseApi ?? this.useResponseApi,
        vertexAI: vertexAI ?? this.vertexAI,
        location: location ?? this.location,
        projectId: projectId ?? this.projectId,
        models: models ?? this.models,
        modelOverrides: modelOverrides ?? this.modelOverrides,
        proxyEnabled: proxyEnabled ?? this.proxyEnabled,
        proxyHost: proxyHost ?? this.proxyHost,
        proxyPort: proxyPort ?? this.proxyPort,
        proxyUsername: proxyUsername ?? this.proxyUsername,
        proxyPassword: proxyPassword ?? this.proxyPassword,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'enabled': enabled,
        'name': name,
        'apiKey': apiKey,
        'baseUrl': baseUrl,
        'chatPath': chatPath,
        'useResponseApi': useResponseApi,
        'vertexAI': vertexAI,
        'location': location,
        'projectId': projectId,
        'models': models,
        'modelOverrides': modelOverrides,
        'proxyEnabled': proxyEnabled,
        'proxyHost': proxyHost,
        'proxyPort': proxyPort,
        'proxyUsername': proxyUsername,
        'proxyPassword': proxyPassword,
      };

  factory ProviderConfig.fromJson(Map<String, dynamic> json) => ProviderConfig(
        id: json['id'] as String? ?? (json['name'] as String? ?? ''),
        enabled: json['enabled'] as bool? ?? true,
        name: json['name'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
        chatPath: json['chatPath'] as String?,
        useResponseApi: json['useResponseApi'] as bool?,
        vertexAI: json['vertexAI'] as bool?,
        location: json['location'] as String?,
        projectId: json['projectId'] as String?,
        models: (json['models'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        modelOverrides: (json['modelOverrides'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? const {},
        proxyEnabled: json['proxyEnabled'] as bool?,
        proxyHost: json['proxyHost'] as String?,
        proxyPort: json['proxyPort'] as String?,
        proxyUsername: json['proxyUsername'] as String?,
        proxyPassword: json['proxyPassword'] as String?,
      );

  static ProviderKind classify(String key) {
    final k = key.toLowerCase();
    if (k.contains('gemini') || k.contains('google')) return ProviderKind.google;
    if (k.contains('claude') || k.contains('anthropic')) return ProviderKind.claude;
    return ProviderKind.openai;
  }

  static String _defaultBase(String key) {
    final k = key.toLowerCase();
    if (k.contains('openrouter')) return 'https://openrouter.ai/api/v1';
    if (RegExp(r'qwen|aliyun|dashscope').hasMatch(k)) return 'https://dashscope.aliyuncs.com/compatible-mode/v1';
    if (RegExp(r'bytedance|doubao|volces|ark').hasMatch(k)) return 'https://ark.cn-beijing.volces.com/api/v3';
    if (k.contains('silicon')) return 'https://api.siliconflow.cn/v1';
    if (k.contains('grok') || k.contains('x.ai') || k.contains('xai')) return 'https://api.x.ai/v1';
    if (k.contains('deepseek')) return 'https://api.deepseek.com/v1';
    if (RegExp(r'zhipu|智谱|glm').hasMatch(k)) return 'https://open.bigmodel.cn/api/paas/v4';
    if (k.contains('gemini') || k.contains('google')) return 'https://generativelanguage.googleapis.com/v1beta';
    if (k.contains('claude') || k.contains('anthropic')) return 'https://api.anthropic.com/v1';
    return 'https://api.openai.com/v1';
  }

  static ProviderConfig defaultsFor(String key, {String? displayName}) {
    bool _defaultEnabled(String k) {
      final s = k.toLowerCase();
      if (s.contains('openai')) return true;
      if (s.contains('gemini') || s.contains('google')) return true;
      if (s.contains('silicon')) return true;
      if (s.contains('openrouter')) return true;
      return false; // others disabled by default
    }
    final kind = classify(key);
    switch (kind) {
      case ProviderKind.google:
        return ProviderConfig(
          id: key,
          enabled: _defaultEnabled(key),
          name: displayName ?? key,
          apiKey: '',
          baseUrl: _defaultBase(key),
          vertexAI: false,
          location: '',
          projectId: '',
          models: const [],
          modelOverrides: const {},
          proxyEnabled: false,
          proxyHost: '',
          proxyPort: '8080',
          proxyUsername: '',
          proxyPassword: '',
        );
      case ProviderKind.claude:
        return ProviderConfig(
          id: key,
          enabled: _defaultEnabled(key),
          name: displayName ?? key,
          apiKey: '',
          baseUrl: _defaultBase(key),
          models: const [],
          modelOverrides: const {},
          proxyEnabled: false,
          proxyHost: '',
          proxyPort: '8080',
          proxyUsername: '',
          proxyPassword: '',
        );
      case ProviderKind.openai:
      default:
        return ProviderConfig(
          id: key,
          enabled: _defaultEnabled(key),
          name: displayName ?? key,
          apiKey: '',
          baseUrl: _defaultBase(key),
          chatPath: '/chat/completions',
          useResponseApi: false,
          models: const [],
          modelOverrides: const {},
          proxyEnabled: false,
          proxyHost: '',
          proxyPort: '8080',
          proxyUsername: '',
          proxyPassword: '',
        );
    }
  }
}
