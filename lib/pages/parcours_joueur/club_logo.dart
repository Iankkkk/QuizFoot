// club_logo.dart
//
// Resolves a (raw Wikipedia FR) club name to a bundled logo asset.
//
// Coverage is partial by design: the assets/logos/<league>/ folders only
// contain CURRENT league rosters, so many historical clubs have no logo.
// That's expected — missing logos render as a clean monogram circle.
//
// Safety: a guessing game must NEVER show the WRONG club logo. Resolution is
// therefore strict — exact normalized match, then a curated alias map, then a
// "core" match ONLY when it maps to a single asset. No fuzzy similarity.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:diacritic/diacritic.dart';

/// Loads & indexes every club logo once per app session.
class ClubLogoIndex {
  ClubLogoIndex._();
  static final ClubLogoIndex instance = ClubLogoIndex._();

  bool _loaded = false;

  /// normalized exact filename → asset path
  final Map<String, String> _byExact = {};

  /// normalized "core" (org tokens stripped) → list of asset paths
  final Map<String, List<String>> _byCore = {};

  // Folders that are NOT club rosters — excluded so we never resolve a club
  // to a country flag or a competition crest. NB: the "Champions League"
  // folder IS included on purpose — it holds 25 big European CLUB logos
  // (Real Madrid, Inter Milan, LOSC Lille…), names close to Wikipedia FR.
  static const _excludedFolders = {'pays', 'competitions'};

