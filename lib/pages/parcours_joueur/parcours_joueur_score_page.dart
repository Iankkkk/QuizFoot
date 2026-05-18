// parcours_joueur_score_page.dart
//
// Shown after a "Parcours Joueur" game. Same structure as the Coup d'Œil
// score page: total score, message, four stat chips, scrollable per-player
// breakdown.
//
// Navigation:
//   "Accueil"  → pops back to the home page
//   "Rejouer"  → new game in the SAME difficulty as the one just played.

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/parcours_result.dart';
import 'parcours_joueur_game_page.dart';
import 'package:quiz_foot/utils/navigation.dart';

class ParcoursJoueurScorePage extends StatelessWidget {
  final int score;
  final int total;
  final int pointsPerPlayer;
  final List<ParcoursResult> results;
  final String difficulty;

  const ParcoursJoueurScorePage({
    super.key,
    required this.score,
    required this.total,
    required this.results,
    required this.difficulty,
    this.pointsPerPlayer = 10,
  });

  int get _maxScore => total * pointsPerPlayer;

  IconData _rowIcon(ParcoursResult r) {
    if (r.found) return Icons.check;
    if (r.attempted) return Icons.close;
    return Icons.arrow_forward;
  }

  Color _rowColor(ParcoursResult r) {
    if (r.found) return AppColors.accentBright;
    if (r.attempted) return AppColors.red;
    return AppColors.textSecondary;
  }

  String _scoreMessage() {
    final ratio = _maxScore == 0 ? 0.0 : score / _maxScore;
    if (ratio == 1.0) return 'Sans-faute, mémoire de légende 🏆';
    if (ratio >= 0.75) return "Excellent ! T'as l'œil pour les parcours !";
    if (ratio >= 0.5) return 'Pas mal grand ! Continue !';
    if (ratio >= 0.3) return "C'est moyen... révise tes transferts !";
    return 'Dur dur... ressaisis-toi !';
  }

  Color _scoreColor() {
    final ratio = _maxScore == 0 ? 0.0 : score / _maxScore;
    if (ratio >= 0.75) return AppColors.accentBright;
    if (ratio >= 0.5) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final found = results.where((r) => r.found).length;
    final wrong = results.where((r) => !r.found && r.attempted).length;
    final skipped = results.where((r) => !r.found && !r.attempted).length;
    final hints = results.fold<int>(0, (s, r) => s + r.hintsUsed);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildScoreCard(found, wrong, skipped, hints),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'DÉTAIL',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildResultList()),
            _buildButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(Icons.arrow_back,
                  color: AppColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Résultats',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accentBright.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              difficulty,
              style: TextStyle(
                color: AppColors.accentBright,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(int found, int wrong, int skipped, int hints) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              '$score',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w800,
                color: _scoreColor(),
                height: 1,
              ),
            ),
            Text(
              '/ $_maxScore pts',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _scoreMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  icon: Icons.check_circle_outline,
                  label: '$found',
                  sublabel: 'trouvés',
                  color: AppColors.accentBright,
                ),
                _StatChip(
                  icon: Icons.cancel_outlined,
                  label: '$wrong',
                  sublabel: 'ratés',
                  color: AppColors.red,
                ),
                _StatChip(
                  icon: Icons.arrow_forward,
                  label: '$skipped',
                  sublabel: 'passés',
                  color: AppColors.textSecondary,
                ),
                _StatChip(
                  icon: Icons.lightbulb_outline,
                  label: '$hints',
                  sublabel: 'indices',
                  color: AppColors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final r = results[index];
        final color = _rowColor(r);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_rowIcon(r), color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.playerName,
                      style: TextStyle(
                        color: r.found
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (r.hintsUsed > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${r.hintsUsed} indice${r.hintsUsed > 1 ? 's' : ''} utilisé${r.hintsUsed > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                r.found
                    ? '+${r.points} pt${r.points > 1 ? 's' : ''}'
                    : '—',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Accueil',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pushReplacement(
                context,
                namedRoute(
                  ParcoursJoueurGamePage(difficulty: difficulty),
                ),
              ),
              child: const Text('Rejouer ↺',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        Text(
          sublabel,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
