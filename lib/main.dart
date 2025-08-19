import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ui/home_page.dart';
import 'package:flutter/services.dart';
// Theme is now managed in SettingsProvider
import 'theme/theme_factory.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'providers/chat_provider.dart';
import 'providers/user_provider.dart';
import 'providers/settings_provider.dart';
import 'services/chat_service.dart';
import 'utils/sandbox_path_resolver.dart';

final RouteObserver<ModalRoute<dynamic>> routeObserver = RouteObserver<ModalRoute<dynamic>>();


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cache current Documents directory to fix sandboxed absolute paths on iOS
  await SandboxPathResolver.init();
  // Enable edge-to-edge to allow content under system bars (Android)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ChatService()),
      ],
      child: Builder(
        builder: (context) {
          final settings = context.watch<SettingsProvider>();
          return DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              final light = buildLightTheme(lightDynamic);
              final dark = buildDarkTheme(darkDynamic);
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Kelivo',
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
                themeMode: settings.themeMode,
                navigatorObservers: <NavigatorObserver>[routeObserver],
                home: const HomePage(),
                builder: (ctx, child) {
                  final bright = Theme.of(ctx).brightness;
                  final overlay = bright == Brightness.dark
                      ? const SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent,
                          statusBarIconBrightness: Brightness.light,
                          statusBarBrightness: Brightness.dark,
                          systemNavigationBarColor: Colors.transparent,
                          systemNavigationBarIconBrightness: Brightness.light,
                          systemNavigationBarDividerColor: Colors.transparent,
                        )
                      : const SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent,
                          statusBarIconBrightness: Brightness.dark,
                          statusBarBrightness: Brightness.light,
                          systemNavigationBarColor: Colors.transparent,
                          systemNavigationBarIconBrightness: Brightness.dark,
                          systemNavigationBarDividerColor: Colors.transparent,
                        );
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: overlay,
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
 
