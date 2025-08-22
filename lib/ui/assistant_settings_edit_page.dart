import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../icons/lucide_adapter.dart';
import '../models/assistant.dart';
import '../providers/assistant_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/mcp_provider.dart';
import '../widgets/avatar_picker_sheet.dart';
import 'model_select_sheet.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../widgets/chat_message_widget.dart';
import '../models/chat_message.dart';
import 'assistant_reasoning_sheet.dart';
import 'reasoning_budget_sheet.dart';
import 'dart:io' show File;

class AssistantSettingsEditPage extends StatefulWidget {
  const AssistantSettingsEditPage({super.key, required this.assistantId});
  final String assistantId;

  @override
  State<AssistantSettingsEditPage> createState() => _AssistantSettingsEditPageState();
}

class _AssistantSettingsEditPageState extends State<AssistantSettingsEditPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final provider = context.watch<AssistantProvider>();
    final assistant = provider.getById(widget.assistantId);

    if (assistant == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: Icon(Lucide.ArrowLeft, size: 22), onPressed: () => Navigator.of(context).maybePop()),
          title: Text(zh ? '助手' : 'Assistant'),
        ),
        body: Center(child: Text(zh ? '助手不存在' : 'Assistant not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Icon(Lucide.ArrowLeft, size: 22), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(assistant.name.isNotEmpty ? assistant.name : (zh ? '助手' : 'Assistant')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: zh ? '基础设定' : 'Basic'),
            Tab(text: zh ? '提示词' : 'Prompts'),
            const Tab(text: 'MCP'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BasicSettingsTab(assistantId: assistant.id),
          _PromptTab(assistantId: assistant.id),
          _McpTab(assistantId: assistant.id),
        ],
      ),
    );
  }
}

class _BasicSettingsTab extends StatefulWidget {
  const _BasicSettingsTab({required this.assistantId});
  final String assistantId;

  @override
  State<_BasicSettingsTab> createState() => _BasicSettingsTabState();
}

