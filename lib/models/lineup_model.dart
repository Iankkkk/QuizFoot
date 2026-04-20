class Lineup {
  final String matchId;
  final String teamName;
  final int playerNumber;
  final String playerName;
  final String? playerName2;
  final String? playerName3;
  final String position;
  final bool starter;

  Lineup({
    required this.matchId,
    required this.teamName,
    required this.playerNumber,
    required this.playerName,
    this.playerName2,
    this.playerName3,
    required this.position,
    required this.starter,
  });

  /// All accepted name variants for answer-matching (main + aliases).
  /// Filters out null / empty values.
  List<String> get allNames => [
    playerName,
    if (playerName2 != null && playerName2!.trim().isNotEmpty) playerName2!,
    if (playerName3 != null && playerName3!.trim().isNotEmpty) playerName3!,
  ];

  factory Lineup.fromJson(Map<String, dynamic> json) {
    String? readOptional(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return Lineup(
      matchId: json['match_id'] as String,
      teamName: json['team_name'] as String,
      playerNumber: int.tryParse(json['player_number'].toString()) ?? 0,
      playerName: json['player_name'] as String,
      playerName2: readOptional('player_name2'),
      playerName3: readOptional('player_name3'),
      position: json['position'] as String,
      starter: (json['starter'].toString().toLowerCase() == 'true'),
    );
  }
}
