import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../data/players_data.dart';
import 'duels_page.dart';
import 'package:quiz_foot/utils/navigation.dart';

const _difficulties = [
  'Amateur',
  'Semi-Pro',
  'Pro',
  'International',
  'Légende',
];

const _gold = Color(0xFFFFB800);
const _silver = Color(0xFF9E9E9E);
const _bronze = Color(0xFFCD7F32);

Color _rankColor(int rank) {
  if (rank == 1) return _gold;
  if (rank == 2) return _silver;
  if (rank == 3) return _bronze;
  return AppColors.border;
}

Color _rankBg(int rank) {
  if (rank == 1) return _gold.withOpacity(0.08);
  if (rank == 2) return _silver.withOpacity(0.06);
  if (rank == 3) return _bronze.withOpacity(0.07);
  return AppColors.card;
}

// ─────────────────────────────────────────────────────────────────────────────

class ClassementPage extends StatefulWidget {
  final String pseudo;
  const ClassementPage({super.key, required this.pseudo});

  @override
  State<ClassementPage> createState() => _ClassementPageState();
}

class _ClassementPageState extends State<ClassementPage> {
  int _selectedTab = 0;

  static const _tabs = [
    "Coup d'Œil",
    'Compos',
    'Compos 1v1',
    "Coup d'Œil 1v1",
    'Qui a menti ?',
  ];

