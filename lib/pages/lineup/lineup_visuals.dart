// lineup_visuals.dart
//
// Shared visual + mapping helpers for the Compos (lineup) feature.
// Single source of truth for solo and 1v1 pages — previously these were
// copy-pasted (and had silently diverged) across:
//   lineup_match_page.dart, compos_1v1_game_page.dart,
//   lineup_match_preview_page.dart, compos_1v1_preview_page.dart,
//   compos_1v1_lobby_page.dart

import 'package:flutter/material.dart';
import 'package:diacritic/diacritic.dart';
import '../../services/theme_service.dart';

Color parseTeamColor(String? name) {
  switch (name?.toLowerCase().trim()) {
    case 'blanc':
      return const Color(0xFFF0F0F0);
    case 'noir':
      return const Color(0xFF000000);
    case 'rouge':
      return const Color(0xFFDC2626);
    case 'bleu':
      return const Color(0xFF1D4ED8);
    case 'bleu clair':
      return const Color(0xFF60A5FA);
    case 'bleu foncé':
      return const Color(0xFF0C034D);
    case 'vert':
      return const Color(0xFF16A34A);
    case 'jaune':
      return const Color(0xFFFACC15);
    case 'orange':
      return const Color(0xFFE16806);
    case 'violet':
      return const Color(0xFF790CC8);
    default:
      return const Color(0xFF4A5568);
  }
}

// Returns null if no second color → flat circle
Color? parseTeamColor2(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  return parseTeamColor(name);
}

Color labelColor(Color bg) =>
    bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

int difficultyToLevel(String difficulty) {
  switch (difficulty) {
    case 'Amateur':
      return 1;
    case 'Semi-Pro':
      return 2;
    case 'Pro':
      return 3;
    case 'International':
      return 4;
    case 'Légende':
      return 5;
    default:
      return 3;
  }
}

String? leagueFolder(String competition) {
  final c = competition.toLowerCase();
  // Champions League block MUST stay before the 'pays' block:
  // 'ligue europa'.contains('euro') is true, so the euro/pays check
  // would otherwise swallow Europa League and break club logos.
  if (c.contains('champions league') ||
      c.contains('ligue des champions') ||
      c.contains('ligue europa'))
    return 'Champions League';
  if (c.contains('euro') ||
      c.contains('coupe du monde') ||
      c.contains('world cup') ||
      c.contains('ligue des nations') ||
      c.contains('copa') ||
      c.contains('barrage') ||
      c.contains('can'))
    return 'pays';
  if (c.contains('ligue 1') ||
      c.contains('coupe de france') ||
      c.contains('coupe de la ligue'))
    return 'France - Ligue 1';
  if (c.contains('premier league') ||
      c.contains('community shield') ||
      c.contains('fa cup'))
    return 'England - Premier League';
  if (c.contains('laliga') || c.contains('la liga')) return 'Spain - La Liga';
  if (c.contains('bundesliga') && !c.contains('austria'))
    return 'Germany - Bundesliga';
  if (c.contains('serie a')) return 'Italy - Serie A';
  if (c.contains('eredivisie')) return 'Netherlands - Eredivisie';
  if (c.contains('liga portugal')) return 'Portugal - Liga Portugal';
  if (c.contains('jupiler')) return 'Belgium - Jupiler Pro League';
  return null;
}

// Color scheme used specifically for the preview-page team logos.
// Distinct from [parseTeamColor] (different 'noir' / 'bleu foncé').
// [fallback] is the per-page default (kept divergent on purpose:
// solo preview uses AppColors.border, 1v1 preview uses 0xFF2D3148).
Color previewLogoColor(String? name, {required Color fallback}) {
  switch (name?.toLowerCase().trim()) {
    case 'blanc':
      return const Color(0xFFF0F0F0);
    case 'noir':
      return const Color(0xFF1A1A1A);
    case 'rouge':
      return const Color(0xFFDC2626);
    case 'bleu':
      return const Color(0xFF1D4ED8);
    case 'bleu clair':
      return const Color(0xFF60A5FA);
    case 'bleu foncé':
      return const Color(0xFF0C0A4D);
    case 'vert':
      return const Color(0xFF16A34A);
    case 'jaune':
      return const Color(0xFFFACC15);
    case 'orange':
      return const Color(0xFFE16806);
    case 'violet':
      return const Color(0xFF790CC8);
    default:
      return fallback;
  }
}

const coloredCompLogos = {'Euro', 'Coupe du Monde', 'CAN', 'Copa America'};

Widget teamLogoSmall(
  String name,
  String colorName,
  String? folder, {
  double size = 28,
}) {
  final bg = parseTeamColor(colorName);
  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
  final fallback = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: bg,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF2D3148), width: 1.5),
    ),
    child: Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          color: bg.computeLuminance() < 0.4 ? Colors.white : Colors.black87,
        ),
      ),
    ),
  );
  if (folder == null) return fallback;
  final fileName = folder == 'pays'
      ? removeDiacritics(name.toLowerCase())
      : name;
  return Image.asset(
    'assets/logos/$folder/$fileName.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => fallback,
  );
}

Widget competitionLogoSmall(String competition) {
  final img = Image.asset(
    'assets/logos/competitions/$competition.png',
    width: 36,
    height: 36,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
  );
  if (coloredCompLogos.contains(competition)) return img;
  return ColorFiltered(
    colorFilter: ColorFilter.mode(
      ThemeService.instance.isDark ? Colors.white : Colors.black87,
      BlendMode.srcIn,
    ),
    child: img,
  );
}
