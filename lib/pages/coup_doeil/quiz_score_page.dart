// quiz_score_page.dart
//
// Displayed after the player completes a Coup d'œil quiz.
// Shows the total score, a motivational message, four stat chips
// (correct / wrong / skipped / time), and a scrollable per-question breakdown.
//
// Navigation:
//   "Accueil"  → pops back to the home page
//   "Rejouer"  → navigates to a new QuizTest with the same difficulty/category.

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/question_result.dart';
import '../../models/game_result.dart';
import '../../services/game_history_service.dart';
import 'quiz_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuizScorePage
// ─────────────────────────────────────────────────────────────────────────────

class QuizScorePage extends StatefulWidget {
  final int score;
  final int total;
  final Duration timeTaken;
  final List<QuestionResult> results;
  final String difficulty;
  final String? category;
  final List<Map<String, String>> errors;

  const QuizScorePage({
    super.key,
    required this.score,
    required this.total,
    required this.timeTaken,
    required this.results,
    required this.difficulty,
    this.category,
    this.errors = const [],
  });

  @override
  State<QuizScorePage> createState() => _QuizScorePageState();
}

class _QuizScorePageState extends State<QuizScorePage> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveResult());
  }

  Future<void> _saveResult() async {
    if (!mounted) return;
    final correct = widget.results.where((r) => r.correct).length;
    final wrong   = widget.results.where((r) => !r.correct && r.attempted).length;
    final skipped = widget.results.where((r) => !r.correct && !r.attempted).length;
    await GameHistoryService.instance.save(
      GameResult.coupDoeil(
        difficulty: widget.difficulty,
        score:      widget.score,
        total:      widget.total,
        correct:    correct,
        wrong:      wrong,
        skipped:    skipped,
        timeTaken:  widget.timeTaken,
        category:   widget.category,
        errors:     widget.errors,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  IconData _rowIcon(QuestionResult result) {
    if (result.correct) return Icons.check;
    if (result.attempted) return Icons.close;
    return Icons.arrow_forward;
  }

  Color _rowColor(QuestionResult result) {
    if (result.correct) return AppColors.accentBright;
    if (result.attempted) return AppColors.red;
    return AppColors.textSecondary;
  }

  String _scoreMessage() {
    final ratio = widget.score / (widget.total * 5);
    if (ratio == 1.0) return 'Score parfait 🏆';
    if (ratio >= 0.75) return "Super score ! T'es un bon !";
    if (ratio >= 0.5)  return 'Pas mal grand ! Continue !';
    if (ratio >= 0.3)  return "C'est moyen... Applique toi !";
    return 'Clairement un mauvais score. Ressaisis toi.';
  }

  Color _scoreColor() {
    final ratio = widget.score / (widget.total * 5);
    if (ratio >= 0.75) return AppColors.accentBright;
    if (ratio >= 0.5)  return AppColors.amber;
    return AppColors.red;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final int minutes  = widget.timeTaken.inMinutes;
    final int seconds  = widget.timeTaken.inSeconds % 60;
    final int maxScore = widget.total * 5;
    final int correct  = widget.results.where((r) => r.correct).length;
    final int wrong    = widget.results.where((r) => !r.correct && r.attempted).length;
    final int skipped  = widget.results.where((r) => !r.correct && !r.attempted).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildScoreCard(
              maxScore: maxScore,
              correct:  correct,
              wrong:    wrong,
              skipped:  skipped,
              minutes:  minutes,
              seconds:  seconds,
            ),
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
            Text(
              '${widget.score}',
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

  Widget _buildResultList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: widget.results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final result = widget.results[index];
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

  Widget _buildButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
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
                    difficulty: widget.difficulty,
                    category:   widget.category,
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
// _StatChip
// ─────────────────────────────────────────────────────────────────────────────

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
