import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../icons/lucide_adapter.dart';
import '../providers/settings_provider.dart';

class ProviderDetailPage extends StatefulWidget {
  const ProviderDetailPage({super.key, required this.keyName, required this.displayName});
  final String keyName;
  final String displayName;

  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage> {
  final PageController _pc = PageController();
  int _index = 0;
  late ProviderConfig _cfg;
  late ProviderKind _kind;
  final _nameCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _baseCtrl = TextEditingController();
  final _pathCtrl = TextEditingController();
  bool _enabled = true;
  bool _useResp = false; // openai
  bool _vertexAI = false; // google
  // network proxy (per provider)
  bool _proxyEnabled = false;
  final _proxyHostCtrl = TextEditingController();
  final _proxyPortCtrl = TextEditingController(text: '8080');
  final _proxyUserCtrl = TextEditingController();
  final _proxyPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _cfg = settings.getProviderConfig(widget.keyName, defaultName: widget.displayName);
    _kind = ProviderConfig.classify(widget.keyName);
    _enabled = _cfg.enabled;
    _nameCtrl.text = _cfg.name;
    _keyCtrl.text = _cfg.apiKey;
    _baseCtrl.text = _cfg.baseUrl;
    _pathCtrl.text = _cfg.chatPath ?? '/chat/completions';
    _useResp = _cfg.useResponseApi ?? false;
    _vertexAI = _cfg.vertexAI ?? false;
    // proxy
    _proxyEnabled = _cfg.proxyEnabled ?? false;
    _proxyHostCtrl.text = _cfg.proxyHost ?? '';
    _proxyPortCtrl.text = _cfg.proxyPort ?? '8080';
    _proxyUserCtrl.text = _cfg.proxyUsername ?? '';
    _proxyPassCtrl.text = _cfg.proxyPassword ?? '';
  }

