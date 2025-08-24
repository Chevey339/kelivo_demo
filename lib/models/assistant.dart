import 'dart:convert';

class Assistant {
  final String id;
  final String name;
  final String? avatar; // path/url/base64, null for initial-letter avatar
  final bool useAssistantAvatar; // replace model icon in chat with assistant avatar
  final String? chatModelProvider; // null -> use global default
  final String? chatModelId; // null -> use global default
  final double temperature; // 0.0 - 2.0
  final double topP; // 0.0 - 1.0
  final int contextMessageSize; // number of previous messages to include
  final bool streamOutput; // streaming responses
  final int? thinkingBudget; // null = use global/default; 0=off; >0 tokens budget
  final int? maxTokens; // null = unlimited
  final String systemPrompt;
  final String messageTemplate; // e.g. "{{ message }}"
  final List<String> mcpServerIds; // bound MCP server IDs
  final String? background; // chat background (color/image ref)
  final bool deletable; // can be deleted by user

  const Assistant({
    required this.id,
    required this.name,
    this.avatar,
    this.useAssistantAvatar = false,
    this.chatModelProvider,
    this.chatModelId,
    this.temperature = 0.6,
    this.topP = 1.0,
    this.contextMessageSize = 64,
    this.streamOutput = true,
    this.thinkingBudget,
    this.maxTokens,
    this.systemPrompt = '',
    this.messageTemplate = '{{ message }}',
    this.mcpServerIds = const <String>[],
    this.background,
    this.deletable = true,
  });

  Assistant copyWith({
    String? id,
    String? name,
    String? avatar,
    bool? useAssistantAvatar,
    String? chatModelProvider,
    String? chatModelId,
    double? temperature,
    double? topP,
    int? contextMessageSize,
    bool? streamOutput,
    int? thinkingBudget,
    int? maxTokens,
    String? systemPrompt,
    String? messageTemplate,
    List<String>? mcpServerIds,
    String? background,
    bool? deletable,
    bool clearChatModel = false,
    bool clearAvatar = false,
    bool clearThinkingBudget = false,
    bool clearMaxTokens = false,
    bool clearBackground = false,
  }) {
    return Assistant(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: clearAvatar ? null : (avatar ?? this.avatar),
      useAssistantAvatar: useAssistantAvatar ?? this.useAssistantAvatar,
      chatModelProvider: clearChatModel ? null : (chatModelProvider ?? this.chatModelProvider),
      chatModelId: clearChatModel ? null : (chatModelId ?? this.chatModelId),
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      contextMessageSize: contextMessageSize ?? this.contextMessageSize,
      streamOutput: streamOutput ?? this.streamOutput,
      thinkingBudget: clearThinkingBudget ? null : (thinkingBudget ?? this.thinkingBudget),
      maxTokens: clearMaxTokens ? null : (maxTokens ?? this.maxTokens),
      systemPrompt: systemPrompt ?? this.systemPrompt,
      messageTemplate: messageTemplate ?? this.messageTemplate,
      mcpServerIds: mcpServerIds ?? this.mcpServerIds,
      background: clearBackground ? null : (background ?? this.background),
      deletable: deletable ?? this.deletable,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'useAssistantAvatar': useAssistantAvatar,
        'chatModelProvider': chatModelProvider,
        'chatModelId': chatModelId,
        'temperature': temperature,
        'topP': topP,
        'contextMessageSize': contextMessageSize,
        'streamOutput': streamOutput,
        'thinkingBudget': thinkingBudget,
        'maxTokens': maxTokens,
        'systemPrompt': systemPrompt,
        'messageTemplate': messageTemplate,
        'mcpServerIds': mcpServerIds,
        'background': background,
        'deletable': deletable,
      };

  static Assistant fromJson(Map<String, dynamic> json) => Assistant(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        avatar: json['avatar'] as String?,
        useAssistantAvatar: json['useAssistantAvatar'] as bool? ?? false,
        chatModelProvider: json['chatModelProvider'] as String?,
        chatModelId: json['chatModelId'] as String?,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.6,
        topP: (json['topP'] as num?)?.toDouble() ?? 1.0,
        contextMessageSize: (json['contextMessageSize'] as num?)?.toInt() ?? 64,
        streamOutput: json['streamOutput'] as bool? ?? true,
        thinkingBudget: (json['thinkingBudget'] as num?)?.toInt(),
        maxTokens: (json['maxTokens'] as num?)?.toInt(),
        systemPrompt: (json['systemPrompt'] as String?) ?? '',
        messageTemplate: (json['messageTemplate'] as String?) ?? '{{ message }}',
        mcpServerIds: (json['mcpServerIds'] as List?)?.cast<String>() ?? const <String>[],
        background: json['background'] as String?,
        deletable: json['deletable'] as bool? ?? true,
      );

  static String encodeList(List<Assistant> list) => jsonEncode(list.map((e) => e.toJson()).toList());
  static List<Assistant> decodeList(String raw) {
    try {
      final arr = jsonDecode(raw) as List<dynamic>;
      return [for (final e in arr) Assistant.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      return const <Assistant>[];
    }
  }
}
