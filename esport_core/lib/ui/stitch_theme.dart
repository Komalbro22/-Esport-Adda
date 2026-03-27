import 'package:flutter/material.dart';

class StitchTheme {
  // Ultra-modern, premium neon palette
  static const Color primary = Color(0xFF00E5FF); // Bright Neon Cyan
  static const Color secondary = Color(0xFF8A2BE2); // Vibrant Electric Purple
  static const Color accent = Color(0xFFFF007F); // Neon Pink Accent
  
  static const Color background = Color(0xFF05060A); // Very Deep Dark
  static const Color surface = Color(0xFF101322); // Premium Dark Surface
  static const Color surfaceHighlight = Color(0xFF1E2340); 
  
  static const Color textMain = Color(0xFFFFFFFF); 
  static const Color textMuted = Color(0xFFA0AABF); // Soft Muted Blue
  
  static const Color error = Color(0xFFFF2A55); 
  static const Color success = Color(0xFF00FFC2); 
  static const Color warning = Color(0xFFFFB800); 

  // Modern Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.2, 1.0],
  );

  static const LinearGradient actionGradient = LinearGradient(
    colors: [accent, secondary],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Colors.white12,
      Colors.white24, 
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onSurface: textMain,
        error: error,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textMain, size: 26),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 12,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: textMuted.withValues(alpha: 0.1), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          elevation: 10,
          shadowColor: primary.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
