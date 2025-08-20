import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../icons/lucide_adapter.dart';
import '../providers/mcp_provider.dart';
import 'mcp_server_edit_sheet.dart';

class McpPage extends StatelessWidget {
  const McpPage({super.key});

  Color _statusColor(BuildContext context, McpStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case McpStatus.connected:
        return Colors.green;
      case McpStatus.connecting:
        return cs.primary;
      case McpStatus.error:
      case McpStatus.idle:
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final mcp = context.watch<McpProvider>();
    final servers = mcp.servers.toList();

    Widget tag(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.green.withOpacity(0.4)),
          ),
          child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
        );

    Future<void> _showErrorDetails(String serverId, String? message, String name) async {
      final cs = Theme.of(context).colorScheme;
      final zh = Localizations.localeOf(context).languageCode == 'zh';
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(zh ? '连接错误' : 'Connection Error', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(name, style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                    ),
                    child: Text(message?.isNotEmpty == true ? message! : (zh ? '未提供错误详情' : 'No details')),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(ctx).maybePop(),
                          icon: Icon(Lucide.X, size: 16, color: cs.primary),
                          label: Text(zh ? '关闭' : 'Close', style: TextStyle(color: cs.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Start reconnect
                            // ignore: use_build_context_synchronously
                            await ctx.read<McpProvider>().reconnect(serverId);
                            // ignore: use_build_context_synchronously
                            Navigator.of(ctx).pop();
                            // ScaffoldMessenger.of(context).showSnackBar(
                            //   SnackBar(content: Text(zh ? '开始连接…' : 'Reconnecting…')),
                            // );
                          },
                          icon: const Icon(Lucide.RefreshCw, size: 18),
                          label: Text(zh ? '重新连接' : 'Reconnect'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: zh ? '返回' : 'Back',
        ),
        title: const Text('MCP'),
        actions: [
          IconButton(
            icon: Icon(Lucide.Plus, color: cs.primary),
            tooltip: zh ? '添加 MCP' : 'Add MCP',
            onPressed: () async {
              await showMcpServerEditSheet(context);
            },
          ),
        ],
      ),
      body: servers.isEmpty
          ? Center(
              child: Text(
                zh ? '暂无启用的 MCP 服务' : 'No enabled MCP servers',
                style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final s = servers[index];
                final st = mcp.statusFor(s.id);
                final err = mcp.errorFor(s.id);
                return ListTile(
                  leading: Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white10
                              : const Color(0xFFF2F3F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Lucide.Terminal, size: 20, color: cs.primary),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: st == McpStatus.connecting
                            ? SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                                ),
                              )
                            : Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: s.enabled ? _statusColor(context, st) : cs.outline,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cs.surface, width: 1.5),
                                ),
                              ),
                      ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          tag(s.transport == McpTransportType.sse ? 'SSE' : 'Streamable HTTP'),
                          if (!s.enabled) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.onSurface.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: cs.onSurface.withOpacity(0.15)),
                              ),
                              child: Text(
                                zh ? '已禁用' : 'Disabled',
                                style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]
                        ]),
                        if (st == McpStatus.error && (err?.isNotEmpty ?? false)) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Lucide.MessageCircleWarning, size: 14, color: Colors.red),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  zh ? '连接失败' : 'Connection failed',
                                  style: const TextStyle(fontSize: 12, color: Colors.red),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _showErrorDetails(s.id, err, s.name),
                                child: Text(zh ? '详情' : 'Details'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (st == McpStatus.error && s.enabled)
                        IconButton(
                          tooltip: zh ? '重新连接' : 'Reconnect',
                          icon: Icon(Lucide.RefreshCw, color: cs.primary),
                          onPressed: () async {
                            // ScaffoldMessenger.of(context).showSnackBar(
                            //   SnackBar(content: Text(zh ? '开始连接…' : 'Reconnecting…')),
                            // );
                            await context.read<McpProvider>().reconnect(s.id);
                            final nowSt = context.read<McpProvider>().statusFor(s.id);
                            if (nowSt == McpStatus.error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(zh ? '连接失败' : 'Reconnect failed')),
                              );
                            }
                          },
                        ),
                      IconButton(
                        icon: Icon(Lucide.Settings, color: cs.primary),
                        onPressed: () async {
                          await showMcpServerEditSheet(context, serverId: s.id);
                        },
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: servers.length,
            ),
    );
  }
}
