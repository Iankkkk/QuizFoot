// parcours_joueur_intro_page.dart
//
// Intro screen for "Parcours Joueur" — same structure as the other solo
// game intros (Qui a menti / Coup d'Œil): hero + rules card + a bottom
// "Jouer !" button that opens the difficulty picker, then launches the game.

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../data/parcours_joueur_api.dart';
import '../../services/theme_service.dart';
import 'parcours_joueur_game_page.dart';
import 'package:quiz_foot/utils/navigation.dart';

const _kDifficulties = [
  'Amateur',
  'Semi-Pro',
  'Pro',
  'International',
  'Légende',
];

class ParcoursJoueurIntroPage extends StatefulWidget {
  final bool autoOpenDifficulty;
  const ParcoursJoueurIntroPage({super.key, this.autoOpenDifficulty = false});

  @override
  State<ParcoursJoueurIntroPage> createState() =>
      _ParcoursJoueurIntroPageState();
}

class _ParcoursJoueurIntroPageState extends State<ParcoursJoueurIntroPage> {
  int _playerCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
    if (widget.autoOpenDifficulty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDifficultyPicker();
      });
    }
  }

  Future<void> _loadCount() async {
    try {
      final players = await ParcoursJoueurApi.fetchPlayers();
      if (!mounted) return;
      setState(() => _playerCount = players.where((p) => p.level != null && p.clubs.isNotEmpty).length);
    } catch (_) {}
  }

  static const List<IconData> _ruleIcons = [
    Icons.route_outlined,
    Icons.person_search_outlined,
    Icons.format_list_numbered,
    Icons.lightbulb_outline,
    Icons.emoji_events_outlined,
  ];

  static const List<String> _rules = [
    'La carrière d\'un joueur est affiché: clubs, années, matchs/buts',
    'Devine le joueur : 1 seul essai par joueur',
    '5 joueurs par partie, du plus facile au plus dur',
    '3 indices déblocables (nationalité, âge, poste) — −2 pts chacun',
    '+10 points par joueur trouvé',
  ];

  void _showDifficultyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                'Choisis la difficulté',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ..._kDifficulties.map((diff) {
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
                          namedRoute(ParcoursJoueurGamePage(difficulty: diff)),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = ThemeService.instance.isDark;
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
          'Parcours Joueur',
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
        child: SizedBox(
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
            child: const Text(
              'Jouer !',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
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
                  colors: dark
                      ? [const Color(0xFF1B2A1F), AppColors.bg]
                      : [const Color(0xFFE7F3EA), AppColors.bg],
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
                      '🧭',
                      style: TextStyle(
                        fontSize: 110,
                        color: dark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.04),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parcours Joueur',
                        style: TextStyle(
                          color: AppColors.accentBright,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Retrouve le joueur grâce à son parcours\nen club et en sélection',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: _playerCount),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOut,
                        builder: (_, val, __) => Text(
                          '$val joueurs disponibles',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Rules card ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
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
                      'Règles du jeu',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (int i = 0; i < _rules.length; i++)
                      Padding(
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
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
