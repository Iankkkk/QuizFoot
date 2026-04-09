// qui_a_menti_score.dart
//
// Results page for "Qui a menti ?".
// Shows the points earned, key stats, and the full candidate breakdown
// (correct / incorrect placement for each of the 10 players).
//
// Navigation:
//   "Accueil"  → pops to the home page
//   "Rejouer"  → pushReplacement to a fresh QuiAMentiGame

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/claim.dart';
import 'qui_a_menti_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuiAMentiScore
// ─────────────────────────────────────────────────────────────────────────────

class QuiAMentiScore extends StatelessWidget {
  /// Points awarded for this game (0, 30, 60, or 100).
  final int points;

  /// Number of candidates correctly placed (0–10).
  final int correctCount;

  /// Number of validations used (1–3).
  final int validationsUsed;

  /// Total time elapsed from game start to end.
  final Duration timeTaken;

  /// Whether the game ended because the 5-minute timer expired.
  final bool timedOut;

  /// Full candidate list with ground-truth [Candidate.isTrue] values.
  final List<Candidate> allCandidates;

  /// Final state of the VRAI bucket when the game ended.
  final List<Candidate> finalTrueBucket;

  /// Final state of the FAUX bucket when the game ended.
  final List<Candidate> finalFalseBucket;

  const QuiAMentiScore({
    super.key,
    required this.points,
    required this.correctCount,
    required this.validationsUsed,
    required this.timeTaken,
    required this.timedOut,
    required this.allCandidates,
    required this.finalTrueBucket,
    required this.finalFalseBucket,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Color of the large score number.
  Color get _scoreColor {
    if (points >= 80) return AppColors.accentBright;
    if (points >= 50) return AppColors.amber;
    return AppColors.red;
  }

  /// Motivational message based on the outcome.
  String get _scoreMessage {
    if (timedOut) return 'Temps écoulé ⏱️';
    if (points == 100) return 'Parfait du premier coup ! 🏆';
    if (points == 60) return 'Bien joué, presque ! 👏';
    if (points == 30) return "C'était serré... 😅";
    return 'Raté cette fois... Rejoue ! 💪';
  }

  /// Formatted elapsed time "Xm00s".
  String get _timerLabel {
    final m = timeTaken.inMinutes;
    final s = timeTaken.inSeconds % 60;
    return '${m}m${s.toString().padLeft(2, '0')}s';
  }

  /// Returns true if [c] ended up in the correct bucket.
  bool _wasCorrect(Candidate c) {
    if (c.isTrue && finalTrueBucket.contains(c)) return true;
    if (!c.isTrue && finalFalseBucket.contains(c)) return true;
    return false;
  }

  /// Label of the bucket where the player placed [c].
  String _placedIn(Candidate c) {
    if (finalTrueBucket.contains(c)) return 'VRAI';
    if (finalFalseBucket.contains(c)) return 'FAUX';
    return 'Non classé';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildScoreCard(),
            // Section label
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
            Expanded(child: _buildCandidateList()),
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
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20,
              ),
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

  /// Large card: score, message, and three stat chips.
  Widget _buildScoreCard() {
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
            // Large score number
            Text(
              '$points',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w800,
                color: _scoreColor,
                height: 1,
              ),
            ),
            const Text(
              '/ 100 pts',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            // Motivational message
            Text(
              _scoreMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            // Stat chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  icon: Icons.check_circle_outline,
                  label: '$correctCount/10',
                  sublabel: 'corrects',
                  color: AppColors.accentBright,
                ),
                _StatChip(
                  icon: Icons.how_to_vote_outlined,
                  label: '$validationsUsed/3',
                  sublabel: 'validations',
                  color: AppColors.amber,
                ),
                _StatChip(
                  icon: Icons.timer_outlined,
                  label: _timerLabel,
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

  /// Scrollable breakdown split into two sections: VRAI and FAUX.
  /// Each section shows the candidates that truly belong there,
  /// with a ✓/✗ indicator based on how the player placed them.
  Widget _buildCandidateList() {
    final trueCandidates = allCandidates.where((c) => c.isTrue).toList();
    final falseCandidates = allCandidates.where((c) => !c.isTrue).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _buildSection(
          title: '✅ VRAI',
          subtitle: 'Ces joueurs validaient l\'affirmation',
          accentColor: AppColors.accentBright,
          candidates: trueCandidates,
        ),
        const SizedBox(height: 12),
        _buildSection(
          title: '❌ FAUX',
          subtitle: 'Ces joueurs sont des menteurs',
          accentColor: AppColors.red,
          candidates: falseCandidates,
        ),
      ],
    );
  }

  /// "Accueil" + "Rejouer ↺" buttons at the bottom.
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Accueil',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Restarts a fresh game. Uses the score page's own context
          // so there is no risk of accessing a disposed state.
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const QuiAMentiGame()),
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
// _Section helpers — private widget builders on QuiAMentiScore
// ─────────────────────────────────────────────────────────────────────────────

extension _SectionBuilders on QuiAMentiScore {
  /// A titled section card listing candidates that truly belong to one bucket.
  Widget _buildSection({
    required String title,
    required String subtitle,
    required Color accentColor,
    required List<Candidate> candidates,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Separator
          Container(height: 1, color: AppColors.border),
          // Candidate rows
          ...candidates.map((c) => _buildCandidateRow(c, accentColor)),
        ],
      ),
    );
  }

  /// A single candidate row inside a section.
  /// Shows ✓ if correctly placed, ✗ with "placé en VRAI/FAUX" if wrong.
  Widget _buildCandidateRow(Candidate c, Color accentColor) {
    final bool correct = _wasCorrect(c);
    final Color color = correct ? accentColor : AppColors.red;
    final String placed = _placedIn(c);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // ✓ or ✗ icon
          Icon(
            correct ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          // Candidate name
          Expanded(
            child: Text(
              c.name,
              style: TextStyle(
                color: correct
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          // If wrong: show where the player placed it
          if (!correct)
            Text(
              'placé en $placed',
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (correct)
            Text(
              '✓ bien placé',
              style: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
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

/// A small vertical chip: icon + value + sublabel.
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
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
