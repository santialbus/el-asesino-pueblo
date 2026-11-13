import 'package:flutter/material.dart';

/// Paleta del proyecto (minimalista y elegante: negro, carbón, marfil, burdeos;
/// el dorado sólo como acento).
class AppColors {
  static const bg = Color(0xFF101014);
  static const bg2 = Color(0xFF19171C);
  static const burgundy = Color(0xFF711E32);
  static const gold = Color(0xFFC9A45C);
  static const danger = Color(0xFFC83B45);
  static const town = Color(0xFF527A60);
  static const text = Color(0xFFF4EFE7);
  static const text2 = Color(0xFFA9A2A0);
}

class AppText {
  /// Títulos: Cinzel (serif romana con carácter).
  static TextStyle title(
    double size, {
    Color color = AppColors.text,
    double spacing = 2,
  }) => TextStyle(
    fontFamily: 'Cinzel',
    fontSize: size,
    color: color,
    letterSpacing: spacing,
    fontVariations: const [FontVariation('wght', 700)],
    height: 1.15,
  );

  /// Texto corrido: Lora.
  static TextStyle body(
    double size, {
    Color color = AppColors.text,
    bool bold = false,
  }) => TextStyle(
    fontFamily: 'Lora',
    fontSize: size,
    color: color,
    height: 1.4,
    fontVariations: [FontVariation('wght', bold ? 700 : 400)],
  );

  static TextStyle label(double size, {Color color = AppColors.gold}) =>
      TextStyle(
        fontFamily: 'Cinzel',
        fontSize: size,
        color: color,
        letterSpacing: 2.4,
        fontVariations: const [FontVariation('wght', 600)],
      );
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.burgundy,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.gold,
        onPrimary: AppColors.bg,
        secondary: AppColors.burgundy,
        surface: AppColors.bg2,
        onSurface: AppColors.text,
        error: AppColors.danger,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Lora',
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: 'Lora',
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.bg2,
      contentTextStyle: AppText.body(14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? AppColors.gold : AppColors.text2,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.burgundy
            : AppColors.bg2,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.gold,
      thumbColor: AppColors.gold,
      inactiveTrackColor: Color(0xFF3A353C),
    ),
  );
}
