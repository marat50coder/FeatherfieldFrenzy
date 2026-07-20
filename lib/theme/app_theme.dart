import 'package:flutter/material.dart';

/// Central place for colors, gradients and text styles used across the app.
class AppTheme {
  static const Color primary = Color(0xFFF6A821); // warm amber (logo yellow)
  static const Color primaryDark = Color(0xFFCE7A12);
  static const Color green = Color(0xFF7CB342);
  static const Color greenDark = Color(0xFF558B2F);
  static const Color sky = Color(0xFF4FB3E8);
  static const Color skyLight = Color(0xFFBDE3F7);
  static const Color brown = Color(0xFF6B4423);
  static const Color cream = Color(0xFFFDF6E3);
  static const Color ink = Color(0xFF3A2A18);
  static const Color danger = Color(0xFFE04A3F);

  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: sky,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
        ),
      );

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF6EC6F0), Color(0xFFBDE7FB)],
  );

  static TextStyle title(double size, {Color color = Colors.white}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.5,
        // Crisp (non-blurred) shadow for depth. A blurred shadow here caused a
        // renderer glitch that filled some glyphs (e.g. "0") with a dark blob.
        shadows: const [
          Shadow(color: Color(0x40000000), offset: Offset(0, 1.5)),
        ],
      );

  static TextStyle body(double size,
          {Color color = Colors.white, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
}
