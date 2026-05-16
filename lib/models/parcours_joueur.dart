// parcours_joueur.dart
//
// Models for the "Parcours Joueur" game.
// Data comes from two SheetDB sheets joined by `id`:
//   • ParcoursJoueur         → 1 row per player (meta)
//   • ParcoursJoueurDETAILS  → N rows per player (career, ordered by `seq`)

/// One career line: a club spell or a senior national-team spell.
class CareerEntry {
  /// Chronological order within the player's career (1, 2, 3…).
  final int seq;

  /// 'club' or 'nat'.
  final String type;

  /// Verbatim string from Wikipedia: "2020", "2020-", "2021-2022".
  final String years;

  /// Club or country name (raw Wikipedia FR, not normalized yet).
  final String team;

  /// True when this spell is a loan (Wikipedia "→" arrow). Always false for nat.
  final bool loan;

  /// Matches played. Null when unknown (blank cell) — distinct from 0.
  final int? matches;

  /// Goals scored. Null when unknown (blank cell) — distinct from 0.
  final int? goals;

  CareerEntry({
    required this.seq,
    required this.type,
    required this.years,
    required this.team,
    required this.loan,
    required this.matches,
    required this.goals,
  });

  bool get isClub => type == 'club';
  bool get isNational => type == 'nat';

  factory CareerEntry.fromJson(Map<String, dynamic> json) {
    final rawMatches = json['matches']?.toString().trim() ?? '';
    final rawGoals = json['goals']?.toString().trim() ?? '';
    final rawLoan = (json['loan'] ?? '').toString().trim().toLowerCase();

    return CareerEntry(
      seq: int.tryParse(json['seq']?.toString() ?? '') ?? 0,
      type: (json['type'] ?? 'club').toString().trim().toLowerCase(),
      years: (json['years'] ?? '').toString().trim(),
      team: (json['team'] ?? '').toString().trim(),
      loan: rawLoan == 'true',
      matches: rawMatches.isEmpty ? null : int.tryParse(rawMatches),
      goals: rawGoals.isEmpty ? null : int.tryParse(rawGoals),
    );
  }
}

/// A player: the answer + the career to display, plus hint data
/// (nationality / age / position).
class ParcoursPlayer {
  final int id;
  final String name;

  /// Difficulty 1–10 (Coup d'Œil scale). Null = not yet rated → excluded by game.
  final int? level;

  final String nationality;

  /// Birth year (age is computed at display time, never stored).
  final int? birthYear;

  final String position;

  /// Wikipedia source — admin/traceability only, not shown in game.
  final String sourceUrl;

  /// Full career, ordered by [CareerEntry.seq].
  final List<CareerEntry> career;

  ParcoursPlayer({
    required this.id,
    required this.name,
    required this.level,
    required this.nationality,
    required this.birthYear,
    required this.position,
    required this.sourceUrl,
    required this.career,
  });

  /// Age computed from birth year (null if birth year missing).
  int? get age =>
      birthYear == null ? null : DateTime.now().year - birthYear!;

  /// Club spells only, in career order.
  List<CareerEntry> get clubs =>
      career.where((e) => e.isClub).toList();

  /// Senior national-team spells only, in career order.
  List<CareerEntry> get nationalTeam =>
      career.where((e) => e.isNational).toList();

  factory ParcoursPlayer.fromJson(
    Map<String, dynamic> json,
    List<CareerEntry> career,
  ) {
    final rawLevel = json['level']?.toString().trim() ?? '';
    final rawYear = json['birth_year']?.toString().trim() ?? '';

    return ParcoursPlayer(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString().trim(),
      level: rawLevel.isEmpty ? null : int.tryParse(rawLevel),
      nationality: (json['nationality'] ?? '').toString().trim(),
      birthYear: rawYear.isEmpty ? null : int.tryParse(rawYear),
      position: (json['position'] ?? '').toString().trim(),
      sourceUrl: (json['source_url'] ?? '').toString().trim(),
      career: career,
    );
  }
}