  @override
  void dispose() {
    _pc.dispose();
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _baseCtrl.dispose();
    _pathCtrl.dispose();
    _proxyHostCtrl.dispose();
    _proxyPortCtrl.dispose();
    _proxyUserCtrl.dispose();
    _proxyPassCtrl.dispose();
    super.dispose();
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
        ),
        title: Row(
          children: [
            _BrandAvatar(name: widget.keyName, size: 22),
            const SizedBox(width: 8),
            Text(_nameCtrl.text.isEmpty ? widget.displayName : _nameCtrl.text,
                style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: zh ? '分享' : 'Share',
            icon: Icon(Lucide.Share, color: cs.onSurface),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(zh ? '分享暂未实现' : 'Share not implemented')),
              );
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        children: [
          _buildConfigTab(context, cs, zh),
          _buildModelsTab(context, cs, zh),
          _buildNetworkTab(context, cs, zh),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 64,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          selectedIconTheme: const IconThemeData(size: 20),
          unselectedIconTheme: const IconThemeData(size: 20),
          backgroundColor: cs.surface,
          selectedItemColor: cs.primary,
          unselectedItemColor: cs.onSurface.withOpacity(0.7),
          currentIndex: _index,
          onTap: (i) {
            setState(() => _index = i);
            _pc.animateToPage(i, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
          },
          items: [
            BottomNavigationBarItem(
              icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: Icon(Lucide.Settings2)),
              label: zh ? '配置' : 'Config',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: Icon(Lucide.Boxes)),
              label: zh ? '模型' : 'Models',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: Icon(Lucide.Network)),
              label: zh ? '网络代理' : 'Network',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigTab(BuildContext context, ColorScheme cs, bool zh) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _switchRow(
          icon: Icons.check_circle_outline,
          title: zh ? '是否启用' : 'Enabled',
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        const SizedBox(height: 12),
        _inputRow(context, label: zh ? '名称' : 'Name', controller: _nameCtrl, hint: widget.displayName),
        const SizedBox(height: 12),
        _inputRow(context, label: 'API Key', controller: _keyCtrl, hint: zh ? '留空则使用上层默认' : 'Leave empty to use default', obscure: true),
        const SizedBox(height: 12),
        _inputRow(context, label: 'API Base URL', controller: _baseCtrl, hint: ProviderConfig.defaultsFor(widget.keyName, displayName: widget.displayName).baseUrl),
        if (_kind == ProviderKind.openai) ...[
          const SizedBox(height: 12),
          _inputRow(context, label: zh ? 'API 路径' : 'API Path', controller: _pathCtrl, enabled: false, hint: '/chat/completions'),
          const SizedBox(height: 4),
          _checkboxRow(context, title: zh ? 'Response API (/responses)' : 'Response API (/responses)', value: _useResp, onChanged: (v) => setState(() => _useResp = v)),
        ],
        if (_kind == ProviderKind.google) ...[
          const SizedBox(height: 12),
          _checkboxRow(context, title: zh ? 'Vertex AI' : 'Vertex AI', value: _vertexAI, onChanged: (v) => setState(() => _vertexAI = v)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _testConnection,
              icon: Icon(Lucide.Cable, size: 18, color: cs.primary),
              label: Text(zh ? '测试' : 'Test', style: TextStyle(color: cs.primary)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.primary.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(zh ? '保存' : 'Save'),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildModelsTab(BuildContext context, ColorScheme cs, bool zh) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(zh ? '暂无模型' : 'No Models', style: TextStyle(fontSize: 18, color: cs.onSurface)),
              const SizedBox(height: 6),
              Text(
                zh ? '点击下方按钮添加模型' : 'Tap the buttons below to add models',
                style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12 + MediaQuery.of(context).padding.bottom,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : const Color(0xFFF2F3F5),
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {},
                    child: Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      padding: const EdgeInsets.all(10),
                      child: Icon(Lucide.Boxes, size: 20, color: cs.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {},
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Lucide.Plus, size: 18, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(zh ? '添加新模型' : 'Add Model', style: TextStyle(color: cs.primary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkTab(BuildContext context, ColorScheme cs, bool zh) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _switchRow(
                icon: Icons.lan_outlined,
                title: zh ? '是否启用代理' : 'Enable Proxy',
                value: _proxyEnabled,
                onChanged: (v) => setState(() => _proxyEnabled = v),
              ),
              if (_proxyEnabled) ...[
                const SizedBox(height: 12),
                _inputRow(context, label: zh ? '主机地址' : 'Host', controller: _proxyHostCtrl, hint: '127.0.0.1'),
                const SizedBox(height: 12),
                _inputRow(context, label: zh ? '端口' : 'Port', controller: _proxyPortCtrl, hint: '8080'),
                const SizedBox(height: 12),
                _inputRow(context, label: zh ? '用户名（可选）' : 'Username (optional)', controller: _proxyUserCtrl),
                const SizedBox(height: 12),
                _inputRow(context, label: zh ? '密码（可选）' : 'Password (optional)', controller: _proxyPassCtrl, obscure: true),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _saveNetwork,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(zh ? '保存' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _switchRow({required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: cs.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          margin: const EdgeInsets.only(right: 12),
          child: Icon(icon, size: 20, color: cs.primary),
        ),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15))),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _inputRow(BuildContext context, {required String label, required TextEditingController controller, String? hint, bool obscure = false, bool enabled = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.8))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.transparent)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.transparent)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.4))),
          ),
        ),
      ],
    );
  }

  Widget _checkboxRow(BuildContext context, {required String title, required bool value, required ValueChanged<bool> onChanged}) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
          Text(title, style: TextStyle(fontSize: 14, color: cs.onSurface)),
        ],
      ),
    );
  }

  

  Future<void> _save() async {
    final settings = context.read<SettingsProvider>();
    final cfg = ProviderConfig(
      enabled: _enabled,
      name: _nameCtrl.text.trim().isEmpty ? widget.displayName : _nameCtrl.text.trim(),
      apiKey: _keyCtrl.text.trim(),
      baseUrl: _baseCtrl.text.trim(),
      chatPath: _kind == ProviderKind.openai ? _pathCtrl.text.trim() : null,
      useResponseApi: _kind == ProviderKind.openai ? _useResp : null,
      vertexAI: _kind == ProviderKind.google ? _vertexAI : null,
    );
    await settings.setProviderConfig(widget.keyName, cfg);
    if (!mounted) return;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(zh ? '已保存' : 'Saved')));
    setState(() {});
  }

  Future<void> _testConnection() async {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(zh ? '测试未实现，稍后接入' : 'Test not implemented yet')));
  }

  Future<void> _saveNetwork() async {
    final settings = context.read<SettingsProvider>();
    final old = settings.getProviderConfig(widget.keyName, defaultName: widget.displayName);
    final cfg = old.copyWith(
      proxyEnabled: _proxyEnabled,
      proxyHost: _proxyHostCtrl.text.trim(),
      proxyPort: _proxyPortCtrl.text.trim(),
      proxyUsername: _proxyUserCtrl.text.trim(),
      proxyPassword: _proxyPassCtrl.text.trim(),
    );
    await settings.setProviderConfig(widget.keyName, cfg);
    if (!mounted) return;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(zh ? '已保存' : 'Saved')));
  }
}

