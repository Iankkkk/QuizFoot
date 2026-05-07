import 'package:flutter/material.dart';
import 'package:quiz_foot/pages/lineup/lineup_match_preview_page.dart';
import '../../constants/app_colors.dart';
import '../../data/lineup_game_data.dart';
import '../../models/match_model.dart';
import '../../models/game_result.dart';
import '../../services/game_history_service.dart';
import '../../main.dart' show routeObserver;
import '../../services/theme_service.dart';

class LineupMatchPageIntro extends StatefulWidget {
  const LineupMatchPageIntro({super.key});

  @override
  State<LineupMatchPageIntro> createState() => _LineupMatchPageIntroState();
}

class _LineupMatchPageIntroState extends State<LineupMatchPageIntro>
    with RouteAware {
  static const List<String> _difficulties = [
    "Amateur",
    "Semi-Pro",
    "Pro",
    "International",
    "Légende",
  ];

  static const List<String> _eras = [
    "Toutes",
    "Avant 2010",
    "2010-2019",
    "2020-2026",
  ];

  static const List<IconData> _ruleIcons = [
    Icons.timer_off_outlined,
    Icons.keyboard_outlined,
    Icons.error_outline,
    Icons.emoji_events_outlined,
    Icons.star_outline,
    Icons.abc_outlined,
  ];

  static const List<String> _rules = [
    "Il n'y a aucune limite de temps.",
    "Tape le NOM DE FAMILLE du joueur.",
    "6 erreurs maximum sont autorisées.",
    "Les titulaires et les remplaçants entrés en jeu sont à trouver.",
    "Chaque bonne réponse rapporte 1 point.",
    "Tu as 5 indices gratuits, en cliquant sur l'un des joueurs pour révéler la 1ère lettre de son nom OU son numéro",
  ];

  final Set<String> _selectedEras = {};

  // Historique
  List<GameResult> _playedResults = [];
  Map<String, Match> _matchById = {};
  int _totalMatchCount = 0;
  bool _historyLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final (results, allMatches) = await (
      GameHistoryService.instance.getAll(),
      loadMatches(),
    ).wait;
    final played = results.where((r) => r.gameType == GameType.compos);
    final Map<String, GameResult> bestByMatch = {};
    for (final r in played) {
      final mid = r.details['matchId'] as String? ?? '';
      if (mid.isEmpty) continue;
      if (!bestByMatch.containsKey(mid) ||
          r.rawScore > bestByMatch[mid]!.rawScore) {
        bestByMatch[mid] = r;
      }
    }
    final byId = {for (final m in allMatches) m.matchId: m};
    if (!mounted) return;
    setState(() {
      _playedResults = bestByMatch.values.toList();
      _matchById = byId;
      _totalMatchCount = allMatches.length;
      _historyLoaded = true;
    });
  }

  void _showDifficultyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Choisis la difficulté",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ..._difficulties.map((diff) {
                  final color = AppColors.forDifficulty(diff);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LineupMatchPreviewPage(
                                difficulty: diff,
                                eras: Set.from(_selectedEras),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                diff,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Compos",
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Période',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
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
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accentBright.withOpacity(0.15)
                            : AppColors.bg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.accentBright
                              : AppColors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        era,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.accentBright
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBright,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showDifficultyPicker,
                child: Text(
                  'Jouer !',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: ThemeService.instance.isDark
                      ? [const Color(0xFF1A2E1A), AppColors.bg]
                      : [const Color(0xFFD6F0E4), AppColors.bg],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Text(
                      '⚽',
                      style: TextStyle(
                        fontSize: 110,
                        color: ThemeService.instance.isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.04),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compos',
                        style: TextStyle(
                          color: AppColors.accentBright,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: _totalMatchCount),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOut,
                        builder: (_, val, __) => Text(
                          '$val compos disponibles',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (_historyLoaded && _playedResults.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Builder(
                          builder: (_) {
                            final best = _playedResults.reduce(
                              (a, b) => a.rawScore >= b.rawScore ? a : b,
                            );
                            final name =
                                best.details['matchName'] as String? ??
                                best.details['matchId'] as String? ??
                                '—';
                            return Text(
                              'Meilleur score : $name · ${best.rawScore}%',
                              style: TextStyle(
                                color: AppColors.accentBright,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // ── Content ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Règles du jeu",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_rules.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _ruleIcons[i],
                                  size: 18,
                                  color: AppColors.accentBright,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _rules[i],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Mes compos ────────────────────────────────────────
                  if (!_historyLoaded)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentBright,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Text(
                          'Mes compos complétées',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_playedResults.length} / $_totalMatchCount',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentBright,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_playedResults.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            'Aucune compo jouée pour l\'instant.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ...(_playedResults.map((r) {
                        final matchId = r.details['matchId'] as String? ?? '';
                        final match = _matchById[matchId];
                        final pct = r.rawScore;
                        final diff = r.difficulty;
                        final diffColor = AppColors.forDifficulty(diff);
                        final isPerfect = pct == 100;
                        final isGood = pct >= 70;
                        const gold = Color(0xFFFFD700);
                        final borderColor = isPerfect
                            ? gold
                            : isGood
                            ? AppColors.accentBright
                            : AppColors.border;
                        final bgColor = isPerfect
                            ? gold.withOpacity(0.07)
                            : AppColors.card;
                        final pctColor = isPerfect
                            ? gold
                            : isGood
                            ? AppColors.accentBright
                            : AppColors.textSecondary;
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
                              width: isPerfect || isGood ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (isPerfect) ...[
                                          Text(
                                            '🏆',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Expanded(
                                          child: Text(
                                            r.details['matchName'] as String? ??
                                                matchId,
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: diffColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            diff,
                                            style: TextStyle(
                                              color: diffColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$pct%',
                                          style: TextStyle(
                                            color: pctColor,
                                            fontSize: 12,
                                            fontWeight: isGood
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (match != null)
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LineupMatchPreviewPage(
                                        difficulty: diff,
                                        preselectedMatch: match,
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentBright.withOpacity(
                                        0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.accentBright
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      'Rejouer',
                                      style: TextStyle(
                                        color: AppColors.accentBright,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      })),
                    const SizedBox(height: 28),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
