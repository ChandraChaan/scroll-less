import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ScrollLess brand palette. Keep in sync with assets/brand/*.svg and the
/// native splash colours in pubspec.yaml.
abstract final class Brand {
  static const indigo = Color(0xFF4F46E5);
  static const indigoDeep = Color(0xFF2B2A8C);
  static const night = Color(0xFF1E1B4B);
  static const coral = Color(0xFFFF5C78);
  static const mint = Color(0xFF2DD4BF);
  static const amber = Color(0xFFF59E0B);

  static const instagram = Color(0xFFE1306C);
  static const youtube = Color(0xFFFF0033);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigoDeep, Color(0xFF5B4BFF)],
  );
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.indigo,
    brightness: brightness,
    secondary: Brand.coral,
    tertiary: Brand.mint,
  );
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);

  return base.copyWith(
    scaffoldBackgroundColor: isDark ? const Color(0xFF0F0E24) : const Color(0xFFF6F5FF),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? const Color(0xFF1A1833) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.6)),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
