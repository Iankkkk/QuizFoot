// qui_a_menti_score.dart
//
// Results page for "Qui a menti ?".
//
// Animations (chained):
//   1. Score card entrance  — scales + fades in (600 ms)
//   2. Star reveal          — stars light up one by one (900 ms)
//   3a. Positive outcome    — confetti (3 stars) or subtle particles (1–2 stars)
//   3b. Negative outcome    — score card shakes horizontally
//
// Navigation:
//   "Accueil"  → pops to the home page
//   "Rejouer"  → pushReplacement to a fresh QuiAMentiGame

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/claim.dart';
import '../../models/game_result.dart';
import '../../services/game_history_service.dart';
import 'qui_a_menti_confetti.dart';
import 'qui_a_menti_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuiAMentiScore
// ─────────────────────────────────────────────────────────────────────────────

class QuiAMentiScore extends StatefulWidget {
  /// Points earned (50 / 40 / 30 / 15 / 0).
  final int points;

  /// Number of candidates correctly placed (0–10, even numbers only).
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

  @override
  State<QuiAMentiScore> createState() => _QuiAMentiScoreState();
}

class _QuiAMentiScoreState extends State<QuiAMentiScore>
    with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────────────────────

  /// Score card entrance: scale 0.8 → 1.0 + fade in.
  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;

  /// Points counter: animates from 0 to widget.points.
  late final AnimationController _pointsController;
  late final Animation<int> _pointsAnim;

  /// End animation: shake (0 pts) or confetti (50 pts).
  late final AnimationController _endController;

  /// Horizontal offset for the shake animation (0 pts).
  late final Animation<double> _shakeOffset;

  /// Whether to show full-screen confetti (50 pts = perfect first attempt).
  bool _showConfetti = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playSequence();
    _saveScore();
  }

  Future<void> _saveScore() async {
    await GameHistoryService.instance.save(
      GameResult.quiAMenti(
        points:          widget.points,
        correctCount:    widget.correctCount,
        validationsUsed: widget.validationsUsed,
        timedOut:        widget.timedOut,
        timeTaken:       widget.timeTaken,
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pointsController.dispose();
    _endController.dispose();
    super.dispose();
  }

  // ── Animation setup ───────────────────────────────────────────────────────

  void _setupAnimations() {
    // 1. Entrance
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceScale = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    );
    _entranceOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    // 2. Points counter animation
    _pointsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pointsAnim = IntTween(
      begin: 0,
      end: widget.points,
    ).animate(CurvedAnimation(parent: _pointsController, curve: Curves.easeOut));

    // 3. End animation
    _endController = AnimationController(
      vsync: this,
      duration: widget.points > 0
          ? const Duration(milliseconds: 1200)
          : const Duration(milliseconds: 500),
    );

    _shakeOffset = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 10),
    ]).animate(_endController);
  }

  Future<void> _playSequence() async {
    await _entranceController.forward();
    await Future.delayed(const Duration(milliseconds: 120));

    if (widget.points > 0) await _pointsController.forward();
    await Future.delayed(const Duration(milliseconds: 200));

    if (widget.points == 50) {
      setState(() => _showConfetti = true);
      await _endController.forward();
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _showConfetti = false);
    } else if (widget.points == 0) {
      await _endController.forward();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color get _pointsColor {
    if (widget.points == 50) return const Color(0xFFFFD740);
    if (widget.points >= 30) return AppColors.accentBright;
    if (widget.points > 0)  return AppColors.amber;
    return AppColors.red;
  }

  Color get _validationColor {
    if (widget.validationsUsed == 1) return AppColors.accentBright;
    if (widget.validationsUsed == 2) return const Color(0xFF6BCB77);
    if (widget.points > 0) return AppColors.orange;
    return AppColors.red;
  }

  String get _scoreMessage {
    if (widget.timedOut) return 'Temps écoulé !';
    if (widget.points == 50) return 'Parfait, du premier coup !';
    if (widget.points == 40) return 'Bien joué !';
    if (widget.points == 30) return 'Trouvé au bout du suspense';
    if (widget.points == 15) return 'Presque… 8/10 !';
    return 'Raté cette fois. Rejoue !';
  }

  String get _timerLabel {
    final m = widget.timeTaken.inMinutes;
    final s = widget.timeTaken.inSeconds % 60;
    return '${m}m${s.toString().padLeft(2, '0')}s';
  }

  bool _wasCorrect(Candidate c) {
    if (c.isTrue && widget.finalTrueBucket.contains(c)) return true;
    if (!c.isTrue && widget.finalFalseBucket.contains(c)) return true;
    return false;
  }

  String _placedIn(Candidate c) {
    if (widget.finalTrueBucket.contains(c)) return 'VRAI';
    if (widget.finalFalseBucket.contains(c)) return 'FAUX';
    return 'Non classé';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildAnimatedScoreCard(),
                Padding(
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
                _buildButtons(),
              ],
            ),
          ),
          // Full-screen confetti overlay (10/10 on first attempt)
          if (_showConfetti)
            IgnorePointer(child: QuiAMentiConfetti(controller: _endController)),
        ],
      ),
    );
  }

  // ── Private widget builders ───────────────────────────────────────────────

  Widget _buildHeader() {
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
              child: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20,
              ),
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
        ],
      ),
    );
  }

  /// Score card wrapped in entrance + shake animations.
  Widget _buildAnimatedScoreCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _entranceController,
        _endController,
        _pointsController,
      ]),
      builder: (_, __) {
        final double dx = widget.points == 0 ? _shakeOffset.value : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: FadeTransition(
            opacity: _entranceOpacity,
            child: ScaleTransition(
              scale: _entranceScale,
              child: _buildScoreCard(),
            ),
          ),
        );
      },
    );
  }

  /// The inner score card content.
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
            // Points counter animé
            AnimatedBuilder(
              animation: _pointsController,
              builder: (_, __) => Text(
                '${_pointsAnim.value} pts',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: _pointsColor,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _scoreMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: widget.points > 0
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  icon: Icons.check_circle_outline,
                  label: '${widget.correctCount}/10',
                  sublabel: 'corrects',
                  color: AppColors.accentBright,
                ),
                _StatChip(
                  icon: Icons.how_to_vote_outlined,
                  label: '${widget.validationsUsed}',
                  sublabel: 'validations',
                  color: _validationColor,
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

  Widget _buildCandidateList() {
    final trueCandidates = widget.allCandidates.where((c) => c.isTrue).toList();
    final falseCandidates = widget.allCandidates
        .where((c) => !c.isTrue)
        .toList();

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
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),
          ...candidates.map((c) => _buildCandidateRow(c, accentColor)),
        ],
      ),
    );
  }

  Widget _buildCandidateRow(Candidate c, Color accentColor) {
    final bool correct = _wasCorrect(c);
    final Color color = correct ? accentColor : AppColors.red;
    final String placed = _placedIn(c);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            correct ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
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
          if (!correct)
            Text(
              'placé en $placed',
              style: TextStyle(
                color: AppColors.textPrimary,
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

  Widget _buildButtons() {
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const QuiAMentiGame()),
              ),
              child: Text(
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
