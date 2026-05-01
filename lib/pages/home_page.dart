import 'package:flutter/material.dart';
import 'coup_doeil/quiz_test.dart';
import 'coup_doeil/quiz_test_intro.dart';
import 'package:quiz_foot/pages/lineup/lineup_match_page_intro.dart';
import 'multiplayer/multiplayer_lobby_page.dart';
import 'package:quiz_foot/data/anecdotes_data.dart';
import 'package:quiz_foot/data/players_data.dart';
import 'package:quiz_foot/data/data_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../services/game_history_service.dart';
import '../models/game_result.dart';
import 'profil_page.dart';
import 'classement_page.dart';

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

  // Stat communauté (Firestore)
  int _communityGames = 0;

  @override
  void initState() {
    super.initState();
    _loadAnecdote();
    _warmCache();
    _loadPseudo();
    _loadStats();
    _loadCommunityStats();
  }

  Future<void> _loadPseudo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _pseudo = prefs.getString('pseudo') ?? '');
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
    setState(() {
      _totalGames = results.length;
      _totalTime = totalTime;
      _favGame = fav;
    });
  }

  String _formatTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h${m}min';
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
        setState(() {
          _randomAnecdote = (anecdotes..shuffle()).first;
        });
      }
    } catch (_) {}
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) _loadStats();
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

  Widget _buildHomeContent() {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 28),

            // ── Header ──────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: Opacity(
                opacity: 0.25,
                child: IconButton(
                  onPressed: _clearCache,
                  icon: Icon(
                    Icons.refresh,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white,
                      border: Border.all(color: AppColors.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.4),
                          blurRadius: 40,
                          spreadRadius: 6,
                          offset: const Offset(0, 0),
                        ),
                        BoxShadow(
                          color: AppColors.accentBright.withOpacity(0.15),
                          blurRadius: 70,
                          spreadRadius: 10,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset('assets/images/logo.png'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'TEMPO',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      letterSpacing: 4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Le jeu, dans la tête.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Anecdote ────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.campaign_rounded,
                        color: AppColors.accentBright,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Anecdote du jour',
                        style: TextStyle(
                          color: AppColors.accentBright,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _randomAnecdote.isEmpty
                      ? SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentBright,
                          ),
                        )
                      : Text(
                          _randomAnecdote,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Stats ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tes stats',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(label: 'Parties jouées', value: '$_totalGames'),
                      _StatItem(
                        label: 'Temps total',
                        value: _totalGames > 0 ? _formatTime(_totalTime) : '—',
                      ),
                      _StatItem(label: 'Jeu préféré', value: _favGame),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Feed activité ─────────────────────────────────────
            _buildFeed(),

            const SizedBox(height: 24),

            // ── À la une ─────────────────────────────────────────
            Text(
              'À la une',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                children: [
                  const _HighlightCard(
                    title: '🔥 Nouveau mode Compos',
                    subtitle:
                        'Revis les matchs mythiques et devine les compos !',
                  ),
                  _HighlightCard(
                    title: '⭐ $_communityGames parties jouées',
                    subtitle: 'Merci à la communauté Tempo !',
                  ),
                  const _HighlightCard(
                    title: '⚽ Zidane ou Platini ?',
                    subtitle: 'Teste ton flair dans Qui a menti ?',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feed')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
        // Dédupliquer les parties 1v1 (2 docs par partie, un par joueur)
        final seen1v1 = <String>{};
        final docs = snap.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          if ((d['gameType'] as String?) != 'multiplayerCompos') return true;
          final key = d['matchName'] as String? ?? doc.id;
          return seen1v1.add(key);
        }).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activité récente',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final pseudo = d['pseudo'] as String? ?? '?';
              final gameType = d['gameType'] as String? ?? '';
              final diff = d['difficulty'] as String? ?? '';
              final score = d['score'] as int? ?? 0;
              final maxScore = d['maxScore'] as int? ?? 0;
              final category = d['category'] as String?;
              final matchName = d['matchName'] as String?;
              final opponentPseudo = d['opponentPseudo'] as String?;
              final ts = d['createdAt'] as Timestamp?;
              final ago = ts != null ? _timeAgo(ts.toDate()) : '';
              final is1v1 = gameType == 'multiplayerCompos';
              final isCompos = gameType == 'compos' || is1v1;
              final icon = is1v1
                  ? '🆚'
                  : isCompos
                  ? '⚽'
                  : '🎯';
              final scoreStr = isCompos ? '$score/$maxScore' : '${score}pts';
              final detail = matchName ?? category ?? '';
              final playerLabel = is1v1 && opponentPseudo != null
                  ? '$pseudo vs $opponentPseudo'
                  : pseudo;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Text(icon, style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: playerLabel,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: '  $scoreStr · $diff'),
                            if (detail.isNotEmpty) TextSpan(text: ' · $detail'),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      ago,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }

  Widget _buildGamesPage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jeux',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choisis ton mode de jeu',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _GameButton(
              title: "Coup d'œil",
              subtitle: 'Reconnais le joueur grâce à sa photo',
              icon: Icons.remove_red_eye_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => QuizTestIntro()),
              ),
            ),
            const SizedBox(height: 12),
            _GameButton(
              title: 'Qui a menti ?',
              subtitle: '1 affirmation, 10 joueurs : 5 menteurs !',
              icon: Icons.psychology_alt_outlined,
              locked: true,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _GameButton(
              title: 'Parcours Joueur',
              subtitle: 'Retrouve le joueur grâce à sa carrière',
              icon: Icons.emoji_events_outlined,
              locked: true,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _GameButton(
              title: 'Compos',
              subtitle:
                  'Retrouve les compositions d\'équipes d\'un match historique',
              icon: Icons.view_module_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LineupMatchPageIntro()),
              ),
            ),
            const SizedBox(height: 12),
            _GameButton(
              title: 'Compos 1v1',
              subtitle: 'Affronte un ami en temps réel',
              icon: Icons.people_outline,
              accent: Color(0xFF58A6FF),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MultiplayerLobbyPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _buildContent(),
      persistentFooterButtons: [
        Container(
          height: 40,
          width: double.infinity,
          color: AppColors.card,
          alignment: Alignment.center,
          child: Text(
            'PUB',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        selectedItemColor: AppColors.accentBright,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.card,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer),
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

// ── Widgets ────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.accentBright,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HighlightCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool locked;
  final Color? accent;
  const _GameButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.locked = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.45 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: locked ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: locked
                        ? AppColors.textSecondary
                        : (accent ?? AppColors.accentBright),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        locked ? 'Bientôt disponible' : subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  locked ? Icons.lock_outline : Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Legacy helpers (still used by other pages) ─────────────────────

void _showDifficultyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Choisis la difficulté"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _difficultyButton(context, "Amateur"),
          _difficultyButton(context, "Semi-Pro"),
          _difficultyButton(context, "Pro"),
          _difficultyButton(context, "International"),
          _difficultyButton(context, "Légende"),
        ],
      ),
    ),
  );
}

Widget _difficultyButton(BuildContext context, String difficulty) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizTest(difficulty: difficulty),
          ),
        );
      },
      child: Text(difficulty),
    ),
  );
}
