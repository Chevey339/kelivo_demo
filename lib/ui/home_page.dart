import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

import '../widgets/chat_input_bar.dart';
import '../models/chat_input_data.dart';
import '../widgets/bottom_tools_sheet.dart';
import '../widgets/side_drawer.dart';
import '../widgets/chat_message_widget.dart';
import '../theme/design_tokens.dart';
import '../icons/lucide_adapter.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/assistant_provider.dart';
import '../services/prompt_transformer.dart';
import '../services/chat_service.dart';
import '../services/chat_api_service.dart';
import '../services/document_text_extractor.dart';
import '../services/mcp_tool_service.dart';
import '../models/token_usage.dart';
import '../providers/model_provider.dart';
import '../providers/mcp_provider.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'model_select_sheet.dart';
import 'language_select_sheet.dart';
import 'message_more_sheet.dart';
import 'mcp_assistant_sheet.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'reasoning_budget_sheet.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, RouteAware {
  bool _toolsOpen = false;
  static const double _sheetHeight = 160; // height of tools area
  // Animation tuning
  static const Duration _scrollAnimateDuration = Duration(milliseconds: 300);
  static const Duration _postSwitchScrollDelay = Duration(milliseconds: 220);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _inputFocus = FocusNode();
  final TextEditingController _inputController = TextEditingController();
  final ChatInputBarController _mediaController = ChatInputBarController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _convoFadeController;
  late final Animation<double> _convoFade;

  late ChatService _chatService;
  Conversation? _currentConversation;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  StreamSubscription? _messageStreamSubscription;
  final Map<String, _ReasoningData> _reasoning = <String, _ReasoningData>{};
  final Map<String, _TranslationData> _translations = <String, _TranslationData>{};
  final Map<String, List<ToolUIPart>> _toolParts = <String, List<ToolUIPart>>{}; // assistantMessageId -> parts
  final Map<String, List<_ReasoningSegmentData>> _reasoningSegments = <String, List<_ReasoningSegmentData>>{}; // assistantMessageId -> reasoning segments
  McpProvider? _mcpProvider;
  Set<String> _connectedMcpIds = <String>{};

  // Helper methods to serialize/deserialize reasoning segments
  String _serializeReasoningSegments(List<_ReasoningSegmentData> segments) {
    final list = segments.map((s) => {
      'text': s.text,
      'startAt': s.startAt?.toIso8601String(),
      'finishedAt': s.finishedAt?.toIso8601String(),
      'expanded': s.expanded,
      'toolStartIndex': s.toolStartIndex,
    }).toList();
    return jsonEncode(list);
  }

  List<_ReasoningSegmentData> _deserializeReasoningSegments(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((item) {
        final s = _ReasoningSegmentData();
        s.text = item['text'] ?? '';
        s.startAt = item['startAt'] != null ? DateTime.parse(item['startAt']) : null;
        s.finishedAt = item['finishedAt'] != null ? DateTime.parse(item['finishedAt']) : null;
        s.expanded = item['expanded'] ?? false;
        s.toolStartIndex = (item['toolStartIndex'] as int?) ?? 0;
        return s;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  bool _isReasoningModel(String providerKey, String modelId) {
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(providerKey);
    final ov = cfg.modelOverrides[modelId] as Map?;
    if (ov != null) {
      final abilities = (ov['abilities'] as List?)?.map((e) => e.toString()).toList() ?? const [];
      if (abilities.map((e) => e.toLowerCase()).contains('reasoning')) return true;
    }
    final inferred = ModelRegistry.infer(ModelInfo(id: modelId, displayName: modelId));
    return inferred.abilities.contains(ModelAbility.reasoning);
  }

  void _cancelStreaming() async {
    // Cancel active stream subscription, if any
    final sub = _messageStreamSubscription;
    _messageStreamSubscription = null;
    await sub?.cancel();

    // Find the latest assistant streaming message and mark it finished
    ChatMessage? streaming;
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role == 'assistant' && m.isStreaming) {
        streaming = m;
        break;
      }
    }
    if (streaming != null) {
      // Persist whatever content we have so far and mark finished
      await _chatService.updateMessage(
        streaming.id,
        content: streaming.content,
        isStreaming: false,
        totalTokens: streaming.totalTokens,
      );
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == streaming!.id);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(isStreaming: false);
          }
          _isLoading = false;
        });
      }
      final r = _reasoning[streaming.id];
      if (r != null) {
        if (r.finishedAt == null) {
          r.finishedAt = DateTime.now();
          await _chatService.updateMessage(
            streaming.id,
            reasoningText: r.text,
            reasoningFinishedAt: r.finishedAt,
          );
        }
        final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
        if (autoCollapse) {
          r.expanded = false;
        }
        _reasoning[streaming.id] = r;
        if (mounted) setState(() {});
      }

      // Also finalize any unfinished reasoning segment blocks and persist them
      final segs = _reasoningSegments[streaming.id];
      if (segs != null && segs.isNotEmpty && segs.last.finishedAt == null) {
        segs.last.finishedAt = DateTime.now();
        final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
        if (autoCollapse) {
          segs.last.expanded = false;
        }
        _reasoningSegments[streaming.id] = segs;
        await _chatService.updateMessage(
          streaming.id,
          reasoningSegmentsJson: _serializeReasoningSegments(segs),
        );
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isReasoningEnabled(int? budget) {
    if (budget == null) return true; // treat null as default/auto -> enabled
    if (budget == -1) return true; // auto
    return budget >= 1024;
  }

  String _titleForLocale(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'zh' ? '新聊天' : 'New Chat';
  }

  void _toggleTools() {
    setState(() {
      final opening = !_toolsOpen;
      _toolsOpen = !_toolsOpen;
      if (opening) _dismissKeyboard();
    });
  }

  void _dismissKeyboard() {
    _inputFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    super.initState();
    _convoFadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _convoFade = CurvedAnimation(parent: _convoFadeController, curve: Curves.easeOutCubic);
    _convoFadeController.value = 1.0;
    // Use the provided ChatService instance
    _chatService = context.read<ChatService>();
    _initChat();

    // Attach MCP provider listener to auto-join new connected servers
    try {
      _mcpProvider = context.read<McpProvider>();
      _connectedMcpIds = _mcpProvider!.connectedServers.map((s) => s.id).toSet();
      _mcpProvider!.addListener(_onMcpChanged);
    } catch (_) {}

    // 监听键盘弹出
    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus) {
        // 延迟一下等待键盘完全弹出
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToBottom();
        });
      }
    });
  }

  Future<void> _initChat() async {
    await _chatService.init();
    // Respect user preference: create new chat on launch
    final prefs = context.read<SettingsProvider>();
    if (prefs.newChatOnLaunch) {
      await _createNewConversation();
    } else {
      // When disabled, jump to the most recent conversation if exists
      final conversations = _chatService.getAllConversations();
      if (conversations.isNotEmpty) {
        final recent = conversations.first; // already sorted by updatedAt desc
        _chatService.setCurrentConversation(recent.id);
        final msgs = _chatService.getMessages(recent.id);
        setState(() {
          _currentConversation = recent;
          _messages = List.of(msgs);
          _reasoning.clear();
          _translations.clear();
          _toolParts.clear();
          _reasoningSegments.clear();
          for (final m in _messages) {
            if (m.role == 'assistant') {
              // Restore reasoning state
              final txt = m.reasoningText ?? '';
              if (txt.isNotEmpty || m.reasoningStartAt != null || m.reasoningFinishedAt != null) {
                final rd = _ReasoningData();
                rd.text = txt;
                rd.startAt = m.reasoningStartAt;
                rd.finishedAt = m.reasoningFinishedAt;
                rd.expanded = false;
                _reasoning[m.id] = rd;
              }
              // Restore tool events persisted for this assistant message
              final events = _chatService.getToolEvents(m.id);
              if (events.isNotEmpty) {
                _toolParts[m.id] = events
                    .map((e) => ToolUIPart(
                  id: (e['id'] ?? '').toString(),
                  toolName: (e['name'] ?? '').toString(),
                  arguments: (e['arguments'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
                  content: (e['content']?.toString().isNotEmpty == true) ? e['content'].toString() : null,
                  loading: !(e['content']?.toString().isNotEmpty == true),
                ))
                    .toList();
              }
              // Restore reasoning segments
              final segments = _deserializeReasoningSegments(m.reasoningSegmentsJson);
              if (segments.isNotEmpty) {
                _reasoningSegments[m.id] = segments;
              }
            }
            // Restore translation collapsed by default
            if (m.translation != null && m.translation!.isNotEmpty) {
              final td = _TranslationData();
              td.expanded = false;
              _translations[m.id] = td;
            }
          }
        });
        _scrollToBottomSoon();
      }
    }
  }

  // _onMcpChanged defined below; remove listener in the main dispose at bottom

  Future<void> _onMcpChanged() async {
    if (!mounted) return;
    final prov = _mcpProvider;
    if (prov == null) return;
    final now = prov.connectedServers.map((s) => s.id).toSet();
    final added = now.difference(_connectedMcpIds);
    _connectedMcpIds = now;
    // Assistant-level MCP selection is managed in Assistant settings; no per-conversation merge.
  }

  Future<List<String>> _copyPickedFiles(List<XFile> files) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory("${docs.path}/upload");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final out = <String>[];
    for (final f in files) {
      try {
        final name = f.name.isNotEmpty ? f.name : DateTime.now().millisecondsSinceEpoch.toString();
        final dest = File("${dir.path}/$name");
        await dest.writeAsBytes(await f.readAsBytes());
        out.add(dest.path);
      } catch (_) {}
    }
    return out;
  }

  Future<void> _onPickPhotos() async {
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage();
      if (files == null || files.isEmpty) return;
      final paths = await _copyPickedFiles(files);
      if (paths.isNotEmpty) {
        _mediaController.addImages(paths);
        _scrollToBottomSoon();
      }
    } catch (_) {} finally {
      if (mounted && _toolsOpen) _toggleTools();
    }
  }

  Future<void> _onPickCamera() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file == null) return;
      final paths = await _copyPickedFiles([file]);
      if (paths.isNotEmpty) {
        _mediaController.addImages(paths);
        _scrollToBottomSoon();
      }
    } catch (_) {} finally {
      if (mounted && _toolsOpen) _toggleTools();
    }
  }

  String _inferMimeByExtension(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.js')) return 'application/javascript';
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return 'text/plain';
    return 'text/plain';
  }

  Future<void> _onPickFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
        type: FileType.custom,
        allowedExtensions: const [
          'txt','md','json','js','pdf','docx'
        ],
      );
      if (res == null || res.files.isEmpty) return;
      final docs = <DocumentAttachment>[];
      final toCopy = <XFile>[];
      for (final f in res.files) {
        if (f.path != null && f.path!.isNotEmpty) {
          toCopy.add(XFile(f.path!));
        }
      }
      final saved = await _copyPickedFiles(toCopy);
      for (int i = 0; i < saved.length; i++) {
        final orig = res.files[i];
        final savedPath = saved[i];
        final name = orig.name;
        final mime = _inferMimeByExtension(name);
        docs.add(DocumentAttachment(path: savedPath, fileName: name, mime: mime));
      }
      if (docs.isNotEmpty) {
        _mediaController.addFiles(docs);
        _scrollToBottomSoon();
      }
    } catch (_) {} finally {
      if (mounted && _toolsOpen) _toggleTools();
    }
  }

  Future<void> _createNewConversation() async {
    final ap = context.read<AssistantProvider>();
    final settings = context.read<SettingsProvider>();
    final assistantId = ap.currentAssistantId;
    // If assistant has a default chat model, seed the global current model for this new conversation
    final a = ap.currentAssistant;
    if (a?.chatModelProvider != null && a?.chatModelId != null) {
      await settings.setCurrentModel(a!.chatModelProvider!, a.chatModelId!);
    }
    final conversation = await _chatService.createDraftConversation(title: '新对话', assistantId: assistantId);
    // Default-enable MCP: select all connected servers for this conversation
    // MCP defaults are now managed per assistant; no per-conversation enabling here
    setState(() {
      _currentConversation = conversation;
      _messages = [];
      _reasoning.clear();
      _translations.clear();
      _toolParts.clear();
      _reasoningSegments.clear();
    });
    _scrollToBottomSoon();
  }

  Future<void> _sendMessage(ChatInputData input) async {
    final content = input.text.trim();
    if (content.isEmpty && input.imagePaths.isEmpty && input.documents.isEmpty) return;
    if (_currentConversation == null) await _createNewConversation();

    final settings = context.read<SettingsProvider>();
    // Use the user's currently selected model (seeded on new chat by assistant default if set)
    final providerKey = settings.currentModelProvider;
    final modelId = settings.currentModelId;
    final assistant = context.read<AssistantProvider>().currentAssistant;

    if (providerKey == null || modelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择模型')),
      );
      return;
    }

    // Add user message
    // Persist user message; append image and document markers for display
    final imageMarkers = input.imagePaths.map((p) => '\n[image:$p]').join();
    final docMarkers = input.documents.map((d) => '\n[file:${d.path}|${d.fileName}|${d.mime}]').join();
    final userMessage = await _chatService.addMessage(
      conversationId: _currentConversation!.id,
      role: 'user',
      content: content + imageMarkers + docMarkers,
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    // 延迟滚动确保UI更新完成
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });

    // Create assistant message placeholder
    final assistantMessage = await _chatService.addMessage(
      conversationId: _currentConversation!.id,
      role: 'assistant',
      content: '',
      modelId: modelId,
      providerId: providerKey,
      isStreaming: true,
    );

    setState(() {
      _messages.add(assistantMessage);
    });

    // Reset tool parts for this new assistant message
    _toolParts.remove(assistantMessage.id);

    // Initialize reasoning state only when enabled and model supports it
    final supportsReasoning = _isReasoningModel(providerKey, modelId);
    final enableReasoning = supportsReasoning && _isReasoningEnabled((assistant?.thinkingBudget) ?? settings.thinkingBudget);
    if (enableReasoning) {
      final rd = _ReasoningData();
      _reasoning[assistantMessage.id] = rd;
      await _chatService.updateMessage(
        assistantMessage.id,
        reasoningStartAt: DateTime.now(),
      );
    }

    // 添加助手消息后也滚动到底部
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });

    // Prepare messages for API
    // Prepare messages for API, but transform the last user message to include document content
    final apiMessages = _messages
        .where((m) => m.content.isNotEmpty)
        .map((m) => {
      'role': m.role == 'assistant' ? 'assistant' : 'user',
      'content': m.content,
    })
        .toList();

    // Build document prompts and clean markers in last user message
    if (apiMessages.isNotEmpty) {
      // Find last user message index in apiMessages
      int lastUserIdx = -1;
      for (int i = apiMessages.length - 1; i >= 0; i--) {
        if (apiMessages[i]['role'] == 'user') { lastUserIdx = i; break; }
      }
      if (lastUserIdx != -1) {
        final raw = (apiMessages[lastUserIdx]['content'] ?? '').toString();
        final cleaned = raw
            .replaceAll(RegExp(r"\[image:.*?\]"), '')
            .replaceAll(RegExp(r"\[file:.*?\]"), '')
            .trim();
        // Build document prompts
        final filePrompts = StringBuffer();
        for (final d in input.documents) {
          try {
            final text = await DocumentTextExtractor.extract(path: d.path, mime: d.mime);
            filePrompts.writeln('## user sent a file: ${d.fileName}');
            filePrompts.writeln('<content>');
            filePrompts.writeln('```');
            filePrompts.writeln(text);
            filePrompts.writeln('```');
            filePrompts.writeln('</content>');
            filePrompts.writeln();
          } catch (_) {}
        }
        final merged = (filePrompts.toString() + cleaned).trim();
        final userText = merged.isEmpty ? cleaned : merged;
        // Apply message template if set
        final templ = (assistant?.messageTemplate ?? '{{ message }}').trim().isEmpty
            ? '{{ message }}'
            : (assistant!.messageTemplate);
        final templated = PromptTransformer.applyMessageTemplate(
          templ,
          role: 'user',
          message: userText,
          now: DateTime.now(),
        );
        apiMessages[lastUserIdx]['content'] = templated;
      }
    }

    // Inject system prompt (assistant.systemPrompt with placeholders)
    if ((assistant?.systemPrompt.trim().isNotEmpty ?? false)) {
      final vars = PromptTransformer.buildPlaceholders(
        context: context,
        assistant: assistant!,
        modelId: modelId,
        modelName: modelId,
        userNickname: context.read<UserProvider>().name,
      );
      final sys = PromptTransformer.replacePlaceholders(assistant.systemPrompt, vars);
      apiMessages.insert(0, {'role': 'system', 'content': sys});
    }

    // Limit context length according to assistant settings
    if ((assistant?.contextMessageSize ?? 0) > 0) {
      final keep = assistant!.contextMessageSize.clamp(1, 512).toInt();
      // Always keep the first message if it's system
      int startIdx = 0;
      if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
        startIdx = 1;
      }
      final tail = apiMessages.sublist(startIdx);
      if (tail.length > keep) {
        final trimmed = tail.sublist(tail.length - keep);
        apiMessages
          ..removeRange(startIdx, apiMessages.length)
          ..addAll(trimmed);
      }
    }

    // Get provider config
    final config = settings.getProviderConfig(providerKey);

    // Stream response
    String fullContent = '';
    int totalTokens = 0;
    TokenUsage? usage;

    try {
      // Prepare MCP tools (if any selected for this conversation)
      List<Map<String, dynamic>>? toolDefs;
      Future<String> Function(String, Map<String, dynamic>)? onToolCall;
      final mcp = context.read<McpProvider>();
      final toolSvc = context.read<McpToolService>();
      final tools = toolSvc.listAvailableToolsForAssistant(mcp, context.read<AssistantProvider>(), assistant?.id);
      if (tools.isNotEmpty) {
        toolDefs = tools.map((t) {
          final props = <String, dynamic>{
            for (final p in t.params) p.name: {'type': 'string'},
          };
          final required = [for (final p in t.params.where((e) => e.required)) p.name];
          return {
            'type': 'function',
            'function': {
              'name': t.name,
              if ((t.description ?? '').isNotEmpty) 'description': t.description,
              'parameters': {
                'type': 'object',
                'properties': props,
                'required': required,
              },
            }
          };
        }).toList();
        onToolCall = (name, args) async {
          final text = await toolSvc.callToolTextForAssistant(
            mcp,
            context.read<AssistantProvider>(),
            assistantId: assistant?.id,
            toolName: name,
            arguments: args,
          );
          return text;
        };
      }

      final stream = ChatApiService.sendMessageStream(
        config: config,
        modelId: modelId,
        messages: apiMessages,
        userImagePaths: input.imagePaths,
        thinkingBudget: assistant?.thinkingBudget ?? settings.thinkingBudget,
        temperature: assistant?.temperature,
        topP: assistant?.topP,
        maxTokens: assistant?.maxTokens,
        tools: toolDefs,
        onToolCall: onToolCall,
      );

      Future<void> finish({bool generateTitle = true}) async {
        await _chatService.updateMessage(
          assistantMessage.id,
          content: fullContent,
          totalTokens: totalTokens,
          isStreaming: false,
        );
        if (!mounted) return;
        setState(() {
          final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              content: fullContent,
              totalTokens: totalTokens,
              isStreaming: false,
            );
          }
          _isLoading = false;
        });
        final r = _reasoning[assistantMessage.id];
        if (r != null) {
          if (r.finishedAt == null) {
            r.finishedAt = DateTime.now();
          }
          final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
          if (autoCollapse) {
            r.expanded = false; // auto close after finish
          }
          _reasoning[assistantMessage.id] = r;
          if (mounted) setState(() {});
        }

        // Also finish any unfinished reasoning segments
        final segments = _reasoningSegments[assistantMessage.id];
        if (segments != null && segments.isNotEmpty && segments.last.finishedAt == null) {
          segments.last.finishedAt = DateTime.now();
          final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
          if (autoCollapse) {
            segments.last.expanded = false;
          }
          _reasoningSegments[assistantMessage.id] = segments;
          if (mounted) setState(() {});
        }

        // Save reasoning segments to database
        if (segments != null && segments.isNotEmpty) {
          await _chatService.updateMessage(
            assistantMessage.id,
            reasoningSegmentsJson: _serializeReasoningSegments(segments),
          );
        }
        if (generateTitle) {
          _maybeGenerateTitle();
        }
      }

      _messageStreamSubscription?.cancel();
      _messageStreamSubscription = stream.listen(
            (chunk) async {
          // Capture reasoning deltas only when reasoning is enabled
          if ((chunk.reasoning ?? '').isNotEmpty && _isReasoningEnabled((assistant?.thinkingBudget) ?? settings.thinkingBudget)) {
            final r = _reasoning[assistantMessage.id] ?? _ReasoningData();
            r.text += chunk.reasoning!;
            r.startAt ??= DateTime.now();
            r.finishedAt = null;
            r.expanded = true; // auto expand while generating
            _reasoning[assistantMessage.id] = r;

            // Add to reasoning segments for mixed display
            final segments = _reasoningSegments[assistantMessage.id] ?? <_ReasoningSegmentData>[];

            if (segments.isEmpty) {
              // First reasoning segment
              final newSegment = _ReasoningSegmentData();
              newSegment.text = chunk.reasoning!;
              newSegment.startAt = DateTime.now();
              newSegment.expanded = true;
              newSegment.toolStartIndex = (_toolParts[assistantMessage.id]?.length ?? 0);
              segments.add(newSegment);
            } else {
              // Check if we should start a new segment (after tool calls)
              final hasToolsAfterLastSegment = (_toolParts[assistantMessage.id]?.isNotEmpty ?? false);
              final lastSegment = segments.last;

              if (hasToolsAfterLastSegment && lastSegment.finishedAt != null) {
                // Start a new segment after tools
                final newSegment = _ReasoningSegmentData();
                newSegment.text = chunk.reasoning!;
                newSegment.startAt = DateTime.now();
                newSegment.expanded = true;
                newSegment.toolStartIndex = (_toolParts[assistantMessage.id]?.length ?? 0);
                segments.add(newSegment);
              } else {
                // Continue current segment
                lastSegment.text += chunk.reasoning!;
                lastSegment.startAt ??= DateTime.now();
              }
            }
            _reasoningSegments[assistantMessage.id] = segments;

            // Save segments to database periodically
            await _chatService.updateMessage(
              assistantMessage.id,
              reasoningSegmentsJson: _serializeReasoningSegments(segments),
            );

            if (mounted) setState(() {});
            await _chatService.updateMessage(
              assistantMessage.id,
              reasoningText: r.text,
              reasoningStartAt: r.startAt,
            );
          }

          // MCP tool call placeholders
          if ((chunk.toolCalls ?? const []).isNotEmpty) {
            // Finish current reasoning segment if exists, and auto-collapse per settings
            final segments = _reasoningSegments[assistantMessage.id] ?? <_ReasoningSegmentData>[];
            if (segments.isNotEmpty && segments.last.finishedAt == null) {
              segments.last.finishedAt = DateTime.now();
              final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
              if (autoCollapse) {
                segments.last.expanded = false;
                final rd = _reasoning[assistantMessage.id];
                if (rd != null) rd.expanded = false;
              }
              _reasoningSegments[assistantMessage.id] = segments;
              // Persist closed segment state
              await _chatService.updateMessage(
                assistantMessage.id,
                reasoningSegmentsJson: _serializeReasoningSegments(segments),
              );
            }

            // Simply append new tool calls instead of merging by ID/name
            // This allows multiple calls to the same tool
            final existing = List<ToolUIPart>.of(_toolParts[assistantMessage.id] ?? const []);
            for (final c in chunk.toolCalls!) {
              existing.add(ToolUIPart(id: c.id, toolName: c.name, arguments: c.arguments, loading: true));
            }
            setState(() {
              _toolParts[assistantMessage.id] = existing;
            });

            // Persist placeholders - append new events
            try {
              final prev = _chatService.getToolEvents(assistantMessage.id);
              final newEvents = <Map<String, dynamic>>[
                ...prev,
                for (final c in chunk.toolCalls!)
                  {
                    'id': c.id,
                    'name': c.name,
                    'arguments': c.arguments,
                    'content': null,
                  },
              ];
              await _chatService.setToolEvents(assistantMessage.id, newEvents);
            } catch (_) {}
          }

          // MCP tool results -> hydrate placeholders in-place (avoid extra tool message cards)
          if ((chunk.toolResults ?? const []).isNotEmpty) {
            final parts = List<ToolUIPart>.of(_toolParts[assistantMessage.id] ?? const []);
            for (final r in chunk.toolResults!) {
              // Find the first loading tool with matching ID or name
              // This ensures we update the correct placeholder even with multiple same-name tools
              int idx = -1;
              for (int i = 0; i < parts.length; i++) {
                if (parts[i].loading && (parts[i].id == r.id || (parts[i].id.isEmpty && parts[i].toolName == r.name))) {
                  idx = i;
                  break;
                }
              }

              if (idx >= 0) {
                parts[idx] = ToolUIPart(
                  id: parts[idx].id,
                  toolName: parts[idx].toolName,
                  arguments: parts[idx].arguments,
                  content: r.content,
                  loading: false,
                );
              } else {
                // If we didn't see the placeholder (edge case), append a finished part
                parts.add(ToolUIPart(
                  id: r.id,
                  toolName: r.name,
                  arguments: r.arguments,
                  content: r.content,
                  loading: false,
                ));
              }
              // Persist each event update
              try {
                await _chatService.upsertToolEvent(
                  assistantMessage.id,
                  id: r.id,
                  name: r.name,
                  arguments: r.arguments,
                  content: r.content,
                );
              } catch (_) {}
            }
            setState(() {
              _toolParts[assistantMessage.id] = parts;
            });
            _scrollToBottomSoon();
          }

          if (chunk.isDone) {
            // Guard: if we have any loading tool-call placeholders, a follow-up round is coming.
            final hasLoadingTool = (_toolParts[assistantMessage.id]?.any((p) => p.loading) ?? false);
            if (hasLoadingTool) {
              // Skip finishing now; wait for follow-up round.
              return;
            }
            // Capture final usage/tokens if only provided at end
            if (chunk.totalTokens > 0) {
              totalTokens = chunk.totalTokens;
            }
            if (chunk.usage != null) {
              usage = (usage ?? const TokenUsage()).merge(chunk.usage!);
              totalTokens = usage!.totalTokens;
            }
            await finish();
            await _messageStreamSubscription?.cancel();
            _messageStreamSubscription = null;
            final r = _reasoning[assistantMessage.id];
            if (r != null && r.finishedAt == null) {
              r.finishedAt = DateTime.now();
              await _chatService.updateMessage(
                assistantMessage.id,
                reasoningText: r.text,
                reasoningFinishedAt: r.finishedAt,
              );
            }
          } else {
            fullContent += chunk.content;
            if (chunk.totalTokens > 0) {
              totalTokens = chunk.totalTokens;
            }
            if (chunk.usage != null) {
              usage = (usage ?? const TokenUsage()).merge(chunk.usage!);
              totalTokens = usage!.totalTokens;
            }

            // If content has started, consider reasoning finished and collapse
            if ((chunk.content).isNotEmpty) {
              final r = _reasoning[assistantMessage.id];
              if (r != null && r.startAt != null && r.finishedAt == null) {
                r.finishedAt = DateTime.now();
                final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
                if (autoCollapse) {
                  r.expanded = false; // auto collapse once main content starts
                }
                _reasoning[assistantMessage.id] = r;
                await _chatService.updateMessage(
                  assistantMessage.id,
                  reasoningText: r.text,
                  reasoningFinishedAt: r.finishedAt,
                );
                if (mounted) setState(() {});
              }

              // Also finish the current reasoning segment
              final segments = _reasoningSegments[assistantMessage.id];
              if (segments != null && segments.isNotEmpty && segments.last.finishedAt == null) {
                segments.last.finishedAt = DateTime.now();
                final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
                if (autoCollapse) {
                  segments.last.expanded = false;
                }
                _reasoningSegments[assistantMessage.id] = segments;
                if (mounted) setState(() {});
                // Persist closed segment state
                await _chatService.updateMessage(
                  assistantMessage.id,
                  reasoningSegmentsJson: _serializeReasoningSegments(segments),
                );
              }
            }

            // Update UI with streaming content
            if (mounted) {
              setState(() {
                final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
                if (index != -1) {
                  _messages[index] = _messages[index].copyWith(
                    content: fullContent,
                    totalTokens: totalTokens,
                  );
                }
              });
            }

            // Persist partial content so it's saved even if interrupted
            await _chatService.updateMessage(
              assistantMessage.id,
              content: fullContent,
              totalTokens: totalTokens,
            );

            // 滚动到底部显示新内容
            Future.delayed(const Duration(milliseconds: 50), () {
              _scrollToBottom();
            });
          }
        },
        onError: (e) async {
          // Preserve partial content; just finalize state and notify user
          await _chatService.updateMessage(
            assistantMessage.id,
            content: fullContent,
            totalTokens: totalTokens,
            isStreaming: false,
          );

          if (!mounted) return;
          setState(() {
            final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                content: fullContent.isNotEmpty ? fullContent : _messages[index].content,
                isStreaming: false,
                totalTokens: totalTokens,
              );
            }
            _isLoading = false;
          });

          // End reasoning on error
          final r = _reasoning[assistantMessage.id];
          if (r != null) {
            if (r.finishedAt == null) {
              r.finishedAt = DateTime.now();
              await _chatService.updateMessage(
                assistantMessage.id,
                reasoningText: r.text,
                reasoningFinishedAt: r.finishedAt,
              );
            }
            final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
            if (autoCollapse) {
              r.expanded = false;
            }
            _reasoning[assistantMessage.id] = r;
          }

          // Also finish any unfinished reasoning segments on error
          final segments = _reasoningSegments[assistantMessage.id];
          if (segments != null && segments.isNotEmpty && segments.last.finishedAt == null) {
            segments.last.finishedAt = DateTime.now();
            final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
            if (autoCollapse) {
              segments.last.expanded = false;
            }
            _reasoningSegments[assistantMessage.id] = segments;
            // Persist closed segment state
            try {
              await _chatService.updateMessage(
                assistantMessage.id,
                reasoningSegmentsJson: _serializeReasoningSegments(segments),
              );
            } catch (_) {}
          }

          _messageStreamSubscription = null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('生成已中断: $e')),
          );
        },
        onDone: () async {
          // If stream closed without explicit isDone chunk, finalize
          if (_isLoading) {
            await finish(generateTitle: true);
          }
          _messageStreamSubscription = null;
        },
        cancelOnError: true,
      );
    } catch (e) {
      // Preserve partial content on outer error as well
      await _chatService.updateMessage(
        assistantMessage.id,
        content: fullContent,
        totalTokens: totalTokens,
        isStreaming: false,
      );

      setState(() {
        final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            content: fullContent.isNotEmpty ? fullContent : _messages[index].content,
            isStreaming: false,
            totalTokens: totalTokens,
          );
        }
        _isLoading = false;
      });

      // End reasoning on error
      final r = _reasoning[assistantMessage.id];
      if (r != null) {
        r.finishedAt = DateTime.now();
        final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
        if (autoCollapse) {
          r.expanded = false;
        }
        _reasoning[assistantMessage.id] = r;
        await _chatService.updateMessage(
          assistantMessage.id,
          reasoningText: r.text,
          reasoningFinishedAt: r.finishedAt,
        );
      }

      // Also finish any unfinished reasoning segments on error
      final segments = _reasoningSegments[assistantMessage.id];
      if (segments != null && segments.isNotEmpty && segments.last.finishedAt == null) {
        segments.last.finishedAt = DateTime.now();
        final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
        if (autoCollapse) {
          segments.last.expanded = false;
        }
        _reasoningSegments[assistantMessage.id] = segments;
        // Persist closed segment state
        try {
          await _chatService.updateMessage(
            assistantMessage.id,
            reasoningSegmentsJson: _serializeReasoningSegments(segments),
          );
        } catch (_) {}
      }

      _messageStreamSubscription = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成已中断: $e')),
      );
    }
  }

  ChatInputData _parseInputFromRaw(String raw) {
    final imgRe = RegExp(r"\[image:(.+?)\]");
    final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
    final images = <String>[];
    final docs = <DocumentAttachment>[];
    final buffer = StringBuffer();
    int idx = 0;
    while (idx < raw.length) {
      final imgMatch = imgRe.matchAsPrefix(raw, idx);
      final fileMatch = fileRe.matchAsPrefix(raw, idx);
      if (imgMatch != null) {
        final p = imgMatch.group(1)?.trim();
        if (p != null && p.isNotEmpty) images.add(p);
        idx = imgMatch.end;
        continue;
      }
      if (fileMatch != null) {
        final path = fileMatch.group(1)?.trim() ?? '';
        final name = fileMatch.group(2)?.trim() ?? 'file';
        final mime = fileMatch.group(3)?.trim() ?? 'text/plain';
        docs.add(DocumentAttachment(path: path, fileName: name, mime: mime));
        idx = fileMatch.end;
        continue;
      }
      buffer.write(raw[idx]);
      idx++;
    }
    return ChatInputData(text: buffer.toString().trim(), imagePaths: images, documents: docs);
  }

  Future<void> _maybeGenerateTitle({bool force = false}) async {
    final convo = _currentConversation;
    if (convo == null) return;
    if (!force && convo.title.isNotEmpty && convo.title != '新对话') return;

    final settings = context.read<SettingsProvider>();
    // Decide model: prefer title model, else fall back to current chat model
    final provKey = settings.titleModelProvider ?? settings.currentModelProvider;
    final mdlId = settings.titleModelId ?? settings.currentModelId;
    if (provKey == null || mdlId == null) return;
    final cfg = settings.getProviderConfig(provKey);

    // Build content from messages (truncate to reasonable length)
    final msgs = _chatService.getMessages(convo.id);
    final joined = msgs
        .where((m) => m.content.isNotEmpty)
        .map((m) => '${m.role == 'assistant' ? 'Assistant' : 'User'}: ${m.content}')
        .join('\n\n');
    final content = joined.length > 3000 ? joined.substring(0, 3000) : joined;
    final locale = Localizations.localeOf(context).toLanguageTag();

    String prompt = settings.titlePrompt
        .replaceAll('{locale}', locale)
        .replaceAll('{content}', content);

    try {
      final title = (await ChatApiService.generateText(config: cfg, modelId: mdlId, prompt: prompt)).trim();
      if (title.isNotEmpty) {
        await _chatService.renameConversation(convo.id, title);
        setState(() {
          _currentConversation = _chatService.getConversation(convo.id);
        });
      }
    } catch (_) {
      // Ignore title generation failure silently
    }
  }

  void _scrollToBottom() {
    try {
      if (!_scrollController.hasClients) return;
      // Prevent using controller while it is still attached to old/new list simultaneously
      if (_scrollController.positions.length != 1) {
        // Try again after microtask when the previous list detaches
        Future.microtask(_scrollToBottom);
        return;
      }
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(max);
    } catch (_) {
      // Ignore transient attachment errors
    }
  }

  // Ensure scroll reaches bottom even after widget tree transitions
  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    Future.delayed(const Duration(milliseconds: 120), _scrollToBottom);
  }

  // Translate message functionality
  Future<void> _translateMessage(ChatMessage message) async {
    // Show language selector
    final language = await showLanguageSelector(context);
    if (language == null) return;

    // Check if clear translation is selected
    if (language.code == '__clear__') {
      // Clear the translation (use empty string so UI hides immediately)
      final updatedMessage = message.copyWith(translation: '');
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = updatedMessage;
        }
        // Remove translation state
        _translations.remove(message.id);
      });
      await _chatService.updateMessage(message.id, translation: '');
      return;
    }

    final settings = context.read<SettingsProvider>();

    // Check if translation model is set
    final translateProvider = settings.translateModelProvider ?? settings.currentModelProvider;
    final translateModelId = settings.translateModelId ?? settings.currentModelId;

    if (translateProvider == null || translateModelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先设置翻译模型')),
      );
      return;
    }

    // Extract text content from message (removing reasoning text if present)
    String textToTranslate = message.content;

    // Set loading state and initialize translation data
    final loadingMessage = message.copyWith(translation: '翻译中...');
    setState(() {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = loadingMessage;
      }
      // Initialize translation state with expanded
      _translations[message.id] = _TranslationData();
    });

    try {
      // Get translation prompt with placeholders replaced
      String prompt = settings.translatePrompt
          .replaceAll('{source_text}', textToTranslate)
          .replaceAll('{target_lang}', language.displayName);

      // Create translation request
      final provider = settings.getProviderConfig(translateProvider);

      final translationStream = ChatApiService.sendMessageStream(
        config: provider,
        modelId: translateModelId,
        messages: [
          {'role': 'user', 'content': prompt}
        ],
      );

      final buffer = StringBuffer();

      await for (final chunk in translationStream) {
        buffer.write(chunk.content);

        // Update translation in real-time
        final updatingMessage = message.copyWith(translation: buffer.toString());
        setState(() {
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index != -1) {
            _messages[index] = updatingMessage;
          }
        });
      }

      // Save final translation
      await _chatService.updateMessage(message.id, translation: buffer.toString());

    } catch (e) {
      // Clear translation on error (empty to hide immediately)
      final errorMessage = message.copyWith(translation: '');
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = errorMessage;
        }
        // Remove translation state on error
        _translations.remove(message.id);
      });

      await _chatService.updateMessage(message.id, translation: '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('翻译失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = ((_currentConversation?.title ?? '').trim().isNotEmpty)
        ? _currentConversation!.title
        : _titleForLocale(context);
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final providerKey = settings.currentModelProvider;
    final modelId = settings.currentModelId;
    String? providerName;
    String? modelDisplay;
    if (providerKey != null && modelId != null) {
      final cfg = settings.getProviderConfig(providerKey);
      providerName = cfg.name.isNotEmpty ? cfg.name : providerKey;
      final ov = cfg.modelOverrides[modelId] as Map?;
      modelDisplay = (ov != null && (ov['name'] as String?)?.isNotEmpty == true) ? (ov['name'] as String) : modelId;
    }

    // Chats are seeded via ChatProvider in main.dart

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        systemOverlayStyle: (Theme.of(context).brightness == Brightness.dark)
            ? const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light, // Android icons
          statusBarBrightness: Brightness.dark, // iOS text
        )
            : const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Lucide.ListTree, size: 22),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: Text(
                title,
                key: ValueKey<String>(title),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (providerName != null && modelDisplay != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  child: Text(
                    '$modelDisplay ($providerName)',
                    key: ValueKey<String>('${settings.currentModelKey ?? ''}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w500),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Lucide.Menu, size: 22),
          ),
          IconButton(
            onPressed: () async {
              await _createNewConversation();
              if (mounted) {
                // Close drawer if open and scroll to bottom (fresh convo)
                _scrollToBottom();
              }
            },
            icon: const Icon(Lucide.MessageCirclePlus, size: 22),
          ),
        ],
      ),
      drawer: SideDrawer(
        userName: context.watch<UserProvider>().name,
        assistantName: (() {
          final zh = Localizations.localeOf(context).languageCode == 'zh';
          final a = context.watch<AssistantProvider>().currentAssistant;
          final n = a?.name.trim();
          return (n == null || n.isEmpty) ? (zh ? '默认助手' : 'Default Assistant') : n;
        })(),
        onSelectConversation: (id) {
          // Update current selection for highlight in drawer
          _chatService.setCurrentConversation(id);
          final convo = _chatService.getConversation(id);
          if (convo != null) {
            final msgs = _chatService.getMessages(id);
            setState(() {
              _currentConversation = convo;
              _messages = List.of(msgs);
              _reasoning.clear();
              _translations.clear();
              _toolParts.clear();
              _reasoningSegments.clear();
              for (final m in _messages) {
                // Restore reasoning state
                if (m.role == 'assistant') {
                  final txt = m.reasoningText ?? '';
                  if (txt.isNotEmpty || m.reasoningStartAt != null || m.reasoningFinishedAt != null) {
                    final rd = _ReasoningData();
                    rd.text = txt;
                    rd.startAt = m.reasoningStartAt;
                    rd.finishedAt = m.reasoningFinishedAt;
                    rd.expanded = false;
                    _reasoning[m.id] = rd;
                  }
                  // Restore tool events for this message
                  final events = _chatService.getToolEvents(m.id);
                  if (events.isNotEmpty) {
                    _toolParts[m.id] = events
                        .map((e) => ToolUIPart(
                      id: (e['id'] ?? '').toString(),
                      toolName: (e['name'] ?? '').toString(),
                      arguments: (e['arguments'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
                      content: (e['content']?.toString().isNotEmpty == true) ? e['content'].toString() : null,
                      loading: !(e['content']?.toString().isNotEmpty == true),
                    ))
                        .toList();
                  }
                  // Restore reasoning segments
                  final segments = _deserializeReasoningSegments(m.reasoningSegmentsJson);
                  if (segments.isNotEmpty) {
                    _reasoningSegments[m.id] = segments;
                  }
                }
                // Restore translation state
                if (m.translation != null && m.translation!.isNotEmpty) {
                  final td = _TranslationData();
                  td.expanded = false; // default to collapsed when loading
                  _translations[m.id] = td;
                }
              }
            });
            // MCP selection is now per-assistant; no per-conversation defaults here
            _triggerConversationFade();
            _scrollToBottomSoon();
          }
          // Close the drawer when a conversation is picked
          Navigator.of(context).maybePop();
        },
        onNewConversation: () async {
          await _createNewConversation();
          if (mounted) {
            _triggerConversationFade();
            _scrollToBottom();
            Navigator.of(context).maybePop();
          }
        },
      ),
      body: Stack(
        children: [
          // Assistant-specific chat background
          Builder(builder: (context) {
            final bg = context.watch<AssistantProvider>().currentAssistant?.background;
            if (bg == null || bg.trim().isEmpty) return const SizedBox.shrink();
            ImageProvider provider;
            if (bg.startsWith('http')) {
              provider = NetworkImage(bg);
            } else {
              provider = FileImage(File(bg));
            }
            return Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: provider,
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.04), BlendMode.srcATop),
                  ),
                ),
              ),
            );
          }),
          // Main column content
          Column(
            children: [
              // Chat messages list (animate when switching topic)
              Expanded(
                child: FadeTransition(
                  opacity: _convoFade,
                  child: KeyedSubtree(
                    key: ValueKey<String>(_currentConversation?.id ?? 'none'),
                    child: (() {
                      // Stable snapshot for this build
                      final messages = List.of(_messages);
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 16, top: 8),
                        itemCount: messages.length,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemBuilder: (context, index) {
                          if (index < 0 || index >= messages.length) {
                            return const SizedBox.shrink();
                          }
                          final message = messages[index];
                          final r = _reasoning[message.id];
                          final t = _translations[message.id];
                          final chatScale = context.watch<SettingsProvider>().chatFontScale;
                          final assistant = context.watch<AssistantProvider>().currentAssistant;
                          final useAssist = assistant?.useAssistantAvatar == true;
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaleFactor: MediaQuery.of(context).textScaleFactor * chatScale,
                            ),
                            child: ChatMessageWidget(
                              message: message,
                              modelIcon: (!useAssist && message.role == 'assistant' && message.providerId != null && message.modelId != null)
                                  ? _CurrentModelIcon(providerKey: message.providerId, modelId: message.modelId)
                                  : null,
                              showModelIcon: useAssist ? false : context.watch<SettingsProvider>().showModelIcon,
                              useAssistantAvatar: useAssist && message.role == 'assistant',
                              assistantName: useAssist ? (assistant?.name ?? 'Assistant') : null,
                              assistantAvatar: useAssist ? (assistant?.avatar ?? '') : null,
                              showUserAvatar: context.watch<SettingsProvider>().showUserAvatar,
                              showTokenStats: context.watch<SettingsProvider>().showTokenStats,
                              reasoningText: (message.role == 'assistant') ? (r?.text ?? '') : null,
                              reasoningExpanded: (message.role == 'assistant') ? (r?.expanded ?? false) : false,
                              reasoningLoading: (message.role == 'assistant') ? (r?.finishedAt == null && (r?.text.isNotEmpty == true)) : false,
                              reasoningStartAt: (message.role == 'assistant') ? r?.startAt : null,
                              reasoningFinishedAt: (message.role == 'assistant') ? r?.finishedAt : null,
                              onToggleReasoning: (message.role == 'assistant' && r != null)
                                  ? () {
                                setState(() {
                                  r.expanded = !r.expanded;
                                });
                              }
                                  : null,
                              translationExpanded: t?.expanded ?? true,
                              onToggleTranslation: (message.translation != null && message.translation!.isNotEmpty && t != null)
                                  ? () {
                                setState(() {
                                  t.expanded = !t.expanded;
                                });
                              }
                                  : null,
                              onRegenerate: message.role == 'assistant'
                                  ? () {
                                // TODO: Implement regenerate
                              }
                                  : null,
                              onResend: message.role == 'user'
                                  ? () {
                                _sendMessage(_parseInputFromRaw(message.content));
                              }
                                  : null,
                              onTranslate: message.role == 'assistant'
                                  ? () {
                                _translateMessage(message);
                              }
                                  : null,
                              onMore: () async {
                                final action = await showMessageMoreSheet(context, message);
                                if (!mounted) return;
                                if (action == MessageMoreAction.delete) {
                                  final zh = Localizations.localeOf(context).languageCode == 'zh';
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(zh ? '删除消息' : 'Delete Message'),
                                      content: Text(zh ? '确定要删除这条消息吗？此操作不可撤销。' : 'Are you sure you want to delete this message? This cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(false),
                                          child: Text(zh ? '取消' : 'Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          child: Text(zh ? '删除' : 'Delete', style: const TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final id = message.id;
                                    setState(() {
                                      _messages.removeWhere((m) => m.id == id);
                                      _reasoning.remove(id);
                                      _translations.remove(id);
                                      _toolParts.remove(id);
                                      _reasoningSegments.remove(id);
                                    });
                                    await _chatService.deleteMessage(id);
                                  }
                                }
                              },
                              toolParts: message.role == 'assistant' ? _toolParts[message.id] : null,
                              reasoningSegments: message.role == 'assistant'
                                  ? (() {
                                final segments = _reasoningSegments[message.id];
                                if (segments == null || segments.isEmpty) return null;
                                return segments
                                    .map((s) => ReasoningSegment(
                                  text: s.text,
                                  expanded: s.expanded,
                                  loading: s.finishedAt == null && s.text.isNotEmpty,
                                  startAt: s.startAt,
                                  finishedAt: s.finishedAt,
                                  onToggle: () {
                                    setState(() {
                                      s.expanded = !s.expanded;
                                    });
                                  },
                                  toolStartIndex: s.toolStartIndex,
                                ))
                                    .toList();
                              })()
                                  : null,
                            ),
                          );
                        },
                      );
                    })(),
                  ),
                ),
              ),
              // Input bar; lifts when tools open
              AnimatedPadding(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: _toolsOpen ? _sheetHeight : 0),
                child: ChatInputBar(
                  onMore: _toggleTools,
                  moreOpen: _toolsOpen,
                  onSelectModel: () => showModelSelectSheet(context),
                  onOpenMcp: () {
                    final a = context.read<AssistantProvider>().currentAssistant;
                    if (a != null) {
                      showAssistantMcpSheet(context, assistantId: a.id);
                    }
                  },
                  onStop: _cancelStreaming,
                  modelIcon: (settings.showModelIcon && settings.currentModelProvider != null && settings.currentModelId != null)
                      ? _CurrentModelIcon(
                    providerKey: settings.currentModelProvider,
                    modelId: settings.currentModelId,
                    size: 34,
                  )
                      : null,
                  focusNode: _inputFocus,
                  controller: _inputController,
                  mediaController: _mediaController,
                  onConfigureReasoning: () async {
                    final assistant = context.read<AssistantProvider>().currentAssistant;
                    if (assistant != null) {
                      if (assistant.thinkingBudget != null) {
                        context.read<SettingsProvider>().setThinkingBudget(assistant.thinkingBudget);
                      }
                      await showReasoningBudgetSheet(context);
                      final chosen = context.read<SettingsProvider>().thinkingBudget;
                      await context.read<AssistantProvider>().updateAssistant(
                        assistant.copyWith(thinkingBudget: chosen),
                      );
                    }
                  },
                  reasoningActive: _isReasoningEnabled((context.watch<AssistantProvider>().currentAssistant?.thinkingBudget) ?? settings.thinkingBudget),
                  supportsReasoning: (settings.currentModelProvider != null && settings.currentModelId != null)
                      ? _isReasoningModel(settings.currentModelProvider!, settings.currentModelId!)
                      : false,
                  onSend: (text) {
                    _sendMessage(text);
                    _inputController.clear();
                    // Dismiss keyboard after sending
                    _dismissKeyboard();
                  },
                  loading: _isLoading,
                  showMcpButton: context.watch<McpProvider>().servers.isNotEmpty,
                  mcpActive: context.select<AssistantProvider, bool>((ap) => (ap.currentAssistant?.mcpServerIds.isNotEmpty ?? false)),
                ),
              ),
            ],
          ),

          // Backdrop to close sheet on tap
          IgnorePointer(
            ignoring: !_toolsOpen,
            child: AnimatedOpacity(
              opacity: _toolsOpen ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: _toggleTools,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Tools sheet overlayed at the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: AnimatedSlide(
                offset: _toolsOpen ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _toolsOpen ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: SizedBox(
                    height: _sheetHeight,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: BottomToolsSheet(
                        onPhotos: _onPickPhotos,
                        onCamera: _onPickCamera,
                        onUpload: _onPickFiles,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _convoFadeController.dispose();
    _mcpProvider?.removeListener(_onMcpChanged);
    _inputFocus.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _messageStreamSubscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _triggerConversationFade() {
    try {
      _convoFadeController.stop();
      _convoFadeController.value = 0;
      _convoFadeController.forward();
    } catch (_) {}
  }

  @override
  void didPushNext() {
    // Navigating away: drop focus so it won't be restored.
    _dismissKeyboard();
  }

  @override
  void didPopNext() {
    // Returning to this page: ensure keyboard stays closed unless user taps.
    WidgetsBinding.instance.addPostFrameCallback((_) => _dismissKeyboard());
  }
}

class _ReasoningData {
  String text = '';
  DateTime? startAt;
  DateTime? finishedAt;
  bool expanded = false;
}

class _ReasoningSegmentData {
  String text = '';
  DateTime? startAt;
  DateTime? finishedAt;
  bool expanded = true;
  int toolStartIndex = 0;
}

class _TranslationData {
  bool expanded = true; // default to expanded when translation is added
}

class _CurrentModelIcon extends StatelessWidget {
  const _CurrentModelIcon({required this.providerKey, required this.modelId, this.size = 28});
  final String? providerKey;
  final String? modelId;
  final double size; // outer diameter

  String? _assetForName(String n) {
    final lower = n.toLowerCase();
    final mapping = <RegExp, String>{
      RegExp(r'openai|gpt|o\d'): 'openai.svg',
      RegExp(r'gemini'): 'gemini-color.svg',
      RegExp(r'google'): 'google-color.svg',
      RegExp(r'claude'): 'claude-color.svg',
      RegExp(r'anthropic'): 'anthropic.svg',
      RegExp(r'deepseek'): 'deepseek-color.svg',
      RegExp(r'grok'): 'grok.svg',
      RegExp(r'qwen|qwq|qvq|aliyun|dashscope'): 'qwen-color.svg',
      RegExp(r'doubao|ark|volc'): 'doubao-color.svg',
      RegExp(r'openrouter'): 'openrouter.svg',
      RegExp(r'zhipu|智谱|glm'): 'zhipu-color.svg',
      RegExp(r'mistral'): 'mistral-color.svg',
      RegExp(r'(?<!o)llama|meta'): 'meta-color.svg',
      RegExp(r'hunyuan|tencent'): 'hunyuan-color.svg',
      RegExp(r'gemma'): 'gemma-color.svg',
      RegExp(r'perplexity'): 'perplexity-color.svg',
      RegExp(r'aliyun|阿里云|百炼'): 'alibabacloud-color.svg',
      RegExp(r'bytedance|火山'): 'bytedance-color.svg',
      RegExp(r'silicon|硅基'): 'siliconflow-color.svg',
      RegExp(r'aihubmix'): 'aihubmix-color.svg',
      RegExp(r'ollama'): 'ollama.svg',
      RegExp(r'github'): 'github.svg',
      RegExp(r'cloudflare'): 'cloudflare-color.svg',
      RegExp(r'minimax'): 'minimax-color.svg',
      RegExp(r'xai|grok'): 'xai.svg',
      RegExp(r'juhenext'): 'juhenext.png',
      RegExp(r'kimi'): 'kimi-color.svg',
      RegExp(r'302'): '302ai-color.svg',
      RegExp(r'step|阶跃'): 'stepfun-color.svg',
      RegExp(r'intern|书生'): 'internlm-color.svg',
      RegExp(r'cohere|command-.+'): 'cohere-color.svg',
    };
    for (final e in mapping.entries) {
      if (e.key.hasMatch(lower)) return 'assets/icons/${e.value}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (providerKey == null || modelId == null) return const SizedBox.shrink();
    String? asset = _assetForName(modelId!);
    asset ??= _assetForName(providerKey!);
    Widget inner;
    if (asset != null) {
      if (asset.endsWith('.svg')) {
        final isColorful = asset.contains('color');
        final ColorFilter? tint = (Theme.of(context).brightness == Brightness.dark && !isColorful)
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null;
        inner = SvgPicture.asset(
          asset,
          width: size * 0.5,
          height: size * 0.5,
          colorFilter: tint,
        );
      } else {
        inner = Image.asset(asset, width: size * 0.5, height: size * 0.5, fit: BoxFit.contain);
      }
    } else {
      inner = Text(
        modelId!.isNotEmpty ? modelId!.characters.first.toUpperCase() : '?',
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: size * 0.43),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: isDark ? Colors.white10 : cs.primary.withOpacity(0.1), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: SizedBox(
        width: size * 0.64,
        height: size * 0.64,
        child: Center(child: inner is SvgPicture || inner is Image ? inner : FittedBox(child: inner)),
      ),
    );
  }
}
