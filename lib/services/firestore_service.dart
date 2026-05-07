import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_result.dart';
import 'game_history_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  static const _pendingKey = 'pending_scores';

  final _db = FirebaseFirestore.instance;

  // ── Écriture ──────────────────────────────────────────────────────────────

  Future<void> saveScore(GameResult result) async {
    final pseudo = await GameHistoryService.instance.getPseudo();
    if (pseudo == null || pseudo.isEmpty) return;

    final ok = await _trySave(result, pseudo, retries: 2);
    if (!ok) await _queuePending(result, pseudo);
  }

  Future<bool> _trySave(GameResult result, String pseudo, {int retries = 0}) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        await _db.collection('scores').add({
          'pseudo':          pseudo,
          'gameType':        result.gameType.name,
          'difficulty':      result.difficulty,
          'category':        result.details['category'] ?? '',
          'rawScore':        result.rawScore,
          'maxRawScore':     result.maxRawScore,
          'normalizedScore': result.normalizedScore,
          'timeTakenMs':     result.timeTaken.inMilliseconds,
          'playedAt':        FieldValue.serverTimestamp(),
          'details':         result.details,
        });
        await _db.collection('feed').add({
          'pseudo':      pseudo,
          'gameType':    result.gameType.name,
          'difficulty':  result.difficulty,
          'score':       result.rawScore,
          'maxScore':    result.maxRawScore,
          if (result.details['category'] != null)
            'category':  result.details['category'],
          if (result.details['matchName'] != null)
            'matchName': result.details['matchName'],
          if (result.details['opponentPseudo'] != null)
            'opponentPseudo': result.details['opponentPseudo'],
          if (result.details['won'] != null)
            'won': result.details['won'],
          'createdAt':   FieldValue.serverTimestamp(),
        });
        return true;
      } catch (_) {
        if (attempt < retries) {
          await Future.delayed(Duration(seconds: 1 << attempt)); // 1s, 2s
        }
      }
    }
    return false;
  }

  Future<void> _queuePending(GameResult result, String pseudo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_pendingKey) ?? [];
      list.add(jsonEncode({'pseudo': pseudo, 'result': result.toJson()}));
      await prefs.setStringList(_pendingKey, list);
    } catch (_) {}
  }

  /// Retries any scores that previously failed to save.
  /// Should be called on app startup once we have network.
  Future<int> retryPendingScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_pendingKey) ?? [];
      if (list.isEmpty) return 0;

      final remaining = <String>[];
      int saved = 0;
      for (final entry in list) {
        try {
          final map = jsonDecode(entry) as Map<String, dynamic>;
          final pseudo = map['pseudo'] as String;
          final result = GameResult.fromJson(Map<String, dynamic>.from(map['result'] as Map));
          final ok = await _trySave(result, pseudo, retries: 1);
          if (ok) {
            saved++;
          } else {
            remaining.add(entry);
          }
        } catch (_) {
          // Drop malformed entries
        }
      }
      await prefs.setStringList(_pendingKey, remaining);
      return saved;
    } catch (_) {
      return 0;
    }
  }

  Future<int> pendingScoresCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_pendingKey) ?? []).length;
    } catch (_) {
      return 0;
    }
  }

  // ── Pseudo ────────────────────────────────────────────────────────────────

  Future<bool> isPseudoAvailable(String pseudo) async {
    try {
      final doc = await _db
          .collection('pseudos')
          .doc(pseudo.toLowerCase())
          .get();
      return !doc.exists;
    } catch (_) {
      return true;
    }
  }

  Future<void> reservePseudo(String pseudo) async {
    await _db
        .collection('pseudos')
        .doc(pseudo.toLowerCase())
        .set({'pseudo': pseudo, 'createdAt': FieldValue.serverTimestamp()});
  }

  // ── Lecture ───────────────────────────────────────────────────────────────

  Future<List<GameResult>> getScores(String pseudo) async {
    try {
      final snap = await _db
          .collection('scores')
          .where('pseudo', isEqualTo: pseudo)
          .get();
      return snap.docs.map((doc) {
        final d = doc.data();
        return GameResult(
          id:              doc.id,
          gameType:        GameType.values.firstWhere((e) => e.name == d['gameType']),
          difficulty:      d['difficulty'] as String,
          rawScore:        (d['rawScore'] as num).toInt(),
          maxRawScore:     (d['maxRawScore'] as num).toInt(),
          normalizedScore: (d['normalizedScore'] as num).toDouble(),
          timeTaken:       Duration(milliseconds: (d['timeTakenMs'] as num).toInt()),
          playedAt:        (d['playedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          details:         Map<String, dynamic>.from(d['details'] as Map),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
