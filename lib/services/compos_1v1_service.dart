import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/compos_1v1_game.dart';

class MultiplayerService {
  MultiplayerService._();
  static final MultiplayerService instance = MultiplayerService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference get _games => _db.collection('games');

  static const int _maxErrors = 3;
  static const int _timerSeconds = 60;

  // ── Room code ─────────────────────────────────────────────────────────────

  static String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Create / Join ──────────────────────────────────────────────────────────

  Future<String> createRoom({
    required String pseudo,
    required String matchId,
    required String difficulty,
  }) async {
    final code = generateRoomCode();
    await _games.doc(code).set({
      'status': GameStatus.waiting.name,
      'matchId': matchId,
      'difficulty': difficulty,
      'currentTurn': '',
      'turnStartedAt': null,
      'timerSeconds': _timerSeconds,
      'suffocatedBy': null,
      'playerOrder': [pseudo],
      'players': {
        pseudo: MultiplayerPlayer().toMap(),
      },
      'foundPlayers': [],
      'winner': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<void> joinRoom({required String code, required String pseudo}) async {
    final ref = _games.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Room introuvable');
      final game = MultiplayerGame.fromDoc(snap);
      if (game.status != GameStatus.waiting) throw Exception('Partie déjà commencée');
      if (game.playerOrder.length >= 2) throw Exception('Room pleine');
      if (game.playerOrder.contains(pseudo)) throw Exception('Pseudo déjà pris dans cette room');

      final order = [...game.playerOrder, pseudo];
      final players = {
        ...game.players.map((k, v) => MapEntry(k, v.toMap())),
        pseudo: MultiplayerPlayer().toMap(),
      };

      tx.update(ref, {
        'playerOrder': order,
        'players': players,
        'status': GameStatus.playing.name,
        'currentTurn': order[Random().nextInt(2)],
        'turnStartedAt': null,
      });
    });
  }

  // ── Start first turn ──────────────────────────────────────────────────────

  Future<void> startFirstTurn(String code) async {
    final ref = _games.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final game = MultiplayerGame.fromDoc(snap);
      if (game.turnStartedAt != null) return;
      tx.update(ref, {'turnStartedAt': FieldValue.serverTimestamp()});
    });
  }

  // ── Listeners ─────────────────────────────────────────────────────────────

  Stream<MultiplayerGame?> watchGame(String code) =>
      _games.doc(code).snapshots().map((s) => s.exists ? MultiplayerGame.fromDoc(s) : null);

  Future<void> abandonRoom({required String code, required String pseudo}) async {
    try {
      await _games.doc(code).update({
        'status': GameStatus.finished.name,
        'winner': null,
        'abandoned': true,
        'abandonedBy': pseudo,
      });
    } catch (_) {}
  }

  // ── Turn actions ──────────────────────────────────────────────────────────

  Future<void> submitMultipleCorrectAnswers({
    required String code,
    required String pseudo,
    required List<String> playerNames,
  }) async {
    final ref = _games.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final game = MultiplayerGame.fromDoc(snap);
      if (game.currentTurn != pseudo) return;

      final opponent = game.opponentOf;
      final opponentData = game.players[opponent]!;
      // All revealed with foundBy: pseudo for proper attribution.
      // Extras (beyond the first) increment bonusCounts so they don't count as points.
      final found = [
        ...game.foundPlayers.map((f) => f.toMap()),
        ...playerNames.map((n) => FoundPlayer(name: n, foundBy: pseudo).toMap()),
      ];
      final extraCount = playerNames.length - 1;
      final updatedBonusCounts = {
        ...game.bonusCounts,
        pseudo: (game.bonusCounts[pseudo] ?? 0) + extraCount,
      };

      tx.update(ref, {
        'foundPlayers': found,
        'bonusCounts': updatedBonusCounts,
        'currentTurn': opponent,
        'turnStartedAt': FieldValue.serverTimestamp(),
        'suffocatedBy': null,
        'pendingFinalTurn': false,
      });

      if (game.pendingFinalTurn) {
        // Ce joueur vient de trouver pendant son tour final → il gagne
        tx.update(ref, {'status': GameStatus.finished.name, 'winner': pseudo});
      } else if (opponentData.eliminated) {
        tx.update(ref, {'status': GameStatus.finished.name, 'winner': pseudo});
      }
    });
  }

  Future<void> submitCorrectAnswer({
    required String code,
    required String pseudo,
    required String playerName,
  }) async {
    final ref = _games.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final game = MultiplayerGame.fromDoc(snap);
      if (game.currentTurn != pseudo) return;

      final opponent = game.opponentOf;
      final opponentData = game.players[opponent]!;
      final found = [...game.foundPlayers.map((f) => f.toMap()), FoundPlayer(name: playerName, foundBy: pseudo).toMap()];

      tx.update(ref, {
        'foundPlayers': found,
        'currentTurn': opponent,
        'turnStartedAt': FieldValue.serverTimestamp(),
        'suffocatedBy': null,
        'pendingFinalTurn': false,
      });

      if (game.pendingFinalTurn) {
        tx.update(ref, {'status': GameStatus.finished.name, 'winner': pseudo});
      } else if (opponentData.eliminated) {
        tx.update(ref, {'status': GameStatus.finished.name, 'winner': pseudo});
      }
    });
  }

  Future<void> submitError({
    required String code,
    required String pseudo,
    String? errorType,
  }) async {
    final ref = _games.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final game = MultiplayerGame.fromDoc(snap);
      if (game.currentTurn != pseudo) return;

      final player = game.players[pseudo]!;
      final newErrors = player.errors + 1;
      final eliminated = newErrors >= _maxErrors;
      final opponent = game.opponentOf;

      final updatedPlayers = {
        ...game.players.map((k, v) => MapEntry(k, v.toMap())),
        pseudo: player.copyWith(errors: newErrors, eliminated: eliminated).toMap(),
      };

      if (game.pendingFinalTurn) {
        // Erreur pendant le tour final → match nul
        tx.update(ref, {
          'players': updatedPlayers,
          'status': GameStatus.finished.name,
          'winner': '__draw__',
          'suffocatedBy': null,
          'lastErrorType': errorType,
        });
      } else if (eliminated) {
        final elimFoundCount = game.foundPlayers.where((f) => f.foundBy == pseudo).length - (game.bonusCounts[pseudo] ?? 0);
        final oppFoundCount  = game.foundPlayers.where((f) => f.foundBy == opponent).length - (game.bonusCounts[opponent] ?? 0);

        if (oppFoundCount > elimFoundCount) {
          // Adversaire déjà devant → victoire normale
          tx.update(ref, {
            'players': updatedPlayers,
            'status': GameStatus.finished.name,
            'winner': opponent,
            'suffocatedBy': null,
            'lastErrorType': errorType,
          });
        } else {
          // Égalité ou éliminé devant → tour final pour l'adversaire
          tx.update(ref, {
            'players': updatedPlayers,
            'currentTurn': opponent,
            'turnStartedAt': FieldValue.serverTimestamp(),
            'pendingFinalTurn': true,
            'suffocatedBy': null,
            'lastErrorType': errorType,
          });
        }
      } else {
        tx.update(ref, {
          'players': updatedPlayers,
          'currentTurn': opponent,
          'turnStartedAt': FieldValue.serverTimestamp(),
          'suffocatedBy': null,
          'lastErrorType': errorType,
        });
      }
    });
  }

  // ── Suffocation ───────────────────────────────────────────────────────────

  Future<void> activateSuffocation({
    required String code,
    required String pseudo,
  }) async {
    final ref = _games.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final game = MultiplayerGame.fromDoc(snap);

      if (game.currentTurn == pseudo) return; // C'est ton tour, tu ne peux pas suffocater
      if (game.suffocatedBy != null) return;  // Déjà actif

      final player = game.players[pseudo]!;
      if (player.suffocationsLeft <= 0) return;

      final updatedPlayers = {
        ...game.players.map((k, v) => MapEntry(k, v.toMap())),
        pseudo: player.copyWith(suffocationsLeft: player.suffocationsLeft - 1).toMap(),
      };

      tx.update(ref, {
        'players': updatedPlayers,
        'suffocatedBy': pseudo,
        'turnStartedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ── Force opponent timeout (waiting player rescues stuck game) ────────────

  Future<void> forceOpponentTimeout({
    required String code,
    required String waitingPseudo,
  }) async {
    final ref = _games.doc(code);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final game = MultiplayerGame.fromDoc(snap);
        if (game.status != GameStatus.playing) return;
        if (game.currentTurn == waitingPseudo) return; // turn already ours
        // Server-side confirmation the timer is truly expired
        final started = game.turnStartedAt;
        if (started != null) {
          final deadline = started.add(Duration(seconds: game.effectiveTimerSeconds + 3));
          if (DateTime.now().isBefore(deadline)) return;
        }

        final activePseudo = game.currentTurn;
        final player = game.players[activePseudo];
        if (player == null) return;

        final newErrors = player.errors + 1;
        final eliminated = newErrors >= _maxErrors;
        final updatedPlayers = {
          ...game.players.map((k, v) => MapEntry(k, v.toMap())),
          activePseudo: player.copyWith(errors: newErrors, eliminated: eliminated).toMap(),
        };

        if (game.pendingFinalTurn) {
          // Timer expiré pendant le tour final → match nul
          tx.update(ref, {
            'players': updatedPlayers,
            'status': GameStatus.finished.name,
            'winner': '__draw__',
            'suffocatedBy': null,
          });
        } else if (eliminated) {
          final elimFoundCount = game.foundPlayers.where((f) => f.foundBy == activePseudo).length - (game.bonusCounts[activePseudo] ?? 0);
          final oppFoundCount  = game.foundPlayers.where((f) => f.foundBy == waitingPseudo).length - (game.bonusCounts[waitingPseudo] ?? 0);

          if (oppFoundCount > elimFoundCount) {
            tx.update(ref, {
              'players': updatedPlayers,
              'status': GameStatus.finished.name,
              'winner': waitingPseudo,
              'suffocatedBy': null,
            });
          } else {
            tx.update(ref, {
              'players': updatedPlayers,
              'currentTurn': waitingPseudo,
              'turnStartedAt': FieldValue.serverTimestamp(),
              'pendingFinalTurn': true,
              'suffocatedBy': null,
            });
          }
        } else {
          tx.update(ref, {
            'players': updatedPlayers,
            'currentTurn': waitingPseudo,
            'turnStartedAt': FieldValue.serverTimestamp(),
            'suffocatedBy': null,
          });
        }
      });
    } catch (_) {}
  }

  // ── Hints ─────────────────────────────────────────────────────────────────

  Future<void> recordHintUsed({required String code, required String pseudo}) async {
    final ref = _games.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final game = MultiplayerGame.fromDoc(snap);
      final player = game.players[pseudo];
      if (player == null) return;
      final updatedPlayers = {
        ...game.players.map((k, v) => MapEntry(k, v.toMap())),
        pseudo: player.copyWith(hintsUsed: player.hintsUsed + 1).toMap(),
      };
      tx.update(ref, {'players': updatedPlayers});
    });
  }

  // ── Rematch ───────────────────────────────────────────────────────────────

  Future<void> requestRematch({required String code, required String pseudo}) async {
    try {
      await _games.doc(code).update({'rematch.$pseudo': true});
    } catch (_) {}
  }

  Future<void> writeRematchRoom({
    required String oldCode,
    required String newCode,
    required String newMatchId,
  }) async {
    try {
      await _games.doc(oldCode).update({
        'rematchCode': newCode,
        'rematchMatchId': newMatchId,
      });
    } catch (_) {}
  }

  // ── Heartbeat ─────────────────────────────────────────────────────────────

  Future<void> pingHeartbeat({required String code, required String pseudo}) async {
    try {
      await _games.doc(code).update({'heartbeat.$pseudo': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  // ── Preview ───────────────────────────────────────────────────────────────

  Future<void> markPreviewReady({required String code, required String pseudo}) async {
    try {
      await _games.doc(code).update({
        'previewReady': FieldValue.arrayUnion([pseudo]),
      });
    } catch (_) {}
  }

  Future<void> requestChangeMatch({required String code, required String pseudo}) async {
    try {
      await _games.doc(code).update({
        'previewChangeRequest': pseudo,
        'previewReady': [],
      });
    } catch (_) {}
  }

  Future<void> acceptChangeMatch({
    required String code,
    required String newMatchId,
  }) async {
    try {
      await _games.doc(code).update({
        'matchId': newMatchId,
        'previewChangeRequest': null,
        'previewReady': [],
      });
    } catch (_) {}
  }

  Future<void> refuseChangeMatch({required String code}) async {
    try {
      await _games.doc(code).update({'previewChangeRequest': null});
    } catch (_) {}
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> deleteRoom(String code) => _games.doc(code).delete();
}
