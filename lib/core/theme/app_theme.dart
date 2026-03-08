import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════
//  TRUUST DELIVERY — APP THEME
//
//  Same brand DNA as Truust but delivery-focused:
//  Primary accent: blue (trust, professional)
//  Secondary: green (earnings, success)
//  Same dark/light system
// ═══════════════════════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  // ── Brand Colors ─────────────────────────────────────────
  static const Color blue = Color(0xFF1A6BFF);
  static const Color indigo = Color(0xFF6C63FF);
  static const Color green = Color(0xFF00C896);
  static const Color amber = Color(0xFFFFB020);
  static const Color error = Color(0xFFFF4D6A);
  static const Color success = Color(0xFF00C896);

  // ── Delivery-specific accents ────────────────────────────
  static const Color bikeColor = Color(0xFF1A6BFF);     // blue
  static const Color carColor = Color(0xFF6C63FF);      // indigo
  static const Color pickupColor = Color(0xFFFFB020);   // amber
  static const Color truckColor = Color(0xFFFF6B35);    // orange

  // ── Dark theme surfaces ──────────────────────────────────
  static const Color darkBg = Color(0xFF080E1A);
  static const Color darkSurface = Color(0xFF0F1826);
  static const Color darkSurface2 = Color(0xFF162033);
  static const Color darkTextPrimary = Color(0xFFF0F4FF);
  static const Color darkTextSecondary = Color(0xFF8896B3);
  static const Color darkTextTertiary = Color(0xFF4A5568);

  // ── Light theme surfaces ─────────────────────────────────
  static const Color lightBg = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF0F4FF);
  static const Color lightTextPrimary = Color(0xFF0A0F1E);
  static const Color lightTextSecondary = Color(0xFF4A5568);
  static const Color lightTextTertiary = Color(0xFF8896B3);

  // ── Gradients ────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [blue, indigo],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient earningsGradient = LinearGradient(
    colors: [green, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient activeGradient = LinearGradient(
    colors: [amber, Color(0xFFFF6B35)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Themes ───────────────────────────────────────────────
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? darkBg : lightBg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: blue,
        onPrimary: Colors.white,
        secondary: green,
        onSecondary: Colors.white,
        error: error,
        onError: Colors.white,
        background: isDark ? darkBg : lightBg,
        onBackground: isDark ? darkTextPrimary : lightTextPrimary,
        surface: isDark ? darkSurface : lightSurface,
        onSurface: isDark ? darkTextPrimary : lightTextPrimary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        TextTheme(
          displayLarge: TextStyle(
            color: isDark ? darkTextPrimary : lightTextPrimary,
            fontWeight: FontWeight.w900,
          ),
          bodyLarge: TextStyle(
            color: isDark ? darkTextPrimary : lightTextPrimary,
          ),
          bodyMedium: TextStyle(
            color: isDark ? darkTextSecondary : lightTextSecondary,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkSurface : lightSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isDark ? darkTextPrimary : lightTextPrimary,
        ),
        iconTheme: IconThemeData(
          color: isDark ? darkTextPrimary : lightTextPrimary,
        ),
      ),
    );
  }
}
