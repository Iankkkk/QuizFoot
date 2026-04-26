import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_result.dart';
import 'firestore_service.dart';

class GameHistoryService {
  GameHistoryService._();
  static final GameHistoryService instance = GameHistoryService._();

  static const _keyResults = 'game_results_v1';
  static const _keyPseudo  = 'pseudo';
  static const _maxResults = 200;

  // ── Pseudo ────────────────────────────────────────────────────────────────

  Future<String?> getPseudo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPseudo);
  }

  Future<void> setPseudo(String pseudo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPseudo, pseudo.trim());
  }

  Future<bool> hasPseudo() async => (await getPseudo())?.isNotEmpty == true;

  // ── Results ───────────────────────────────────────────────────────────────

  Future<List<GameResult>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_keyResults) ?? [];
    return raw
        .map((s) {
          try {
            return GameResult.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<GameResult>()
        .toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  Future<void> save(GameResult result) async {
    final prefs   = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_keyResults) ?? [];
    current.add(jsonEncode(result.toJson()));
    if (current.length > _maxResults) {
      current.removeRange(0, current.length - _maxResults);
    }
    await prefs.setStringList(_keyResults, current);
    FirestoreService.instance.saveScore(result); // fire-and-forget
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyResults);
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    final results = await getAll();
    if (results.isEmpty) return {};

    final byType = <GameType, List<GameResult>>{};
    for (final r in results) {
      byType.putIfAbsent(r.gameType, () => []).add(r);
    }

    double bestNormalized = 0;
    for (final r in results) {
      if (r.normalizedScore > bestNormalized) bestNormalized = r.normalizedScore;
    }

    return {
      'totalGames':    results.length,
      'bestScore':     bestNormalized,
      'byType':        byType.map((k, v) => MapEntry(k.name, v.length)),
    };
  }
}