// Legacy page-based implementations removed in favor of swipeable PageView tabs.


class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.name, this.size = 20});
  final String name;
  final double size;

  String? _assetForName(String n) {
    final lower = n.toLowerCase();
    final mapping = <RegExp, String>{
      RegExp(r'openai|gpt|o\d'): 'openai.svg',
      RegExp(r'gemini'): 'gemini-color.svg',
      RegExp(r'google'): 'google-color.svg',
      RegExp(r'claude'): 'claude-color.svg',
      RegExp(r'anthropic'): 'anthropic.svg',
      RegExp(r'deepseek'): 'deepseek-color.svg',
      RegExp(r'grok'): 'grok.svg',
      RegExp(r'qwen|qwq|qvq'): 'qwen-color.svg',
      RegExp(r'doubao'): 'doubao-color.svg',
      RegExp(r'openrouter'): 'openrouter.svg',
      RegExp(r'zhipu|智谱|glm'): 'zhipu-color.svg',
      RegExp(r'mistral'): 'mistral-color.svg',
      RegExp(r'(?<!o)llama|meta'): 'meta-color.svg',
      RegExp(r'hunyuan|tencent'): 'hunyuan-color.svg',
      RegExp(r'gemma'): 'gemma-color.svg',
      RegExp(r'perplexity'): 'perplexity-color.svg',
      RegExp(r'aliyun|阿里云|百炼'): 'alibabacloud-color.svg',
      RegExp(r'bytedance|火山'): 'bytedance-color.svg',
      RegExp(r'silicon|硅基'): 'siliconflow.svg',
      RegExp(r'aihubmix'): 'aihubmix-color.svg',
      RegExp(r'ollama'): 'ollama.svg',
      RegExp(r'github'): 'github.svg',
      RegExp(r'cloudflare'): 'cloudflare-color.svg',
      RegExp(r'minimax'): 'minimax-color.svg',
      RegExp(r'xai'): 'xai.svg',
      RegExp(r'juhenext'): 'juhenext.png',
      RegExp(r'kimi'): 'kimi-color.svg',
      RegExp(r'302'): '302ai.svg',
      RegExp(r'step|阶跃'): 'stepfun-color.svg',
      RegExp(r'intern|书生'): 'internlm-color.svg',
      RegExp(r'cohere|command-.+'): 'cohere-color.svg',
    };
    for (final e in mapping.entries) {
      if (e.key.hasMatch(lower)) return 'assets/icons/${e.value}';
    }
    return null;
  }

  bool _preferMonochromeWhite(String n) {
    final k = n.toLowerCase();
    if (RegExp(r'openai|gpt|o\d').hasMatch(k)) return true;
    if (RegExp(r'grok|xai').hasMatch(k)) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = _assetForName(name);
    final lower = name.toLowerCase();
    final bool _mono = isDark && (RegExp(r'openai|gpt|o\\d').hasMatch(lower) || RegExp(r'grok|xai').hasMatch(lower) || RegExp(r'openrouter').hasMatch(lower));
    final bool _purple = RegExp(r'silicon|硅基').hasMatch(lower);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: isDark ? Colors.white10 : cs.primary.withOpacity(0.1),
      child: asset == null
          ? Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
              style: TextStyle(color: cs.primary, fontSize: size * 0.5, fontWeight: FontWeight.w700))
          : (asset.endsWith('.svg')
              ? SvgPicture.asset(
                  asset,
                  width: size * 0.7,
                  height: size * 0.7,
                  colorFilter: _mono
                      ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                      : (_purple ? const ColorFilter.mode(Color(0xFF7C4DFF), BlendMode.srcIn) : null),
                )
              : Image.asset(
                  asset,
                  width: size * 0.7,
                  height: size * 0.7,
                  fit: BoxFit.contain,
                  color: _mono ? Colors.white : (_purple ? const Color(0xFF7C4DFF) : null),
                  colorBlendMode: (_mono || _purple) ? BlendMode.srcIn : null,
                )),
    );
  }
}
