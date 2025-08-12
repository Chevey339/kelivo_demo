import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ui/home_page.dart';
import 'theme/theme_provider.dart';
import 'theme/theme_factory.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'providers/chat_provider.dart';
import 'models/chat_item.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider(seed: _seedChats())),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
          return DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              final light = buildLightTheme(lightDynamic);
              final dark = buildDarkTheme(darkDynamic);
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Kelivo Demo',
                // Default to Chinese; English supported.
                locale: const Locale('zh', 'CN'),
                supportedLocales: const [
                  Locale('zh', 'CN'),
                  Locale('en', 'US'),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: light,
                darkTheme: dark,
                themeMode: themeProvider.themeMode,
                home: const HomePage(),
              );
            },
          );
        },
      ),
    );
  }
}

List<ChatItem> _seedChats() => <ChatItem>[
      ChatItem(id: 'c1', title: '新建对话', created: DateTime.now().subtract(const Duration(minutes: 30))),
      ChatItem(id: 'c2', title: '需求讨论', created: DateTime.now().subtract(const Duration(hours: 2))),
      ChatItem(id: 'c3', title: '设计评审纪要', created: DateTime.now().subtract(const Duration(days: 1, hours: 1))),
      ChatItem(id: 'c4', title: '技术栈选择', created: DateTime.now().subtract(const Duration(days: 3))),
    ];
 
