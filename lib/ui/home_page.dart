import 'package:flutter/material.dart';
import 'dart:async';

import '../widgets/chat_input_bar.dart';
import '../widgets/bottom_tools_sheet.dart';
import '../widgets/side_drawer.dart';
import '../widgets/chat_message_widget.dart';
import '../theme/design_tokens.dart';
import '../icons/lucide_adapter.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import '../services/chat_service.dart';
import '../services/chat_api_service.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'model_select_sheet.dart';
import 'package:flutter_svg/flutter_svg.dart';


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
  final ScrollController _scrollController = ScrollController();

  late ChatService _chatService;
  Conversation? _currentConversation;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  StreamSubscription? _messageStreamSubscription;

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
    // Use the provided ChatService instance
    _chatService = context.read<ChatService>();
    _initChat();

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
    // Always start with a fresh conversation on app open
    await _createNewConversation();
  }

  Future<void> _createNewConversation() async {
    final conversation = await _chatService.createDraftConversation(title: '新对话');
    setState(() {
      _currentConversation = conversation;
      _messages = [];
    });
    _scrollToBottomSoon();
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    if (_currentConversation == null) await _createNewConversation();

    final settings = context.read<SettingsProvider>();
    final providerKey = settings.currentModelProvider;
    final modelId = settings.currentModelId;

    if (providerKey == null || modelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择模型')),
      );
      return;
    }

    // Add user message
    final userMessage = await _chatService.addMessage(
      conversationId: _currentConversation!.id,
      role: 'user',
      content: content,
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

    // 添加助手消息后也滚动到底部
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });

    // Prepare messages for API
    final apiMessages = _messages
        .where((m) => m.content.isNotEmpty)
        .map((m) => {
      'role': m.role == 'assistant' ? 'assistant' : 'user',
      'content': m.content,
    })
        .toList();

    // Get provider config
    final config = settings.getProviderConfig(providerKey);

    // Stream response
    String fullContent = '';
    int totalTokens = 0;

    try {
      final stream = ChatApiService.sendMessageStream(
        config: config,
        modelId: modelId,
        messages: apiMessages,
      );

      await for (final chunk in stream) {
        if (chunk.isDone) {
          // Update message as complete
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
                content: fullContent,
                totalTokens: totalTokens,
                isStreaming: false,
              );
            }
            _isLoading = false;
          });

          // Auto-generate title after completion
          _maybeGenerateTitle();
        } else {
          fullContent += chunk.content;
          if (chunk.totalTokens > 0) {
            totalTokens = chunk.totalTokens;
          }

          // Update UI with streaming content
          setState(() {
            final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                content: fullContent,
                totalTokens: totalTokens,
              );
            }
          });

          // 滚动到底部显示新内容
          Future.delayed(const Duration(milliseconds: 50), () {
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      // Handle error
      await _chatService.updateMessage(
        assistantMessage.id,
        content: '发生错误: $e',
        isStreaming: false,
      );

      setState(() {
        final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            content: '发生错误: $e',
            isStreaming: false,
          );
        }
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e')),
      );
    }
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: _scrollAnimateDuration,
        curve: Curves.easeOut,
      );
    }
  }

  // Ensure scroll reaches bottom even after widget tree transitions
  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    // Also scroll after list fade transition completes
    Future.delayed(_postSwitchScrollDelay, () {
      _scrollToBottom();
    });
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
        leading: IconButton(
          tooltip: Localizations.localeOf(context).languageCode == 'zh'
              ? '菜单'
              : 'Menu',
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
            tooltip: Localizations.localeOf(context).languageCode == 'zh'
                ? '更多'
                : 'Menu',
            onPressed: () {},
            icon: const Icon(Lucide.Menu, size: 22),
          ),
          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'zh'
                ? '新建话题'
                : 'New Topic',
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
        assistantName: Localizations.localeOf(context).languageCode == 'zh' ? '默认助手' : 'Default Assistant',
        onSelectConversation: (id) {
          final convo = _chatService.getConversation(id);
          if (convo != null) {
            final msgs = _chatService.getMessages(id);
            setState(() {
              _currentConversation = convo;
              _messages = List.of(msgs);
            });
            _scrollToBottomSoon();
          }
          // Close the drawer when a conversation is picked
          Navigator.of(context).maybePop();
        },
      ),
      body: Stack(
        children: [
          // Main column content
          Column(
            children: [
              // Chat messages list (animate when switching topic)
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  child: KeyedSubtree(
                    key: ValueKey<String>(_currentConversation?.id ?? 'none'),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 16, top: 8),
                      itemCount: _messages.length,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return ChatMessageWidget(
                          message: message,
                          modelIcon: message.role == 'assistant' &&
                                  message.providerId != null &&
                                  message.modelId != null
                              ? _CurrentModelIcon(
                                  providerKey: message.providerId,
                                  modelId: message.modelId,
                                )
                              : null,
                          onRegenerate: message.role == 'assistant' ? () {
                            // TODO: Implement regenerate
                          } : null,
                          onResend: message.role == 'user' ? () {
                            _sendMessage(message.content);
                          } : null,
                        );
                      },
                    ),
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
                  modelIcon: (settings.currentModelProvider != null && settings.currentModelId != null)
                      ? _CurrentModelIcon(
                    providerKey: settings.currentModelProvider,
                    modelId: settings.currentModelId,
                    size: 34,
                  )
                      : null,
                  focusNode: _inputFocus,
                  controller: _inputController,
                  onSend: (text) {
                    _sendMessage(text);
                    _inputController.clear();
                  },
                  loading: _isLoading,
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
                      child: const BottomToolsSheet(),
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
    _inputFocus.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _messageStreamSubscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
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
