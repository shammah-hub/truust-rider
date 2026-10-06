import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════
//  TRUUST RIDER — APP THEME
//
//  Same design language as the web dashboard: a neutral black /
//  white / gray base, with the iOS system colors doing specific
//  jobs (blue = primary action, green = success/money, orange =
//  pending, red = danger/destination, purple/indigo = secondary
//  categories). Color is used in small doses — status chips,
//  icon tiles, badges — never as a full-screen wash.
//
//  Field names from the old monochrome theme are kept so existing
//  screens keep compiling; only the values changed.
// ═══════════════════════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  // ── iOS system colors (light) ─────────────────────────────
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color iosGreen = Color(0xFF34C759);
  static const Color iosIndigo = Color(0xFF5856D6);
  static const Color iosOrange = Color(0xFFFF9500);
  static const Color iosPink = Color(0xFFFF2D55);
  static const Color iosPurple = Color(0xFFAF52DE);
  static const Color iosRed = Color(0xFFFF3B30);
  static const Color iosTeal = Color(0xFF30B0C7);
  static const Color iosYellow = Color(0xFFFFCC00);
  static const Color iosMint = Color(0xFF00C7BE);
  static const Color iosCyan = Color(0xFF32ADE6);
  static const Color iosBrown = Color(0xFFA2845E);

  // ── iOS system colors (dark) — same roles, brighter ───────
  static const Color iosBlueDark = Color(0xFF0A84FF);
  static const Color iosGreenDark = Color(0xFF30D158);
  static const Color iosIndigoDark = Color(0xFF5E5CE6);
  static const Color iosOrangeDark = Color(0xFFFF9F0A);
  static const Color iosPinkDark = Color(0xFFFF375F);
  static const Color iosPurpleDark = Color(0xFFBF5AF2);
  static const Color iosRedDark = Color(0xFFFF453A);
  static const Color iosTealDark = Color(0xFF40C8E0);
  static const Color iosYellowDark = Color(0xFFFFD60A);

  /// Returns the right shade for the current brightness — use this
  /// instead of the bare iosX constants wherever a screen switches
  /// with dark mode (status colors, icon tiles, chips).
  static Color blueFor(bool isDark) => isDark ? iosBlueDark : iosBlue;
  static Color greenFor(bool isDark) => isDark ? iosGreenDark : iosGreen;
  static Color indigoFor(bool isDark) => isDark ? iosIndigoDark : iosIndigo;
  static Color orangeFor(bool isDark) => isDark ? iosOrangeDark : iosOrange;
  static Color pinkFor(bool isDark) => isDark ? iosPinkDark : iosPink;
  static Color purpleFor(bool isDark) => isDark ? iosPurpleDark : iosPurple;
  static Color redFor(bool isDark) => isDark ? iosRedDark : iosRed;
  static Color tealFor(bool isDark) => isDark ? iosTealDark : iosTeal;
  static Color yellowFor(bool isDark) => isDark ? iosYellowDark : iosYellow;

  // ── THE ONE ACCENT — kept for anything still keyed off it ─
  static const Color accent = Color(0xFFFFB800);

  // ── Legacy names — now resolve to an actual iOS color each,
  //    instead of collapsing to black/white. Prefer the *For()
  //    helpers above in new code; these stay for old call sites.
  static const Color blue = iosBlue;
  static const Color indigo = iosIndigo;
  static const Color amber = iosOrange;
  static const Color green = iosGreen;
  static const Color error = iosRed;
  static const Color success = iosGreen;

  // ── Delivery-specific accents — one color per vehicle/marker
  //    so riders can tell them apart in lists and on the map,
  //    same convention as the dashboard's Fleet Map pins.
  static const Color bikeColor = iosTeal;
  static const Color carColor = iosIndigo;
  static const Color truckColor = iosOrange;
  static const Color pickupColor = iosBlue;
  static const Color dropoffColor = iosRed;

  // ── Gray scale ─────────────────────────────────────────────
  static const Color gray = Color(0xFF8E8E93);
  static const Color gray2 = Color(0xFFAEAEB2);
  static const Color gray3 = Color(0xFFC7C7CC);
  static const Color gray4 = Color(0xFFD1D1D6);
  static const Color gray5 = Color(0xFFE5E5EA);
  static const Color gray6 = Color(0xFFF2F2F7);

  // ── Dark theme surfaces ────────────────────────────────────
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurface2 = Color(0xFF2C2C2E);
  static const Color darkBorder = Color(0x1FFFFFFF); // white 12%
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0x99EBEBF5); // 60%
  static const Color darkTextTertiary = Color(0x4DEBEBF5); // 30%

  // ── Light theme surfaces ───────────────────────────────────
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF9F9FB);
  static const Color lightBorder = Color(0x21000000); // black 13%
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xCC3C3C43); // 80%
  static const Color lightTextTertiary = Color(0x993C3C43); // 60%

  // ── Surface / text helpers — read these instead of picking
  //    darkX / lightX by hand at every call site ──────────────
  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color surface2(bool isDark) => isDark ? darkSurface2 : lightSurface2;
  static Color border(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color textPrimary(bool isDark) =>
      isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) =>
      isDark ? darkTextSecondary : lightTextSecondary;
  static Color textTertiary(bool isDark) =>
      isDark ? darkTextTertiary : lightTextTertiary;

  // ── INK HELPERS ────────────────────────────────────────────
  static Color ink(bool isDark) => isDark ? Colors.white : Colors.black;
  static Color inkInverse(bool isDark) => isDark ? Colors.black : Colors.white;

  // ── Corner radii — matches the web dashboard's tokens ─────
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 28;
  static const double radiusPill = 999;

  // ── Solid gradients kept for spots that still expect one,
  //    e.g. a full-bleed hero — flat, not two-tone.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [iosBlue, iosBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient earningsGradient = LinearGradient(
    colors: [iosGreen, iosGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient activeGradient = LinearGradient(
    colors: [accent, accent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Themes ───────────────────────────────────────────────
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg(isDark),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: blueFor(isDark),
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.black,
        error: redFor(isDark),
        onError: Colors.white,
        background: bg(isDark),
        onBackground: textPrimary(isDark),
        surface: surface(isDark),
        onSurface: textPrimary(isDark),
      ),
      fontFamily: GoogleFonts.dmSans().fontFamily,
      textTheme: GoogleFonts.dmSansTextTheme(
        TextTheme(
          displayLarge: TextStyle(
            color: textPrimary(isDark),
            fontWeight: FontWeight.w800,
          ),
          bodyLarge: TextStyle(color: textPrimary(isDark)),
          bodyMedium: TextStyle(color: textSecondary(isDark)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary(isDark),
        ),
        iconTheme: IconThemeData(color: textPrimary(isDark)),
      ),
      // Primary CTA — solid iOS blue fill, like a filled UIButton.
      // (Previously forced black/white; that flat monochrome look
      // was the "still needs migrating" placeholder, not the goal.)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blueFor(isDark),
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: blueFor(isDark)),
      ),
      dividerTheme: DividerThemeData(color: border(isDark), thickness: 1),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  GLOSSY ICON TILE
//
//  The rounded-square colored icon you see throughout iOS
//  Settings — a vertical gradient, a soft highlight across the
//  top half, and a subtle drop shadow in the tile's own color.
//  Use this everywhere a status or category needs a small colored
//  icon: vehicle type, order status, a stat card, a menu row.
// ═══════════════════════════════════════════════════════════════

class GlossyIconTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;
  final double? iconSize;

  const GlossyIconTile({
    super.key,
    required this.color,
    required this.icon,
    this.size = 40,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.28;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.28)!,
            color,
            Color.lerp(color, Colors.black, 0.14)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // top-half sheen — the "glossy" part
          Positioned(
            top: 1,
            left: 1,
            right: 1,
            height: size * 0.46,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(radius - 1),
                  topRight: Radius.circular(radius - 1),
                  bottomLeft: Radius.circular(radius * 0.6),
                  bottomRight: Radius.circular(radius * 0.6),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.45),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
          Icon(icon, color: Colors.white, size: iconSize ?? size * 0.5),
        ],
      ),
    );
  }
}

/// A translucent tint of an iOS color, for chip/badge backgrounds —
/// same idea as `color-mix(in srgb, var(--ios-x) N%, transparent)`
/// on the web dashboard.
Color iosTint(Color color, double opacity) => color.withOpacity(opacity);
