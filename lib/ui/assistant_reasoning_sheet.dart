import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/assistant_provider.dart';
import '../icons/lucide_adapter.dart';

Future<void> showAssistantReasoningSheet(BuildContext context, {required String assistantId}) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _AssistantReasoningSheet(assistantId: assistantId),
  );
}

class _AssistantReasoningSheet extends StatefulWidget {
  const _AssistantReasoningSheet({required this.assistantId});
  final String assistantId;
  @override
  State<_AssistantReasoningSheet> createState() => _AssistantReasoningSheetState();
}

class _AssistantReasoningSheetState extends State<_AssistantReasoningSheet> {
  int? _selected;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final a = context.read<AssistantProvider>().getById(widget.assistantId)!;
    _selected = a.thinkingBudget ?? -1;
    _controller = TextEditingController(text: (_selected ?? -1).toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update(int value) async {
    setState(() => _selected = value);
    final ap = context.read<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;
    await ap.updateAssistant(a.copyWith(thinkingBudget: value));
  }

  int _bucket(int? n) {
    if (n == null) return -1;
    if (n == -1) return -1;
    if (n < 1024) return 0;
    if (n < 16000) return 1024;
    if (n < 32000) return 16000;
    return 32000;
  }

  String _bucketName(int? n) {
    final b = _bucket(n);
    switch (b) {
      case 0:
        return '关闭';
      case -1:
        return '自动';
      case 1024:
        return '轻度推理';
      case 16000:
        return '中度推理';
      default:
        return '重度推理';
    }
  }

  Widget _tile(IconData icon, String title, int value, {String? subtitle}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _bucket(_selected) == value;
    final bg = active ? (isDark ? cs.primary.withOpacity(0.12) : cs.primary.withOpacity(0.08)) : cs.surface;
    final Color iconColor = active ? cs.primary : cs.onSurface.withOpacity(0.7);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _update(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
                      ]
                    ],
                  ),
                ),
                if (active) Icon(Lucide.Check, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.6,
          minChildSize: 0.4,
          builder: (c, controller) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Text('思维链强度', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '当前档位：${_bucketName(_selected)}',
                          style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7), fontWeight: FontWeight.w500),
                        ),
                      ),
                      _tile(Lucide.X, '关闭', 0, subtitle: '关闭推理功能，直接回答'),
                      _tile(Lucide.Settings2, '自动', -1, subtitle: '由模型自动决定推理级别'),
                      _tile(Lucide.Brain, '轻度推理', 1024),
                      _tile(Lucide.Brain, '中度推理', 16000),
                      _tile(Lucide.Brain, '重度推理', 32000),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('自定义推理预算 (tokens)', style: Theme.of(context).textTheme.labelMedium),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _controller,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '例如：2048 (-1 自动，0 关闭)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (v) {
                                final n = int.tryParse(v.trim());
                                if (n != null) {
                                  _update(n);
                                } else {
                                  setState(() {});
                                }
                              },
                              onSubmitted: (v) {
                                final n = int.tryParse(v.trim());
                                if (n != null) _update(n);
                                Navigator.of(context).maybePop();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

