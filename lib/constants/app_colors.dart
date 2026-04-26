// app_colors.dart
//
// Single source of truth for the app's dark color palette.
// All three Coup d'œil pages (intro, game, score) import from here,
// so a palette change only needs to happen in one place.

import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation — this class is a namespace for constants only.
  AppColors._();

  // ── Backgrounds ─────────────────────────────────────────────────────
  /// Main page background. Deep navy, used on every scaffold.
  static const Color bg = Color(0xFF171923);

  /// Card / surface color. Slightly lighter than [bg].
  static const Color card = Color(0xFF1E2130);

  // ── Borders ─────────────────────────────────────────────────────────
  /// Default border color for containers and dividers.
  static const Color border = Color(0xFF2D3148);

  /// Slightly lighter border used as a separator inside pills.
  static const Color separator = Color(0xFF3D4460);

  // ── Accent ──────────────────────────────────────────────────────────
  /// Primary green accent (darker shade, used on the intro page).
  static const Color accent = Color(0xFF2EA043);

  /// Bright green accent — buttons, progress bars, highlights.
  static const Color accentBright = Color(0xFF3FB950);

  // ── Text ────────────────────────────────────────────────────────────
  /// Primary text color. Near-white, used for titles and body text.
  static const Color textPrimary = Color(0xFFE6EDF3);

  /// Secondary text color. Muted grey, used for labels and hints.
  static const Color textSecondary = Color(0xFF8B949E);

  // ── Semantic ────────────────────────────────────────────────────────
  /// Wrong answer / error state.
  static const Color red = Color(0xFFDA3633);

  /// Two-point zone / warning.
  static const Color orange = Color(0xFFE87820);

  /// Three-point zone / caution.
  static const Color amber = Color(0xFFD29922);

  /// Four-point zone / good.
  static const Color greenLight = Color(0xFF7CB95A);

  /// "Légende" difficulty badge.
  static const Color purple = Color(0xFF8957E5);

  // ── Difficulty ──────────────────────────────────────────────────────
  /// Returns the color associated with a given difficulty label.
  /// Used in the intro page's difficulty picker and category chips.
  static Color forDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Amateur':
        return const Color(0xFF238636);
      case 'Semi-Pro':
        return accent;
      case 'Pro':
        return amber;
      case 'International':
        return red;
      case 'Légende':
        return purple;
      default:
        return textSecondary;
    }
  }

  // ── Points ──────────────────────────────────────────────────────────
  /// Returns the color for a given point value (1–5).
  /// Used in the game page's timer pill to show urgency.
  static Color forPoints(int points) {
    switch (points) {
      case 5:
        return accentBright;
      case 4:
        return greenLight;
      case 3:
        return amber;
      case 2:
        return orange;
      default:
        return red;
    }
  }
}
