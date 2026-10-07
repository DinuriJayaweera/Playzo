import 'package:flutter/material.dart';

/// The bright palette used for arrows, chosen so neighbours stand apart.
const arrowColors = [
  Color(0xFFFF4D6D), // coral red
  Color(0xFFFF9F1C), // orange
  Color(0xFFFFC300), // sunflower
  Color(0xFF06D6A0), // mint
  Color(0xFF2EC4B6), // teal
  Color(0xFF3A86FF), // blue
  Color(0xFF8338EC), // violet
  Color(0xFFFF006E), // magenta
  Color(0xFF7CB518), // lime
];

class AppColors {
  static const bgTop = Color(0xFF241468);
  static const bgMid = Color(0xFF5B21B6);
  static const bgBottom = Color(0xFF0E7490);
  static const board = Color(0xFFFFFBF5);
  static const dot = Color(0xFFCBC3E3);
  static const heart = Color(0xFFFF3B5C);
  static const gold = Color(0xFFFFC94A);
  static const ink = Color(0xFF2B2250);
  static const play = Color(0xFF22C55E);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.bgMid,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bgTop,
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
      headlineMedium: TextStyle(fontWeight: FontWeight.w900),
      titleLarge: TextStyle(fontWeight: FontWeight.w800),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.board,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
