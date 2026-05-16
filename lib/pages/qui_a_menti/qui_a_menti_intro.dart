import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/theme_service.dart';
import 'qui_a_menti_game.dart';
import 'package:quiz_foot/utils/navigation.dart';

const _kDifficulties = [
  'Amateur',
  'Semi-Pro',
  'Pro',
  'International',
  'Légende',
];

class QuiAMentiIntro extends StatefulWidget {
  final bool autoOpenDifficulty;
  const QuiAMentiIntro({super.key, this.autoOpenDifficulty = false});

  @override
  State<QuiAMentiIntro> createState() => _QuiAMentiIntroState();
}

class _QuiAMentiIntroState extends State<QuiAMentiIntro> {
  @override
  void initState() {
    super.initState();
    if (widget.autoOpenDifficulty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDifficultyPicker();
      });
    }
  }

  static const List<IconData> _ruleIcons = [
    Icons.campaign_outlined,
    Icons.people_outline,
    Icons.swap_horiz_outlined,
    Icons.how_to_vote_outlined,
    Icons.timer_outlined,
  ];

  static const List<String> _rules = [
    'Une affirmation est posée : vraie pour 5 joueurs, fausse pour les 5 autres',
    'Classe les 10 joueurs dans les colonnes VRAI et FAUX',
    '3 validations maximum : à chaque validation incorrecte, un indice t\'est révélé',
    'Plus tu réussis tôt, plus tu gagnes de points',
    '5 minutes maximum pour tout classer',
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
                          namedRoute(QuiAMentiGame(difficulty: diff)),
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
          'Qui a menti ?',
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
                  colors: ThemeService.instance.isDark
                      ? [const Color(0xFF2A1A1A), AppColors.bg]
                      : [const Color(0xFFF5E6D6), AppColors.bg],
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
                      '🎭',
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
                        'Qui a menti ?',
                        style: TextStyle(
                          color: AppColors.accentBright,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1 affirmation, 10 joueurs\n5 vrais, 5 menteurs — à toi de les trouver',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
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
