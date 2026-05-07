import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coup_doeil_1v1_game.dart';

class CoupDoeil1v1Service {
  CoupDoeil1v1Service._();
  static final CoupDoeil1v1Service instance = CoupDoeil1v1Service._();

  final _db = FirebaseFirestore.instance;
  CollectionReference get _games => _db.collection('cdo_1v1_games');

  static String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Create / Join ──────────────────────────────────────────────────────────

  Future<String> createRoom({
    required String pseudo,
    required String difficulty,
    String? category,
    required List<String> questionNames,
  }) async {
    final code = generateRoomCode();
    await _games.doc(code).set({
      'status': CdoGameStatus.waiting.name,
      'difficulty': difficulty,
      'category': category,
      'playerOrder': [pseudo],
      'questionNames': questionNames,
      'players': {
        pseudo: const CdoPlayer().toMap(),
      },
      'winner': null,
      'abandoned': false,
      'abandonedBy': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<void> joinRoom({required String code, required String pseudo}) async {
    final ref = _games.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Room introuvable');
      final game = CoupDoeil1v1Game.fromDoc(snap);
      if (game.status != CdoGameStatus.waiting) throw Exception('Partie déjà commencée');
      if (game.playerOrder.length >= 2) throw Exception('Room pleine');
      if (game.playerOrder.contains(pseudo)) throw Exception('Pseudo déjà pris dans cette room');

      tx.update(ref, {
        'playerOrder': [...game.playerOrder, pseudo],
        'players': {
          ...game.players.map((k, v) => MapEntry(k, v.toMap())),
          pseudo: const CdoPlayer().toMap(),
        },
        'status': CdoGameStatus.playing.name,
      });
    });
  }

  // ── Stream ─────────────────────────────────────────────────────────────────

  Stream<CoupDoeil1v1Game?> watchGame(String code) =>
      _games.doc(code).snapshots().map((s) => s.exists ? CoupDoeil1v1Game.fromDoc(s) : null);

  // ── Submit results (called when a player finishes all 10 questions) ────────

  Future<void> submitResults({
    required String code,
    required String pseudo,
    required int score,
    required List<CdoQuestionResult> results,
  }) async {
    final ref = _games.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final game = CoupDoeil1v1Game.fromDoc(snap);
      if (game.status == CdoGameStatus.finished) return;

      final updatedPlayers = {
        ...game.players.map((k, v) => MapEntry(k, v.toMap())),
        pseudo: CdoPlayer(score: score, finished: true, results: results).toMap(),
      };

      final opponent = game.opponentOf(pseudo);
      final opponentFinished = game.players[opponent]?.finished == true;

      if (opponentFinished) {
        final opponentScore = game.players[opponent]!.score;
        final winner = score > opponentScore
            ? pseudo
            : opponentScore > score
                ? opponent
                : '__draw__';
        tx.update(ref, {
          'players': updatedPlayers,
          'status': CdoGameStatus.finished.name,
          'winner': winner,
        });
      } else {
        tx.update(ref, {'players': updatedPlayers});
      }
    });
  }

  // ── Abandon ────────────────────────────────────────────────────────────────

  Future<void> abandonRoom({required String code, required String pseudo}) async {
    try {
      await _games.doc(code).update({
        'status': CdoGameStatus.finished.name,
        'winner': null,
        'abandoned': true,
        'abandonedBy': pseudo,
      });
    } catch (_) {}
  }

  Future<void> deleteRoom(String code) => _games.doc(code).delete();
}
