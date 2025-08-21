import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import '../icons/lucide_adapter.dart';

/// Markdown renderer that preserves gpt_markdown features
/// but replaces fenced code blocks with syntax highlighted views.
class MarkdownWithCodeHighlight extends StatelessWidget {
  const MarkdownWithCodeHighlight({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final segments = _splitMarkdown(text);
    if (segments.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final seg in segments) ...[
          if (!seg.isCode)
            GptMarkdown(seg.content)
          else
            Container(
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
                        _displayLanguage(context, seg.language),
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
                          await Clipboard.setData(ClipboardData(text: seg.content));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_isZh(context) ? '已复制代码' : 'Code copied')),
                            );
                          }
                        },
                        icon: Icon(Lucide.Copy, size: 16, color: cs.onSurface.withOpacity(0.7)),
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
                      seg.content,
                      language: _normalizeLanguage(seg.language),
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
            ),
        ],
      ],
    );
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

  static List<_MdSegment> _splitMarkdown(String input) {
    if (input.isEmpty) return const [];
    final pattern = RegExp(r"```\s*([^\n`]*)\n([\s\S]*?)\n?```", multiLine: true);
    final segments = <_MdSegment>[];
    int last = 0;
    final matches = pattern.allMatches(input).toList();
    for (final m in matches) {
      if (m.start > last) {
        final before = input.substring(last, m.start);
        if (before.trim().isNotEmpty) {
          segments.add(_MdSegment(isCode: false, content: before));
        }
      }
      final lang = (m.group(1) ?? '').trim();
      final code = (m.group(2) ?? '').replaceAll(RegExp(r"\n\s+$"), '\n');
      segments.add(_MdSegment(isCode: true, content: code, language: lang));
      last = m.end;
    }
    if (last < input.length) {
      final tail = input.substring(last);
      if (tail.trim().isNotEmpty) {
        segments.add(_MdSegment(isCode: false, content: tail));
      }
    }
    // If everything was whitespace, return one empty segment to avoid empty widget
    if (segments.isEmpty) return [const _MdSegment(isCode: false, content: '')];
    return segments;
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
}

class _MdSegment {
  final bool isCode;
  final String content;
  final String? language;
  const _MdSegment({required this.isCode, required this.content, this.language});
}

// Inline code styling is left to gpt_markdown defaults to preserve visual parity.
