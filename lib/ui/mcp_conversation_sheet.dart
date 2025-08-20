import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../icons/lucide_adapter.dart';
import '../providers/mcp_provider.dart';
import '../services/chat_service.dart';

Future<void> showConversationMcpSheet(BuildContext context, {required String conversationId}) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ConversationMcpSheet(conversationId: conversationId),
  );
}

class _ConversationMcpSheet extends StatelessWidget {
  const _ConversationMcpSheet({required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final mcp = context.watch<McpProvider>();
    final chat = context.watch<ChatService>();

    final selected = chat.getConversationMcpServers(conversationId).toSet();
    final servers = mcp.servers.where((s) => mcp.statusFor(s.id) == McpStatus.connected).toList();

    Widget tag(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.primary.withOpacity(0.35)),
          ),
          child: Text(text, style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600)),
        );

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, controller) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      zh ? 'MCP服务器' : 'MCP Servers',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: servers.isEmpty
                    ? Center(
                        child: Text(
                          zh ? '暂无已启动的 MCP 服务器' : 'No running MCP servers',
                          style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        itemBuilder: (context, index) {
                          final s = servers[index];
                          final tools = s.tools;
                          final enabledTools = tools.where((t) => t.enabled).length;
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Lucide.Terminal, size: 20, color: cs.primary),
                            ),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  tag('${zh ? '已连接' : 'Connected'} · $enabledTools/${tools.length} tools'),
                                ],
                              ),
                            ),
                            trailing: Switch(
                              value: selected.contains(s.id),
                              onChanged: (v) {
                                context.read<ChatService>().toggleConversationMcpServer(conversationId, s.id, v);
                              },
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemCount: servers.length,
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

