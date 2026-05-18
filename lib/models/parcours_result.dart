// parcours_result.dart
//
// One player's outcome in a "Parcours Joueur" game, used by the score page.

class ParcoursResult {
  final String playerName;

  /// Player was correctly guessed.
  final bool found;

  /// A wrong answer was typed (true) vs. the player was skipped (false).
  /// Only meaningful when [found] is false.
  final bool attempted;

  /// Points earned for this player (0 if not found).
  final int points;

  /// Number of hints unlocked for this player (0–3).
  final int hintsUsed;

  const ParcoursResult({
    required this.playerName,
    required this.found,
    required this.attempted,
    required this.points,
    required this.hintsUsed,
  });
}
