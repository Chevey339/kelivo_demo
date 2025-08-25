import 'package:flutter/material.dart';
import '../icons/lucide_adapter.dart';

class TtsServicesPage extends StatelessWidget {
  const TtsServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: zh ? '返回' : 'Back',
        ),
        title: Text(zh ? '语音服务' : 'Text-to-Speech'),
        actions: [
          IconButton(
            tooltip: zh ? '新增' : 'Add',
            icon: Icon(Lucide.Plus, color: cs.onSurface),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(zh ? '新增 TTS 服务暂未实现' : 'Add TTS service not implemented')),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _TtsServiceCard(
            avatarText: '系',
            title: zh ? '系统TTS' : 'System TTS',
            subtitle: zh ? '系统TTS' : 'System TTS',
            selected: true,
            onTest: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(zh ? '测试播放暂未实现' : 'Test playback not implemented')),
              );
            },
            onDelete: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(zh ? '系统 TTS 不可删除' : 'System TTS cannot be deleted')),
              );
            },
            onConfig: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(zh ? '配置暂未实现' : 'Configure not implemented')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TtsServiceCard extends StatelessWidget {
  const _TtsServiceCard({
    required this.avatarText,
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.onConfig,
    this.onTest,
    this.onDelete,
  });

  final String avatarText;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onConfig;
  final VoidCallback? onTest;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected
        ? (isDark ? Colors.white10 : cs.primary.withOpacity(0.08))
        : cs.surface;
    final borderColor = selected
        ? cs.primary.withOpacity(0.35)
        : cs.outlineVariant.withOpacity(0.4);

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + titles + settings on the far right
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CircleAvatar(text: avatarText),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: Localizations.localeOf(context).languageCode == 'zh' ? '配置' : 'Configure',
                  onPressed: onConfig,
                  icon: Icon(Lucide.Settings, size: 20, color: cs.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bottom row: selected tag on the left, actions on the right
            Row(
              children: [
                if (selected) const _SelectedTagFancy() else const SizedBox.shrink(),
                const Spacer(),
                IconButton(
                  tooltip: Localizations.localeOf(context).languageCode == 'zh' ? '测试语音' : 'Test voice',
                  onPressed: onTest,
                  icon: Icon(Lucide.Volume2, size: 20, color: cs.onSurface),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: Localizations.localeOf(context).languageCode == 'zh' ? '删除' : 'Delete',
                  onPressed: onDelete,
                  icon: Icon(Lucide.Trash2, size: 20, color: cs.onSurface.withOpacity(0.9)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAvatar extends StatelessWidget {
  const _CircleAvatar({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : cs.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _SelectedTagFancy extends StatelessWidget {
  const _SelectedTagFancy();

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    const base = Color(0xFF22C55E);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? base.withOpacity(0.22) : base.withOpacity(0.14);
    final border = isDark ? base.withOpacity(0.45) : base.withOpacity(0.28);
    final fg = isDark ? const Color(0xFF34D399) : base;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Lucide.Check, size: 13, color: fg),
          const SizedBox(width: 7),
          Text(
            zh ? '已选择' : 'Selected',
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.1),
          ),
        ],
      ),
    );
  }
}
