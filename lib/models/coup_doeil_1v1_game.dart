import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Per-question result stored after the game
// ─────────────────────────────────────────────────────────────────────────────

class CdoQuestionResult {
  final String playerName;
  final bool correct;
  final int points;
  final bool attempted; // false = skipped or auto-timed-out

  const CdoQuestionResult({
    required this.playerName,
    required this.correct,
    required this.points,
    required this.attempted,
  });

  factory CdoQuestionResult.fromMap(Map<String, dynamic> m) => CdoQuestionResult(
        playerName: m['playerName'] as String? ?? '',
        correct: m['correct'] as bool? ?? false,
        points: (m['points'] as num?)?.toInt() ?? 0,
        attempted: m['attempted'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'playerName': playerName,
        'correct': correct,
        'points': points,
        'attempted': attempted,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-player state
// ─────────────────────────────────────────────────────────────────────────────

class CdoPlayer {
  final int score;
  final bool finished;
  final List<CdoQuestionResult> results;

  const CdoPlayer({
    this.score = 0,
    this.finished = false,
    this.results = const [],
  });

  factory CdoPlayer.fromMap(Map<String, dynamic> m) => CdoPlayer(
        score: (m['score'] as num?)?.toInt() ?? 0,
        finished: m['finished'] as bool? ?? false,
        results: (m['results'] as List? ?? [])
            .map((e) => CdoQuestionResult.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'score': score,
        'finished': finished,
        'results': results.map((r) => r.toMap()).toList(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Game document
// ─────────────────────────────────────────────────────────────────────────────

enum CdoGameStatus { waiting, playing, finished }

class CoupDoeil1v1Game {
  final String roomCode;
  final CdoGameStatus status;
  final String difficulty;
  final String? category;
  final List<String> playerOrder;
  final List<String> questionNames; // primary name of each player, in order
  final Map<String, CdoPlayer> players;
  final String? winner; // pseudo | '__draw__' | null
  final bool abandoned;
  final String? abandonedBy;
  final DateTime createdAt;

  const CoupDoeil1v1Game({
    required this.roomCode,
    required this.status,
    required this.difficulty,
    this.category,
    required this.playerOrder,
    required this.questionNames,
    required this.players,
    this.winner,
    this.abandoned = false,
    this.abandonedBy,
    required this.createdAt,
  });

  factory CoupDoeil1v1Game.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CoupDoeil1v1Game(
      roomCode: doc.id,
      status: CdoGameStatus.values.firstWhere(
        (e) => e.name == (d['status'] as String? ?? ''),
        orElse: () => CdoGameStatus.waiting,
      ),
      difficulty: d['difficulty'] as String? ?? '',
      category: d['category'] as String?,
      playerOrder: List<String>.from(d['playerOrder'] as List? ?? []),
      questionNames: List<String>.from(d['questionNames'] as List? ?? []),
      players: ((d['players'] as Map<String, dynamic>?) ?? {}).map(
        (k, v) => MapEntry(k, CdoPlayer.fromMap(Map<String, dynamic>.from(v as Map))),
      ),
      winner: d['winner'] as String?,
      abandoned: d['abandoned'] as bool? ?? false,
      abandonedBy: d['abandonedBy'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String opponentOf(String pseudo) =>
      playerOrder.firstWhere((p) => p != pseudo, orElse: () => '');
}
