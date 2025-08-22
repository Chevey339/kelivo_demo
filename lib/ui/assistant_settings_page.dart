import 'package:flutter/material.dart';
import '../icons/lucide_adapter.dart';
import '../theme/design_tokens.dart';
import 'package:provider/provider.dart';
import '../providers/assistant_provider.dart';
import '../models/assistant.dart';
import 'assistant_settings_edit_page.dart';

class AssistantSettingsPage extends StatelessWidget {
  const AssistantSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    final assistants = context.watch<AssistantProvider>().assistants;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: zh ? '返回' : 'Back',
        ),
        title: Text(zh ? '助手设置' : 'Assistant Settings'),
        actions: [
          IconButton(
            icon: Icon(Lucide.Plus, size: 22, color: cs.onSurface),
            onPressed: () async {
              final id = await context.read<AssistantProvider>().addAssistant();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AssistantSettingsEditPage(assistantId: id)),
              );
            },
            tooltip: zh ? '添加助手' : 'Add Assistant',
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: assistants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = assistants[index];
          return _AssistantCard(item: item);
        },
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.item});
  final Assistant item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AssistantSettingsEditPage(assistantId: item.id)),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
            boxShadow: isDark ? [] : AppShadows.soft,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: cs.primary.withOpacity(isDark ? 0.18 : 0.12),
                      child: Text(
                        _initials(item.name),
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (!item.deletable)
                                _TagPill(text: zh ? '默认' : 'Default', color: cs.primary),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.systemPrompt,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.7), height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Spacer(),
                    TextButton.icon(
                      onPressed: item.deletable
                          ? () => context.read<AssistantProvider>().deleteAssistant(item.id)
                          : null,
                      style: TextButton.styleFrom(foregroundColor: cs.error),
                      icon: Icon(Lucide.Trash2, size: 16),
                      label: Text(zh ? '删除' : 'Delete'),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AssistantSettingsEditPage(assistantId: item.id)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Lucide.Edit, size: 16),
                      label: Text(zh ? '编辑' : 'Edit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final first = String.fromCharCode(trimmed.runes.first);
    return first.toUpperCase();
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
