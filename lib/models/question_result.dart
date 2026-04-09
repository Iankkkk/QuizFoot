// question_result.dart
//
// Immutable data class that records the outcome of a single quiz question.
// A list of [QuestionResult] is built during the game and handed off
// to [QuizScorePage] so the per-question breakdown can be displayed.

/// Outcome of a single Coup d'œil question.
class QuestionResult {
  /// The player's canonical display name (name field from the database).
  final String playerName;

  /// Whether the user answered correctly.
  final bool correct;

  /// Whether the user typed at least one wrong answer before skipping.
  ///
  /// Distinction matters on the score page:
  /// - [correct] = true  → ✅ green
  /// - [attempted] = true, [correct] = false → ❌ red  (tried and failed)
  /// - [attempted] = false, [correct] = false → ⏩ grey (skipped without trying)
  final bool attempted;

  /// Points earned for this question. Always 0 when [correct] is false.
  final int points;

  const QuestionResult({
    required this.playerName,
    required this.correct,
    required this.attempted,
    required this.points,
  });
}
