import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../icons/lucide_adapter.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    this.onSend,
    this.onStop,
    this.onSelectModel,
    this.onToggleSearch,
    this.onMore,
    this.onConfigureReasoning,
    this.moreOpen = false,
    this.focusNode,
    this.modelIcon,
    this.controller,
    this.loading = false,
    this.reasoningActive = false,
  });

  final ValueChanged<String>? onSend;
  final VoidCallback? onStop;
  final VoidCallback? onSelectModel;
  final ValueChanged<bool>? onToggleSearch;
  final VoidCallback? onMore;
  final VoidCallback? onConfigureReasoning;
  final bool moreOpen;
  final FocusNode? focusNode;
  final Widget? modelIcon;
  final TextEditingController? controller;
  final bool loading;
  final bool reasoningActive;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late TextEditingController _controller;
  bool _searchEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  String _hint(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'zh' ? '输入消息与AI聊天' : 'Type a message for AI';
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasText = _controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top: large rounded input capsule
            DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.capsule),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : AppShadows.soft,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: TextField(
                  controller: _controller,
                  focusNode: widget.focusNode,
                  onChanged: (_) => setState(() {}),
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: _hint(context),
                    hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.55)),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  cursorColor: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Bottom: circular buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _CircleIconButton(
                      tooltip: Localizations.localeOf(context).languageCode == 'zh'
                          ? '选择模型'
                          : 'Select Model',
                      icon: Lucide.Boxes,
                      child: widget.modelIcon,
                      onTap: widget.onSelectModel,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _CircleIconButton(
                      tooltip: Localizations.localeOf(context).languageCode == 'zh'
                          ? '联网搜索'
                          : 'Online Search',
                      icon: Lucide.Globe,
                      active: _searchEnabled,
                      onTap: () {
                        setState(() => _searchEnabled = !_searchEnabled);
                        widget.onToggleSearch?.call(_searchEnabled);
                      },
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _CircleIconButton(
                      tooltip: Localizations.localeOf(context).languageCode == 'zh'
                          ? '思维链强度'
                          : 'Reasoning Strength',
                      icon: Lucide.Brain,
                      active: widget.reasoningActive,
                      onTap: widget.onConfigureReasoning,
                      child: SvgPicture.asset(
                        'assets/icons/deepthink.svg',
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(
                          widget.reasoningActive
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.white : Colors.black87),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _CircleIconButton(
                      tooltip: Localizations.localeOf(context).languageCode == 'zh'
                          ? '更多'
                          : 'Add',
                      icon: Lucide.Plus,
                      active: widget.moreOpen,
                      onTap: widget.onMore,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => RotationTransition(
                          turns: Tween<double>(begin: 0.85, end: 1).animate(anim),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Icon(
                          widget.moreOpen ? Lucide.X : Lucide.Plus,
                          key: ValueKey(widget.moreOpen ? 'close' : 'add'),
                          size: 22,
                          color: widget.moreOpen
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _SendButton(
                      enabled: hasText && !widget.loading,
                      loading: widget.loading,
                      onSend: _handleSend,
                      onStop: widget.loading ? widget.onStop : null,
                      color: theme.colorScheme.primary,
                      icon: widget.loading ? Lucide.X : Lucide.ArrowUp,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.active = false,
    this.child,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = active ? theme.colorScheme.primary.withOpacity(0.12) : Colors.transparent;
    final fgColor = active ? theme.colorScheme.primary : (isDark ? Colors.white : Colors.black87);

    final button = Material(
      color: bgColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: child ?? Icon(icon, size: 22, color: fgColor),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.onSend,
    required this.color,
    required this.icon,
    this.loading = false,
    this.onStop,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (enabled || loading) ? color : (isDark ? Colors.white12 : Colors.grey.shade300);
    final fg = (enabled || loading) ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.grey.shade600);

    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? onStop : (enabled ? onSend : null),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}
