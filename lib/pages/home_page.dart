import 'dart:convert';
import 'dart:math' show log, sqrt;
import 'package:flutter/material.dart';
import 'coup_doeil/coup_doeil_intro_page.dart';
import 'package:quiz_foot/pages/lineup/lineup_match_page_intro.dart';
import 'lineup/compos_1v1_lobby_page.dart';
import 'coup_doeil/coup_doeil_1v1_lobby_page.dart';
import 'package:quiz_foot/data/anecdotes_data.dart';
import 'package:quiz_foot/data/players_data.dart';
import 'package:quiz_foot/data/data_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../services/game_history_service.dart';
import '../services/theme_service.dart';
import '../services/firestore_service.dart';
import '../models/game_result.dart';
import 'profil_page.dart';
import 'classement_page.dart';
import 'qui_a_menti/qui_a_menti_intro.dart';
import 'parcours_joueur/parcours_joueur_intro_page.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:quiz_foot/utils/navigation.dart';

// ── Design tokens (Tempo home — dark + light) ────────────────────────────────
class _C {
  static bool get _d => ThemeService.instance.isDark;
  static Color get card =>
      _d ? const Color(0xFF1E2130) : const Color(0xFFF0F2F8);
  static Color get border =>
      _d ? const Color(0xFF2D3148) : const Color(0xFFD4D9E8);
  static Color get accent =>
      _d ? const Color(0xFF2EA043) : const Color(0xFF009E6B);
  static Color get accentBr =>
      _d ? const Color(0xFF3FB950) : const Color(0xFF00B87A);
  static Color get accentDp =>
      _d ? const Color(0xFF1E7F4F) : const Color(0xFF006B47);
  static Color get fg1 =>
      _d ? const Color(0xFFE6EDF3) : const Color(0xFF0D1117);
  static Color get fg2 =>
      _d ? const Color(0xFF8B949E) : const Color(0xFF586069);
  static Color get fg3 =>
      _d ? const Color(0xFF5A6272) : const Color(0xFF9AA3B0);
  static Color get orange =>
      _d ? const Color(0xFFE87820) : const Color(0xFFC85D0F);
  static Color get cardAlt =>
      _d ? const Color(0xFF171923) : const Color(0xFFE4E8F2);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _randomAnecdote = '';
  String _pseudo = '';

  // Stats locales
  int _totalGames = 0;
  Duration _totalTime = Duration.zero;
  String _favGame = '—';
  int _streak = 0;

  // Stat communauté (Firestore)
  int _communityGames = 0;

  // Sondage du jour
  Map<String, dynamic>? _pollData;
  String? _pollId;
  String? _pollMyChoice;

  // Hero "Partie rapide"
  Map<String, dynamic>? _lastConfig;

  // Préférences du modal "Régler" (persistées)
  Map<String, dynamic> _reglePrefs = {};

  // Top joueurs de l'app
  List<({String pseudo, double score})> _topPlayers = [];
  List<({String pseudo, int wins, int losses, double ratio})> _top1v1Players =
      [];

