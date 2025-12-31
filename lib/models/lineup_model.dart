class Lineup {
  final String matchId;
  final String teamName;
  final int playerNumber;
  final String playerName;
  final String position;
  final bool starter;

  Lineup({
    required this.matchId,
    required this.teamName,
    required this.playerNumber,
    required this.playerName,
    required this.position,
    required this.starter,
  });

  factory Lineup.fromJson(Map<String, dynamic> json) {
    return Lineup(
      matchId: json['match_id'] as String,
      teamName: json['team_name'] as String,
      playerNumber: int.tryParse(json['player_number'].toString()) ?? 0,
      playerName: json['player_name'] as String,
      position: json['position'] as String,
      starter: (json['starter'].toString().toLowerCase() == 'true'),
    );
  }
}
