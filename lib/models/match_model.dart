class Match {
  final String matchId;
  final String matchName;
  final String competition;
  final String date;
  final String homeTeam;
  final String awayTeam;
  final String formationHome;
  final String formationAway;
  final int level;
  final String colorHome;
  final String? colorHome2;
  final String colorAway;
  final String? colorAway2;

  Match({
    required this.matchId,
    required this.matchName,
    required this.competition,
    required this.date,
    required this.homeTeam,
    required this.awayTeam,
    required this.formationHome,
    required this.formationAway,
    required this.level,
    this.colorHome = '',
    this.colorHome2,
    this.colorAway = '',
    this.colorAway2,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    String? _nullIfEmpty(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return Match(
      matchId:       json['match_id'] as String,
      matchName:     json['match_name'] as String,
      competition:   json['competition'] as String,
      date:          json['date'] as String,
      homeTeam:      json['home_team'] as String,
      awayTeam:      json['away_team'] as String,
      formationHome: json['formation_home'] as String,
      formationAway: json['formation_away'] as String,
      level:         int.tryParse(json['level'].toString()) ?? 1,
      colorHome:     _nullIfEmpty(json['color_home'])  ?? '',
      colorHome2:    _nullIfEmpty(json['color_home2']),
      colorAway:     _nullIfEmpty(json['color_away'])  ?? '',
      colorAway2:    _nullIfEmpty(json['color_away2']),
    );
  }
}
