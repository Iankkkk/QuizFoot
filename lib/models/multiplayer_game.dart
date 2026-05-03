import 'package:cloud_firestore/cloud_firestore.dart';

class MultiplayerPlayer {
  final int errors;
  final bool eliminated;
  final int suffocationsLeft;
  final int hintsUsed;

  const MultiplayerPlayer({
    this.errors = 0,
    this.eliminated = false,
    this.suffocationsLeft = 2,
    this.hintsUsed = 0,
  });

  factory MultiplayerPlayer.fromMap(Map<String, dynamic> m) => MultiplayerPlayer(
        errors: (m['errors'] as num?)?.toInt() ?? 0,
        eliminated: m['eliminated'] as bool? ?? false,
        suffocationsLeft: (m['suffocationsLeft'] as num?)?.toInt() ?? 2,
        hintsUsed: (m['hintsUsed'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'errors': errors,
        'eliminated': eliminated,
        'suffocationsLeft': suffocationsLeft,
        'hintsUsed': hintsUsed,
      };

  MultiplayerPlayer copyWith({int? errors, bool? eliminated, int? suffocationsLeft, int? hintsUsed}) =>
      MultiplayerPlayer(
        errors: errors ?? this.errors,
        eliminated: eliminated ?? this.eliminated,
        suffocationsLeft: suffocationsLeft ?? this.suffocationsLeft,
        hintsUsed: hintsUsed ?? this.hintsUsed,
      );
}

class FoundPlayer {
  final String name;
  final String foundBy;

  const FoundPlayer({required this.name, required this.foundBy});

  factory FoundPlayer.fromMap(Map<String, dynamic> m) =>
      FoundPlayer(name: m['name'] as String, foundBy: m['foundBy'] as String);

  Map<String, dynamic> toMap() => {'name': name, 'foundBy': foundBy};
}

enum GameStatus { waiting, playing, finished }

class MultiplayerGame {
  final String roomCode;
  final GameStatus status;
  final String matchId;
  final String difficulty;
  final String currentTurn;
  final DateTime? turnStartedAt;
  final int timerSeconds;
  final String? suffocatedBy;
  final List<String> playerOrder;
  final Map<String, MultiplayerPlayer> players;
  final List<FoundPlayer> foundPlayers;
  final String? winner;
  final bool abandoned;
  final String? abandonedBy;
  final DateTime createdAt;
  final bool pendingFinalTurn;

  const MultiplayerGame({
    required this.roomCode,
    required this.status,
    required this.matchId,
    required this.difficulty,
    required this.currentTurn,
    this.turnStartedAt,
    this.timerSeconds = 60,
    this.suffocatedBy,
    required this.playerOrder,
    required this.players,
    required this.foundPlayers,
    this.winner,
    this.abandoned = false,
    this.abandonedBy,
    required this.createdAt,
    this.pendingFinalTurn = false,
  });

  factory MultiplayerGame.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MultiplayerGame(
      roomCode: doc.id,
      status: GameStatus.values.firstWhere(
        (e) => e.name == (d['status'] as String),
        orElse: () => GameStatus.waiting,
      ),
      matchId: d['matchId'] as String,
      difficulty: d['difficulty'] as String,
      currentTurn: d['currentTurn'] as String? ?? '',
      turnStartedAt: (d['turnStartedAt'] as Timestamp?)?.toDate(),
      timerSeconds: (d['timerSeconds'] as num?)?.toInt() ?? 60,
      suffocatedBy: d['suffocatedBy'] as String?,
      playerOrder: List<String>.from(d['playerOrder'] as List),
      players: (d['players'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, MultiplayerPlayer.fromMap(Map<String, dynamic>.from(v as Map))),
      ),
      foundPlayers: (d['foundPlayers'] as List? ?? [])
          .map((e) => FoundPlayer.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      winner: d['winner'] as String?,
      abandoned: d['abandoned'] as bool? ?? false,
      abandonedBy: d['abandonedBy'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pendingFinalTurn: d['pendingFinalTurn'] as bool? ?? false,
    );
  }

  String get opponentOf => playerOrder.firstWhere((p) => p != currentTurn, orElse: () => '');

  int get effectiveTimerSeconds => suffocatedBy != null ? 10 : timerSeconds;
}
