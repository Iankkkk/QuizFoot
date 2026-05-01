import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../data/players_data.dart';

const _difficulties = ['Amateur', 'Semi-Pro', 'Pro', 'International', 'Légende'];

class ClassementPage extends StatefulWidget {
  final String pseudo;
  const ClassementPage({super.key, required this.pseudo});

  @override
  State<ClassementPage> createState() => _ClassementPageState();
}

class _ClassementPageState extends State<ClassementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text(
              'Classement',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                color: AppColors.accentBright,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.black,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(text: "Coup d'Œil"),
                Tab(text: 'Compos'),
                Tab(text: 'Compos 1v1'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _LeaderboardTab(gameType: 'coupDoeil', myPseudo: widget.pseudo),
                _ComposOverallTab(myPseudo: widget.pseudo),
                _MultiplayerDuelsTab(myPseudo: widget.pseudo),
              ],
            ),
          ),
        ],
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
      final cats = players
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBright : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accentBright : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
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
        // ── Difficulty pills ───────────────────────────────────────────────
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
        // ── Category dropdown (Coup d'Œil only) ───────────────────────────
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
                  color: _selectedCategory != null ? AppColors.accentBright : AppColors.border,
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
                    ..._categories.map((c) => DropdownMenuItem<String?>(
                          value: c,
                          child: Text(c),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        // ── Leaderboard ────────────────────────────────────────────────────
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

        // Moyenne des scores par pseudo
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
          for (final e in totals.entries)
            e.key: e.value / games[e.key]!,
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

        return ListView.builder(
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

  Color get _rankColor {
    if (rank == 1) return Color(0xFFFFD700);
    if (rank == 2) return Color(0xFFC0C0C0);
    if (rank == 3) return Color(0xFFCD7F32);
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMe ? AppColors.accentBright.withValues(alpha: 0.1) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? AppColors.accentBright : AppColors.border,
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              rank <= 3 ? _medal(rank) : '$rank',
              style: TextStyle(
                color: _rankColor,
                fontWeight: FontWeight.w800,
                fontSize: rank <= 3 ? 18 : 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pseudo,
                  style: TextStyle(
                    color:
                        isMe ? AppColors.accentBright : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
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
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            gameType == 'compos' ? '%' : 'pts',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _medal(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    return '🥉';
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
          return Center(child: CircularProgressIndicator(color: AppColors.accentBright));
        }
        if (snap.hasError) {
          return Center(
            child: Text('Erreur de chargement', style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        // Moyenne des normalizedScore par pseudo, toutes difficultés confondues
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
            child: Text('Aucun score encore.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          );
        }

        final ranked = totals.entries
            .map((e) => MapEntry(e.key, e.value / counts[e.key]!))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
          .where('details.won', isEqualTo: true)
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

        // Agréger les victoires par pseudo
        final Map<String, int> winsByPseudo = {};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final pseudo = data['pseudo'] as String? ?? '?';
          winsByPseudo[pseudo] = (winsByPseudo[pseudo] ?? 0) + 1;
        }
        final ranked = winsByPseudo.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          itemCount: ranked.length,
          itemBuilder: (context, i) {
            final entry = ranked[i];
            final pseudo = entry.key;
            final wins = entry.value;
            final isMe = pseudo == myPseudo;
            final rank = i + 1;
            const gold   = Color(0xFFFFD700);
            const silver = Color(0xFFB0B0B0);
            const bronze = Color(0xFFCD7F32);
            final medalColor = rank == 1 ? gold : rank == 2 ? silver : rank == 3 ? bronze : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.accentBright.withValues(alpha: 0.06)
                    : AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMe ? AppColors.accentBright : AppColors.border,
                  width: isMe ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: medalColor != null
                        ? Text(
                            rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                            style: TextStyle(fontSize: 18),
                          )
                        : Text(
                            '$rank',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pseudo,
                      style: TextStyle(
                        color: isMe ? AppColors.accentBright : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '$wins victoire${wins > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: AppColors.accentBright,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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

class _PseudoChip extends StatelessWidget {
  final String pseudo;
  final bool isWinner;
  final bool isMe;
  const _PseudoChip({required this.pseudo, required this.isWinner, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final color = isWinner ? AppColors.accentBright : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isWinner)
          Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text('🏆', style: TextStyle(fontSize: 12)),
          ),
        Text(
          pseudo,
          style: TextStyle(
            color: isMe ? AppColors.accentBright : color,
            fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
