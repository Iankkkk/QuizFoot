// lineup_score_page.dart
//
// Results page for "Compos".
//
// Stars:
//   3★ → all found, ≤ 2 errors
//   2★ → all found, ≤ 4 errors
//   1★ → all found, 5 errors
//   0★ → defeat (6 errors before finding all)
//
// Animations:
//   1. Score card entrance — scale + fade (600 ms)
//   2. Star reveal         — lights up one by one (900 ms)
//   3. Confetti            — 3★ only

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/match_model.dart';
import '../../models/lineup_model.dart';
import 'lineup_match_page.dart';
import 'lineup_match_page_intro.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LineupScorePage
// ─────────────────────────────────────────────────────────────────────────────

class LineupScorePage extends StatefulWidget {
  final Match match;
  final List<Lineup> lineups;
  final Set<String> foundPlayers;
  final Set<String> passedPlayers;
  final int score;
  final int errors;
  final Duration timeTaken;
  final bool defeat;
  final String difficulty;

  const LineupScorePage({
    super.key,
    required this.match,
    required this.lineups,
    required this.foundPlayers,
    required this.passedPlayers,
    required this.score,
    required this.errors,
    required this.timeTaken,
    required this.defeat,
    required this.difficulty,
  });

  @override
  State<LineupScorePage> createState() => _LineupScorePageState();
}

class _LineupScorePageState extends State<LineupScorePage>
    with TickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────────────────────

  late final AnimationController _entranceController;
  late final Animation<double>   _entranceScale;
  late final Animation<double>   _entranceOpacity;

  /// Counts from 0 → widget.score.
  late final AnimationController _counterController;
  late final Animation<int>      _counterValue;

  /// Shake on defeat.
  late final AnimationController _endController;
  late final Animation<double>   _shakeOffset;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playSequence();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _counterController.dispose();
    _endController.dispose();
    super.dispose();
  }

  // ── Animations ────────────────────────────────────────────────────────────

  void _setupAnimations() {
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceScale = CurvedAnimation(
      parent: _entranceController, curve: Curves.easeOutBack,
    );
    _entranceOpacity = CurvedAnimation(
      parent: _entranceController, curve: Curves.easeIn,
    );

    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _counterValue = IntTween(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _counterController, curve: Curves.easeOut),
    );

    _endController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeOffset = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0,  end: -10.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -10.0, end:  10.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 10.0,  end:  -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0,  end:   6.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 6.0,   end:   0.0), weight: 10),
    ]).animate(_endController);
  }

  Future<void> _playSequence() async {
    await _entranceController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _counterController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    if (widget.defeat) await _endController.forward();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _isPerfect =>
      !widget.defeat &&
      widget.foundPlayers.length == widget.lineups.length &&
      widget.passedPlayers.isEmpty;

  Color get _scoreColor {
    if (_isPerfect)          return const Color(0xFFFFD740); // gold
    if (widget.score >= 20)  return AppColors.accentBright;
    if (widget.score >= 15)  return AppColors.amber;
    if (widget.defeat)       return AppColors.red;
    return AppColors.textSecondary;
  }

  String get _message {
    if (_isPerfect)          return 'Exceptionnel ! Compo parfaite';
    if (widget.score >= 20)  return 'Excellent score !';
    if (widget.score >= 15)  return 'Bon score !';
    if (widget.defeat)       return 'Trop d\'erreurs... Rejoue !';
    return 'Pas mal, rejoue pour faire mieux !';
  }

  String get _timerLabel {
    final m = widget.timeTaken.inMinutes;
    final s = widget.timeTaken.inSeconds % 60;
    return '${m}m${s.toString().padLeft(2, '0')}s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildAnimatedScoreCard(),
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
            Expanded(child: _buildPlayerList()),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
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

  Widget _buildAnimatedScoreCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceController, _endController, _counterController]),
      builder: (_, __) {
        final dx = widget.defeat ? _shakeOffset.value : 0.0;
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

  Widget _buildScoreCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Match label
            Text(
              widget.match.matchName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Score counter
            Text(
              '${_counterValue.value}',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w800,
                color: _scoreColor,
                height: 1,
              ),
            ),
            const SizedBox(height: 14),

            // Message
            Text(
              _message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: widget.score >= 15 || _isPerfect
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  icon: Icons.people_outline,
                  label: '${widget.foundPlayers.length}/${widget.lineups.length}',
                  sublabel: 'trouvés',
                  color: AppColors.accentBright,
                ),
                _StatChip(
                  icon: Icons.close_rounded,
                  label: '${widget.errors}/6',
                  sublabel: 'erreurs',
                  color: widget.errors >= 5 ? AppColors.red : AppColors.textSecondary,
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

  Widget _buildPlayerList() {
    final homeStarters = widget.lineups.where((l) => l.teamName == widget.match.homeTeam && l.starter).toList();
    final homeSubs     = widget.lineups.where((l) => l.teamName == widget.match.homeTeam && !l.starter).toList();
    final awayStarters = widget.lineups.where((l) => l.teamName == widget.match.awayTeam && l.starter).toList();
    final awaySubs     = widget.lineups.where((l) => l.teamName == widget.match.awayTeam && !l.starter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _buildTeamBlock(widget.match.homeTeam, homeStarters, homeSubs),
        const SizedBox(height: 12),
        _buildTeamBlock(widget.match.awayTeam, awayStarters, awaySubs),
      ],
    );
  }

  Widget _buildTeamBlock(
    String teamName,
    List<Lineup> starters,
    List<Lineup> subs,
  ) {
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
            child: Text(
              teamName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          Container(height: 1, color: AppColors.border),
          ...[...starters, ...subs].map((p) => _buildPlayerRow(p)),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Lineup p) {
    final found  = widget.foundPlayers.contains(p.playerName);
    final passed = widget.passedPlayers.contains(p.playerName);
    final color  = found ? AppColors.accentBright : passed ? AppColors.amber : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            found  ? Icons.check_circle_outline :
            passed ? Icons.visibility_outlined :
                     Icons.cancel_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Text(
            p.playerName,
            style: TextStyle(
              color: found ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: found ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              p.starter ? p.position : 'REM',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
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
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LineupMatchPageIntro()),
                (r) => r.isFirst,
              ),
              child: const Text('Accueil', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  builder: (_) => LineupMatchPage(difficulty: widget.difficulty),
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
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
        Text(sublabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
