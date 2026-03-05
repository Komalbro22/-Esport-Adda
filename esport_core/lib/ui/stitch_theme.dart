import 'package:flutter/material.dart';

class StitchTheme {
  // Vibrant, modern color palette
  static const Color primary = Color(0xFF6A5AE0); // Indigo/Purple
  static const Color secondary = Color(0xFF8F7CFF); // Light Purple
  static const Color accent = Color(0xFF4DA3FF); // Accent Blue
  
  static const Color background = Color(0xFF0B1220); // Deep Dark Blue
  static const Color surface = Color(0xFF141C2F); // Card Background
  static const Color surfaceHighlight = Color(0xFF1E293B); // Slightly lighter
  
  static const Color textMain = Color(0xFFF8FAFC); // Slate 50
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  
  static const Color error = Color(0xFFEF4444); // Danger
  static const Color success = Color(0xFF22C55E); // Success
  static const Color warning = Color(0xFFF59E0B); // Warning

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      fontFamily: 'Inter', // We added google_fonts previously
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textMain),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textMain,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
