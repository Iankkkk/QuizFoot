import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_result.dart';
import 'game_history_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  // ── Écriture ──────────────────────────────────────────────────────────────

  Future<void> saveScore(GameResult result) async {
    final pseudo = await GameHistoryService.instance.getPseudo();
    if (pseudo == null || pseudo.isEmpty) return;
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
    } catch (_) {}
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
