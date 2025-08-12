import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData buildLightTheme(ColorScheme? dynamicScheme) {
  final scheme = (dynamicScheme?.harmonized()) ?? const ColorScheme.light(
    surface: Color.fromARGB(255, 242, 247, 251),
    surfaceBright: Color(0x00FFFFFF),
    primary: Color(0xFF0A84FF),
    secondary: Color(0xFFE3EDF2),
    tertiary: Colors.black,
    onSecondary: Colors.black,
    secondaryContainer: Color(0xFFE3EDF2),
    onSecondaryContainer: Color.fromARGB(255, 242, 247, 251),
    inversePrimary: Colors.black54,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Colors.black,
      titleTextStyle: const TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: Colors.black),
      actionsIconTheme: const IconThemeData(color: Colors.black),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: scheme.surface,
      ),
    ),
  );
}

ThemeData buildDarkTheme(ColorScheme? dynamicScheme) {
  final scheme = (dynamicScheme?.harmonized()) ?? const ColorScheme.dark(
    surface: Color(0xFF121012),
    surfaceBright: Color(0x00000000),
    primary: Color(0xFF0A84FF),
    secondary: Color(0xFF382C3E),
    tertiary: Colors.white,
    onSecondary: Colors.white30,
    secondaryContainer: Color.fromARGB(255, 12, 11, 12),
    onSecondaryContainer: Colors.black26,
    inversePrimary: Colors.white54,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: scheme.surface,
      ),
    ),
  );
}

