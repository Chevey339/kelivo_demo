import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import '../icons/lucide_adapter.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_item.dart';

class SideDrawer extends StatefulWidget {
  const SideDrawer({
    super.key,
    required this.userName,
    required this.assistantName,
  });

  final String userName;
  final String assistantName;

  @override
  State<SideDrawer> createState() => _SideDrawerState();
}

class _SideDrawerState extends State<SideDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_query != _searchController.text) {
        setState(() => _query = _searchController.text);
      }
    });
  }

  void _showChatMenu(BuildContext context, ChatItem chat) async {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final provider = context.read<ChatProvider>();
    final isPinned = provider.pinnedIds.contains(chat.id);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Lucide.Edit, size: 20),
                title: Text(zh ? '重命名' : 'Rename'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _renameChat(context, chat);
                },
              ),
              ListTile(
                leading: Icon(Lucide.Pin, size: 20),
                title: Text(isPinned ? (zh ? '取消置顶' : 'Unpin') : (zh ? '置顶' : 'Pin')),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await provider.togglePin(chat.id);
                },
              ),
              ListTile(
                leading: Icon(Lucide.Trash, size: 20, color: Colors.redAccent),
                title: Text(zh ? '删除' : 'Delete', style: const TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await provider.deleteById(chat.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _renameChat(BuildContext context, ChatItem chat) async {
    final controller = TextEditingController(text: chat.title);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(zh ? '重命名' : 'Rename'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: zh ? '输入新名称' : 'Enter new name',
            ),
            onSubmitted: (_) => Navigator.of(ctx).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(zh ? '取消' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(zh ? '确定' : 'OK'),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await context.read<ChatProvider>().rename(chat.id, controller.text.trim());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    String base;
    if (zh) {
      if (hour < 11) base = '早上好';
      else if (hour < 13) base = '中午好';
      else if (hour < 18) base = '下午好';
      else base = '晚上好';
      return '$base 👋';
    }
    if (hour < 12) base = 'Good morning';
    else if (hour < 17) base = 'Good afternoon';
    else base = 'Good evening';
    return '$base 👋';
  }

  String _dateLabel(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(aDay).inDays;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    if (diff == 0) return zh ? '今天' : 'Today';
    if (diff == 1) return zh ? '昨天' : 'Yesterday';
    if (zh) return '${date.year}年${date.month}月${date.day}日';
    // Simple English format like Aug 10, 2025
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  List<_ChatGroup> _groupByDate(BuildContext context, List<ChatItem> source) {
    final items = [...source];
    // group by day (truncate time)
    final map = <DateTime, List<ChatItem>>{};
    for (final c in items) {
      final d = DateTime(c.created.year, c.created.month, c.created.day);
      map.putIfAbsent(d, () => []).add(c);
    }
    // sort groups by date desc (recent first)
    final keys = map.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      for (final k in keys)
        _ChatGroup(
          label: _dateLabel(context, k),
          items: (map[k]!..sort((a, b) => a.created.compareTo(b.created)))!,
        )
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final textBase = isDark ? cs.tertiary : Colors.black; // 纯黑（白天），夜间自动适配
    final chatProvider = context.watch<ChatProvider>();
    final all = chatProvider.chats;
    final pinnedIds = chatProvider.pinnedIds;

    final base = _query.trim().isEmpty
        ? all
        : all.where((c) => c.title.toLowerCase().contains(_query.toLowerCase())).toList();
    final pinnedList = base.where((c) => pinnedIds.contains(c.id)).toList()
      ..sort((a, b) => a.created.compareTo(b.created));
    final rest = base.where((c) => !pinnedIds.contains(c.id)).toList();
    final groups = _groupByDate(context, rest);

    // Default text avatar: light theme color background + theme color text
    Widget avatarDefault(String name, {double size = 40}) {
      final letter = name.isNotEmpty ? name.characters.first : '?';
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            color: cs.primary,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  // 1. 用户信息区
                  Row(
                    children: [
                      avatarDefault(widget.userName, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.userName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textBase,
                                )),
                            const SizedBox(height: 2),
                            Text(_greeting(context),
                                style: TextStyle(color: textBase, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. 搜索框（圆角50的胶囊，使用主题默认容器色，仅隐藏指示线）
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: Localizations.localeOf(context).languageCode == 'zh'
                          ? '搜索聊天记录'
                          : 'Search chat history',
                      filled: true,
                      fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5), // 非常浅的淡灰色（白天），夜间自适配
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50), // 胶囊
                        borderSide: BorderSide(color: Colors.transparent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide(color: Colors.transparent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide(color: Colors.transparent),
                      ),
                    ),
                    style: TextStyle(color: textBase, fontSize: 14), // 黑色（白天）
                  ),

                  const SizedBox(height: 18),

                  // 3. 聊天记录区（按日期分组，最近在前；垂直列表）
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      key: ValueKey('${_query}_${groups.length}_${pinnedList.length}'),
                      children: [
                        if (pinnedList.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'zh' ? '置顶' : 'Pinned',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.primary),
                            ),
                          ),
                          Column(
                            children: [
                              for (final chat in pinnedList)
                                _ChatTile(
                                  chat: chat,
                                  textColor: textBase,
                                  onLongPress: () => _showChatMenu(context, chat),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        for (final group in groups) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
                            child: Text(
                              group.label,
                              textAlign: TextAlign.left,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.primary),
                            ),
                          ),
                          Column(
                            children: [
                              for (final chat in group.items)
                                _ChatTile(
                                  chat: chat,
                                  textColor: textBase,
                                  onLongPress: () => _showChatMenu(context, chat),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 底部工具栏（固定）
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: cs.surface,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // 左：机器人按钮
                      Material(
                        color: cs.surface,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(Lucide.Bot, size: 22, color: cs.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 右：默认助手卡片
                      Expanded(
                        child: Material(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  avatarDefault(widget.assistantName, size: 28),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      widget.assistantName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textBase),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Lucide.History, size: 18, color: cs.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    Localizations.localeOf(context).languageCode == 'zh' ? '聊天历史' : 'History',
                                    style: TextStyle(color: textBase),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Material(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Lucide.Settings, size: 18, color: cs.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    Localizations.localeOf(context).languageCode == 'zh' ? '设置' : 'Settings',
                                    style: TextStyle(color: textBase),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatGroup {
  final String label;
  final List<ChatItem> items;
  _ChatGroup({required this.label, required this.items});
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.textColor, this.onTap, this.onLongPress});

  final ChatItem chat;
  final Color textColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(
              chat.title,
              style: TextStyle(fontSize: 15, color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}
