import 'package:flutter/material.dart';

import '../widgets/chat_input_bar.dart';
import '../widgets/bottom_tools_sheet.dart';
import '../widgets/side_drawer.dart';
import '../theme/design_tokens.dart';
import '../icons/lucide_adapter.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  bool _toolsOpen = false;
  static const double _sheetHeight = 160; // height of tools area
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _titleForLocale(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'zh' ? '新聊天' : 'New Chat';
  }

  void _toggleTools() {
    setState(() => _toolsOpen = !_toolsOpen);
  }

  @override
  Widget build(BuildContext context) {
    final title = _titleForLocale(context);

    // Chats are seeded via ChatProvider in main.dart

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          tooltip: Localizations.localeOf(context).languageCode == 'zh'
              ? '菜单'
              : 'Menu',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Lucide.ListTree, size: 22),
        ),
        titleSpacing: 0,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'zh'
                ? '更多'
                : 'Menu',
            onPressed: () {},
            icon: const Icon(Lucide.Menu, size: 22),
          ),
          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'zh'
                ? '新建话题'
                : 'New Topic',
            onPressed: () {},
            icon: const Icon(Lucide.MessageCirclePlus, size: 22),
          ),
        ],
      ),
      drawer: SideDrawer(
        userName: context.watch<UserProvider>().name,
        assistantName: Localizations.localeOf(context).languageCode == 'zh' ? '默认助手' : 'Default Assistant',
      ),
      body: Stack(
        children: [
          const Center(
            child: Text(
              '内容区域 / Content Area',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          // Backdrop to close sheet on tap
          if (_toolsOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleTools,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
          // Tools sheet
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: 0,
            height: _toolsOpen ? _sheetHeight : 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: OverflowBox(
                maxHeight: _sheetHeight,
                alignment: Alignment.bottomCenter,
                child: const BottomToolsSheet(),
              ),
            ),
          ),
          // Input bar animates up when sheet is open
          AnimatedPadding(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: _toolsOpen ? _sheetHeight : 0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ChatInputBar(
                onMore: _toggleTools,
                moreOpen: _toolsOpen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
