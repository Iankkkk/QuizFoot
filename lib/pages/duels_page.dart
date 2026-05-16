import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';

class DuelsPage extends StatefulWidget {
  final String myPseudo;
  const DuelsPage({super.key, required this.myPseudo});

  @override
  State<DuelsPage> createState() => _DuelsPageState();
}

class _DuelsPageState extends State<DuelsPage> {
  String? _playerA;
  String? _playerB;
  List<String> _allPseudos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPseudosAndDefault();
  }

  Future<void> _loadPseudosAndDefault() async {
    try {
      // Charger toutes les parties 1v1 (Compos + Coup d'œil)
      final compos = await FirebaseFirestore.instance
          .collection('scores')
          .where('gameType', isEqualTo: 'multiplayerCompos')
          .get();
      final cdo = await FirebaseFirestore.instance
          .collection('scores')
          .where('gameType', isEqualTo: 'multiplayerCoupDoeil')
          .get();

      final pseudos = <String>{};
      final opponentCount = <String, int>{};
      for (final doc in [...compos.docs, ...cdo.docs]) {
        final d = doc.data();
        final p = d['pseudo'] as String? ?? '';
        final details = d['details'] as Map<String, dynamic>? ?? {};
        final opp = details['opponentPseudo'] as String? ?? '';
        if (p.isNotEmpty) pseudos.add(p);
        if (opp.isNotEmpty) pseudos.add(opp);

        // Compter les adversaires de moi
        if (p == widget.myPseudo && opp.isNotEmpty) {
          opponentCount[opp] = (opponentCount[opp] ?? 0) + 1;
        } else if (opp == widget.myPseudo && p.isNotEmpty) {
          opponentCount[p] = (opponentCount[p] ?? 0) + 1;
        }
      }

      // Adversaire le plus joué par défaut
      String? topOpp;
      if (opponentCount.isNotEmpty) {
        topOpp = opponentCount.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
      }

      final list = pseudos.toList()..sort();

      if (mounted) {
        setState(() {
          _allPseudos = list;
          _playerA = list.contains(widget.myPseudo) ? widget.myPseudo : (list.isNotEmpty ? list.first : null);
          _playerB = topOpp ?? (list.length > 1 ? list.firstWhere((p) => p != _playerA, orElse: () => list[1]) : null);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Duels',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accentBright))
          : _allPseudos.length < 2
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      'Pas assez de joueurs pour comparer.\nJoue quelques duels d\'abord !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSelectors(),
                      const SizedBox(height: 24),
                      if (_playerA != null && _playerB != null && _playerA != _playerB)
                        _DuelStats(playerA: _playerA!, playerB: _playerB!)
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Center(
                            child: Text(
                              'Sélectionne deux joueurs différents',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSelectors() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown(
              value: _playerA,
              hint: 'Joueur A',
              onChanged: (v) => setState(() => _playerA = v),
              accent: AppColors.accentBright,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'VS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: _buildDropdown(
              value: _playerB,
              hint: 'Joueur B',
              onChanged: (v) => setState(() => _playerB = v),
              accent: const Color(0xFF58A6FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required ValueChanged<String?> onChanged,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          dropdownColor: AppColors.card,
          iconEnabledColor: AppColors.textSecondary,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          hint: Text(
            hint,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          items: _allPseudos.map((p) => DropdownMenuItem<String>(
                value: p,
                child: Text(p, overflow: TextOverflow.ellipsis),
              )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DuelStats extends StatelessWidget {
  final String playerA;
  final String playerB;
  const _DuelStats({required this.playerA, required this.playerB});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuerySnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance
            .collection('scores')
            .where('gameType', isEqualTo: 'multiplayerCompos')
            .where('pseudo', isEqualTo: playerA)
            .get(),
        FirebaseFirestore.instance
            .collection('scores')
            .where('gameType', isEqualTo: 'multiplayerCoupDoeil')
            .where('pseudo', isEqualTo: playerA)
            .get(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Filtrer les matches où l'adversaire est playerB (côté playerA, opponentPseudo = B)
        final composMatches = snap.data![0].docs.where((d) {
          final details = (d.data() as Map<String, dynamic>)['details'] as Map<String, dynamic>? ?? {};
          return details['opponentPseudo'] == playerB;
        }).toList();
        final cdoMatches = snap.data![1].docs.where((d) {
          final details = (d.data() as Map<String, dynamic>)['details'] as Map<String, dynamic>? ?? {};
          return details['opponentPseudo'] == playerB;
        }).toList();

        // Compter wins de A et de B
        int aWinsCompos = 0, bWinsCompos = 0;
        int aWinsCdo = 0, bWinsCdo = 0, drawsCdo = 0;
        for (final d in composMatches) {
          final details = (d.data() as Map<String, dynamic>)['details'] as Map<String, dynamic>? ?? {};
          final won = details['won'] as bool? ?? false;
          if (won) aWinsCompos++; else bWinsCompos++;
        }
        for (final d in cdoMatches) {
          final details = (d.data() as Map<String, dynamic>)['details'] as Map<String, dynamic>? ?? {};
          final won = details['won'] as bool? ?? false;
          final draw = details['draw'] as bool? ?? false;
          if (draw) drawsCdo++;
          else if (won) aWinsCdo++;
          else bWinsCdo++;
        }

        final totalA = aWinsCompos + aWinsCdo;
        final totalB = bWinsCompos + bWinsCdo;
        final totalGames = composMatches.length + cdoMatches.length;

        if (totalGames == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'Aucun duel entre $playerA et $playerB',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          );
        }

        // Récents matchs (mélange + tri par date desc)
        final allDocs = [...composMatches, ...cdoMatches];
        allDocs.sort((a, b) {
          final ta = (a.data() as Map<String, dynamic>)['playedAt'] as Timestamp?;
          final tb = (b.data() as Map<String, dynamic>)['playedAt'] as Timestamp?;
          if (ta == null || tb == null) return 0;
          return tb.compareTo(ta);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScoreCard(totalA, totalB, totalGames),
            const SizedBox(height: 16),
            _buildBreakdownCard(
              composA: aWinsCompos,
              composB: bWinsCompos,
              composTotal: composMatches.length,
              cdoA: aWinsCdo,
              cdoB: bWinsCdo,
              cdoDraws: drawsCdo,
              cdoTotal: cdoMatches.length,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'DERNIERS MATCHS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ...allDocs.take(15).map(_buildMatchRow),
          ],
        );
      },
    );
  }

  Widget _buildScoreCard(int totalA, int totalB, int totalGames) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildBigScore(playerA, totalA, AppColors.accentBright, isLeading: totalA > totalB)),
              Container(width: 1, height: 70, color: AppColors.border),
              Expanded(child: _buildBigScore(playerB, totalB, const Color(0xFF58A6FF), isLeading: totalB > totalA)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$totalGames duel${totalGames > 1 ? 's' : ''} joué${totalGames > 1 ? 's' : ''}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBigScore(String pseudo, int wins, Color color, {required bool isLeading}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLeading) ...[
              Text('🏆', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                pseudo,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$wins',
          style: TextStyle(
            color: color,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'victoire${wins > 1 ? 's' : ''}',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildBreakdownCard({
    required int composA,
    required int composB,
    required int composTotal,
    required int cdoA,
    required int cdoB,
    required int cdoDraws,
    required int cdoTotal,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (composTotal > 0)
            _breakdownRow('⚽⚔️', 'Compos 1v1', composA, composB, composTotal),
          if (composTotal > 0 && cdoTotal > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(height: 1, color: AppColors.border),
            ),
          if (cdoTotal > 0)
            _breakdownRow('👁️⚔️', "Coup d'Œil 1v1", cdoA, cdoB, cdoTotal, draws: cdoDraws),
        ],
      ),
    );
  }

  Widget _breakdownRow(String emoji, String label, int aWins, int bWins, int total, {int draws = 0}) {
    return Row(
      children: [
        Text(emoji, style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$total partie${total > 1 ? 's' : ''}${draws > 0 ? '  ·  $draws nul${draws > 1 ? 's' : ''}' : ''}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          '$aWins',
          style: TextStyle(
            color: aWins > bWins ? AppColors.accentBright : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('-', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ),
        Text(
          '$bWins',
          style: TextStyle(
            color: bWins > aWins ? const Color(0xFF58A6FF) : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildMatchRow(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final details = d['details'] as Map<String, dynamic>? ?? {};
    final type = d['gameType'] as String? ?? '';
    final ts = d['playedAt'] as Timestamp?;
    final won = details['won'] as bool? ?? false;
    final draw = details['draw'] as bool? ?? false;

    final isCompos = type == 'multiplayerCompos';
    final emoji = isCompos ? '⚽⚔️' : '👁️⚔️';
    final label = isCompos
        ? (details['matchName'] as String? ?? 'Compos')
        : (details['category'] as String? ?? 'Tous');

    final String tagText;
    final Color tagColor;
    if (draw) {
      tagText = 'Nul'; tagColor = AppColors.amber;
    } else if (won) {
      tagText = playerA; tagColor = AppColors.accentBright;
    } else {
      tagText = playerB; tagColor = const Color(0xFF58A6FF);
    }

    final date = ts != null
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year % 100}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              draw ? 'Nul' : '🏆 $tagText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tagColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