class _BasicSettingsTabState extends State<_BasicSettingsTab> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _thinkingCtrl;
  late final TextEditingController _maxTokensCtrl;
  late final TextEditingController _backgroundCtrl;

  @override
  void initState() {
    super.initState();
    final ap = context.read<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;
    _nameCtrl = TextEditingController(text: a.name);
    _thinkingCtrl = TextEditingController(text: a.thinkingBudget?.toString() ?? '');
    _maxTokensCtrl = TextEditingController(text: a.maxTokens?.toString() ?? '');
    _backgroundCtrl = TextEditingController(text: a.background ?? '');
  }

  @override
  void didUpdateWidget(covariant _BasicSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assistantId != widget.assistantId) {
      final ap = context.read<AssistantProvider>();
      final a = ap.getById(widget.assistantId)!;
      _nameCtrl.text = a.name;
      _thinkingCtrl.text = a.thinkingBudget?.toString() ?? '';
      _maxTokensCtrl.text = a.maxTokens?.toString() ?? '';
      _backgroundCtrl.text = a.background ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _thinkingCtrl.dispose();
    _maxTokensCtrl.dispose();
    _backgroundCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
        );

    Widget card({required Widget child}) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
            ),
            child: Padding(padding: const EdgeInsets.all(12), child: child),
          ),
        );

    Widget titleDesc(String title, String? desc) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (desc != null) ...[
              const SizedBox(height: 6),
              Text(desc, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
            ]
          ],
        );

    Widget avatarWidget() {
      final bg = cs.primary.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.12);
      Widget inner;
      final av = a.avatar?.trim();
      if (av != null && av.isNotEmpty) {
        if (av.startsWith('http')) {
          inner = ClipOval(child: Image.network(av, width: 52, height: 52, fit: BoxFit.cover));
        } else if (av.startsWith('/') || av.contains(':')) {
          inner = ClipOval(child: Image.file(File(av), width: 52, height: 52, fit: BoxFit.cover));
        } else {
          inner = Text(av, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700));
        }
      } else {
        inner = Text((a.name.trim().isNotEmpty ? String.fromCharCode(a.name.trim().runes.first).toUpperCase() : 'A'),
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700));
      }
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _showAvatarPicker(context, a),
        child: CircleAvatar(radius: 26, backgroundColor: bg, child: inner),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // Top: avatar + name
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              avatarWidget(),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(name: v)),
                  decoration: InputDecoration(
                    labelText: zh ? '助手名称' : 'Assistant Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Use assistant avatar
        card(
          child: Row(
            children: [
              Expanded(child: titleDesc(zh ? '使用助手头像' : 'Use Assistant Avatar', zh ? '在聊天中使用助手头像和名字而不是模型头像和名字' : 'Use assistant avatar/name instead of model')),
              Switch(
                value: a.useAssistantAvatar,
                onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(useAssistantAvatar: v)),
              ),
            ],
          ),
        ),

        // Chat model
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleDesc(zh ? '聊天模型' : 'Chat Model', zh ? '设置助手的默认聊天模型，如果不设置，则使用全局默认聊天模型' : 'Default chat model for this assistant; fallback to global if unset'),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final sel = await showModelSelector(context);
                      if (sel != null) {
                        await context.read<AssistantProvider>().updateAssistant(a.copyWith(chatModelProvider: sel.providerKey, chatModelId: sel.modelId));
                      }
                    },
                    icon: const Icon(Lucide.Bot, size: 18),
                    label: Text(zh ? '选择模型' : 'Choose Model'),
                  ),
                  const SizedBox(width: 10),
                  if (a.chatModelProvider != null)
                    TextButton.icon(
                      onPressed: () => context.read<AssistantProvider>().updateAssistant(a.copyWith(clearChatModel: true)),
                      icon: Icon(Lucide.X, size: 16, color: cs.primary),
                      label: Text(zh ? '清除' : 'Clear', style: TextStyle(color: cs.primary)),
                    ),
                  const Spacer(),
                  Text(
                    a.chatModelProvider != null && a.chatModelId != null
                        ? '${a.chatModelProvider}::${a.chatModelId}'
                        : (zh ? '使用全局默认' : 'Use global default'),
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Temperature
        card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            titleDesc('Temperature', zh ? '控制输出的随机性，建议保持在 0.6（平衡）' : 'Controls randomness; 0.6 is balanced'),
            _SliderTile(
              value: a.temperature.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: a.temperature.toStringAsFixed(2),
              onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(temperature: v)),
            ),
            Text(zh ? '平衡' : 'Balanced', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
          ]),
        ),

        // Top P
        card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            titleDesc('Top P', zh ? '请不要修改此值，除非你知道自己在做什么' : 'Do not change unless you know what you are doing'),
            _SliderTile(
              value: a.topP.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: a.topP.toStringAsFixed(2),
              onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(topP: v)),
            ),
          ]),
        ),

        // Context messages
        card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            titleDesc(zh ? '上下文消息数量' : 'Context Messages', zh ? '多少历史消息会被当作上下文发送给模型，超过数量会忽略，只保留最近 N 条' : 'How many recent messages to keep in context'),
            _SliderTile(
              value: a.contextMessageSize.toDouble().clamp(0, 256),
              min: 0,
              max: 256,
              divisions: 256,
              label: a.contextMessageSize.toString(),
              onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(contextMessageSize: v.round())),
            ),
          ]),
        ),

        // Stream output
        card(
          child: Row(children: [
            Expanded(child: titleDesc(zh ? '流式输出' : 'Stream Output', zh ? '是否启用消息的流式输出' : 'Enable streaming responses')),
            Switch(value: a.streamOutput, onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(streamOutput: v))),
          ]),
        ),

        // Thinking budget (card with icon and button)
        card(
          child: Row(children: [
            const Icon(Lucide.Brain, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(zh ? '思考预算' : 'Thinking Budget', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            TextButton(
              onPressed: () async {
                // Set the current assistant's thinking budget to global settings before showing dialog
                final currentBudget = a.thinkingBudget;
                if (currentBudget != null) {
                  context.read<SettingsProvider>().setThinkingBudget(currentBudget);
                }
                await showReasoningBudgetSheet(context);
                // Get the updated value from global settings after dialog closes
                final global = context.read<SettingsProvider>().thinkingBudget;
                await context.read<AssistantProvider>().updateAssistant(a.copyWith(thinkingBudget: global));
              },
              child: Text(zh ? '配置' : 'Configure'),
            ),
          ]),
        ),

        // Max tokens
        card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            titleDesc(zh ? '最大 Token 数' : 'Max Tokens', zh ? '留空表示无限制' : 'Leave empty for unlimited'),
            const SizedBox(height: 10),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _maxTokensCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: zh ? '无限制' : 'Unlimited',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) {
                  final val = int.tryParse(v);
                  context.read<AssistantProvider>().updateAssistant(a.copyWith(maxTokens: val, clearMaxTokens: v.trim().isEmpty));
                },
              ),
            ),
          ]),
        ),

        // Chat background
        card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            titleDesc(zh ? '聊天背景' : 'Chat Background', zh ? '设置助手聊天页面的背景图片' : 'Set a background image for this assistant'),
            const SizedBox(height: 10),
            Row(children: [
              ElevatedButton.icon(
                onPressed: () => _pickBackground(context, a),
                icon: const Icon(Lucide.Image, size: 18),
                label: Text(zh ? '选择背景图片' : 'Choose Image'),
              ),
              const SizedBox(width: 10),
              if ((a.background ?? '').isNotEmpty)
                TextButton.icon(
                  onPressed: () => context.read<AssistantProvider>().updateAssistant(a.copyWith(clearBackground: true)),
                  icon: Icon(Lucide.X, size: 16, color: cs.primary),
                  label: Text(zh ? '清除' : 'Clear', style: TextStyle(color: cs.primary)),
                ),
            ]),
          ]),
        ),
      ],
    );
  }

  Future<void> _showAvatarPicker(BuildContext context, Assistant a) async {
    final result = await showAvatarPicker(
      context: context,
      showRemoveOption: (a.avatar ?? '').isNotEmpty,
    );
    
    if (result != null) {
      if (result.value.isEmpty) {
        // Reset avatar
        await context.read<AssistantProvider>().updateAssistant(a.copyWith(clearAvatar: true));
      } else {
        await context.read<AssistantProvider>().updateAssistant(a.copyWith(avatar: result.value));
      }
    }
  }

  Future<void> _pickBackground(BuildContext context, Assistant a) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
      if (file != null) {
        await context.read<AssistantProvider>().updateAssistant(a.copyWith(background: file.path));
      }
    } catch (_) {}
  }

}

