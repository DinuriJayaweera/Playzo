import 'package:flutter/material.dart';

/// The bright palette used for arrows, chosen so neighbours stand apart.
/// It stays the same in light and dark mode, since it pops on both boards.
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

/// Colours that are the same in both themes.
class AppColors {
  static const heart = Color(0xFFFF3B5C);
  static const gold = Color(0xFFFFC94A);
  static const ink = Color(0xFF2B2250);
  static const play = Color(0xFF22C55E);
}

/// Colours that change between light and dark mode.
@immutable
class GamePalette extends ThemeExtension<GamePalette> {
  const GamePalette({
    required this.bgTop,
    required this.bgMid,
    required this.bgBottom,
    required this.board,
    required this.dot,
    required this.surface,
    required this.ink,
    required this.button,
    required this.buttonIcon,
    required this.glass,
    required this.driftAlpha,
  });

  final Color bgTop;
  final Color bgMid;
  final Color bgBottom;

  /// The puzzle board and its dotted grid.
  final Color board;
  final Color dot;

  /// Sheets and dialogs, and the text drawn on them.
  final Color surface;
  final Color ink;

  /// Round icon buttons.
  final Color button;
  final Color buttonIcon;

  /// Frosted panels over the background.
  final Color glass;

  /// Opacity of the arrows drifting behind each screen.
  final double driftAlpha;

  static const light = GamePalette(
    bgTop: Color(0xFF3B1FB8),
    bgMid: Color(0xFF7C3AED),
    bgBottom: Color(0xFF0EA5C6),
    board: Color(0xFFFFFBF5),
    dot: Color(0xFFCBC3E3),
    surface: Color(0xFFFFFBF5),
    ink: AppColors.ink,
    button: Colors.white,
    buttonIcon: AppColors.ink,
    glass: Color(0x24FFFFFF),
    driftAlpha: 0.16,
  );

  static const dark = GamePalette(
    bgTop: Color(0xFF07061A),
    bgMid: Color(0xFF171039),
    bgBottom: Color(0xFF062635),
    board: Color(0xFF17152E),
    dot: Color(0xFF4A4572),
    surface: Color(0xFF1D1A38),
    ink: Color(0xFFEDEAFF),
    button: Color(0xFF2B2752),
    buttonIcon: Colors.white,
    glass: Color(0x14FFFFFF),
    driftAlpha: 0.1,
  );

  @override
  GamePalette copyWith() => this;

  @override
  GamePalette lerp(GamePalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return GamePalette(
      bgTop: c(bgTop, other.bgTop),
      bgMid: c(bgMid, other.bgMid),
      bgBottom: c(bgBottom, other.bgBottom),
      board: c(board, other.board),
      dot: c(dot, other.dot),
      surface: c(surface, other.surface),
      ink: c(ink, other.ink),
      button: c(button, other.button),
      buttonIcon: c(buttonIcon, other.buttonIcon),
      glass: c(glass, other.glass),
      driftAlpha: driftAlpha + (other.driftAlpha - driftAlpha) * t,
    );
  }
}

extension PaletteContext on BuildContext {
  GamePalette get palette => Theme.of(this).extension<GamePalette>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark
      ? GamePalette.dark
      : GamePalette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C3AED),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bgTop,
    extensions: [palette],
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
      headlineMedium: TextStyle(fontWeight: FontWeight.w900),
      titleLarge: TextStyle(fontWeight: FontWeight.w800),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: palette.ink,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
      contentTextStyle: TextStyle(color: palette.ink, fontSize: 15),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surface,
      contentTextStyle: TextStyle(
        color: palette.ink,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
