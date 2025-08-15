import 'package:flutter/material.dart';

import '../widgets/chat_input_bar.dart';
import '../widgets/bottom_tools_sheet.dart';
import '../widgets/side_drawer.dart';
import '../theme/design_tokens.dart';
import '../icons/lucide_adapter.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _inputFocus = FocusNode();

  String _titleForLocale(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'zh' ? '新聊天' : 'New Chat';
  }

  void _toggleTools() {
    setState(() => _toolsOpen = !_toolsOpen);
  }

  void _dismissKeyboard() {
    _inputFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final title = _titleForLocale(context);
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
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
            if (providerName != null && modelDisplay != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$modelDisplay ($providerName)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w500),
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
            onPressed: () {},
            icon: const Icon(Lucide.MessageCirclePlus, size: 22),
          ),
        ],
      ),
      drawer: SideDrawer(
        userName: context.watch<UserProvider>().name,
        assistantName: Localizations.localeOf(context).languageCode == 'zh' ? '默认助手' : 'Default Assistant',
      ),
      body: Stack(
        children: [
          const Center(
            child: Text(
              '内容区域 / Content Area',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          // Backdrop to close sheet on tap
          if (_toolsOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleTools,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
          // Tools sheet
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: 0,
            height: _toolsOpen ? _sheetHeight : 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: OverflowBox(
                maxHeight: _sheetHeight,
                alignment: Alignment.bottomCenter,
                child: const BottomToolsSheet(),
              ),
            ),
          ),
          // Input bar animates up when sheet is open
          AnimatedPadding(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: _toolsOpen ? _sheetHeight : 0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ChatInputBar(
                onMore: _toggleTools,
                moreOpen: _toolsOpen,
                onSelectModel: () => showModelSelectSheet(context),
                modelIcon: (settings.currentModelProvider != null && settings.currentModelId != null)
                    ? _CurrentModelIcon(providerKey: settings.currentModelProvider, modelId: settings.currentModelId)
                    : null,
                focusNode: _inputFocus,
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
  const _CurrentModelIcon({required this.providerKey, required this.modelId});
  final String? providerKey;
  final String? modelId;

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
      RegExp(r'silicon|硅基'): 'siliconflow.svg',
      RegExp(r'aihubmix'): 'aihubmix-color.svg',
      RegExp(r'ollama'): 'ollama.svg',
      RegExp(r'github'): 'github.svg',
      RegExp(r'cloudflare'): 'cloudflare-color.svg',
      RegExp(r'minimax'): 'minimax-color.svg',
      RegExp(r'xai|grok'): 'xai.svg',
      RegExp(r'juhenext'): 'juhenext.png',
      RegExp(r'kimi'): 'kimi-color.svg',
      RegExp(r'302'): '302ai.svg',
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
        inner = SvgPicture.asset(asset, width: 14, height: 14);
      } else {
        inner = Image.asset(asset, width: 14, height: 14, fit: BoxFit.contain);
      }
    } else {
      inner = Text(modelId!.isNotEmpty ? modelId!.characters.first.toUpperCase() : '?', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 12));
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: isDark ? Colors.white10 : cs.primary.withOpacity(0.1), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: SizedBox(width: 18, height: 18, child: Center(child: inner is SvgPicture || inner is Image ? inner : FittedBox(child: inner))),
    );
  }
}