class _PromptTab extends StatefulWidget {
  const _PromptTab({required this.assistantId});
  final String assistantId;

  @override
  State<_PromptTab> createState() => _PromptTabState();
}

class _PromptTabState extends State<_PromptTab> {
  late final TextEditingController _sysCtrl;
  late final TextEditingController _tmplCtrl;

  @override
  void initState() {
    super.initState();
    final ap = context.read<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;
    _sysCtrl = TextEditingController(text: a.systemPrompt);
    _tmplCtrl = TextEditingController(text: a.messageTemplate);
  }

  @override
  void didUpdateWidget(covariant _PromptTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assistantId != widget.assistantId) {
      final ap = context.read<AssistantProvider>();
      final a = ap.getById(widget.assistantId)!;
      _sysCtrl.text = a.systemPrompt;
      _tmplCtrl.text = a.messageTemplate;
    }
  }

  @override
  void dispose() {
    _sysCtrl.dispose();
    _tmplCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;

    Widget chips(List<String> items, void Function(String v) onPick) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in items)
              ActionChip(
                label: Text(t, style: const TextStyle(fontSize: 12)),
                onPressed: () => onPick(t),
              ),
          ],
        ),
      );
    }

    final sysVars = const [
      '{cur_date}', '{cur_time}', '{cur_datetime}', '{model_id}', '{model_name}', '{locale}', '{timezone}', '{system_version}', '{device_info}', '{battery_level}', '{nickname}',
    ];
    final tmplVars = const [
      '{{ role }}', '{{ message }}', '{{ time }}', '{{ date }}',
    ];

    // Helper to render link-like variable chips
    Widget linkWrap(List<String> vars, void Function(String v) onPick) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final t in vars)
              InkWell(
                onTap: () => onPick(t),
                child: Text(
                  t,
                  style: TextStyle(color: cs.primary, decoration: TextDecoration.underline, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      );
    }

    // Sample preview for message template
    final now = DateTime.now();
    final ts = zh
        ? DateFormat('yyyy年M月d日 a h:mm:ss', 'zh').format(now)
        : DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final sampleUser = zh ? '用户' : 'User';
    final sampleMsg = zh ? '你好啊' : 'Hello there';
    final sampleReply = zh ? '你好，有什么我可以帮你的吗？' : 'Hello, how can I help you?';

    String processed(String tpl) {
      final t = (tpl.trim().isEmpty ? '{{ message }}' : tpl);
      // Simple replacements consistent with PromptTransformer
      final dateStr = zh ? DateFormat('yyyy年M月d日', 'zh').format(now) : DateFormat('yyyy-MM-dd').format(now);
      final timeStr = zh ? DateFormat('a h:mm:ss', 'zh').format(now) : DateFormat('HH:mm:ss').format(now);
      return t
          .replaceAll('{{ role }}', 'user')
          .replaceAll('{{ message }}', sampleMsg)
          .replaceAll('{{ time }}', timeStr)
          .replaceAll('{{ date }}', dateStr);
    }

    // System Prompt Card
    final sysCard = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(zh ? '系统提示词' : 'System Prompt', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
              controller: _sysCtrl,
              onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(systemPrompt: v)),
              maxLines: 8,
              decoration: InputDecoration(
                hintText: zh ? '输入系统提示词…' : 'Enter system prompt…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.35))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(zh ? '可用变量：' : 'Available variables:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            _VarExplainList(
              items: [
                (zh ? '日期' : 'Date', '{cur_date}'),
                (zh ? '时间' : 'Time', '{cur_time}'),
                (zh ? '日期和时间' : 'Datetime', '{cur_datetime}'),
                (zh ? '模型ID' : 'Model ID', '{model_id}'),
                (zh ? '模型名称' : 'Model Name', '{model_name}'),
                (zh ? '语言环境' : 'Locale', '{locale}'),
                (zh ? '时区' : 'Timezone', '{timezone}'),
                (zh ? '系统版本' : 'System Version', '{system_version}'),
                (zh ? '设备信息' : 'Device Info', '{device_info}'),
                (zh ? '电池电量' : 'Battery Level', '{battery_level}'),
                (zh ? '用户昵称' : 'Nickname', '{nickname}'),
              ],
              onTapVar: (v) {
                final current = _sysCtrl.text;
                final next = (current + (current.isEmpty ? '' : ' ') + v).trim();
                _sysCtrl.text = next;
                _sysCtrl.selection = TextSelection.collapsed(offset: _sysCtrl.text.length);
                context.read<AssistantProvider>().updateAssistant(a.copyWith(systemPrompt: next));
              },
            ),
          ],
        ),
      ),
    );

    // Template Card with preview
    final tmplCard = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(zh ? '聊天内容模板' : 'Message Template', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
              controller: _tmplCtrl,
              maxLines: 4,
              onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(messageTemplate: v)),
              decoration: InputDecoration(
                hintText: '{{ message }}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.35))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
              ),
            ),
            const SizedBox(height: 8),
            Text(zh ? '可用变量：' : 'Available variables:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            _VarExplainList(
              items: [
                (zh ? '角色' : 'Role', '{{ role }}'),
                (zh ? '内容' : 'Message', '{{ message }}'),
                (zh ? '时间' : 'Time', '{{ time }}'),
                (zh ? '日期' : 'Date', '{{ date }}'),
              ],
              onTapVar: (v) {
                final current = _tmplCtrl.text;
                final next = (current + (current.isEmpty ? '' : ' ') + v).trim();
                _tmplCtrl.text = next;
                _tmplCtrl.selection = TextSelection.collapsed(offset: _tmplCtrl.text.length);
                context.read<AssistantProvider>().updateAssistant(a.copyWith(messageTemplate: next));
              },
            ),

            const SizedBox(height: 12),
            Text(zh ? '预览' : 'Preview', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
            const SizedBox(height: 6),
            // Use real chat message widgets for preview (consistent styling)
            const SizedBox(height: 6),
            Builder(builder: (context) {
              final userMsg = ChatMessage(role: 'user', content: processed(_tmplCtrl.text), conversationId: 'preview');
              final botMsg = ChatMessage(role: 'assistant', content: sampleReply, conversationId: 'preview');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChatMessageWidget(
                    message: userMsg,
                    showModelIcon: false,
                    showTokenStats: false,
                  ),
                  ChatMessageWidget(
                    message: botMsg,
                    showModelIcon: false,
                    showTokenStats: false,
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        sysCard,
        const SizedBox(height: 12),
        tmplCard,
      ],
    );
  }
}

