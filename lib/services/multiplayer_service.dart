import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/multiplayer_game.dart';

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
      });

      // Si l'adversaire est éliminé, la partie est finie
      if (opponentData.eliminated) {
        tx.update(ref, {'status': GameStatus.finished.name, 'winner': pseudo});
      }
    });
  }

  Future<void> submitError({
    required String code,
    required String pseudo,
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

      if (eliminated) {
        tx.update(ref, {
          'players': updatedPlayers,
          'status': GameStatus.finished.name,
          'winner': opponent,
          'suffocatedBy': null,
        });
      } else {
        tx.update(ref, {
          'players': updatedPlayers,
          'currentTurn': opponent,
          'turnStartedAt': FieldValue.serverTimestamp(),
          'suffocatedBy': null,
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

        if (eliminated) {
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

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> deleteRoom(String code) => _games.doc(code).delete();
}
