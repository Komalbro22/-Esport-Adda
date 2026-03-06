import 'package:flutter/material.dart';

class StitchTheme {
  // Ultra-modern, premium neon palette
  static const Color primary = Color(0xFF00FBFF); // Neon Cyan
  static const Color secondary = Color(0xFF6E00FF); // Electric Purple
  static const Color accent = Color(0xFF00FBFF); 
  
  static const Color background = Color(0xFF070912); // Deep Space Black
  static const Color surface = Color(0xFF0E1120); // Dark Glass
  static const Color surfaceHighlight = Color(0xFF1B1F35); 
  
  static const Color textMain = Color(0xFFFFFFFF); 
  static const Color textMuted = Color(0xFF8B95B7); // Modern Slate
  
  static const Color error = Color(0xFFFF2E63); // Neon Red/Pink
  static const Color success = Color(0xFF08FFC8); // Neon Green/Teal
  static const Color warning = Color(0xFFFFB400); 

  // Modern Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Colors.white10,
      Color(0x0DFFFFFF), // Roughly 0.05 opacity white
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
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textMain, size: 24),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: textMuted.withOpacity(0.1), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          elevation: 8,
          shadowColor: primary.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
