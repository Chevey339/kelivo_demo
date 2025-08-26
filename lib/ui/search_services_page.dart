import 'package:flutter/material.dart';
import '../icons/lucide_adapter.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SearchServicesPage extends StatefulWidget {
  const SearchServicesPage({super.key});

  @override
  State<SearchServicesPage> createState() => _SearchServicesPageState();
}

class _SearchServicesPageState extends State<SearchServicesPage> {
  final List<_SearchProviderEntry> _providers = <_SearchProviderEntry>[
    _SearchProviderEntry(provider: 'Bing'),
  ];
  int _resultCount = 10;

  static const List<String> _allProviders = <String>[
    'Bing', '智谱', 'Tavily', 'Exa', 'SearXNG', 'LinkUp', 'Brave',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: zh ? '返回' : 'Back',
        ),
        title: Text(zh ? '搜索服务' : 'Search Services'),
        actions: [
          IconButton(
            tooltip: zh ? '添加提供商' : 'Add Provider',
            icon: Icon(Lucide.Plus, color: cs.onSurface),
            onPressed: () {
              setState(() {
                _providers.add(_SearchProviderEntry(provider: 'Bing'));
              });
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _sectionHeader(zh ? '搜索提供商' : 'Search Providers', cs),
          const SizedBox(height: 8),
          ..._providers.asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildProviderCard(context, cs, isDark, zh, i, entry),
            );
          }),
          const SizedBox(height: 16),
          _sectionHeader(zh ? '通用选项' : 'General Options', cs),
          const SizedBox(height: 8),
          _buildGeneralOptionsCard(context, cs, isDark, zh),
        ],
      ),
    );
  }

  Widget _buildProviderCard(BuildContext context, ColorScheme cs, bool isDark, bool zh, int index, _SearchProviderEntry entry) {
    final bg = isDark ? Colors.white10 : cs.primary.withOpacity(0.06);
    final borderColor = cs.primary.withOpacity(0.35);
    final allowDelete = _providers.length > 1;
    final requiresKey = _requiresApiKey(entry.provider);
    final desc = _providerTip(entry.provider, zh);

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Provider picker
            InkWell(
              onTap: () => _pickProvider(index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    _BrandBadge(name: entry.provider, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.provider,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Lucide.ChevronDown, size: 18, color: cs.onSurface.withOpacity(0.8)),
                  ],
                ),
              ),
            ),
            if (desc != null) ...[
              const SizedBox(height: 8),
              Text(
                desc,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.65)),
              ),
            ],
            if (requiresKey) ...[
              const SizedBox(height: 10),
              Text(zh ? 'API Key' : 'API Key', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
              const SizedBox(height: 6),
              TextField(
                onChanged: (v) {
                  setState(() {
                    _providers[index] = entry.copyWith(apiKey: v);
                  });
                },
                decoration: InputDecoration(
                  hintText: zh ? '请输入 API Key' : 'Enter API Key',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.35))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(zh ? '打开获取 API Key 的链接（未实现）' : 'Open API Key link (not implemented)')),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    zh ? '点击获取 API Key' : 'Get API Key',
                    style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
            if (allowDelete) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    tooltip: zh ? '删除' : 'Delete',
                    icon: Icon(Lucide.Trash2, size: 18, color: cs.onSurface.withOpacity(0.8)),
                    onPressed: () {
                      setState(() { _providers.removeAt(index); });
                    },
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralOptionsCard(BuildContext context, ColorScheme cs, bool isDark, bool zh) {
    final bg = isDark ? Colors.white10 : cs.primary.withOpacity(0.06);
    final borderColor = cs.primary.withOpacity(0.35);
    final controller = TextEditingController(text: _resultCount.toString());
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(zh ? '结果数量' : 'Result Count', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final n = int.tryParse(v.trim());
                if (n != null) _resultCount = n;
              },
              decoration: InputDecoration(
                hintText: '10',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.35))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, ColorScheme cs) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary),
        ),
      );

  Future<void> _pickProvider(int index) async {
    final cs = Theme.of(context).colorScheme;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: _allProviders.map((p) {
              return ListTile(
                leading: _BrandBadge(name: p, size: 20),
                title: Text(p),
                onTap: () => Navigator.of(ctx).pop(p),
              );
            }).toList(),
          ),
        );
      },
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() {
        _providers[index] = _providers[index].copyWith(provider: picked);
      });
    }
  }

  static bool _requiresApiKey(String provider) {
    // Only Tavily explicitly required in spec; others may be added later
    return provider == 'Tavily';
  }

  static String? _providerTip(String provider, bool zh) {
    if (provider == 'Bing') {
      return zh
          ? 'Bing 搜索基于爬虫，容易被风控拦截，不推荐使用'
          : 'Bing relies on scraping and is often blocked by anti-bot measures; not recommended.';
    }
    return null;
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.name, this.size = 20});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lower = name.toLowerCase();
    String? asset;
    // Map known search brands to assets/icons
    final mapping = <RegExp, String>{
      RegExp(r'bing'): 'bing.png',
      RegExp(r'zhipu|glm|智谱'): 'zhipu-color.svg',
      RegExp(r'tavily'): 'tavily.png',
      RegExp(r'exa'): 'exa.png',
      RegExp(r'linkup'): 'linkup.png',
      RegExp(r'brave'): 'brave-color.svg',
      // SearXNG has no dedicated asset; will fall back to letter
    };
    for (final e in mapping.entries) {
      if (e.key.hasMatch(lower)) { asset = 'assets/icons/${e.value}'; break; }
    }
    if (asset != null) {
      final bg = isDark ? Colors.white10 : cs.primary.withOpacity(0.1);
      if (asset!.endsWith('.svg')) {
        final isColorful = asset!.contains('color');
        final ColorFilter? tint = (isDark && !isColorful) ? const ColorFilter.mode(Colors.white, BlendMode.srcIn) : null;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: SvgPicture.asset(asset!, width: size * 0.62, height: size * 0.62, colorFilter: tint),
        );
      } else {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: isDark ? Colors.white10 : cs.primary.withOpacity(0.1), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Image.asset(asset!, width: size * 0.62, height: size * 0.62, fit: BoxFit.contain),
        );
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: isDark ? Colors.white10 : cs.primary.withOpacity(0.1), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: size * 0.42)),
    );
  }
}

class _SearchProviderEntry {
  final String provider;
  final String? apiKey;
  _SearchProviderEntry({required this.provider, this.apiKey});
  _SearchProviderEntry copyWith({String? provider, String? apiKey}) => _SearchProviderEntry(
        provider: provider ?? this.provider,
        apiKey: apiKey ?? this.apiKey,
      );
}