  @override
  void initState() {
    super.initState();
    _loadAnecdote();
    _warmCache();
    _loadPseudoThenPoll();
    _loadStats();
    _loadCommunityStats();
    _loadLastConfig();
    _loadReglePrefs();
    _loadBestPlayer();
    _loadBest1v1Player();
    _retryPendingScores();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  Future<void> _retryPendingScores() async {
    final saved = await FirestoreService.instance.retryPendingScores();
    if (saved > 0 && mounted) {
      GameHistoryService.instance.invalidateCache();
      _loadStats();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$saved score${saved > 1 ? 's' : ''} en attente envoyé${saved > 1 ? 's' : ''} ✓',
          ),
          backgroundColor: _C.accentBr,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  Future<void> _loadPseudoThenPoll() async {
    final prefs = await SharedPreferences.getInstance();
    final pseudo = prefs.getString('pseudo') ?? '';
    if (mounted) setState(() => _pseudo = pseudo);
    await _loadPoll(pseudo);
  }

  Future<void> _loadPoll(String pseudo) async {
    try {
      final db = FirebaseFirestore.instance;
      final all = await db.collection('polls').get();
      final now = DateTime.now();
      QueryDocumentSnapshot<Map<String, dynamic>>? latestDoc;
      DateTime? latestDate;
      for (final doc in all.docs) {
        try {
          final p = doc.id.split('-');
          if (p.length != 3) continue;
          final d = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
          if (d.isAfter(now)) continue;
          if (latestDate == null || d.isAfter(latestDate)) {
            latestDoc = doc;
            latestDate = d;
          }
        } catch (_) {}
      }
      if (latestDoc == null) return;
      final pollId = latestDoc.id;
      final pollData = latestDoc.data();
      String? myChoice;
      if (pseudo.isNotEmpty) {
        final voteDoc = await db
            .collection('polls')
            .doc(pollId)
            .collection('votes')
            .doc(pseudo)
            .get();
        if (voteDoc.exists) myChoice = voteDoc.data()?['choice'] as String?;
      }
      if (mounted) {
        setState(() {
          _pollData = pollData;
          _pollId = pollId;
          _pollMyChoice = myChoice;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    final results = await GameHistoryService.instance.getAll();
    if (!mounted || results.isEmpty) return;
    final totalTime = results.fold(
      Duration.zero,
      (acc, r) => acc + r.timeTaken,
    );
    final coupDoeilCount = results
        .where((r) => r.gameType == GameType.coupDoeil)
        .length;
    final composCount = results
        .where((r) => r.gameType == GameType.compos)
        .length;
    final fav = coupDoeilCount >= composCount ? "Coup d'Œil" : 'Compos';
    final streak = _computeStreak(results);
    setState(() {
      _totalGames = results.length;
      _totalTime = totalTime;
      _favGame = fav;
      _streak = streak;
    });
  }

  int _computeStreak(List<GameResult> results) {
    if (results.isEmpty) return 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dates =
        results
            .map(
              (r) =>
                  DateTime(r.playedAt.year, r.playedAt.month, r.playedAt.day),
            )
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (dates.first.isBefore(todayDate.subtract(const Duration(days: 1))))
      return 0;
    int streak = 1;
    for (int i = 1; i < dates.length; i++) {
      if (dates[i - 1].difference(dates[i]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  String _formatTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    return '${m}min';
  }

  Future<void> _loadCommunityStats() async {
    try {
      final agg = await FirebaseFirestore.instance
          .collection('scores')
          .count()
          .get();
      if (mounted) setState(() => _communityGames = agg.count ?? 0);
    } catch (_) {}
  }

  Future<void> _warmCache() async {
    try {
      await loadPlayers();
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('players_json');
    await prefs.remove('players_expiry');
    await prefs.remove('anecdotes_json');
    await prefs.remove('anecdotes_expiry');
    await prefs.remove('matches_json');
    await prefs.remove('matches_expiry');
    await prefs.remove('lineups_json');
    await prefs.remove('lineups_expiry');
    DataCache.instance.invalidateAll();
    await _loadAnecdote();
    await _warmCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache vidé — données rechargées ✓')),
      );
    }
  }

  Future<void> _loadAnecdote() async {
    try {
      final anecdotes = await loadAnecdotes();
      if (anecdotes.isNotEmpty && mounted) {
        final now = DateTime.now();
        final daySeed = now.year * 10000 + now.month * 100 + now.day;
        final index = daySeed % anecdotes.length;
        setState(() => _randomAnecdote = anecdotes[index]);
      }
    } catch (_) {}
  }

  Future<void> _loadLastConfig() async {
    final results = await GameHistoryService.instance.getAll();
    if (!mounted || results.isEmpty) return;
    results.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    final last = results.first;
    final Map<String, dynamic> config;
    if (last.gameType == GameType.compos ||
        last.gameType == GameType.multiplayerCompos) {
      final category = last.details['category'] as String?;
      config = {'mode': 'compos', if (category != null) 'category': category};
    } else if (last.gameType == GameType.quiAMenti) {
      config = {'mode': 'quiAMenti', 'difficulty': last.difficulty};
    } else {
      final category = last.details['category'] as String?;
      config = {
        'mode': 'coupDoeil',
        if (category != null) 'category': category,
      };
    }
    setState(() => _lastConfig = config);
  }

  Future<void> _loadReglePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('regle_prefs');
    if (raw != null && mounted) {
      try {
        setState(() => _reglePrefs = jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> _saveReglePrefs(Map<String, dynamic> prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('regle_prefs', jsonEncode(prefs));
    if (mounted) setState(() => _reglePrefs = prefs);
  }

  Future<void> _loadBestPlayer() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('scores')
          .orderBy('playedAt', descending: true)
          .limit(300)
          .get();

      final Map<String, double> sums = {};
      final Map<String, int> counts = {};

      for (final doc in snap.docs) {
        final d = doc.data();
        final pseudo = d['pseudo'] as String? ?? '';
        if (pseudo.isEmpty) continue;
        final gameType = d['gameType'] as String? ?? '';
        final difficulty = d['difficulty'] as String? ?? 'Pro';
        final rawScore = (d['rawScore'] as num?)?.toInt() ?? 0;
        final maxRaw = (d['maxRawScore'] as num?)?.toInt() ?? 1;

        final isCompos =
            gameType == 'compos' || gameType == 'multiplayerCompos';
        final isNoDifficulty = isCompos || gameType == 'quiAMenti';
        final mult = isNoDifficulty
            ? 1.0
            : GameResult.difficultyMultiplier(difficulty);
        final pct = maxRaw > 0 ? rawScore / maxRaw : 0.0;
        double contribution = pct * 100 * mult;

        final is1v1 =
            gameType == 'multiplayerCompos' ||
            gameType == 'multiplayerCoupDoeil';
        if (is1v1) continue; // solo uniquement

        sums[pseudo] = (sums[pseudo] ?? 0) + contribution;
        counts[pseudo] = (counts[pseudo] ?? 0) + 1;
      }

      final eligible = sums.entries
          .where((e) => (counts[e.key] ?? 0) >= 5)
          .toList();
      if (eligible.isEmpty) return;

      eligible.sort((a, b) {
        final n1 = counts[a.key]!;
        final n2 = counts[b.key]!;
        final scoreA = (a.value / n1) + log(n1.toDouble()) * 3;
        final scoreB = (b.value / n2) + log(n2.toDouble()) * 3;
        return scoreB.compareTo(scoreA);
      });

      final all = eligible.take(5).map((e) {
        final n = counts[e.key]!;
        final score = (e.value / n) + log(n.toDouble()) * 3;
        return (pseudo: e.key, score: score);
      }).toList();

      if (mounted) setState(() => _topPlayers = all);
    } catch (_) {}
  }

  Future<void> _loadBest1v1Player() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('scores')
          .get();

      final Map<String, int> wins = {};
      final Map<String, int> losses = {};

      for (final doc in snap.docs) {
        final d = doc.data();
        final pseudo = d['pseudo'] as String? ?? '';
        if (pseudo.isEmpty) continue;
        final gameType = d['gameType'] as String? ?? '';
        if (gameType != 'multiplayerCompos' &&
            gameType != 'multiplayerCoupDoeil')
          continue;
        final details = d['details'] as Map<String, dynamic>?;
        if (details?['abandoned'] == true) continue;
        final won = details?['won'] as bool?;
        final isDraw = details?['draw'] as bool? ?? false;
        if (won == null || isDraw) continue;
        if (won) {
          wins[pseudo] = (wins[pseudo] ?? 0) + 1;
        } else {
          losses[pseudo] = (losses[pseudo] ?? 0) + 1;
        }
      }

      final allPseudos = {...wins.keys, ...losses.keys};
      final eligible = allPseudos
          .where((p) => (wins[p] ?? 0) + (losses[p] ?? 0) >= 1)
          .toList();
      if (eligible.isEmpty) return;

      double wilsonScore(int w, int total) {
        if (total == 0) return 0;
        const z = 1.645;
        final p = w / total;
        final n = total.toDouble();
        return (p + z * z / (2 * n) -
                z * sqrt(p * (1 - p) / n + z * z / (4 * n * n))) /
            (1 + z * z / n);
      }

      eligible.sort((a, b) {
        final wA = wins[a] ?? 0;
        final wB = wins[b] ?? 0;
        final sA = wilsonScore(wA, wA + (losses[a] ?? 0)) * (1 + log(wA + 1) * 0.3);
        final sB = wilsonScore(wB, wB + (losses[b] ?? 0)) * (1 + log(wB + 1) * 0.3);
        return sB.compareTo(sA);
      });

      final all = eligible.take(5).map((p) {
        final w = wins[p] ?? 0;
        final l = losses[p] ?? 0;
        final t = w + l;
        return (pseudo: p, wins: w, losses: l, ratio: t > 0 ? w / t : 0.0);
      }).toList();

      if (mounted) setState(() => _top1v1Players = all);
    } catch (_) {}
  }

  void _launchFromConfig(Map<String, dynamic> config) {
    final mode = config['mode'] as String? ?? 'coupDoeil';
    final category = config['category'] as String?;
    final erasList = (_reglePrefs['eras'] as List?)?.cast<String>() ?? [];
    final eras = erasList.toSet();
    if (mode == 'compos') {
      Navigator.push(
        context,
        namedRoute(
          LineupMatchPageIntro(
            autoOpenDifficulty: true,
            initialEras: eras.isNotEmpty ? eras : null,
          ),
        ),
      );
    } else if (mode == 'quiAMenti') {
      Navigator.push(
        context,
        namedRoute(const QuiAMentiIntro(autoOpenDifficulty: true)),
      );
    } else {
      Navigator.push(
        context,
        namedRoute(
          CoupDoeilIntroPage(
            initialCategory: category,
            autoOpenDifficulty: true,
          ),
        ),
      );
    }
  }

  void _showRegleModal() {
    final current = {
      'mode': _lastConfig?['mode'] ?? _reglePrefs['mode'] ?? 'coupDoeil',
      'category': _reglePrefs['category'],
      'eras': _reglePrefs['eras'],
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _RegleModal(
        initial: current,
        onConfirm: (config) {
          Navigator.pop(context);
          _saveReglePrefs(config);
          _launchFromConfig(config);
        },
      ),
    );
  }

  void _showTop5() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Classement Solo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.fg1),
            ),
            const SizedBox(height: 4),
            Text(
              'Scores pondérés par difficulté et volume — parties solo uniquement.',
              style: TextStyle(fontSize: 11, color: _C.fg2),
            ),
            const SizedBox(height: 16),
            ...List.generate(_topPlayers.length, (rank) {
              final player = _topPlayers[rank];
              final isFirst = rank == 0;
              final medal = rank == 0 ? '🥇' : rank == 1 ? '🥈' : rank == 2 ? '🥉' : '${rank + 1}.';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isFirst ? _C.accent.withValues(alpha: 0.12) : _C.cardAlt,
                  border: Border.all(color: isFirst ? _C.accentBr.withValues(alpha: 0.5) : _C.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(medal, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        player.pseudo,
                        style: TextStyle(fontSize: 14, fontWeight: isFirst ? FontWeight.w800 : FontWeight.w600, color: _C.fg1),
                      ),
                    ),
                    Text(
                      player.score.toStringAsFixed(1),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isFirst ? _C.accentBr : _C.fg2),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showTop51v1() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Classement 1v1',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.fg1),
            ),
            const SizedBox(height: 4),
            Text(
              'Score normalisé (ratio + volume de victoires).',
              style: TextStyle(fontSize: 11, color: _C.fg2),
            ),
            const SizedBox(height: 16),
            ...List.generate(_top1v1Players.length, (rank) {
              final player = _top1v1Players[rank];
              final isFirst = rank == 0;
              final medal = rank == 0 ? '🥇' : rank == 1 ? '🥈' : rank == 2 ? '🥉' : '${rank + 1}.';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isFirst ? _C.accent.withValues(alpha: 0.12) : _C.cardAlt,
                  border: Border.all(color: isFirst ? _C.accentBr.withValues(alpha: 0.5) : _C.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(medal, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        player.pseudo,
                        style: TextStyle(fontSize: 14, fontWeight: isFirst ? FontWeight.w800 : FontWeight.w600, color: _C.fg1),
                      ),
                    ),
                    Text(
                      '${player.wins}V · ${player.losses}D',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isFirst ? _C.accentBr : _C.fg2),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadAnecdote(),
      _loadPseudoThenPoll(),
      _loadStats(),
      _loadCommunityStats(),
      _loadLastConfig(),
      _loadBestPlayer(),
      _loadBest1v1Player(),
    ]);
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      _loadStats();
      _loadLastConfig();
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildGamesPage();
      case 2:
        return ClassementPage(pseudo: _pseudo);
      case 3:
        return ProfilPage(pseudo: _pseudo);
      default:
        return _buildHomeContent();
    }
  }

  // ── Home content ─────────────────────────────────────────────────────────────

  Widget _buildHomeContent() {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: _C.accentBr,
        backgroundColor: _C.card,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildHero(),
              if (_pollData != null) ...[
                _SectionTitle('📊 Sondage de la semaine'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DailySondage(
                    pseudo: _pseudo,
                    pollId: _pollId!,
                    initialPoll: _pollData!,
                    initialChoice: _pollMyChoice,
                    onVoted: (choice) => setState(() => _pollMyChoice = choice),
                  ),
                ),
              ],
              _SectionTitle('Le saviez-vous ?'),
              _buildAnecdoteCard(),
              _SectionTitle(
                'Activité de la commu',
                action: 'Voir tout →',
                onAction: () {
                  Navigator.push(
                    context,
                    namedRoute(const _CommunityFeedPage()),
                  );
                },
              ),
              _buildFeed(),
              _SectionTitle(
                'Tes stats',
                action: 'Voir tout →',
                onAction: () {
                  _onNavItemTapped(3);
                },
              ),
              _buildStatsGrid(),
              _SectionTitle('À la une'),
              _buildHighlights(),
              _buildPub(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo tile
          GestureDetector(
            onLongPress: _clearCache,
            child: Image.asset('assets/images/logo.png', width: 80, height: 80),
          ),
          const SizedBox(width: 14),
          // Wordmark
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TEMPO',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 4.5,
                  color: _C.fg1,
                  height: 1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Le jeu, dans la tête.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _C.fg2,
                  letterSpacing: 0.3,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Streak pill (affiché à partir de 2 jours consécutifs)
          if (_streak >= 2)
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: _C.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      Text(
                        _streak > 0
                            ? 'Tu as joué à Tempo Foot $_streak jour${_streak > 1 ? 's' : ''} d\'affilée !'
                            : 'Joue aujourd\'hui pour démarrer une série !',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _C.fg1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _streak > 0 ? 'Merci !' : 'Lance une partie 👇',
                        style: TextStyle(fontSize: 13, color: _C.fg2),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Super !',
                        style: TextStyle(
                          color: _C.accentBr,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _C.card,
                  border: Border.all(color: _C.orange.withValues(alpha: 0.33)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 17,
                      color: _C.orange,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$_streak',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _C.fg1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _clearCache,
            icon: Icon(Icons.refresh_rounded, size: 22, color: _C.fg2),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
    );
  }

  // ── Hero "Partie rapide" ─────────────────────────────────────────────────────

  Widget _buildHero() {
    final config = _lastConfig;
    final hasConfig = config != null;
    final mode = config?['mode'] as String? ?? 'coupDoeil';
    final category = config?['category'] as String?;

    final modeLabel = mode == 'compos'
        ? 'Compos'
        : mode == 'quiAMenti'
        ? 'Qui a menti ?'
        : "Coup d'Œil";
    final heroTitle = category != null ? '$modeLabel · $category' : modeLabel;
    final eyebrow = hasConfig ? '▶ REPRENDS OÙ TU EN ÉTAIS' : 'DÉMARRER';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.accent, _C.accentDp],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x402EA043),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Field lines décor
            Positioned.fill(
              child: Opacity(
                opacity: 0.09,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.transparent],
                      stops: [0, 1],
                    ),
                  ),
                  child: CustomPaint(painter: _DiagonalLinesPainter()),
                ),
              ),
            ),
            // Watermark icon
            Positioned(
              right: -18,
              bottom: -28,
              child: Opacity(
                opacity: 0.13,
                child: Icon(
                  mode == 'compos'
                      ? Icons.sports_soccer
                      : mode == 'quiAMenti'
                      ? Icons.gavel
                      : Icons.visibility,
                  size: 180,
                  color: Colors.white,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: Color(0xC8FFFFFF),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    heroTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Primary CTA
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _launchFromConfig(
                            config ?? {'mode': 'coupDoeil'},
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 11,
                              horizontal: 18,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_arrow,
                                  size: 20,
                                  color: _C.accentDp,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Jouer !',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _C.accentDp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (mode != 'quiAMenti') ...[
                        const SizedBox(width: 8),
                        // Secondary CTA
                        GestureDetector(
                          onTap: _showRegleModal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 11,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune, size: 16, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Paramètres',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Anecdote card ─────────────────────────────────────────────────────────────

  Widget _buildAnecdoteCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: _C.card,
          border: Border.all(color: _C.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.auto_stories_outlined, size: 20, color: _C.fg2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _randomAnecdote.isEmpty
                  ? SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _C.accentBr,
                      ),
                    )
                  : Text(
                      _randomAnecdote,
                      style: TextStyle(
                        fontSize: 13,
                        color: _C.fg1,
                        height: 1.45,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Feed (activité) ───────────────────────────────────────────────────────────

  Widget _buildFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feed')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
        final seen1v1 = <String>{};
        final docs = snap.data!.docs
            .where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final type = d['gameType'] as String?;
              if (type != 'multiplayerCompos' && type != 'multiplayerCoupDoeil')
                return true;
              final p1 = d['pseudo'] as String? ?? '';
              final p2 = d['opponentPseudo'] as String? ?? '';
              final matchKey = (d['matchName'] ?? d['category'] ?? '') as String;
              final pair = ([p1, p2]..sort()).join('-');
              return seen1v1.add('$type-$pair-$matchKey');
            })
            .take(3)
            .toList();

        if (docs.isEmpty) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final pseudo = d['pseudo'] as String? ?? '?';
              final gameType = d['gameType'] as String? ?? '';
              final diff = d['difficulty'] as String? ?? '';
              final score = d['score'] as int? ?? 0;
              final category = d['category'] as String?;
              final matchName = d['matchName'] as String?;
              final opponentPseudo = d['opponentPseudo'] as String?;
              final won = d['won'] as bool?;
              final draw = d['draw'] as bool? ?? false;
              final ts = d['createdAt'] as Timestamp?;
              final ago = ts != null ? _timeAgo(ts.toDate()) : '';
              final is1v1Compos = gameType == 'multiplayerCompos';
              final is1v1Cdo = gameType == 'multiplayerCoupDoeil';
              final is1v1 = is1v1Compos || is1v1Cdo;
              final isCompos = gameType == 'compos';
              final isQuiAMenti = gameType == 'quiAMenti';

              final String emoji = is1v1Compos
                  ? '⚔️'
                  : is1v1Cdo
                  ? '⚔️'
                  : isCompos
                  ? '⚽'
                  : '👁️';
              final String? claim = d['claim'] as String?;
              final String detail = isQuiAMenti
                  ? (claim ?? '')
                  : (matchName ?? category ?? '');

              Widget mainText;
              if (is1v1) {
                final opp = opponentPseudo ?? '?';
                final winnerLine = won == null
                    ? '$pseudo vs $opp'
                    : draw
                    ? '🤝 $pseudo vs $opp — Match nul'
                    : won
                    ? '🏆 $pseudo bat $opp'
                    : '🏆 $opp bat $pseudo';
                mainText = RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12.5, color: _C.fg1),
                    children: [
                      TextSpan(
                        text: winnerLine,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              } else {
                final scoreStr = isCompos ? '$score%' : '${score}pts';
                mainText = RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12.5, color: _C.fg1),
                    children: [
                      TextSpan(
                        text: pseudo,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _C.fg1,
                        ),
                      ),
                      TextSpan(
                        text: '  $scoreStr',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _C.accentBr,
                        ),
                      ),
                      if (!isCompos &&
                          !isQuiAMenti &&
                          diff.isNotEmpty &&
                          diff != 'Standard')
                        TextSpan(
                          text: ' · $diff',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _C.fg2,
                          ),
                        ),
                    ],
                  ),
                );
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _C.card,
                  border: Border.all(color: _C.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon container
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        border: Border.all(color: _C.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: isQuiAMenti
                          ? Icon(Icons.gavel, size: 14, color: _C.orange)
                          : Text(
                              emoji,
                              style: const TextStyle(fontSize: 14, height: 1),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          mainText,
                          if (detail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              detail,
                              style: TextStyle(fontSize: 11, color: _C.fg2),
                              maxLines: isQuiAMenti ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(ago, style: TextStyle(fontSize: 10, color: _C.fg2)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Stats grid ────────────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final stats = [
      _StatCell(value: '$_totalGames', label: 'Parties'),
      _StatCell(
        value: _totalGames > 0 ? _formatTime(_totalTime) : '—',
        label: 'Temps total',
      ),
      _StatCell(value: _favGame, label: 'Préféré'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: _C.card,
          border: Border.all(color: _C.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 32,
                  color: _C.border,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      stats[i].value,
                      style: TextStyle(
                        fontSize: stats[i].value.length > 6 ? 13 : 17,
                        fontWeight: FontWeight.w800,
                        color: _C.accentBr,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stats[i].label,
                      style: TextStyle(fontSize: 10.5, color: _C.fg2),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── À la une (highlights carousel) ───────────────────────────────────────────

  Widget _buildHighlights() {
    final cards = [
      _HighlightData(
        tag: 'Nouveau jeu',
        title: 'Qui a menti ?',
        subtitle: '1 affirmation, 10 joueurs : 5 menteurs à démasquer !',
        emoji: '🎭',
        onTap: () =>
            Navigator.push(context, namedRoute(const QuiAMentiIntro())),
      ),
      _HighlightData(
        tag: 'Communauté',
        title: '$_communityGames parties',
        subtitle: 'Merci à la commu Tempo ! 💚💚💚',
        icon: Icons.diversity_3,
      ),
      if (_topPlayers.isNotEmpty)
        _HighlightData(
          tag: 'Meilleur Joueur Solo',
          title: "🏆 ${_topPlayers.first.pseudo}",
          subtitle: 'Le crack du solo Tempo !',
          emoji: '🥇',
          onTap: () => _showTop5(),
        ),
      if (_top1v1Players.isNotEmpty)
        _HighlightData(
          tag: 'Meilleur Joueur 1v1',
          title: "⚔️ ${_top1v1Players.first.pseudo}",
          subtitle: 'La terreur des matchs 1v1 !!',
          emoji: '⚔️',
          onTap: () => _showTop51v1(),
        ),
    ];

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: cards.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == cards.length) return const SizedBox(width: 10);
          final c = cards[i];
          return GestureDetector(
            onTap: c.onTap,
            child: Container(
              width: 180,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.card,
                border: Border.all(color: _C.border),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Opacity(
                      opacity: 0.08,
                      child: c.emoji != null
                          ? Text(
                              c.emoji!,
                              style: const TextStyle(fontSize: 56, height: 1),
                            )
                          : Icon(c.icon, size: 64, color: _C.fg1),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.tag.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: _C.fg2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _C.fg1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        c.subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _C.fg2,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── PUB strip ─────────────────────────────────────────────────────────────────

  Widget _buildPub() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: SizedBox(
        height: 28,
        child: Center(
          child: Opacity(
            opacity: 0.5,
            child: Text(
              'PUB',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: _C.fg3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Time helper ───────────────────────────────────────────────────────────────

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }

  // ── Games page ───────────────────────────────────────────────────────────────

  Widget _buildGamesPage() {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jeux',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 26,
                color: _C.fg1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choisis ton mode de jeu',
              style: TextStyle(fontSize: 13.5, color: _C.fg2),
            ),
            const SizedBox(height: 28),

            // ── Coup d'Œil ──────────────────────────────────────────────────
            _GameCard(
              icon: PhosphorIconsFill.eye,
              title: "Coup d'Œil",
              subtitle: 'Reconnais le joueur grâce à sa photo',
              accentColor: _C.accent,
              onTap: () =>
                  Navigator.push(context, namedRoute(CoupDoeilIntroPage())),
              duelLabel: "Coup d'Œil 1v1",
              onDuelTap: () => Navigator.push(
                context,
                namedRoute(const CoupDoeil1v1LobbyPage()),
              ),
            ),
            const SizedBox(height: 12),

            // ── Compos ──────────────────────────────────────────────────────
            _GameCard(
              icon: PhosphorIconsFill.usersThree,
              title: 'Compos',
              subtitle: "Retrouve les compos d'un match historique",
              accentColor: _C.accent,
              onTap: () => Navigator.push(
                context,
                namedRoute(const LineupMatchPageIntro()),
              ),
              duelLabel: 'Compos 1v1',
              onDuelTap: () => Navigator.push(
                context,
                namedRoute(const Compos1v1LobbyPage()),
              ),
            ),
            const SizedBox(height: 12),

            // ── Qui a menti ? ───────────────────────────────────────────────
            _GameCard(
              icon: PhosphorIconsFill.maskHappy,
              title: 'Qui a menti ?',
              subtitle: '1 affirmation, 10 joueurs : 5 menteurs !',
              accentColor: _C.accent,
              onTap: () =>
                  Navigator.push(context, namedRoute(const QuiAMentiIntro())),
            ),
            const SizedBox(height: 12),

            // ── Parcours Joueur ─────────────────────────────────────────────
            _GameCard(
              icon: Icons.route_outlined,
              title: 'Parcours Joueur',
              subtitle: 'Retrouve le joueur grâce à sa carrière',
              accentColor: _C.fg3,
              locked: false,
              onTap: () => Navigator.push(
                context,
                namedRoute(const ParcoursJoueurIntroPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Scaffold ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _buildContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        selectedItemColor: _C.accentBr,
        unselectedItemColor: _C.fg2,
        backgroundColor: _C.card,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 10,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.stadium_outlined),
            label: 'Jeux',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Classements',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ── Section title helper ───────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _C.fg1,
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.accentBr,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Diagonal lines painter (hero décor) ───────────────────────────────────────

class _DiagonalLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    const spacing = 22.0;
    final count = (size.width + size.height) ~/ spacing + 2;
    for (int i = 0; i < count; i++) {
      final x = i * spacing - size.height;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Stat cell data ─────────────────────────────────────────────────────────────

class _StatCell {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});
}

// ── Highlight data ─────────────────────────────────────────────────────────────

class _HighlightData {
  final String tag;
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? emoji;
  final VoidCallback? onTap;
  const _HighlightData({
    required this.tag,
    required this.title,
    required this.subtitle,
    this.icon,
    this.emoji,
    this.onTap,
  });
}

// ── Régler modal ──────────────────────────────────────────────────────────────

class _RegleModal extends StatefulWidget {
  final Map<String, dynamic> initial;
  final void Function(Map<String, dynamic>) onConfirm;
  const _RegleModal({required this.initial, required this.onConfirm});

  @override
  State<_RegleModal> createState() => _RegleModalState();
}

class _RegleModalState extends State<_RegleModal> {
  late String _mode;
  String? _category;
  late Set<String> _selectedEras;

  static const _modes = ['coupDoeil', 'compos'];
  static const _modeLabels = {"coupDoeil": "Coup d'Œil", "compos": "Compos"};
  static const _categories = [
    'Ligue 1',
    'Ligue 2',
    'Premier League',
    'La Liga',
    'Serie A',
    'Bundesliga',
    'Légendes',
    'Équipes nationales',
  ];
  static const _eras = ['Toutes', 'Avant 2010', '2010-2019', '2020-2026'];

  @override
  void initState() {
    super.initState();
    _mode = widget.initial['mode'] as String? ?? 'coupDoeil';
    _category = widget.initial['category'] as String?;
    final erasList = (widget.initial['eras'] as List?)?.cast<String>() ?? [];
    _selectedEras = erasList.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurer la partie',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _C.fg1,
              ),
            ),
            const SizedBox(height: 20),
            // Mode
            Text(
              'Mode',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _C.fg2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _modes.map((m) {
                final selected = _mode == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _mode = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? _C.accent.withValues(alpha: 0.15)
                            : _C.card,
                        border: Border.all(
                          color: selected ? _C.accentBr : _C.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _modeLabels[m]!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? _C.accentBr : _C.fg2,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_mode == 'compos') ...[
              const SizedBox(height: 16),
              Text(
                'Période',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.fg2,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _eras.map((era) {
                  final isAll = era == 'Toutes';
                  final selected = isAll
                      ? _selectedEras.isEmpty
                      : _selectedEras.contains(era);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isAll) {
                        _selectedEras.clear();
                      } else {
                        if (_selectedEras.contains(era)) {
                          _selectedEras.remove(era);
                        } else {
                          _selectedEras.add(era);
                          if (_selectedEras.length == 3) _selectedEras.clear();
                        }
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? _C.accent.withValues(alpha: 0.15)
                            : _C.card,
                        border: Border.all(
                          color: selected ? _C.accentBr : _C.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        era,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? _C.accentBr : _C.fg2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (_mode == 'coupDoeil') ...[
              const SizedBox(height: 16),
              Text(
                'Catégorie',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.fg2,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // "Toutes" option
                  GestureDetector(
                    onTap: () => setState(() => _category = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _category == null
                            ? _C.accent.withValues(alpha: 0.15)
                            : _C.card,
                        border: Border.all(
                          color: _category == null ? _C.accentBr : _C.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Toutes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _category == null ? _C.accentBr : _C.fg2,
                        ),
                      ),
                    ),
                  ),
                  ..._categories.map((c) {
                    final selected = _category == c;
                    return GestureDetector(
                      onTap: () => setState(() => _category = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? _C.accent.withValues(alpha: 0.15)
                              : _C.card,
                          border: Border.all(
                            color: selected ? _C.accentBr : _C.border,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? _C.accentBr : _C.fg2,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => widget.onConfirm({
                  'mode': _mode,
                  if (_mode == 'coupDoeil') 'category': _category,
                  if (_mode == 'compos' && _selectedEras.isNotEmpty)
                    'eras': _selectedEras.toList(),
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _C.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Lancer la partie',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sondage du jour ───────────────────────────────────────────────────────────

class _DailySondage extends StatefulWidget {
  final String pseudo;
  final String pollId;
  final Map<String, dynamic> initialPoll;
  final String? initialChoice;
  final void Function(String choice)? onVoted;
  const _DailySondage({
    required this.pseudo,
    required this.pollId,
    required this.initialPoll,
    this.initialChoice,
    this.onVoted,
  });

  @override
  State<_DailySondage> createState() => _DailySondageState();
}

class _DailySondageState extends State<_DailySondage> {
  late Map<String, dynamic> _poll;
  String? _myChoice;
  bool _voting = false;

  @override
  void initState() {
    super.initState();
    _poll = widget.initialPoll;
    _myChoice = widget.initialChoice;
  }

  Future<void> _vote(String choice) async {
    if (_voting || widget.pseudo.isEmpty || _myChoice != null) return;
    setState(() => _voting = true);
    try {
      final pollRef = FirebaseFirestore.instance
          .collection('polls')
          .doc(widget.pollId);
      final voteRef = pollRef.collection('votes').doc(widget.pseudo);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(voteRef, {
          'choice': choice,
          'votedAt': FieldValue.serverTimestamp(),
        });
        tx.update(pollRef, {
          choice == 'A' ? 'votesA' : 'votesB': FieldValue.increment(1),
        });
      });
      final updated = await pollRef.get();
      if (mounted) {
        setState(() {
          _myChoice = choice;
          _poll = updated.data() ?? _poll;
          _voting = false;
        });
        widget.onVoted?.call(choice);
      }
    } catch (_) {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = _poll['question'] as String? ?? '';
    final optionA = _poll['optionA'] as String? ?? 'Option A';
    final optionB = _poll['optionB'] as String? ?? 'Option B';
    final votesA = (_poll['votesA'] as num?)?.toInt() ?? 0;
    final votesB = (_poll['votesB'] as num?)?.toInt() ?? 0;
    final total = votesA + votesB;

    final opts = [
      (key: 'A', label: optionA, votes: votesA),
      (key: 'B', label: optionB, votes: votesB),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.card,
        border: Border.all(color: _C.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            total > 0 ? '$total votes' : '—',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: _C.fg2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _C.fg1,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: opts.map((opt) {
              final picked = _myChoice == opt.key;
              final pct = total > 0 ? opt.votes / total : 0.0;
              final pctLabel = '${(pct * 100).round()}%';
              final canVote =
                  _myChoice == null && !_voting && widget.pseudo.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: canVote ? () => _vote(opt.key) : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        // Background
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: _C.cardAlt,
                            border: Border.all(
                              color: picked
                                  ? _C.accentBr.withValues(alpha: 0.6)
                                  : _C.border,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        // Fill bar
                        if (_myChoice != null)
                          FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: picked
                                    ? _C.accentBr.withValues(alpha: 0.13)
                                    : _C.fg3.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        // Content
                        SizedBox(
                          height: 36,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                if (picked)
                                  Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.check,
                                      size: 13,
                                      color: _C.accentBr,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    opt.label,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: picked
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _C.fg1,
                                    ),
                                  ),
                                ),
                                if (_myChoice != null)
                                  Text(
                                    '$pctLabel · ${opt.votes} votes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: picked ? _C.accentBr : _C.fg2,
                                    ),
                                  )
                                else if (_voting && _myChoice == null)
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _C.accentBr,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Game card (Jeux page) ─────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  final bool locked;
  final String? duelLabel;
  final VoidCallback? onDuelTap;

  const _GameCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.locked = false,
    this.duelLabel,
    this.onDuelTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.4 : 1.0,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: locked ? null : onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: _C.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        locked ? Icons.lock_outline : icon,
                        color: locked ? _C.fg3 : accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: _C.fg1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            locked ? 'Bientôt disponible' : subtitle,
                            style: TextStyle(fontSize: 12.5, color: _C.fg2),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: _C.fg3, size: 20),
                  ],
                ),
              ),
            ),
          ),
          if (duelLabel != null && onDuelTap != null && !locked) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onDuelTap,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _C.cardAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF58A6FF).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('⚔️', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 10),
                        Text(
                          duelLabel!,
                          style: const TextStyle(
                            color: Color(0xFF58A6FF),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right, color: _C.fg3, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Community feed page ───────────────────────────────────────────────────────

class _CommunityFeedPage extends StatelessWidget {
  const _CommunityFeedPage();

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: _C.card,
        elevation: 0,
        title: Text(
          'Activité de la commu',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _C.fg1,
          ),
        ),
        iconTheme: IconThemeData(color: _C.fg1),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.border),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('feed')
            .orderBy('createdAt', descending: true)
            .limit(40)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(child: CircularProgressIndicator(color: _C.accentBr));
          }
          final seen1v1 = <String>{};
          final docs = snap.data!.docs
              .where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final type = d['gameType'] as String?;
                if (type != 'multiplayerCompos' &&
                    type != 'multiplayerCoupDoeil')
                  return true;
                final p1 = d['pseudo'] as String? ?? '';
                final p2 = d['opponentPseudo'] as String? ?? '';
                final matchKey = (d['matchName'] ?? d['category'] ?? '') as String;
                final pair = ([p1, p2]..sort()).join('-');
                return seen1v1.add('$type-$pair-$matchKey');
              })
              .take(25)
              .toList();

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Aucune activité pour le moment.',
                style: TextStyle(color: _C.fg2),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final pseudo = d['pseudo'] as String? ?? '?';
              final gameType = d['gameType'] as String? ?? '';
              final diff = d['difficulty'] as String? ?? '';
              final score = d['score'] as int? ?? 0;
              final matchName = d['matchName'] as String?;
              final category = d['category'] as String?;
              final opponentPseudo = d['opponentPseudo'] as String?;
              final won = d['won'] as bool?;
              final ts = d['createdAt'] as Timestamp?;
              final ago = ts != null ? _timeAgo(ts.toDate()) : '';
              final is1v1Compos = gameType == 'multiplayerCompos';
              final is1v1Cdo = gameType == 'multiplayerCoupDoeil';
              final is1v1 = is1v1Compos || is1v1Cdo;
              final isCompos = gameType == 'compos';
              final isQuiAMenti = gameType == 'quiAMenti';
              final emoji = is1v1Compos
                  ? '⚔️'
                  : is1v1Cdo
                  ? '⚔️'
                  : isCompos
                  ? '⚽'
                  : '👁️';
              final String? claim = d['claim'] as String?;
              final detail = isQuiAMenti
                  ? (claim ?? '')
                  : (matchName ?? category ?? '');

              Widget mainText;
              if (is1v1) {
                final opp = opponentPseudo ?? '?';
                final line = won == null
                    ? '$pseudo vs $opp'
                    : won
                    ? '🏆 $pseudo a battu $opp'
                    : '🏆 $opp a battu $pseudo';
                mainText = Text(
                  line,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.fg1,
                  ),
                );
              } else {
                final scoreStr = isCompos ? '$score%' : '${score}pts';
                mainText = RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: _C.fg1),
                    children: [
                      TextSpan(
                        text: pseudo,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  $scoreStr',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _C.accentBr,
                        ),
                      ),
                      if (!isCompos &&
                          !isQuiAMenti &&
                          diff.isNotEmpty &&
                          diff != 'Standard')
                        TextSpan(
                          text: ' · $diff',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _C.fg2,
                          ),
                        ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _C.card,
                  border: Border.all(color: _C.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        border: Border.all(color: _C.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: isQuiAMenti
                          ? Icon(Icons.gavel, size: 15, color: _C.orange)
                          : Text(
                              emoji,
                              style: const TextStyle(fontSize: 15, height: 1),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          mainText,
                          if (detail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              detail,
                              style: TextStyle(fontSize: 11.5, color: _C.fg2),
                              maxLines: isQuiAMenti ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(ago, style: TextStyle(fontSize: 10.5, color: _C.fg2)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
