import 'package:flutter/material.dart';

/// Quiet Ledger design tokens — derived from UI_UX.md
/// Primary: forest green #146356 · Surface: warm off-white #f7f6f2
/// Dark surface: #101917

abstract final class LdtColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF146356);
  static const Color primaryDark = Color(0xFF8DD4BE);

  // ── Surfaces (light) ───────────────────────────────────────────────────────
  static const Color background = Color(0xFFF7F6F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0EFE9);
  static const Color outline = Color(0xFFE5E3DC);

  // ── Surfaces (dark) ────────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF101917);
  static const Color surfaceDark = Color(0xFF192622);
  static const Color surfaceVariantDark = Color(0xFF243B35);
  static const Color outlineDark = Color(0xFF40594E);

  // ── Text (light) ───────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF182B29);
  static const Color textSecondary = Color(0xFF5E706B);
  static const Color textDisabled = Color(0xFF9DB0AB);

  // ── Text (dark) ────────────────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFEDF5EF);
  static const Color textSecondaryDark = Color(0xFFB5C8BF);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFB3261E);
  static const Color errorContainer = Color(0xFFF9DEDC);
  static const Color success = Color(0xFF2E7D52);
  static const Color warning = Color(0xFFE65C00);

  // ── Amount colours (never sole indicator of direction) ────────────────────
  static const Color amountLent = Color(0xFF146356);   // owed to me
  static const Color amountBorrowed = Color(0xFF9C4221); // owed by me
  static const Color amountLentDark = Color(0xFF8DD4BE);
  static const Color amountBorrowedDark = Color(0xFFFFB4A2);
}

abstract final class LdtTextStyles {
  static const String _font = 'Inter';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: _font,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: _font,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: _font,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Monospace amount display (large balance figures)
  static const TextStyle amountDisplay = TextStyle(
    fontFamily: _font,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle amountMedium = TextStyle(
    fontFamily: _font,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

abstract final class LdtRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;
}

abstract final class LdtSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
