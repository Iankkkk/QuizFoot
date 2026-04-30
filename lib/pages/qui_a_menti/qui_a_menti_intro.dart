// qui_a_menti_intro.dart
//
// Entry point for the "Qui a menti ?" game.
// Shows the rules and navigates to the game page when the player taps "Jouer !".
//
// No difficulty picker — the game always uses the same rules.

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'qui_a_menti_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuiAMentiIntro
// ─────────────────────────────────────────────────────────────────────────────

class QuiAMentiIntro extends StatelessWidget {
  const QuiAMentiIntro({super.key});

  // ── Constants ──────────────────────────────────────────────────────────────

  /// Icons paired with each rule string (same index).
  static const List<IconData> _ruleIcons = [
    Icons.campaign_outlined,
    Icons.people_outline,
    Icons.swap_horiz_outlined,
    Icons.how_to_vote_outlined,
    Icons.timer_outlined,
  ];

  /// Plain-text rules shown on the intro card.
  static const List<String> _rules = [
    'Une affirmation est posée : vraie pour 5 joueurs, fausse pour les 5 autres',
    'Classe les 10 joueurs dans les colonnes VRAI et FAUX',
    '3 validations maximum — à chaque erreur, un indice t\'est révélé',
    'Plus tu réussis tôt, plus tu gagnes de points',
    '5 minutes maximum pour tout classer',
  ];

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            _buildLogo(),
            const SizedBox(height: 16),
            _buildRulesCard(),
            const SizedBox(height: 32),
            _buildPlayButton(context),
          ],
        ),
      ),
    );
  }

  // ── Private widget builders ───────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
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
    );
  }

  /// App logo centered at the top.
  Widget _buildLogo() {
    return Center(
      child: Image.asset('assets/images/logo.png', width: 120, height: 120),
    );
  }

  /// Card listing the game rules with icons.
  Widget _buildRulesCard() {
    return Container(
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
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          // One row per rule
          for (int i = 0; i < _rules.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_ruleIcons[i], size: 18, color: AppColors.accentBright),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _rules[i],
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Green "Jouer !" button that navigates to the game page.
  Widget _buildPlayButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentBright,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QuiAMentiGame()),
      ),
      child: Text(
        'Jouer !',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }
}