class _VarExplainList extends StatelessWidget {
  const _VarExplainList({required this.items, required this.onTapVar});
  final List<(String, String)> items; // (label, var)
  final ValueChanged<String> onTapVar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final it in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${it.$1}: ', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.75))),
              InkWell(
                onTap: () => onTapVar(it.$2),
                child: Text(
                  it.$2,
                  style: TextStyle(color: cs.primary, decoration: TextDecoration.underline, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _McpTab extends StatelessWidget {
  const _McpTab({required this.assistantId});
  final String assistantId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(assistantId)!;
    final mcp = context.watch<McpProvider>();
    final servers = mcp.servers.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 16),
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final s = servers[index];
        final checked = a.mcpServerIds.contains(s.id);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          child: Material(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : cs.surface,
            borderRadius: BorderRadius.circular(12),
            child: CheckboxListTile(
              value: checked,
              onChanged: (v) {
                final set = a.mcpServerIds.toList();
                if (v == true) {
                  if (!set.contains(s.id)) set.add(s.id);
                } else {
                  set.remove(s.id);
                }
                context.read<AssistantProvider>().updateAssistant(a.copyWith(mcpServerIds: set));
              },
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Lucide.Terminal, size: 18, color: cs.primary),
              ),
              title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(s.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
            ),
          ),
        );
      },
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({required this.value, required this.min, required this.max, required this.divisions, required this.label, required this.onChanged});
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: label,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