  // Common football org tokens stripped to build the "core" key.
  static const _orgTokens = {
    'fc',
    'afc',
    'sc',
    'cf',
    'ac',
    'as',
    'sv',
    'bc',
    'cfc',
    'ca',
    'rc',
    'ogc',
    'sco',
    'sl',
    'cd',
    'ssc',
    'us',
    'aj',
    'if',
    'bk',
    'fk',
    'club',
    'calcio',
    'futebol',
    'cp',
    'ud',
    'rcd',
    'spvgg',
    'tsg',
    'vfb',
    'vfl',
    'fsv',
    'bsc',
    'kv',
    'kaa',
    'rsc',
  };

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final path in manifest.listAssets()) {
        if (!path.startsWith('assets/logos/') || !path.endsWith('.png')) {
          continue;
        }
        final parts = path.split('/');
        if (parts.length < 4) continue; // assets/logos/<folder>/<file>.png
        final folder = parts[2];
        if (_excludedFolders.contains(folder)) continue;

        // Strip .png, then strip any domain-like suffix (e.g. ".football-logos.cc")
        // so packs named "club-name.provider.tld.png" resolve as "club-name".
        final stem = parts.last.substring(0, parts.last.length - 4);
        final file = stem.contains('.') ? stem.substring(0, stem.indexOf('.')) : stem;
        final exact = _normalize(file);
        _byExact.putIfAbsent(exact, () => path);

        final core = _core(exact);
        if (core.isNotEmpty && core != exact) {
          _byCore.putIfAbsent(core, () => []).add(path);
        }
      }
    } catch (_) {
      // If the manifest can't be read, every club just falls back to monogram.
    }
    _loaded = true;
  }

  /// Returns the asset path for [clubName], or null → caller shows a monogram.
  String? resolve(String clubName) {
    final n = _normalize(clubName);
    if (n.isEmpty) return null;

    // 1. Exact normalized match (safest).
    final exact = _byExact[n];
    if (exact != null) return exact;

    // 2. Curated alias (Wikipedia FR form → known asset key).
    final alias = _aliases[n];
    if (alias != null) {
      final viaAlias = _byExact[alias];
      if (viaAlias != null) return viaAlias;
    }

    // 3. Core match — ONLY if it resolves to a single asset (else fallback,
    //    never guess between several clubs).
    final core = _core(n);
    final candidates = _byCore[core];
    if (candidates != null && candidates.length == 1) return candidates.first;

    return null;
  }

  static String _normalize(String s) {
    var t = removeDiacritics(s).toLowerCase();
    t = t.replaceAll(RegExp(r"[._&/'\-]"), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  static String _core(String normalized) {
    final words = normalized
        .split(' ')
        .where((w) => w.isNotEmpty && !_orgTokens.contains(w))
        .toList();
    return words.join(' ');
  }

  // Curated alias map — ENRICHIR ICI au fil des cas repérés.
  //
  // Format : 'nom carriere normalise' : 'nom fichier asset normalise',
  //   • clé   = team Wikipedia normalisé (minuscules, sans accents,
  //             . _ & / ' - → espace, espaces réduits, trim).
  //   • valeur= nom du .png (sans extension) normalisé pareil, et qui
  //             EXISTE dans assets/logos/<ligue>/ ou /Champions League.
  // Inutile si le nom carrière == nom fichier (le match exact gère déjà).
  // Ex. carrière "Strasbourg", fichier "RC Strasbourg Alsace.png" →
  //   'strasbourg': 'rc strasbourg alsace',
  static const Map<String, String> _aliases = {
    'olympique de marseille': 'om',
    'olympique lyonnais': 'ol',
    'paris saint germain': 'psg',
    'paris sg': 'psg',
    'as rome': 'as roma',
    'juventus fc': 'juventus',
    'arsenal fc': 'arsenal',
    'chelsea fc': 'chelsea',
    'real madrid cf': 'real madrid',
    'west ham united': 'west ham',
    'seville fc': 'fc seville',
    'tottenham hotspur': 'tottenham',
    'liverpool fc': 'liverpool',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// National team flag widget
// ─────────────────────────────────────────────────────────────────────────────

/// Maps a French country name (as used in career nat rows) → asset filename
/// (without extension) inside assets/logos/pays/.
const _kFlagMap = <String, String>{
  // Named files (main football nations)
  'france': 'france',
  'espagne': 'espagne',
  'portugal': 'portugal',
  'angleterre': 'angleterre',
  'allemagne': 'allemagne',
  'italie': 'italie',
  'brésil': 'bresil',
  'bresil': 'bresil',
  'argentine': 'argentine',
  'algérie': 'algerie',
  'algerie': 'algerie',
  'maroc': 'maroc',
  'cameroun': 'cameroun',
  "côte d'ivoire": "cote d'ivoire",
  "cote d'ivoire": "cote d'ivoire",
  'sénégal': 'senegal',
  'senegal': 'senegal',
  'ghana': 'ghana',
  'belgique': 'belgique',
  'pays-bas': 'pays-bas',
  'russie': 'russie',
  'ukraine': 'ukraine',
  'uruguay': 'uruguay',
  'colombie': 'colombie',
  'chili': 'chili',
  'grèce': 'grece',
  'grece': 'grece',
  'norvège': 'norvege',
  'norvege': 'norvege',
  'tunisie': 'tunisie',
  // ISO code files
  // Named files (added/renamed)
  'bosnie-herzégovine': 'bosnie',
  'bosnie-herzegovine': 'bosnie',
  'bosnie': 'bosnie',
  'burkina faso': 'burkina faso',
  'irlande': 'irlande',
  'autriche': 'autriche',
  'albanie': 'albanie',
  'arménie': 'armenie',
  'armenie': 'armenie',
  'australie': 'australie',
  'gabon': 'gabon',
  // ISO code files (not yet renamed)
  'danemark': 'dk',
  'suisse': 'ch',
  'togo': 'tg',
  'écosse': 'gb-sct',
  'ecosse': 'gb-sct',
  'pays de galles': 'gb-wls',
  'croatie': 'hr',
  'serbie': 'rs',
  'pologne': 'pl',
  'turquie': 'tr',
  'suède': 'se',
  'suede': 'se',
  'finlande': 'fi',
  'roumanie': 'ro',
  'hongrie': 'hu',
  'slovaquie': 'sk',
  'slovénie': 'si',
  'slovenie': 'si',
  'tchéquie': 'cz',
  'tcheque': 'cz',
  'émirats arabes unis': 'ae',
  'arabie saoudite': 'sa',
  'japon': 'jp',
  'corée du sud': 'kr',
  'mali': 'ml',
  'guinée': 'gn',
  'guinee': 'gn',
  'nigeria': 'ng',
  'angola': 'ao',
  'mozambique': 'mz',
  'zambie': 'zm',
  'kenya': 'ke',
  'tanzanie': 'tz',
  'afrique du sud': 'za',
  'venezuela': 've',
  'pérou': 'pe',
  'peru': 'pe',
  'équateur': 'ec',
  'equateur': 'ec',
  'paraguai': 'py',
  'paraguay': 'py',
  'bolivie': 'bo',
  'mexique': 'mx',
  'états-unis': 'us',
  'etats-unis': 'us',
  'canada': 'ca',
  'qatar': 'qa',
};

String? _resolveFlag(String teamName) {
  final key = removeDiacritics(teamName.toLowerCase().trim());
  // Try with diacritics first, then normalized
  final hit = _kFlagMap[teamName.toLowerCase().trim()] ?? _kFlagMap[key];
  if (hit == null) return null;
  return 'assets/logos/pays/$hit.png';
}

/// Displays a country flag for a national team row.
/// Falls back to a generic globe icon if the country is not mapped.
class NatFlag extends StatelessWidget {
  final String teamName;
  final double size;

  const NatFlag({super.key, required this.teamName, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final path = _resolveFlag(teamName);
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          path,
          width: size,
          height: size * 0.67,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _GlobeIcon(size: size),
        ),
      );
    }
    return _GlobeIcon(size: size);
  }
}

class _GlobeIcon extends StatelessWidget {
  final double size;
  const _GlobeIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.67,
      child: Icon(Icons.public_rounded, size: size * 0.7, color: const Color(0xFF5B8C7A)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// A square logo (or monogram fallback) of the given [size].
/// Visually uniform whether a logo exists or not — keeps career lists clean.
class ClubLogo extends StatelessWidget {
  final String clubName;
  final double size;

  const ClubLogo({super.key, required this.clubName, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final path = ClubLogoIndex.instance.resolve(clubName);
    if (path != null) {
      return Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _Monogram(clubName: clubName, size: size),
      );
    }
    return _Monogram(clubName: clubName, size: size);
  }
}

class _Monogram extends StatelessWidget {
  final String clubName;
  final double size;

  const _Monogram({required this.clubName, required this.size});

  // Deterministic muted color from the club name so monograms aren't all
  // identical but stay calm/neutral (no clash with the accent palette).
  Color get _tint {
    const palette = [
      Color(0xFF5B6B8C),
      Color(0xFF6B5B8C),
      Color(0xFF5B8C7A),
      Color(0xFF8C7A5B),
      Color(0xFF8C5B6B),
      Color(0xFF5B7A8C),
    ];
    var h = 0;
    for (final c in clubName.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }

  String get _initials {
    final words = clubName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return (words.first.substring(0, 1) + words[1].substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = _tint;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.45), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: c,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
