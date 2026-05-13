enum GameType { coupDoeil, compos, multiplayerCompos, multiplayerCoupDoeil, quiAMenti }

class GameResult {
  final String id;
  final GameType gameType;
  final String difficulty;
  final int rawScore;
  final int maxRawScore;
  final double normalizedScore;
  final Duration timeTaken;
  final DateTime playedAt;
  final Map<String, dynamic> details;

  const GameResult({
    required this.id,
    required this.gameType,
    required this.difficulty,
    required this.rawScore,
    required this.maxRawScore,
    required this.normalizedScore,
    required this.timeTaken,
    required this.playedAt,
    required this.details,
  });

  static double difficultyMultiplier(String difficulty) {
    switch (difficulty) {
      case 'Amateur': return 0.6;
      case 'Semi-Pro':      return 0.8;
      case 'Pro':     return 1.0;
      case 'International':   return 1.3;
      case 'Légende':  return 1.7;
      default:            return 1.0;
    }
  }

  factory GameResult.coupDoeil({
    required String difficulty,
    required int score,
    required int total,
    required int correct,
    required int wrong,
    required int skipped,
    required Duration timeTaken,
    String? category,
    List<Map<String, String>> errors = const [],
  }) {
    final maxRaw = total * 5;
    return GameResult(
      id:              DateTime.now().microsecondsSinceEpoch.toString(),
      gameType:        GameType.coupDoeil,
      difficulty:      difficulty,
      rawScore:        score,
      maxRawScore:     maxRaw,
      normalizedScore: score.toDouble(),
      timeTaken:       timeTaken,
      playedAt:        DateTime.now(),
      details: {
        'total':    total,
        'correct':  correct,
        'wrong':    wrong,
        'skipped':  skipped,
        if (category != null) 'category': category,
        if (errors.isNotEmpty) 'errors': errors,
      },
    );
  }

  factory GameResult.compos({
    required String difficulty,
    required String matchId,
    required String matchName,
    required int found,
    required int total,
    required int errors,
    required int hintsUsed,
    required List<String> wrongAnswers,
    required List<String> foundPlayers,
    required bool defeat,
    required Duration timeTaken,
  }) {
    final score = total > 0 ? (found / total * 100).round() : 0;
    return GameResult(
      id:              DateTime.now().microsecondsSinceEpoch.toString(),
      gameType:        GameType.compos,
      difficulty:      difficulty,
      rawScore:        score,
      maxRawScore:     100,
      normalizedScore: score.toDouble(),
      timeTaken:       timeTaken,
      playedAt:        DateTime.now(),
      details: {
        'matchId':      matchId,
        'matchName':    matchName,
        'found':        found,
        'total':        total,
        'errors':       errors,
        'hintsUsed':    hintsUsed,
        'wrongAnswers':  wrongAnswers,
        'foundPlayers':  foundPlayers,
        'defeat':        defeat,
      },
    );
  }

  factory GameResult.multiplayerCompos({
    required String difficulty,
    required String matchId,
    required String matchName,
    required String opponentPseudo,
    required bool won,
    required bool abandoned,
    required int foundByMe,
    required int foundByOpponent,
    required int totalPlayers,
    required int myErrors,
    required Duration timeTaken,
  }) {
    final score = totalPlayers > 0 ? (foundByMe / totalPlayers * 100).round() : 0;
    return GameResult(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      gameType: GameType.multiplayerCompos,
      difficulty: difficulty,
      rawScore: score,
      maxRawScore: 100,
      normalizedScore: score.toDouble(),
      timeTaken: timeTaken,
      playedAt: DateTime.now(),
      details: {
        'matchId': matchId,
        'matchName': matchName,
        'opponentPseudo': opponentPseudo,
        'won': won,
        'abandoned': abandoned,
        'foundByMe': foundByMe,
        'foundByOpponent': foundByOpponent,
        'totalPlayers': totalPlayers,
        'myErrors': myErrors,
      },
    );
  }

  factory GameResult.multiplayerCoupDoeil({
    required String difficulty,
    String? category,
    required String opponentPseudo,
    required int myScore,
    required int opponentScore,
    required int myCorrect,
    required int opponentCorrect,
    required int total,
    required bool won,
    required bool draw,
    required bool abandoned,
    required bool iAbandoned,
  }) {
    return GameResult(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      gameType: GameType.multiplayerCoupDoeil,
      difficulty: difficulty,
      rawScore: myScore,
      maxRawScore: total * 5,
      normalizedScore: myScore.toDouble(),
      timeTaken: Duration.zero,
      playedAt: DateTime.now(),
      details: {
        'opponentPseudo': opponentPseudo,
        'myScore': myScore,
        'opponentScore': opponentScore,
        'myCorrect': myCorrect,
        'opponentCorrect': opponentCorrect,
        'total': total,
        'won': won,
        'draw': draw,
        'abandoned': abandoned,
        'iAbandoned': iAbandoned,
        if (category != null) 'category': category,
      },
    );
  }

  factory GameResult.quiAMenti({
    required int points,
    required int correctCount,
    required int validationsUsed,
    required bool timedOut,
    required Duration timeTaken,
  }) {
    return GameResult(
      id:              DateTime.now().microsecondsSinceEpoch.toString(),
      gameType:        GameType.quiAMenti,
      difficulty:      'Standard',
      rawScore:        points,
      maxRawScore:     50,
      normalizedScore: points.toDouble(),
      timeTaken:       timeTaken,
      playedAt:        DateTime.now(),
      details: {
        'correctCount':     correctCount,
        'validationsUsed':  validationsUsed,
        'timedOut':         timedOut,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'id':              id,
    'gameType':        gameType.name,
    'difficulty':      difficulty,
    'rawScore':        rawScore,
    'maxRawScore':     maxRawScore,
    'normalizedScore': normalizedScore,
    'timeTakenMs':     timeTaken.inMilliseconds,
    'playedAt':        playedAt.toIso8601String(),
    'details':         details,
  };

  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
    id:              json['id'] as String,
    gameType:        GameType.values.firstWhere((e) => e.name == json['gameType']),
    difficulty:      json['difficulty'] as String,
    rawScore:        json['rawScore'] as int,
    maxRawScore:     json['maxRawScore'] as int,
    normalizedScore: (json['normalizedScore'] as num).toDouble(),
    timeTaken:       Duration(milliseconds: json['timeTakenMs'] as int),
    playedAt:        DateTime.parse(json['playedAt'] as String),
    details:         Map<String, dynamic>.from(json['details'] as Map),
  );
}
