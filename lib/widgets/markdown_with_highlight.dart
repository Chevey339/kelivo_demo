import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import '../icons/lucide_adapter.dart';

/// gpt_markdown with custom code block highlight and inline code styling.
class MarkdownWithCodeHighlight extends StatelessWidget {
  const MarkdownWithCodeHighlight({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final normalized = _preprocessFences(text);
    return GptMarkdown(
      normalized,
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
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
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
                      fontSize: 14,
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

    return out;
  }
}
