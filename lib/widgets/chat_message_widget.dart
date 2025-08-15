import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

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
          // Message content with markdown support
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
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
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
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
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
