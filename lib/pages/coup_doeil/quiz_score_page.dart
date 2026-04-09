// quiz_score_page.dart
//
// Displayed after the player completes a Coup d'œil quiz.
// Shows the total score, a motivational message, four stat chips
// (correct / wrong / skipped / time), and a scrollable per-question breakdown.
//
// Navigation:
//   "Accueil"  → pops back to the home page
//   "Rejouer"  → calls [onReplay], which the game page provides.
//               Using a callback avoids a circular import between this file
//               and quiz_test.dart.

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/question_result.dart';
import 'quiz_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuizScorePage
// ─────────────────────────────────────────────────────────────────────────────

class QuizScorePage extends StatelessWidget {
  /// Total points earned during the quiz.
  final int score;

  /// Total number of questions (always 10 in the current setup).
  final int total;

  /// Wall-clock duration from the first question to the last answer.
  final Duration timeTaken;

  /// Per-question outcomes built during the game.
  final List<QuestionResult> results;

  /// Difficulty used during this quiz — passed back to [QuizTest] on replay.
  final String difficulty;

  /// Category filter used during this quiz — null means all categories.
  final String? category;

  const QuizScorePage({
    super.key,
    required this.score,
    required this.total,
    required this.timeTaken,
    required this.results,
    required this.difficulty,
    this.category,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Icon shown in the per-question list row.
  IconData _rowIcon(QuestionResult result) {
    if (result.correct) return Icons.check;
    if (result.attempted) return Icons.close;   // wrong answer(s) before skipping
    return Icons.arrow_forward;                  // skipped without attempting
  }

  /// Accent color for a row based on its outcome.
  Color _rowColor(QuestionResult result) {
    if (result.correct) return AppColors.accentBright;
    if (result.attempted) return AppColors.red;
    return AppColors.textSecondary;
  }

  /// Motivational message based on the score ratio (score / maxPossible).
  String _scoreMessage() {
    final ratio = score / (total * 5);
    if (ratio == 1.0) return 'Score parfait 🏆';
    if (ratio >= 0.75) return "Super score ! T'es un bon !";
    if (ratio >= 0.5)  return 'Pas mal grand ! Continue !';
    if (ratio >= 0.3)  return "C'est moyen... Applique toi !";
    return 'Clairement un mauvais score. Ressaisis toi.';
  }

  /// Color of the large score number — green, amber, or red.
  Color _scoreColor() {
    final ratio = score / (total * 5);
    if (ratio >= 0.75) return AppColors.accentBright;
    if (ratio >= 0.5)  return AppColors.amber;
    return AppColors.red;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final int minutes   = timeTaken.inMinutes;
    final int seconds   = timeTaken.inSeconds % 60;
    final int maxScore  = total * 5;
    final int correct   = results.where((r) => r.correct).length;
    final int wrong     = results.where((r) => !r.correct && r.attempted).length;
    final int skipped   = results.where((r) => !r.correct && !r.attempted).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [

            // ── Header ────────────────────────────────────────────────────
            _buildHeader(context),

            // ── Score card ────────────────────────────────────────────────
            _buildScoreCard(
              maxScore: maxScore,
              correct:  correct,
              wrong:    wrong,
              skipped:  skipped,
              minutes:  minutes,
              seconds:  seconds,
            ),

            // ── Section label ─────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
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

            // ── Per-question list ─────────────────────────────────────────
            Expanded(child: _buildResultList()),

            // ── Action buttons ────────────────────────────────────────────
            _buildButtons(context),
          ],
        ),
      ),
    );
  }

  // ── Private widget builders ───────────────────────────────────────────────

  /// Top bar with a back arrow and the page title.
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Back button — goes to the home page
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
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Résultats',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Large card showing the score, message, and four stat chips.
  Widget _buildScoreCard({
    required int maxScore,
    required int correct,
    required int wrong,
    required int skipped,
    required int minutes,
    required int seconds,
  }) {
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
            // Score number in large text
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
              '/ $maxScore pts',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            // Motivational message
            Text(
              _scoreMessage(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            // Four quick stats in a row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  icon: Icons.check_circle_outline,
                  label: '$correct',
                  sublabel: 'correctes',
                  color: AppColors.accentBright,
                ),
                _StatChip(
                  icon: Icons.cancel_outlined,
                  label: '$wrong',
                  sublabel: 'ratées',
                  color: AppColors.red,
                ),
                _StatChip(
                  icon: Icons.arrow_forward,
                  label: '$skipped',
                  sublabel: 'passées',
                  color: AppColors.textSecondary,
                ),
                _StatChip(
                  icon: Icons.timer_outlined,
                  label: '${minutes}m${seconds.toString().padLeft(2, '0')}',
                  sublabel: 'temps',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Scrollable list showing one row per question.
  Widget _buildResultList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final result = results[index];
        final color  = _rowColor(result);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Outcome icon (check / close / arrow)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_rowIcon(result), color: color, size: 18),
              ),
              const SizedBox(width: 12),
              // Player name
              Expanded(
                child: Text(
                  result.playerName,
                  style: TextStyle(
                    color: result.correct ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              // Points earned (or dash if none)
              Text(
                result.correct
                    ? '+${result.points} pt${result.points > 1 ? 's' : ''}'
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

  /// "Accueil" + "Rejouer ↺" buttons at the bottom of the page.
  Widget _buildButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          // Goes back to the home page
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Accueil',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Restarts the quiz with the same difficulty and category.
          // Navigation uses the score page's own context — not a captured one.
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizTest(
                    difficulty: difficulty,
                    category:   category,
                  ),
                ),
              ),
              child: const Text(
                'Rejouer ↺',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatChip — private helper widget
// ─────────────────────────────────────────────────────────────────────────────

/// A small vertical chip showing an icon, a value, and a sublabel.
/// Used in the score card's stats row.
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
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
