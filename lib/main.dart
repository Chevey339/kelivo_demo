import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ui/home_page.dart';
import 'theme/theme_provider.dart';
import 'theme/theme_factory.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'providers/chat_provider.dart';
import 'providers/user_provider.dart';

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
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
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
 
