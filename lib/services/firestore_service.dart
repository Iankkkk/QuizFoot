import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_result.dart';
import 'game_history_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  Future<void> saveScore(GameResult result) async {
    final pseudo = await GameHistoryService.instance.getPseudo();
    if (pseudo == null || pseudo.isEmpty) return;
    try {
      await _db.collection('scores').add({
        'pseudo':          pseudo,
        'gameType':        result.gameType.name,
        'difficulty':      result.difficulty,
        'rawScore':        result.rawScore,
        'maxRawScore':     result.maxRawScore,
        'normalizedScore': result.normalizedScore,
        'timeTakenMs':     result.timeTaken.inMilliseconds,
        'playedAt':        FieldValue.serverTimestamp(),
        'details':         result.details,
      });
    } catch (_) {
      // Silencieux — le score local est déjà sauvegardé
    }
  }
}
