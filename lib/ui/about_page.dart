import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../icons/lucide_adapter.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  String _buildNumber = '';
  String _systemInfo = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final pkg = await PackageInfo.fromPlatform();
    String sys;
    if (Platform.isAndroid) {
      sys = 'Android';
    } else if (Platform.isIOS) {
      sys = 'iOS';
    } else if (Platform.isMacOS) {
      sys = 'macOS';
    } else if (Platform.isWindows) {
      sys = 'Windows';
    } else if (Platform.isLinux) {
      sys = 'Linux';
    } else {
      sys = Platform.operatingSystem;
    }
    setState(() {
      _version = pkg.version;
      _buildNumber = pkg.buildNumber;
      _systemInfo = sys;
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Fallback: try in-app web view
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: zh ? '返回' : 'Back',
        ),
        title: Text(zh ? '关于' : 'About'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white12
                          : const Color(0xFFF2F3F5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Lucide.Bot, size: 64, color: cs.primary),
                  ),
                  const SizedBox(height: 12),
                  Text('Kelivo', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    zh ? '开源移动端 AI 助手' : 'Open-source Mobile AI Assistant',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _ChipButton(
                        icon: Lucide.Earth,
                        label: zh ? '官网' : 'Website',
                        onTap: () => _openUrl('https://psycheas.top/'),
                      ),
                      _ChipButton(
                        icon: Lucide.GitFork,
                        label: 'GitHub',
                        onTap: () => _openUrl('https://github.com/Chevey339/kelivo_demo'),
                      ),
                      _ChipButton(
                        icon: Lucide.FileText,
                        label: zh ? '许可证' : 'License',
                        onTap: () => _openUrl('https://github.com/Chevey339/kelivo_demo/blob/main/LICENSE'),
                      ),
                      _ChipButton(
                        icon: Lucide.Share2,
                        label: zh ? '分享' : 'Share',
                        onTap: () => Share.share('Kelivo - 开源移动端AI助手'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SliverList.list(
            children: [
              const SizedBox(height: 8),
              _AboutItem(
                icon: Lucide.BadgeInfo,
                title: zh ? '版本' : 'Version',
                subtitle: _version.isEmpty ? '...' : '$_version / $_buildNumber',
              ),
              _AboutItem(
                icon: Lucide.Phone,
                title: zh ? '系统' : 'System',
                subtitle: _systemInfo.isEmpty ? '...' : _systemInfo,
              ),
              _AboutItem(
                icon: Lucide.Earth,
                title: zh ? '官网' : 'Website',
                subtitle: 'https://psycheas.top/',
                onTap: () => _openUrl('https://psycheas.top/'),
              ),
              _AboutItem(
                icon: Lucide.GitFork,
                title: 'GitHub',
                subtitle: 'https://github.com/Chevey339/kelivo_demo',
                onTap: () => _openUrl('https://github.com/Chevey339/kelivo_demo'),
              ),
              _AboutItem(
                icon: Lucide.FileText,
                title: zh ? '许可证' : 'License',
                subtitle: 'https://github.com/Chevey339/kelivo_demo/blob/main/LICENSE',
                onTap: () => _openUrl('https://github.com/Chevey339/kelivo_demo/blob/main/LICENSE'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutItem extends StatelessWidget {
  const _AboutItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Material(
        color: cs.surfaceVariant.withOpacity(isDark ? 0.18 : 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 12),
                  child: Icon(icon, size: 20, color: cs.primary),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null) Icon(Lucide.ChevronRight, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: cs.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
