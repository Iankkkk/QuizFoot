import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_result.dart';
import 'firestore_service.dart';

class GameHistoryService {
  GameHistoryService._();
  static final GameHistoryService instance = GameHistoryService._();

  static const _keyPseudo = 'pseudo';
  static const _keyPlayedClaims = 'played_claims';

  // ── Cache mémoire (TTL 5 min) ─────────────────────────────────────────────

  List<GameResult>? _cache;
  DateTime? _cacheTime;
  static const _cacheTtl = Duration(minutes: 5);

  bool get _cacheValid =>
      _cache != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTtl;

  void invalidateCache() {
    _cache = null;
    _cacheTime = null;
  }

  // ── Pseudo ────────────────────────────────────────────────────────────────

  Future<String?> getPseudo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPseudo);
  }

  Future<bool> hasPseudo() async => (await getPseudo())?.isNotEmpty == true;

  // ── Results ───────────────────────────────────────────────────────────────

  Future<List<GameResult>> getAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _cacheValid) return _cache!;
    final pseudo = await getPseudo();
    if (pseudo == null || pseudo.isEmpty) return [];
    final results = await FirestoreService.instance.getScores(pseudo)
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    _cache = results;
    _cacheTime = DateTime.now();
    return results;
  }

  Future<Set<String>> getPlayedClaims() async {
    final pseudo = await getPseudo();
    if (pseudo == null || pseudo.isEmpty) return {};
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('${_keyPlayedClaims}_$pseudo') ?? []).toSet();
  }

  Future<void> markClaimPlayed(String claimText) async {
    final pseudo = await getPseudo();
    if (pseudo == null || pseudo.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '${_keyPlayedClaims}_$pseudo';
    final list = prefs.getStringList(key) ?? [];
    if (!list.contains(claimText)) {
      list.add(claimText);
      await prefs.setStringList(key, list);
    }
  }

  Future<void> save(GameResult result) async {
    if (_cache != null) {
      _cache = [result, ..._cache!];
      _cacheTime = DateTime.now();
    }
    await FirestoreService.instance.saveScore(result);
  }
}
