import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

abstract final class MemoryColors {
  static const background = Color(0xFFF6F8FC);
  static const ink = Color(0xFF152238);
  static const secondaryInk = Color(0xFF66788F);
  static const hairline = Color(0xFFDCE5F0);
  static const accent = Color(0xFF5C8CFF);
  static const cyan = Color(0xFF41C7BE);
  static const violet = Color(0xFF8F7CF6);
  static const coral = Color(0xFFFF6E67);
}

ThemeData buildMemoryTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: MemoryColors.accent,
        brightness: Brightness.light,
        surface: MemoryColors.background,
      ).copyWith(
        primary: MemoryColors.accent,
        onSurface: MemoryColors.ink,
        outline: MemoryColors.hairline,
        error: MemoryColors.coral,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamilyFallback: const ['Noto Sans SC', 'Microsoft YaHei', 'sans-serif'],
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: MemoryColors.ink,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
      ),
      headlineSmall: TextStyle(
        color: MemoryColors.ink,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: MemoryColors.ink,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(
        color: MemoryColors.ink,
        fontSize: 15,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        color: MemoryColors.secondaryInk,
        fontSize: 13,
        height: 1.4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MemoryColors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFFF8FAFD),
      modalBackgroundColor: Color(0xFFF8FAFD),
      showDragHandle: true,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
