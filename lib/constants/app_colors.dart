import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AppColors {
  AppColors._();

  static bool get _d => ThemeService.instance.isDark;

  // ── Backgrounds ─────────────────────────────────────────────────────
  static Color get bg   => _d ? const Color(0xFF111318) : const Color(0xFFECEFF5);
  static Color get card => _d ? const Color(0xFF1C1F28) : const Color(0xFFF5F7FC);

  // ── Borders ─────────────────────────────────────────────────────────
  static Color get border    => _d ? const Color(0xFF2A2E3E) : const Color(0xFFD4D9E8);
  static Color get separator => _d ? const Color(0xFF373C52) : const Color(0xFFBEC5D6);

  // ── Accent ──────────────────────────────────────────────────────────
  static Color get accent      => _d ? const Color(0xFF00C07F) : const Color(0xFF009E6B);
  static Color get accentBright => _d ? const Color(0xFF00D98B) : const Color(0xFF00B87A);

  // ── Text ────────────────────────────────────────────────────────────
  static Color get textPrimary   => _d ? const Color(0xFFE6EDF3) : const Color(0xFF0D1117);
  static Color get textSecondary => _d ? const Color(0xFF8B949E) : const Color(0xFF586069);

  // ── Semantic ────────────────────────────────────────────────────────
  static Color get red       => _d ? const Color(0xFFDA3633) : const Color(0xFFCF2222);
  static Color get orange    => _d ? const Color(0xFFE87820) : const Color(0xFFC85D0F);
  static Color get amber     => _d ? const Color(0xFFD29922) : const Color(0xFF9A7300);
  static Color get greenLight => _d ? const Color(0xFF7CB95A) : const Color(0xFF4A8F2A);
  static Color get purple    => _d ? const Color(0xFF8957E5) : const Color(0xFF6030C8);

  // ── Difficulty ──────────────────────────────────────────────────────
  static Color forDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Amateur':      return _d ? const Color(0xFF238636) : const Color(0xFF1A6E2A);
      case 'Semi-Pro':     return accent;
      case 'Pro':          return amber;
      case 'International': return red;
      case 'Légende':      return purple;
      default:             return textSecondary;
    }
  }

  // ── Points ──────────────────────────────────────────────────────────
  static Color forPoints(int points) {
    switch (points) {
      case 5:  return accentBright;
      case 4:  return greenLight;
      case 3:  return amber;
      case 2:  return orange;
      default: return red;
    }
  }
}
