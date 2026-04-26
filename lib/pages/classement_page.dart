import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';

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
    _tab = TabController(length: 2, vsync: this);
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
          const Padding(
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
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: "Coup d'Œil"),
                Tab(text: 'Compos'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _LeaderboardTab(gameType: 'coupDoeil', myPseudo: widget.pseudo),
                _LeaderboardTab(gameType: 'compos', myPseudo: widget.pseudo),
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
              final selected = d == _selectedDifficulty;
              return GestureDetector(
                onTap: () => setState(() => _selectedDifficulty = d),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accentBright : AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.accentBright
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    d,
                    style: TextStyle(
                      color: selected ? Colors.black : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // ── Leaderboard ────────────────────────────────────────────────────
        Expanded(
          child: _LeaderboardList(
            gameType: widget.gameType,
            difficulty: _selectedDifficulty,
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
  final String myPseudo;

  const _LeaderboardList({
    required this.gameType,
    required this.difficulty,
    required this.myPseudo,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('scores')
          .where('gameType', isEqualTo: gameType)
          .where('difficulty', isEqualTo: difficulty)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentBright),
          );
        }
        if (snap.hasError) {
          return const Center(
            child: Text(
              'Erreur de chargement',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        // Meilleur score par pseudo
        final Map<String, double> bests = {};
        final Map<String, int> games = {};
        for (final doc in snap.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final pseudo = data['pseudo'] as String? ?? '?';
          final score = (data['normalizedScore'] as num?)?.toDouble() ?? 0;
          if (!bests.containsKey(pseudo) || score > bests[pseudo]!) {
            bests[pseudo] = score;
          }
          games[pseudo] = (games[pseudo] ?? 0) + 1;
        }

        if (bests.isEmpty) {
          return const Center(
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

  const _LeaderboardRow({
    required this.rank,
    required this.pseudo,
    required this.score,
    required this.games,
    required this.isMe,
  });

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
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
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            score.toStringAsFixed(0),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'pts',
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
