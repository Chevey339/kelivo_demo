import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData buildLightTheme(ColorScheme? dynamicScheme) {
  final scheme = (dynamicScheme?.harmonized()) ?? const ColorScheme.light(
    primary: Color(0xFF4D5C92),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF595D72),
    onSecondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFF75546F),
    surface: Color(0xFFFEFBFF),
    onSurface: Color(0xFF1A1B21),
    primaryContainer: Color(0xFFDCE1FF),
    error: Color(0xFFBA1A1A),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 14, fontWeight: FontWeight.w500),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: scheme.primary,
      disabledActionTextColor: scheme.onInverseSurface.withOpacity(0.5),
    ),
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
    primary: Color(0xFFB6C4FF),
    onPrimary: Color(0xFF1D2D61),
    secondary: Color(0xFFC2C5DD),
    onSecondary: Color(0xFF2B3042),
    tertiary: Color(0xFFE3BADA),
    surface: Color(0xFF1A1B21),
    onSurface: Color(0xFFE3E1E9),
    primaryContainer: Color(0xFF354479),
    error: Color(0xFFFFB4AB),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 14, fontWeight: FontWeight.w500),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: scheme.primary,
      disabledActionTextColor: scheme.onInverseSurface.withOpacity(0.6),
    ),
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
