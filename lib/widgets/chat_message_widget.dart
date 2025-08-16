import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/chat_message.dart';
import '../icons/lucide_adapter.dart';
import '../theme/design_tokens.dart';
import '../providers/user_provider.dart';
import 'package:intl/intl.dart';

class ChatMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final Widget? modelIcon;
  final VoidCallback? onRegenerate;
  final VoidCallback? onResend;
  final VoidCallback? onCopy;
  final VoidCallback? onTranslate;
  final VoidCallback? onSpeak;
  final VoidCallback? onMore;
  // Optional reasoning UI props (for reasoning-capable models)
  final String? reasoningText;
  final bool reasoningExpanded;
  final bool reasoningLoading;
  final DateTime? reasoningStartAt;
  final DateTime? reasoningFinishedAt;
  final VoidCallback? onToggleReasoning;

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.modelIcon,
    this.onRegenerate,
    this.onResend,
    this.onCopy,
    this.onTranslate,
    this.onSpeak,
    this.onMore,
    this.reasoningText,
    this.reasoningExpanded = false,
    this.reasoningLoading = false,
    this.reasoningStartAt,
    this.reasoningFinishedAt,
    this.onToggleReasoning,
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final ScrollController _reasoningScroll = ScrollController();
  bool _tickActive = false;
  late final Ticker _ticker = Ticker((_) {
    if (mounted && _tickActive) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ChatMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final loading = widget.reasoningStartAt != null && widget.reasoningFinishedAt == null;
    _tickActive = loading;
    if (loading) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _reasoningScroll.dispose();
    super.dispose();
  }

  Widget _buildUserAvatar(UserProvider userProvider, ColorScheme cs) {
    Widget avatarContent;
    
    if (userProvider.avatarType == 'emoji' && userProvider.avatarValue != null) {
      avatarContent = Center(
        child: Text(
          userProvider.avatarValue!,
          style: const TextStyle(fontSize: 18),
        ),
      );
    } else if (userProvider.avatarType == 'url' && userProvider.avatarValue != null) {
      avatarContent = ClipOval(
        child: Image.network(
          userProvider.avatarValue!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Lucide.User,
            size: 18,
            color: cs.primary,
          ),
        ),
      );
    } else if (userProvider.avatarType == 'file' && userProvider.avatarValue != null) {
      avatarContent = ClipOval(
        child: Image.file(
          File(userProvider.avatarValue!),
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Lucide.User,
            size: 18,
            color: cs.primary,
          ),
        ),
      );
    } else {
      avatarContent = Icon(
        Lucide.User,
        size: 18,
        color: cs.primary,
      );
    }
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: avatarContent,
    );
  }

  Widget _buildUserMessage() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = context.watch<UserProvider>();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Header: User info and avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    userProvider.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateFormat.format(widget.message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // User avatar
              _buildUserAvatar(userProvider, cs),
            ],
          ),
          const SizedBox(height: 8),
          // Message content
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark 
                  ? cs.primary.withOpacity(0.15)
                  : cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.message.content,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface,
              ),
            ),
          ),
          // Action buttons
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Lucide.Copy, size: 16),
                onPressed: widget.onCopy ?? () {
                  Clipboard.setData(ClipboardData(text: widget.message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
                visualDensity: VisualDensity.compact,
                iconSize: 16,
              ),
              IconButton(
                icon: Icon(Lucide.RefreshCw, size: 16),
                onPressed: widget.onResend,
                tooltip: '重新发送',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
              ),
              IconButton(
                icon: Icon(Lucide.Ellipsis, size: 16),
                onPressed: widget.onMore,
                tooltip: '更多',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantMessage() {
    final cs = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Model info and time
          Row(
            children: [
              // Model icon
              widget.modelIcon ?? Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.secondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Lucide.Bot,
                  size: 18,
                  color: cs.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.message.modelId ?? 'AI Assistant',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _dateFormat.format(widget.message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.5),
                        ),
                      ),
                      if (widget.message.totalTokens != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${widget.message.totalTokens} tokens',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reasoning preview (if provided)
          if ((widget.reasoningText != null && widget.reasoningText!.isNotEmpty) || widget.reasoningLoading)
            _ReasoningSection(
              text: widget.reasoningText ?? '',
              expanded: widget.reasoningExpanded,
              loading: widget.reasoningFinishedAt == null,
              startAt: widget.reasoningStartAt,
              finishedAt: widget.reasoningFinishedAt,
              onToggle: widget.onToggleReasoning,
            ),
          const SizedBox(height: 8),
          // Message content with markdown support (fill available width)
          Container(
            width: double.infinity,
            child: widget.message.isStreaming && widget.message.content.isEmpty
                ? Row(
                    children: [
                      _LoadingIndicator(),
                      const SizedBox(width: 8),
                      Text(
                        '正在思考...',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withOpacity(0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GptMarkdown(
                        widget.message.content,
                      ),
                      if (widget.message.isStreaming)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: _LoadingIndicator(),
                        ),
                    ],
                  ),
          ),
          // Action buttons
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: Icon(Lucide.Copy, size: 16),
                onPressed: widget.onCopy ?? () {
                  Clipboard.setData(ClipboardData(text: widget.message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
                visualDensity: VisualDensity.compact,
                iconSize: 16,
              ),
              IconButton(
                icon: Icon(Lucide.RefreshCw, size: 16),
                onPressed: widget.onRegenerate,
                tooltip: '重新生成',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
              ),
              IconButton(
                icon: Icon(Lucide.Volume2, size: 16),
                onPressed: widget.onSpeak,
                tooltip: '朗读',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
              ),
              IconButton(
                icon: Icon(Lucide.Languages, size: 16),
                onPressed: widget.onTranslate,
                tooltip: '翻译',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
              ),
              IconButton(
                icon: Icon(Lucide.Ellipsis, size: 16),
                onPressed: widget.onMore,
                tooltip: '更多',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.message.role == 'user'
        ? _buildUserMessage()
        : _buildAssistantMessage();
  }
}

// Loading indicator similar to OpenAI's breathing circle
class _LoadingIndicator extends StatefulWidget {
  @override
  State<_LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<_LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    // Smoother, symmetric breathing with reverse to avoid jump cuts
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        // Scale and opacity gently breathe in sync
        final scale = 0.9 + 0.2 * _curve.value; // 0.9 -> 1.1
        final opacity = 0.6 + 0.4 * _curve.value; // 0.6 -> 1.0
        final base = cs.primary;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: base.withOpacity(opacity),
              boxShadow: [
                BoxShadow(
                  color: base.withOpacity(0.35 * opacity),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReasoningSection extends StatefulWidget {
  const _ReasoningSection({
    required this.text,
    required this.expanded,
    required this.loading,
    required this.startAt,
    required this.finishedAt,
    this.onToggle,
  });

  final String text;
  final bool expanded;
  final bool loading;
  final DateTime? startAt;
  final DateTime? finishedAt;
  final VoidCallback? onToggle;

  @override
  State<_ReasoningSection> createState() => _ReasoningSectionState();
}

class _ReasoningSectionState extends State<_ReasoningSection> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = Ticker((_) => setState(() {}));
  final ScrollController _scroll = ScrollController();

  String _elapsed() {
    final start = widget.startAt;
    if (start == null) return '';
    final end = widget.finishedAt ?? DateTime.now();
    final ms = end.difference(start).inMilliseconds;
    return '(${(ms / 1000).toStringAsFixed(1)}s)';
  }

  @override
  void initState() {
    super.initState();
    if (widget.loading) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant _ReasoningSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !_ticker.isActive) _ticker.start();
    if (!widget.loading && _ticker.isActive) _ticker.stop();
    if (widget.loading && widget.expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final header = Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/deepthink.svg',
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(cs.secondary, BlendMode.srcIn),
              ),
              const SizedBox(width: 6),
              Text(
                '深度思考',
                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.8), fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              if (widget.startAt != null)
                Text(
                  _elapsed(),
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                ),
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: AnimatedRotation(
            turns: widget.expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: Icon(Lucide.ChevronDown, size: 18, color: cs.onSurface.withOpacity(0.7)),
          ),
          onPressed: widget.onToggle,
        )
      ],
    );

    final content = AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      firstChild: const SizedBox.shrink(),
      secondChild: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: widget.loading
                  ? const BoxConstraints(maxHeight: 126) // about 7 lines
                  : const BoxConstraints(),
              child: SingleChildScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
                child: Text(
                  widget.text.isNotEmpty ? widget.text : '…',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.38,
                    color: cs.onSurface.withOpacity(0.75),
                  ),
                ),
              ),
            ),
            // Gradient fades top/bottom
            if (widget.loading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 16,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (isDark ? Colors.black : Colors.white).withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.loading)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 16,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          (isDark ? Colors.black : Colors.white).withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      crossFadeState: widget.expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        content,
      ],
    );
  }
}
