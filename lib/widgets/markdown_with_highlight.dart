import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import '../icons/lucide_adapter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import '../utils/sandbox_path_resolver.dart';
import '../ui/image_viewer_page.dart';

/// gpt_markdown with custom code block highlight and inline code styling.
class MarkdownWithCodeHighlight extends StatelessWidget {
  const MarkdownWithCodeHighlight({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final imageUrls = _extractImageUrls(text);

    final normalized = _preprocessFences(text);
    return GptMarkdown(
      normalized,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface,
          ),
      followLinkColor: true,
      onLinkTap: (url, title) => _handleLinkTap(context, url),
      imageBuilder: (ctx, url) {
        final imgs = imageUrls.isNotEmpty ? imageUrls : [url];
        final idx = imgs.indexOf(url);
        final initial = idx >= 0 ? idx : 0;
        final provider = _imageProviderFor(url);
        return GestureDetector(
          onTap: () {
            Navigator.of(ctx).push(PageRouteBuilder(
              pageBuilder: (_, __, ___) => ImageViewerPage(images: imgs, initialIndex: initial),
              transitionDuration: const Duration(milliseconds: 360),
              reverseTransitionDuration: const Duration(milliseconds: 280),
              transitionsBuilder: (context, anim, sec, child) {
                final curved = CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
            ));
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: provider,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => const Icon(Icons.broken_image),
            ),
          ),
        );
      },
      linkBuilder: (ctx, span, url, style) {
        final text = span.toPlainText();
        final cs = Theme.of(ctx).colorScheme;
        return Text(
          text,
          style: style.copyWith(
            color: cs.primary,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.start,
          textScaler: MediaQuery.of(ctx).textScaler,
        );
      },
      orderedListBuilder: (ctx, no, child, cfg) {
        final style = (cfg.style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w400, // normal weight
        );
        return Directionality(
          textDirection: cfg.textDirection,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6, end: 6),
                child: Text("$no.", style: style),
              ),
              Flexible(child: child),
            ],
          ),
        );
      },
      // Inline `code` styling via highlightBuilder in gpt_markdown
      highlightBuilder: (ctx, inline, style) {
        final bg = isDark ? Colors.white12 : const Color(0xFFF1F3F5);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.22)),
          ),
          child: Text(
            inline,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.3,
            ).copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        );
      },
      // Fenced code block styling via codeBuilder
      codeBuilder: (ctx, name, code, closed) {
        final lang = name.trim();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(10, 0, 6, 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _displayLanguage(context, lang),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.secondary,
                      height: 1.0,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isZh(context) ? '已复制代码' : 'Code copied'),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      Lucide.Copy,
                      size: 16,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                    tooltip: _isZh(context) ? '复制' : 'Copy',
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: HighlightView(
                  code,
                  language: _normalizeLanguage(lang) ?? 'plaintext',
                  theme: _transparentBgTheme(
                    isDark ? atomOneDarkReasonableTheme : githubTheme,
                  ),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _displayLanguage(BuildContext context, String? raw) {
    final zh = _isZh(context);
    final t = raw?.trim();
    if (t != null && t.isNotEmpty) return t;
    return zh ? '代码' : 'Code';
  }

  static bool _isZh(BuildContext context) => Localizations.localeOf(context).languageCode == 'zh';

  static Map<String, TextStyle> _transparentBgTheme(Map<String, TextStyle> base) {
    final m = Map<String, TextStyle>.from(base);
    final root = base['root'];
    if (root != null) {
      m['root'] = root.copyWith(backgroundColor: Colors.transparent);
    } else {
      m['root'] = const TextStyle(backgroundColor: Colors.transparent);
    }
    return m;
  }

  static String? _normalizeLanguage(String? lang) {
    if (lang == null || lang.trim().isEmpty) return null;
    final l = lang.trim().toLowerCase();
    switch (l) {
      case 'js':
      case 'javascript':
        return 'javascript';
      case 'ts':
      case 'typescript':
        return 'typescript';
      case 'sh':
      case 'zsh':
      case 'bash':
      case 'shell':
        return 'bash';
      case 'yml':
        return 'yaml';
      case 'py':
      case 'python':
        return 'python';
      case 'rb':
      case 'ruby':
        return 'ruby';
      case 'kt':
      case 'kotlin':
        return 'kotlin';
      case 'java':
        return 'java';
      case 'c#':
      case 'cs':
      case 'csharp':
        return 'csharp';
      case 'objc':
      case 'objectivec':
        return 'objectivec';
      case 'swift':
        return 'swift';
      case 'go':
      case 'golang':
        return 'go';
      case 'php':
        return 'php';
      case 'dart':
        return 'dart';
      case 'json':
        return 'json';
      case 'html':
        return 'xml';
      case 'md':
      case 'markdown':
        return 'markdown';
      case 'sql':
        return 'sql';
      default:
        return l; // try as-is
    }
  }

  static String _preprocessFences(String input) {
    // 1) Move fenced code from list lines to the next line: "* ```lang" -> "*\n```lang"
    final bulletFence = RegExp(r"^(\s*(?:[*+-]|\d+\.)\s+)```([^\s`]*)\s*$", multiLine: true);
    var out = input.replaceAllMapped(bulletFence, (m) => "${m[1]}\n```${m[2]}" );

    // 2) Dedent opening fences: leading spaces before ```lang
    final dedentOpen = RegExp(r"^[ \t]+```([^\n`]*)\s*$", multiLine: true);
    out = out.replaceAllMapped(dedentOpen, (m) => "```${m[1]}" );

    // 3) Dedent closing fences: leading spaces before ```
    final dedentClose = RegExp(r"^[ \t]+```\s*$", multiLine: true);
    out = out.replaceAllMapped(dedentClose, (m) => "```" );

    // 4) Ensure closing fences are on their own line: transform "} ```" or "}```" into "}\n```"
    final inlineClosing = RegExp(r"([^\r\n`])```(?=\s*(?:\r?\n|$))");
    out = out.replaceAllMapped(inlineClosing, (m) => "${m[1]}\n```");

    return out;
  }

  Future<void> _handleLinkTap(BuildContext context, String url) async {
    Uri uri;
    try {
      uri = _normalizeUrl(url);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isZh(context) ? '无效链接' : 'Invalid link')),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isZh(context) ? '无法打开链接' : 'Cannot open link')),
      );
    }
  }

  Uri _normalizeUrl(String url) {
    var u = url.trim();
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(u)) {
      u = 'https://'+u;
    }
    return Uri.parse(u);
  }

  static List<String> _extractImageUrls(String md) {
    final re = RegExp(r"!\[[^\]]*\]\(([^)\s]+)\)");
    return re
        .allMatches(md)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static ImageProvider _imageProviderFor(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return NetworkImage(src);
    }
    if (src.startsWith('data:')) {
      try {
        final base64Marker = 'base64,';
        final idx = src.indexOf(base64Marker);
        if (idx != -1) {
          final b64 = src.substring(idx + base64Marker.length);
          return MemoryImage(base64Decode(b64));
        }
      } catch (_) {}
    }
    final fixed = SandboxPathResolver.fix(src);
    return FileImage(File(fixed));
  }
}
