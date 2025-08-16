import 'package:flutter/material.dart';
import 'dart:ui' as ui;
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
  bool _hasOverflow = false;

  String _sanitize(String s) {
    return s.replaceAll('\r', '').trim();
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _checkOverflow() {
    if (!_scroll.hasClients) return;
    final over = _scroll.position.maxScrollExtent > 0.5;
    if (over != _hasOverflow && mounted) setState(() => _hasOverflow = over);
  }

  String _sanitizedeepthink(String s) {
    // 统一换行
    s = s.replaceAll('\r\n', '\n');

    // 去掉首尾零宽字符（模型有时会插入）
    s = s
        .replaceAll(RegExp(r'^[\u200B\u200C\u200D\uFEFF]+'), '')
        .replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF]+$'), '');

    // 去掉**开头**的纯空白行
    s = s.replaceFirst(RegExp(r'^\s*\n+'), '');

    // 去掉**结尾**的纯空白行
    s = s.replaceFirst(RegExp(r'\n+\s*$'), '');

    return s;
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loading = widget.loading;

    // Android-like surface style
    final bg = cs.primaryContainer.withOpacity(isDark ? 0.25 : 0.30);
    final fg = cs.onPrimaryContainer;

    final curve = const Cubic(0.2, 0.8, 0.2, 1);

    // Build a compact header with optional scrolling preview when loading
    Widget header = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/deepthink.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(cs.secondary, BlendMode.srcIn),
            ),
            const SizedBox(width: 8),
            _Shimmer(
              enabled: loading,
              child: Text('深度思考', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.secondary)),
            ),
            const SizedBox(width: 8),
            if (widget.startAt != null)
              _Shimmer(
                enabled: loading,
                child: Text(_elapsed(), style: TextStyle(fontSize: 13, color: cs.secondary.withOpacity(0.9))),
              ),
            // No header marquee; content area handles scrolling when loading
            const Spacer(),
            Icon(
              widget.expanded
                  ? Lucide.ChevronDown
                  : (loading && !widget.expanded ? Lucide.ChevronRight : Lucide.ChevronRight),
              size: 18,
              color: cs.secondary,
            ),
          ],
        ),
      ),
    );

    final bool isLoading = loading;
    final display = _sanitize(widget.text);
    Widget body = Padding(
      // 这里也收紧一点 padding，避免看起来“垫高”
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),

      child: Text(
        display.isNotEmpty ? display : '…',
        // 不要在 style 里再设 height
        style: TextStyle(fontSize: 12, color: fg),
        // 用 strut 控制行高与 leading（内建行距）
        strutStyle: const StrutStyle(
          forceStrutHeight: true,
          fontSize: 12,
          height: 1.32,   // 更紧凑的行距
          leading: 0,     // 关键：不额外加前后导距
        ),
        // 关键：不把行高施加到首行上升/末行下降
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
          leadingDistribution: TextLeadingDistribution.proportional,
        ),
      ),
    );
    if (isLoading) {
      // Cap max height to 80, grow naturally until overflow, then scroll with smooth fades
      body = Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 80),
          child: _hasOverflow
              ? ShaderMask(
                  shaderCallback: (rect) {
                    final h = rect.height;
                    const double topFade = 12.0;
                    const double bottomFade = 28.0;
                    final double sTop = (topFade / h).clamp(0.0, 1.0);
                    final double sBot = (1.0 - bottomFade / h).clamp(0.0, 1.0);
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Color(0x00FFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: [0.0, sTop, sBot, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: NotificationListener<ScrollUpdateNotification>(
                    onNotification: (_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _scroll,
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        display.isNotEmpty ? display : '…',
                        style: const TextStyle(fontSize: 12),
                        strutStyle: const StrutStyle(forceStrutHeight: true, fontSize: 12, height: 1.32, leading: 0),
                        textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false, leadingDistribution: TextLeadingDistribution.proportional),
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  controller: _scroll,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Text(
                    display.isNotEmpty ? display : '…',
                    style: const TextStyle(fontSize: 12),
                    strutStyle: const StrutStyle(forceStrutHeight: true, fontSize: 12, height: 1.32, leading: 0),
                    textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false, leadingDistribution: TextLeadingDistribution.proportional),
                  ),
                ),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: curve,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              if (widget.expanded || isLoading) body,
            ],
          ),
        ),
      ),
    );
  }
}

// Lightweight shimmer effect without external dependency
class _Shimmer extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const _Shimmer({required this.child, this.enabled = false});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_c.isAnimating) _c.repeat();
    if (!widget.enabled && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value; // 0..1
        return ShaderMask(
          shaderCallback: (rect) {
            final width = rect.width;
            final gradientWidth = width * 0.4;
            final dx = (width + gradientWidth) * t - gradientWidth;
            final shaderRect = Rect.fromLTWH(-dx, 0, width + gradientWidth * 2, rect.height);
            return LinearGradient(
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.35),
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(shaderRect);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// Simple marquee that bounces horizontally if text exceeds maxWidth
class _Marquee extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double maxWidth;
  final Duration duration;
  const _Marquee({
    required this.text,
    required this.style,
    this.maxWidth = 160,
    this.duration = const Duration(milliseconds: 3000),
  });

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _measure(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
      textScaleFactor: MediaQuery.of(context).textScaleFactor,
    )..layout();
    return tp.width;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.maxWidth;
    final textWidth = _measure(widget.text, widget.style);
    final needScroll = textWidth > w;
    final gap = 32.0;
    final loopWidth = textWidth + gap;
    return SizedBox(
      width: w,
      height: (widget.style.fontSize ?? 13) * 1.35,
      child: ClipRect(
        child: needScroll
            ? AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = Curves.linear.transform(_c.value);
                  final dx = -loopWidth * t;
                  return ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0xFFFFFFFF),
                          Color(0xFFFFFFFF),
                          Color(0x00FFFFFF),
                        ],
                        stops: [0.0, 0.07, 0.93, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Transform.translate(
                      offset: Offset(dx, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                          SizedBox(width: gap),
                          Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                        ],
                      ),
                    ),
                  );
                },
              )
            : Align(alignment: Alignment.centerLeft, child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false)),
      ),
    );
  }
}
