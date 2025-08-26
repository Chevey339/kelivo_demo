import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/search/search_service.dart';
import '../icons/lucide_adapter.dart';
import 'search_services_page.dart';

Future<void> showSearchSettingsSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _SearchSettingsSheet(),
  );
}

class _SearchSettingsSheet extends StatelessWidget {
  const _SearchSettingsSheet();

  IconData _iconFor(SearchServiceOptions s) {
    if (s is BingLocalOptions) return Lucide.Search;
    if (s is TavilyOptions) return Lucide.Sparkles;
    if (s is ExaOptions) return Lucide.Brain;
    if (s is ZhipuOptions) return Lucide.Languages;
    if (s is SearXNGOptions) return Lucide.Shield;
    if (s is LinkUpOptions) return Lucide.Link2;
    if (s is BraveOptions) return Lucide.Shield;
    if (s is MetasoOptions) return Lucide.Compass;
    return Lucide.Search;
  }

  String _nameOf(BuildContext context, SearchServiceOptions s) {
    final svc = SearchService.getService(s);
    return svc.name;
  }

  String? _statusOf(BuildContext context, SearchServiceOptions s) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    if (s is BingLocalOptions) return null;
    if (s is TavilyOptions) return s.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    if (s is ExaOptions) return s.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    if (s is ZhipuOptions) return s.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    if (s is SearXNGOptions) return s.url.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 URL' : 'URL Required');
    if (s is LinkUpOptions) return s.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    if (s is BraveOptions) return s.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    if (s is MetasoOptions) return s.apiKey.isNotEmpty ? (zh ? '已配置' : 'Configured') : (zh ? '需要 API Key' : 'API Key Required');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final settings = context.watch<SettingsProvider>();
    final services = settings.searchServices;
    final selected = settings.searchServiceSelected.clamp(0, services.isNotEmpty ? services.length - 1 : 0);
    final enabled = settings.searchEnabled;

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (ctx, controller) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ListView(
              controller: controller,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Lucide.Earth, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      zh ? '搜索设置' : 'Search Settings',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Toggle card
                Material(
                  color: enabled ? cs.primary.withOpacity(0.08) : theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Lucide.Globe, color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(zh ? '网络搜索' : 'Web Search', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                zh ? '是否启用网页搜索' : 'Enable web search in chat',
                                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ),
                        // Settings button -> full search services page
                        IconButton(
                          tooltip: zh ? '打开搜索服务设置' : 'Open search services',
                          icon: Icon(Lucide.Settings, size: 20),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SearchServicesPage()),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        Switch(
                          value: enabled,
                          onChanged: (v) => context.read<SettingsProvider>().setSearchEnabled(v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Services grid (2 per row, larger tiles)
                if (services.isNotEmpty) ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.8,
                    ),
                    itemCount: services.length,
                    itemBuilder: (ctx, i) {
                      final s = services[i];
                      final status = _statusOf(ctx, s);
                      return _ServiceTileLarge(
                        icon: _iconFor(s),
                        label: _nameOf(context, s),
                        status: status,
                        selected: i == selected,
                        onTap: () => context.read<SettingsProvider>().setSearchServiceSelected(i),
                      );
                    },
                  ),
                ] else ...[
                  Text(
                    zh ? '暂无可用服务，请先在“搜索服务”中添加' : 'No services. Add from Search Services.',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ServiceTileLarge extends StatelessWidget {
  const _ServiceTileLarge({
    required this.icon,
    required this.label,
    required this.selected,
    this.status,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final String? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected ? cs.primary.withOpacity(isDark ? 0.18 : 0.12) : (isDark ? Colors.white12 : const Color(0xFFF7F7F9));
    final fg = selected ? cs.primary : cs.onSurface.withOpacity(0.85);
    final border = selected ? Border.all(color: cs.primary, width: 1.2) : null;
    final configured = (status != null) && (status!.contains('已配置') || status!.toLowerCase().contains('configured'));
    final statusBg = configured ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12);
    final statusFg = configured ? Colors.green : Colors.orange;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: border),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: fg.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
                    if (status != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                        child: Text(status!, style: TextStyle(fontSize: 11, color: statusFg)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