  static const _tabEmojis = ['👁️', '⚽', '⚔️⚽', '⚔️👁️', '🎭'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Text(
                  'Classement',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    namedRoute(DuelsPage(myPseudo: widget.pseudo)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentBright.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accentBright.withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('⚔️', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        Text(
                          'Duels',
                          style: TextStyle(
                            color: AppColors.accentBright,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tab selector ────────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(
                _tabs.length,
                (i) => Padding(
                  padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
                  child: _GameTab(
                    label: _tabs[i],
                    emoji: _tabEmojis[i],
                    selected: _selectedTab == i,
                    onTap: () => setState(() => _selectedTab = i),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Content ─────────────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _LeaderboardTab(gameType: 'coupDoeil', myPseudo: widget.pseudo),
                _ComposOverallTab(myPseudo: widget.pseudo),
                _MultiplayerDuelsTab(myPseudo: widget.pseudo),
                _CdoDuelsTab(myPseudo: widget.pseudo),
                _QuiAMentiLeaderboardTab(myPseudo: widget.pseudo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GameTab extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _GameTab({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBright : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accentBright : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14, height: 1)),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared rank badge circle

class _RankBadge extends StatelessWidget {
  final int rank;
  final bool isMe;
  const _RankBadge({required this.rank, required this.isMe});

  Color get _color {
    if (rank <= 3) return _rankColor(rank);
    if (isMe) return AppColors.accentBright;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: rank <= 3
            ? _rankColor(rank).withOpacity(0.12)
            : (isMe ? AppColors.accentBright.withOpacity(0.1) : AppColors.bg),
        border: Border.all(
          color: _color.withOpacity(rank <= 3 ? 0.7 : 0.4),
          width: 1.5,
        ),
      ),
      child: Center(
        child: rank == 1
            ? Text('🥇', style: TextStyle(fontSize: 18, height: 1))
            : rank == 2
            ? Text('🥈', style: TextStyle(fontSize: 18, height: 1))
            : rank == 3
            ? Text('🥉', style: TextStyle(fontSize: 18, height: 1))
            : Text(
                '$rank',
                style: TextStyle(
                  color: _color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardTab extends StatefulWidget {
  final String gameType;
  final String myPseudo;
  const _LeaderboardTab({required this.gameType, required this.myPseudo});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  String _selectedDifficulty = 'Pro';
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    if (widget.gameType == 'coupDoeil') _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final players = await loadPlayers();
      final cats =
          players
              .expand((p) => p.categories)
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Widget _buildPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBright : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accentBright : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Difficulty pills
        SizedBox(
          height: 36,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _difficulties.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = _difficulties[i];
              return _buildPill(
                label: d,
                selected: d == _selectedDifficulty,
                onTap: () => setState(() => _selectedDifficulty = d),
              );
            },
          ),
        ),
        // Category dropdown (Coup d'Œil only)
        if (widget.gameType == 'coupDoeil' && _categories.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedCategory != null
                      ? AppColors.accentBright
                      : AppColors.border,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedCategory,
                  isDense: true,
                  dropdownColor: AppColors.card,
                  iconEnabledColor: AppColors.textSecondary,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                  hint: Text(
                    'Toutes catégories',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Toutes catégories'),
                    ),
                    ..._categories.map(
                      (c) =>
                          DropdownMenuItem<String?>(value: c, child: Text(c)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: _LeaderboardList(
            gameType: widget.gameType,
            difficulty: _selectedDifficulty,
            category: widget.gameType == 'coupDoeil' ? _selectedCategory : null,
            myPseudo: widget.myPseudo,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardList extends StatelessWidget {
  final String gameType;
  final String difficulty;
  final String? category;
  final String myPseudo;

  const _LeaderboardList({
    required this.gameType,
    required this.difficulty,
    this.category,
    required this.myPseudo,
  });

  @override
  Widget build(BuildContext context) {
    var query = FirebaseFirestore.instance
        .collection('scores')
        .where('gameType', isEqualTo: gameType)
        .where('difficulty', isEqualTo: difficulty);
    if (category != null) query = query.where('category', isEqualTo: category);

    return FutureBuilder<QuerySnapshot>(
      future: query.get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.accentBright),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Erreur de chargement',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        final Map<String, double> totals = {};
        final Map<String, int> games = {};
        for (final doc in snap.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final pseudo = data['pseudo'] as String? ?? '?';
          final score = (data['normalizedScore'] as num?)?.toDouble() ?? 0;
          totals[pseudo] = (totals[pseudo] ?? 0) + score;
          games[pseudo] = (games[pseudo] ?? 0) + 1;
        }
        final Map<String, double> bests = {
          for (final e in totals.entries) e.key: e.value / games[e.key]!,
        };

        if (bests.isEmpty) {
          return Center(
            child: Text(
              'Aucun score encore dans ce niveau.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          );
        }

        final ranked = bests.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Score moyen par partie',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: ranked.length,
                itemBuilder: (context, i) {
                  final entry = ranked[i];
                  return _LeaderboardRow(
                    rank: i + 1,
                    pseudo: entry.key,
                    score: entry.value,
                    games: games[entry.key] ?? 0,
                    isMe: entry.key == myPseudo,
                    gameType: gameType,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String pseudo;
  final double score;
  final int games;
  final bool isMe;
  final String gameType;

  const _LeaderboardRow({
    required this.rank,
    required this.pseudo,
    required this.score,
    required this.games,
    required this.isMe,
    required this.gameType,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTop3 = rank <= 3;
    final Color borderColor = isMe
        ? AppColors.accentBright
        : isTop3
        ? _rankColor(rank)
        : AppColors.border;
    final Color bgColor = isMe && !isTop3
        ? AppColors.accentBright.withOpacity(0.07)
        : isTop3
        ? _rankBg(rank)
        : AppColors.card;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: (isTop3 || isMe) ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          _RankBadge(rank: rank, isMe: isMe),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pseudo,
                  style: TextStyle(
                    color: isMe
                        ? AppColors.accentBright
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$games partie${games > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  color: isTop3 ? _rankColor(rank) : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                gameType == 'compos' ? '%' : 'pts',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ComposOverallTab extends StatelessWidget {
  final String myPseudo;
  const _ComposOverallTab({required this.myPseudo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('scores')
          .where('gameType', isEqualTo: 'compos')
          .get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.accentBright),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Erreur de chargement',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        final Map<String, double> totals = {};
        final Map<String, int> counts = {};
        for (final doc in snap.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          final pseudo = d['pseudo'] as String? ?? '?';
          final score = (d['normalizedScore'] as num?)?.toDouble() ?? 0;
          totals[pseudo] = (totals[pseudo] ?? 0) + score;
          counts[pseudo] = (counts[pseudo] ?? 0) + 1;
        }

        if (totals.isEmpty) {
          return Center(
            child: Text(
              'Aucun score encore.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          );
        }

        final ranked =
            totals.entries
                .map((e) => MapEntry(e.key, e.value / counts[e.key]!))
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Score moyen par partie',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                itemCount: ranked.length,
                itemBuilder: (_, i) {
                  final entry = ranked[i];
                  return _LeaderboardRow(
                    rank: i + 1,
                    pseudo: entry.key,
                    score: entry.value,
                    games: counts[entry.key] ?? 0,
                    isMe: entry.key == myPseudo,
                    gameType: 'compos',
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MultiplayerDuelsTab extends StatelessWidget {
  final String myPseudo;
  const _MultiplayerDuelsTab({required this.myPseudo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('scores')
          .where('gameType', isEqualTo: 'multiplayerCompos')
          .get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.accentBright),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Erreur de chargement',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'Aucun duel encore joué.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          );
        }

        final Map<String, int> winsByPseudo = {};
        final Map<String, int> lossesByPseudo = {};
        final Map<String, int> foundByPseudo = {};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final pseudo = data['pseudo'] as String? ?? '?';
          final details = data['details'] as Map<String, dynamic>? ?? {};
          if (details['abandoned'] == true) continue;
          final won = details['won'] as bool? ?? false;
          final draw = details['draw'] as bool? ?? false;
          final found = (details['foundByMe'] as num?)?.toInt() ?? 0;
          winsByPseudo[pseudo] = (winsByPseudo[pseudo] ?? 0) + (won ? 1 : 0);
          lossesByPseudo[pseudo] =
              (lossesByPseudo[pseudo] ?? 0) + (!won && !draw ? 1 : 0);
          foundByPseudo[pseudo] = (foundByPseudo[pseudo] ?? 0) + found;
        }
        final ranked = winsByPseudo.entries.toList()
          ..sort((a, b) {
            final cmp = b.value.compareTo(a.value);
            if (cmp != 0) return cmp;
            final lossDiff = (lossesByPseudo[a.key] ?? 0).compareTo(
              lossesByPseudo[b.key] ?? 0,
            );
            if (lossDiff != 0) return lossDiff;
            return (foundByPseudo[b.key] ?? 0).compareTo(
              foundByPseudo[a.key] ?? 0,
            );
          });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          itemCount: ranked.length,
          itemBuilder: (context, i) {
            final entry = ranked[i];
            final pseudo = entry.key;
            final wins = entry.value;
            final losses = lossesByPseudo[pseudo] ?? 0;
            final found = foundByPseudo[pseudo] ?? 0;
            final isMe = pseudo == myPseudo;
            final rank = i + 1;
            final isTop3 = rank <= 3;
            final borderColor = isMe
                ? AppColors.accentBright
                : isTop3
                ? _rankColor(rank)
                : AppColors.border;
            final bgColor = isMe && !isTop3
                ? AppColors.accentBright.withOpacity(0.07)
                : isTop3
                ? _rankBg(rank)
                : AppColors.card;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: (isTop3 || isMe) ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  _RankBadge(rank: rank, isMe: isMe),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pseudo,
                      style: TextStyle(
                        color: isMe
                            ? AppColors.accentBright
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${wins}V',
                              style: TextStyle(
                                color: wins > 0
                                    ? AppColors.accentBright
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            TextSpan(
                              text: '  ·  ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: '${losses}D',
                              style: TextStyle(
                                color: losses > 0
                                    ? AppColors.red
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (wins == 0 && losses == 0)
                        Text(
                          '$found trouvé${found > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CdoDuelsTab extends StatefulWidget {
  final String myPseudo;
  const _CdoDuelsTab({required this.myPseudo});

  @override
  State<_CdoDuelsTab> createState() => _CdoDuelsTabState();
}

class _CdoDuelsTabState extends State<_CdoDuelsTab> {
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final players = await loadPlayers();
      final cats =
          players
              .expand((p) => p.categories)
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Widget _buildPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBright : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accentBright : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_categories.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _buildPill(
                    label: 'Toutes',
                    selected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  );
                }
                final cat = _categories[i - 1];
                return _buildPill(
                  label: cat,
                  selected: _selectedCategory == cat,
                  onTap: () => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: _CdoDuelsList(
            myPseudo: widget.myPseudo,
            category: _selectedCategory,
          ),
        ),
      ],
    );
  }
}

class _CdoDuelsList extends StatelessWidget {
  final String myPseudo;
  final String? category;
  const _CdoDuelsList({required this.myPseudo, this.category});

  @override
  Widget build(BuildContext context) {
    var query = FirebaseFirestore.instance
        .collection('scores')
        .where('gameType', isEqualTo: 'multiplayerCoupDoeil');
    if (category != null) query = query.where('category', isEqualTo: category);

    return FutureBuilder<QuerySnapshot>(
      future: query.get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.accentBright),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Erreur de chargement',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'Aucun duel encore joué.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          );
        }

        final Map<String, int> wins = {};
        final Map<String, int> losses = {};
        final Map<String, int> totalScore = {};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final pseudo = data['pseudo'] as String? ?? '?';
          final details = data['details'] as Map<String, dynamic>? ?? {};
          if (details['abandoned'] == true) continue;
          final won = details['won'] as bool? ?? false;
          final draw = details['draw'] as bool? ?? false;
          final score = (details['myScore'] as num?)?.toInt() ?? 0;
          wins[pseudo] = (wins[pseudo] ?? 0) + (won ? 1 : 0);
          losses[pseudo] = (losses[pseudo] ?? 0) + (!won && !draw ? 1 : 0);
          totalScore[pseudo] = (totalScore[pseudo] ?? 0) + score;
        }

        final ranked = wins.entries.toList()
          ..sort((a, b) {
            final cmp = b.value.compareTo(a.value);
            if (cmp != 0) return cmp;
            final lossDiff = (losses[a.key] ?? 0).compareTo(losses[b.key] ?? 0);
            if (lossDiff != 0) return lossDiff;
            return (totalScore[b.key] ?? 0).compareTo(totalScore[a.key] ?? 0);
          });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          itemCount: ranked.length,
          itemBuilder: (context, i) {
            final entry = ranked[i];
            final pseudo = entry.key;
            final w = entry.value;
            final l = losses[pseudo] ?? 0;
            final isMe = pseudo == myPseudo;
            final rank = i + 1;
            final isTop3 = rank <= 3;
            final borderColor = isMe
                ? AppColors.accentBright
                : isTop3
                ? _rankColor(rank)
                : AppColors.border;
            final bgColor = isMe && !isTop3
                ? AppColors.accentBright.withOpacity(0.07)
                : isTop3
                ? _rankBg(rank)
                : AppColors.card;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: (isTop3 || isMe) ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  _RankBadge(rank: rank, isMe: isMe),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pseudo,
                      style: TextStyle(
                        color: isMe
                            ? AppColors.accentBright
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${w}V',
                          style: TextStyle(
                            color: w > 0
                                ? AppColors.accentBright
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        TextSpan(
                          text: '  ·  ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: '${l}D',
                          style: TextStyle(
                            color: l > 0
                                ? AppColors.red
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _QuiAMentiLeaderboardTab extends StatelessWidget {
  final String myPseudo;
  const _QuiAMentiLeaderboardTab({required this.myPseudo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('scores')
          .where('gameType', isEqualTo: 'quiAMenti')
          .get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.accentBright),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Erreur de chargement',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'Aucun score encore.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          );
        }

        final Map<String, int> wins = {};
        final Map<String, int> losses = {};
        final Map<String, double> totalPts = {};
        final Map<String, int> counts = {};

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final pseudo = d['pseudo'] as String? ?? '?';
          final raw = (d['rawScore'] as num?)?.toInt() ?? 0;
          final details = d['details'] as Map<String, dynamic>? ?? {};
          // Victoire uniquement si 10/10 — le rawScore seul ne suffit pas
          // car 8/10 rapporte 15 pts (raw > 0) mais reste une défaite.
          final correctCount = (details['correctCount'] as num?)?.toInt() ?? -1;
          final won = correctCount == 10;
          wins[pseudo] = (wins[pseudo] ?? 0) + (won ? 1 : 0);
          losses[pseudo] = (losses[pseudo] ?? 0) + (won ? 0 : 1);
          totalPts[pseudo] = (totalPts[pseudo] ?? 0) + raw;
          counts[pseudo] = (counts[pseudo] ?? 0) + 1;
        }

        final ranked = wins.entries.toList()
          ..sort((a, b) {
            final cmp = b.value.compareTo(a.value);
            if (cmp != 0) return cmp;
            final avgA = (totalPts[a.key] ?? 0) / (counts[a.key] ?? 1);
            final avgB = (totalPts[b.key] ?? 0) / (counts[b.key] ?? 1);
            return avgB.compareTo(avgA);
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Classé par nombre de victoires',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: ranked.length,
                itemBuilder: (_, i) {
                  final pseudo = ranked[i].key;
                  final w = ranked[i].value;
                  final l = losses[pseudo] ?? 0;
                  final avg = (totalPts[pseudo] ?? 0) / (counts[pseudo] ?? 1);
                  final total = counts[pseudo] ?? 0;
                  final isMe = pseudo == myPseudo;
                  final rank = i + 1;
                  final isTop3 = rank <= 3;
                  final borderColor = isMe
                      ? AppColors.accentBright
                      : isTop3
                      ? _rankColor(rank)
                      : AppColors.border;
                  final bgColor = isMe && !isTop3
                      ? AppColors.accentBright.withOpacity(0.07)
                      : isTop3
                      ? _rankBg(rank)
                      : AppColors.card;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: (isTop3 || isMe) ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _RankBadge(rank: rank, isMe: isMe),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pseudo,
                                style: TextStyle(
                                  color: isMe
                                      ? AppColors.accentBright
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '$total partie${total > 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${w}V',
                                    style: TextStyle(
                                      color: w > 0
                                          ? AppColors.accentBright
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  ·  ',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '${l}D',
                                    style: TextStyle(
                                      color: l > 0
                                          ? AppColors.red
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${avg.toStringAsFixed(1)} pts moy.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

