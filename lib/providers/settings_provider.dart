import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsProvider extends ChangeNotifier {
  static const String _providersOrderKey = 'providers_order_v1';
  static const String _themeModeKey = 'theme_mode_v1';
  static const String _providerConfigsKey = 'provider_configs_v1';

  List<String> _providersOrder = const [];
  List<String> get providersOrder => _providersOrder;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Map<String, ProviderConfig> _providerConfigs = {};
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
}

enum ProviderKind { openai, google, claude }

class ProviderConfig {
  final bool enabled;
  final String name;
  final String apiKey;
  final String baseUrl;
  final String? chatPath; // openai only
  final bool? useResponseApi; // openai only
  final bool? vertexAI; // google only

  ProviderConfig({
    required this.enabled,
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    this.chatPath,
    this.useResponseApi,
    this.vertexAI,
  });

  ProviderConfig copyWith({
    bool? enabled,
    String? name,
    String? apiKey,
    String? baseUrl,
    String? chatPath,
    bool? useResponseApi,
    bool? vertexAI,
  }) => ProviderConfig(
        enabled: enabled ?? this.enabled,
        name: name ?? this.name,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        chatPath: chatPath ?? this.chatPath,
        useResponseApi: useResponseApi ?? this.useResponseApi,
        vertexAI: vertexAI ?? this.vertexAI,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'name': name,
        'apiKey': apiKey,
        'baseUrl': baseUrl,
        'chatPath': chatPath,
        'useResponseApi': useResponseApi,
        'vertexAI': vertexAI,
      };

  factory ProviderConfig.fromJson(Map<String, dynamic> json) => ProviderConfig(
        enabled: json['enabled'] as bool? ?? true,
        name: json['name'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
        chatPath: json['chatPath'] as String?,
        useResponseApi: json['useResponseApi'] as bool?,
        vertexAI: json['vertexAI'] as bool?,
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
    final kind = classify(key);
    switch (kind) {
      case ProviderKind.google:
        return ProviderConfig(
          enabled: true,
          name: displayName ?? key,
          apiKey: '',
          baseUrl: _defaultBase(key),
          vertexAI: false,
        );
      case ProviderKind.claude:
        return ProviderConfig(
          enabled: true,
          name: displayName ?? key,
          apiKey: '',
          baseUrl: _defaultBase(key),
        );
      case ProviderKind.openai:
      default:
        return ProviderConfig(
          enabled: true,
          name: displayName ?? key,
          apiKey: '',
          baseUrl: _defaultBase(key),
          chatPath: '/chat/completions',
          useResponseApi: false,
        );
    }
  }
}
