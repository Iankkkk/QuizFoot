// qui_a_menti_game.dart
//
// Core game page for "Qui a menti ?".
//
// Game flow:
//   1. Load a random claim from the API (10 candidates, 5 true / 5 false)
//   2. Player drag-and-drops candidates into VRAI or FAUX columns
//   3. Up to 3 validations:
//        • Cards that moved since the last attempt flash green (correct move)
//          or red (wrong move) for 1.5 s
//        • After each non-final validation, 1 correctly placed card is revealed
//          and locked so the player can use it as a reference
//        • 10/10 or 0/10 → immediate end (0/10 = perfectly inverted)
//   4. Timer: 5 minutes — game ends automatically when it expires
//   5. On game end → QuiAMentiScore page
//
// Scoring (points awarded on the score page):
//   • 1st validation correct  → 100 pts
//   • 2nd validation correct  → 60 pts
//   • 3rd validation correct  → 30 pts
//   • Failed all 3 or timeout →  0 pts

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../data/qui_a_menti_api.dart';
import '../../data/api_exception.dart';
import '../../models/claim.dart';
import 'qui_a_menti_confetti.dart';
import 'qui_a_menti_score.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuiAMentiGame
// ─────────────────────────────────────────────────────────────────────────────

class QuiAMentiGame extends StatefulWidget {
  const QuiAMentiGame({super.key});

  @override
  State<QuiAMentiGame> createState() => _QuiAMentiGameState();
}

class _QuiAMentiGameState extends State<QuiAMentiGame>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────

  bool _isLoading = true;
  String? _errorMessage;

  /// The loaded claim (statement + 10 candidates).
  late Claim _claim;

  /// Candidates not yet placed in either bucket.
  List<Candidate> _toClassify = [];

  /// Candidates placed in the "VRAI" (true) bucket.
  List<Candidate> _trueBucket = [];

  /// Candidates placed in the "FAUX" (false) bucket.
  List<Candidate> _falseBucket = [];

  /// Names of candidates that are revealed / locked after a validation.
  /// Locked cards cannot be moved and display a distinct visual.
  final Set<String> _lockedCardNames = {};

  /// Snapshots of each past validation (candidate name → bucket 'true'/'false').
  /// Used to block duplicate validations.
  final List<Map<String, String>> _previousSnapshots = [];

  /// Score of the last validation (null before first validation).
  /// Displayed as a persistent banner below the claim card.
  int? _lastScore;

  /// Number of validations used so far (0 – 3).
  int _validationCount = 0;

  // ── Claim entrance ────────────────────────────────────────────────────────

  late final AnimationController _claimEntranceController;
  late final Animation<double> _claimScale;
  late final Animation<double> _claimOpacity;

  // ── Confetti ──────────────────────────────────────────────────────────────

  /// Controller for the full-screen confetti overlay (10/10 on first attempt).
  late final AnimationController _confettiController;

  /// Whether to show the confetti overlay.
  bool _showConfetti = false;

  // ── Outcome animations ────────────────────────────────────────────────────

  /// Shared controller for win-particles (2nd/3rd victory) and defeat effects.
  late final AnimationController _outcomeController;

  /// Horizontal shake applied to the whole content on defeat.
  late final Animation<double> _shakeAnim;

  /// Red flash opacity on defeat (rises then fades quickly).
  late final Animation<double> _defeatFlashAnim;

  /// Whether to show floating star particles (2nd/3rd attempt victory).
  bool _showWinParticles = false;

  /// Whether to show the defeat shake + flash.
  bool _showDefeat = false;

  // ── Timer ─────────────────────────────────────────────────────────────────

  /// Total game duration in seconds (5 minutes).
  static const int _totalSeconds = 5 * 60;

  /// Seconds remaining on the clock.
  int _secondsLeft = _totalSeconds;

  Timer? _countdownTimer;

  /// Wall-clock moment when the game started (used to compute elapsed time).
  late final DateTime _startTime;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _claimEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _claimScale = CurvedAnimation(
      parent: _claimEntranceController,
      curve: Curves.easeOutBack,
    );
    _claimOpacity = CurvedAnimation(
      parent: _claimEntranceController,
      curve: Curves.easeIn,
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _outcomeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Shake: quick left-right oscillation, finishes at 65% of the animation.
    _shakeAnim =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -14.0), weight: 15),
          TweenSequenceItem(tween: Tween(begin: -14.0, end: 14.0), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 14.0, end: -9.0), weight: 25),
          TweenSequenceItem(tween: Tween(begin: -9.0, end: 6.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 10),
        ]).animate(
          CurvedAnimation(
            parent: _outcomeController,
            curve: const Interval(0.0, 0.65),
          ),
        );
    // Red flash: peaks at 18% opacity then fades out in the first half.
    _defeatFlashAnim =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.18), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.18, end: 0.0), weight: 70),
        ]).animate(
          CurvedAnimation(
            parent: _outcomeController,
            curve: const Interval(0.0, 0.50),
          ),
        );

    _loadClaim();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _claimEntranceController.dispose();
    _confettiController.dispose();
    _outcomeController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  /// Fetches a random claim from the API and initialises game state.
  /// Retries once silently before showing the error screen.
  Future<void> _loadClaim({bool isRetry = false}) async {
    try {
      final claims = await QuiAMentiApi.fetchRandomClaim();
      final valid = claims.where((c) => c.candidates.length == 10).toList();
      if (valid.isEmpty) throw Exception('Aucun claim valide trouvé.');

      final picked = valid[Random().nextInt(valid.length)];

      // Shuffle candidates so the order is unpredictable each game.
      final shuffled = List<Candidate>.from(picked.candidates)..shuffle();

      setState(() {
        _claim = picked;
        _toClassify = shuffled;
        _trueBucket = [];
        _falseBucket = [];
        _isLoading = false;
      });

      _claimEntranceController.forward();
      _startCountdown();
    } on ApiException catch (e) {
      if (!isRetry) { _loadClaim(isRetry: true); return; }
      _showError(e.userMessage);
    } catch (_) {
      if (!isRetry) { _loadClaim(isRetry: true); return; }
      _showError('Erreur inattendue. Réessaie.');
    }
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  /// Starts a 1-second periodic timer. Ends the game when it hits zero.
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _countdownTimer?.cancel();
        _endGame(timedOut: true);
      }
    });
  }

  // ── Move logic ────────────────────────────────────────────────────────────

  /// Moves [c] into [target] bucket.
  /// Rejects locked cards. No bucket size limit — the validate button
  /// enforces the 5/5 balance constraint instead.
  void _moveCandidate(Candidate c, List<Candidate> target) {
    if (_lockedCardNames.contains(c.name)) return; // locked — cannot move

    HapticFeedback.lightImpact(); // subtle vibration on card drop

    setState(() {
      _toClassify.remove(c);
      _trueBucket.remove(c);
      _falseBucket.remove(c);
      target.add(c);
    });
  }

  /// Returns [c] from any bucket back to the unclassified pool.
  void _returnCandidate(Candidate c) {
    if (_lockedCardNames.contains(c.name)) return; // locked — cannot move

    setState(() {
      _trueBucket.remove(c);
      _falseBucket.remove(c);
      if (!_toClassify.contains(c)) _toClassify.add(c);
    });
  }

  // ── Validation ────────────────────────────────────────────────────────────

  /// Called when the player taps "Valider".
  void _validate() {
    // Both buckets must be balanced (5 each) — enforced by the button, but
    // kept as a safety guard.
    if (_trueBucket.length != 5 || _falseBucket.length != 5) return;

    // Block duplicate validations (same placement as a previous attempt).
    final snapshot = _buildSnapshot();
    if (_isDuplicateSnapshot(snapshot)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Tu as déjà validé cette disposition !'),
          backgroundColor: AppColors.amber,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _previousSnapshots.add(snapshot);

    // Count correctly placed candidates.
    int correct = _computeCorrectCount();

    _validationCount++;

    final bool perfect = correct == 10;
    final bool veryLow = correct <= 2; // 0 or 2 → too informative to continue
    final bool lastAttempt = _validationCount >= 3;

    setState(() => _lastScore = correct);

    if (perfect || veryLow || lastAttempt) {
      final bool showConfetti = perfect && _validationCount == 1;
      final bool showWinParticles = perfect && _validationCount > 1;
      final bool showDefeat = !perfect;

      if (showConfetti) {
        setState(() => _showConfetti = true);
        _confettiController.forward(from: 0);
      }
      if (showWinParticles) {
        setState(() => _showWinParticles = true);
        _outcomeController.forward(from: 0);
      }
      if (showDefeat) {
        setState(() => _showDefeat = true);
        _outcomeController.forward(from: 0);
      }

      // Give each animation enough time to be seen before navigating.
      final delay = showConfetti
          ? const Duration(milliseconds: 1800)
          : (showWinParticles || showDefeat)
          ? const Duration(milliseconds: 1200)
          : const Duration(milliseconds: 800);
      Future.delayed(delay, () {
        if (mounted) _endGame(timedOut: false, correctCount: correct);
      });
    } else {
      if (_previousSnapshots.length == 1) {
        // First validation: random reveals based on score.
        final int revealsPerBucket = correct == 8 ? 2 : (correct >= 6 ? 1 : 0);
        if (revealsPerBucket > 0) {
          setState(() => _revealPerBucket(revealsPerBucket));
          HapticFeedback.mediumImpact();
          Future.delayed(const Duration(milliseconds: 120), HapticFeedback.mediumImpact);
        }
      } else {
        // Subsequent validations: lock whatever the user correctly moved.
        final int beforeCount = _lockedCardNames.length;
        setState(() => _revealNewlyCorrect());
        if (_lockedCardNames.length > beforeCount) {
          HapticFeedback.mediumImpact();
          Future.delayed(const Duration(milliseconds: 120), HapticFeedback.mediumImpact);
        }
      }
    }
  }

  /// Computes how many candidates are in the correct bucket right now.
  int _computeCorrectCount() {
    int correct = 0;
    for (final c in _trueBucket) {
      if (c.isTrue) correct++;
    }
    for (final c in _falseBucket) {
      if (!c.isTrue) correct++;
    }
    return correct;
  }

  /// Locks every candidate the user correctly moved since the previous attempt.
  void _revealNewlyCorrect() {
    if (_previousSnapshots.length < 2) return;
    final prev = _previousSnapshots[_previousSnapshots.length - 2];
    final curr = _previousSnapshots[_previousSnapshots.length - 1];

    for (final c in _claim.candidates) {
      if (_lockedCardNames.contains(c.name)) continue;
      final currBucket = curr[c.name];
      if (currBucket == null) continue;
      if (currBucket == prev[c.name]) continue; // didn't move
      final isNowCorrect = (currBucket == 'true' && c.isTrue) ||
                           (currBucket == 'false' && !c.isTrue);
      if (isNowCorrect) _lockedCardNames.add(c.name);
    }
  }

  /// Locks [count] correctly-placed cards per bucket as confirmed hints.
  void _revealPerBucket(int count) {
    final trueRevealable = _trueBucket
        .where((c) => c.isTrue && !_lockedCardNames.contains(c.name))
        .toList()..shuffle();
    for (int i = 0; i < count && i < trueRevealable.length; i++) {
      _lockedCardNames.add(trueRevealable[i].name);
    }

    final falseRevealable = _falseBucket
        .where((c) => !c.isTrue && !_lockedCardNames.contains(c.name))
        .toList()..shuffle();
    for (int i = 0; i < count && i < falseRevealable.length; i++) {
      _lockedCardNames.add(falseRevealable[i].name);
    }
  }

  // ── End game ──────────────────────────────────────────────────────────────

  /// Stops the timer, computes stars, and navigates to [QuiAMentiScore].
  void _endGame({required bool timedOut, int? correctCount}) {
    _countdownTimer?.cancel();

    final int correct = correctCount ?? _computeCorrectCount();

    // Stars: only awarded for a perfect 10/10.
    // 3 stars → 1st attempt, 2 stars → 2nd, 1 star → 3rd, 0 → failed/timeout.
    int stars = 0;
    if (correct == 10) {
      if (_validationCount == 1)      stars = 3;
      else if (_validationCount == 2) stars = 2;
      else                            stars = 1;
    }

    final timeTaken = DateTime.now().difference(_startTime);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuiAMentiScore(
          stars: stars,
          correctCount: correct,
          validationsUsed: _validationCount,
          timeTaken: timeTaken,
          timedOut: timedOut,
          allCandidates: _claim.candidates,
          finalTrueBucket: List.from(_trueBucket),
          finalFalseBucket: List.from(_falseBucket),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Builds a snapshot of the current bucket placement.
  /// Key = candidate name, value = 'true' | 'false'.
  Map<String, String> _buildSnapshot() => {
    for (final c in _trueBucket) c.name: 'true',
    for (final c in _falseBucket) c.name: 'false',
  };

  /// Returns true if [snapshot] matches any previously validated placement.
  bool _isDuplicateSnapshot(Map<String, String> snapshot) {
    for (final prev in _previousSnapshots) {
      if (prev.length == snapshot.length &&
          prev.keys.every((k) => prev[k] == snapshot[k])) {
        return true;
      }
    }
    return false;
  }

  void _showError(String message) {
    if (mounted) setState(() { _isLoading = false; _errorMessage = message; });
  }

  /// Formatted timer string "MM:SS".
  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Timer color: red under 1 min, amber under 2 min, muted otherwise.
  Color get _timerColor {
    if (_secondsLeft <= 60) return AppColors.red;
    if (_secondsLeft <= 120) return AppColors.amber;
    return AppColors.textSecondary;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept Android back gesture — ask for confirmation.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _showExitDialog();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            // Main content — wrapped for the defeat shake.
            AnimatedBuilder(
              animation: _outcomeController,
              builder: (_, child) => Transform.translate(
                offset: _showDefeat ? Offset(_shakeAnim.value, 0) : Offset.zero,
                child: child,
              ),
              child: SafeArea(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentBright,
                        ),
                      )
                    : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_rounded, color: AppColors.textSecondary, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentBright,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  setState(() { _isLoading = true; _errorMessage = null; });
                                  _loadClaim();
                                },
                                child: Text('Réessayer'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          _buildAppBar(),
                          _buildClaimCard(),
                          if (!_showConfetti && !_showWinParticles) _buildAttemptsBar(),
                          if (_lastScore != null)
                            _buildScoreBanner(_lastScore!),
                          const SizedBox(height: 4),
                          Expanded(child: _buildGameArea()),
                          _buildValidateButton(),
                        ],
                      ),
              ),
            ),
            // Defeat: red flash overlay.
            if (_showDefeat)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _outcomeController,
                  builder: (_, __) => Container(
                    color: AppColors.red.withValues(
                      alpha: _defeatFlashAnim.value,
                    ),
                  ),
                ),
              ),
            // Victory 2nd/3rd attempt: floating star particles.
            if (_showWinParticles)
              IgnorePointer(child: _buildWinParticlesOverlay()),
            // Victory 1st attempt: full-screen confetti.
            if (_showConfetti)
              IgnorePointer(
                child: QuiAMentiConfetti(controller: _confettiController),
              ),
          ],
        ),
      ),
    );
  }

  // ── Private widget builders ───────────────────────────────────────────────

  /// Top bar: back button | title | validation dots | countdown timer.
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Back button — asks for confirmation before leaving
          GestureDetector(
            onTap: () async {
              final leave = await _showExitDialog();
              if (leave && mounted) Navigator.of(context).pop();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.bg,
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
          Expanded(
            child: Text(
              'Qui a menti ?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          // Countdown timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _timerLabel,
              style: TextStyle(
                color: _timerColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Progress bar showing attempts used (1 segment per attempt, red when used).
  Widget _buildAttemptsBar() {
    final int remaining = 3 - _validationCount;
    final String label = _validationCount == 0
        ? '3 tentatives disponibles'
        : remaining == 0
        ? 'Dernière tentative utilisée'
        : '$remaining tentative${remaining > 1 ? 's' : ''} restante${remaining > 1 ? 's' : ''}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // 3 segment progress bar
          ...List.generate(3, (i) {
            final used = i < _validationCount;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: used ? AppColors.red : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
          const SizedBox(width: 10),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: remaining == 1 ? AppColors.red : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Banner showing score + validated players count after a validation.
  Widget _buildScoreBanner(int score) {
    final Color scoreColor;
    if (score >= 8)
      scoreColor = AppColors.accentBright;
    else if (score == 6)
      scoreColor = AppColors.amber;
    else
      scoreColor = AppColors.red;

    final int validated = _lockedCardNames.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: scoreColor, size: 16),
          const SizedBox(width: 6),
          Text(
            '$score bien placés',
            style: TextStyle(
              color: scoreColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (validated > 0) ...[
            const SizedBox(width: 16),
            Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 14),
            const SizedBox(width: 6),
            Text(
              '$validated joueur${validated > 1 ? 's' : ''} validé${validated > 1 ? 's' : ''}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Card that displays the claim statement.
  Widget _buildClaimCard() {
    return FadeTransition(
      opacity: _claimOpacity,
      child: ScaleTransition(
        scale: _claimScale,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: AppColors.accentBright.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.accentBright.withOpacity(0.45),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentBright.withOpacity(0.12),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_outlined, color: AppColors.accentBright, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'L\'AFFIRMATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentBright,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Text(
                  _claim.claim,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Main game area: VRAI and FAUX buckets side-by-side, pool below.
  Widget _buildGameArea() {
    return Column(
      children: [
        // Buckets row
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildDropZone(
                    title: '✅ VRAI',
                    bucket: _trueBucket,
                    accentColor: AppColors.accentBright,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropZone(
                    title: '❌ FAUX',
                    bucket: _falseBucket,
                    accentColor: AppColors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Unclassified pool
        _buildToClassifyPool(),
      ],
    );
  }

  /// A droppable zone (VRAI or FAUX) that accepts candidate cards.
  /// Highlights with [accentColor] when a card is being dragged over it.
  Widget _buildDropZone({
    required String title,
    required List<Candidate> bucket,
    required Color accentColor,
  }) {
    return DragTarget<Candidate>(
      onWillAcceptWithDetails: (details) =>
          !_lockedCardNames.contains(details.data.name),
      onAcceptWithDetails: (details) => _moveCandidate(details.data, bucket),
      builder: (context, inFlight, _) {
        final isHovered = inFlight.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHovered ? accentColor.withOpacity(0.08) : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovered ? accentColor : AppColors.border,
              width: isHovered ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              // Bucket title + count
              Text(
                '$title  ${bucket.length}/5',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 18),
              // Candidate cards — locked cards always rendered first
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        ([...bucket]..sort((a, b) {
                              final aL = _lockedCardNames.contains(a.name)
                                  ? 0
                                  : 1;
                              final bL = _lockedCardNames.contains(b.name)
                                  ? 0
                                  : 1;
                              return aL.compareTo(bL);
                            }))
                            .map(_buildCandidateCard)
                            .toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Pool of candidates not yet placed, also acts as a drop target
  /// to return cards from buckets.
  Widget _buildToClassifyPool() {
    return DragTarget<Candidate>(
      onWillAcceptWithDetails: (details) =>
          !_lockedCardNames.contains(details.data.name),
      onAcceptWithDetails: (details) => _returnCandidate(details.data),
      builder: (context, inFlight, _) {
        final isHovered = inFlight.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.fromLTRB(12, 20, 12, 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isHovered
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovered ? AppColors.textSecondary : AppColors.border,
              width: isHovered ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'À classer  ${_toClassify.length} restant${_toClassify.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              _toClassify.isEmpty
                  ? Text(
                      'Tous classés ✓',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.accentBright,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _toClassify.map(_buildCandidateCard).toList(),
                    ),
            ],
          ),
        );
      },
    );
  }

  /// Delegates rendering to [_CandidateCard] which handles its own animation.
  Widget _buildCandidateCard(Candidate c) {
    return _CandidateCard(
      candidate: c,
      isLocked: _lockedCardNames.contains(c.name),
    );
  }

  /// "Valider" button at the bottom.
  /// Disabled when buckets are not 5/5, all attempts used, or current
  /// placement is identical to a previous validation.
  Widget _buildValidateButton() {
    final bool allPlaced = _trueBucket.length == 5 && _falseBucket.length == 5;
    final bool isDuplicate =
        allPlaced && _isDuplicateSnapshot(_buildSnapshot());
    final bool canValidate = allPlaced && !isDuplicate && _validationCount < 3;
    final int remaining = 3 - _validationCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBright,
          disabledBackgroundColor: AppColors.border,
          foregroundColor: Colors.white,
          disabledForegroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 0),
        ),
        onPressed: canValidate ? _validate : null,
        child: Text(
          'Valider  ($remaining tentative${remaining > 1 ? 's' : ''} restante${remaining > 1 ? 's' : ''})',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  /// Dialog shown when the player tries to leave mid-game.
  Future<bool> _showExitDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.border),
            ),
            title: Text(
              'Quitter la partie ?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'Ta progression sera perdue.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Continuer',
                  style: TextStyle(color: AppColors.accentBright),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Quitter',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Overlay with rising geometric particles for 2nd or 3rd attempt victory.
  Widget _buildWinParticlesOverlay() {
    final colors = [
      AppColors.accentBright,
      AppColors.amber,
      Color(0xFF40C4FF), // light blue
      AppColors.accentBright,
      AppColors.orange,
      Color(0xFF40C4FF),
      AppColors.amber,
      AppColors.accentBright,
      AppColors.orange,
      AppColors.amber,
      AppColors.accentBright,
      Color(0xFF40C4FF),
    ];
    final size = MediaQuery.of(context).size;
    final rng  = Random(13);

    return SizedBox.expand(
      child: Stack(
        children: List.generate(colors.length, (i) {
          final x      = size.width  * 0.10 + rng.nextDouble() * size.width  * 0.80;
          final y      = size.height * 0.40 + rng.nextDouble() * size.height * 0.25;
          final sz     = 5.0 + rng.nextDouble() * 6.0;
          final circle = rng.nextBool(); // circle or rotated square
          return Positioned(
            left: x,
            top:  y,
            child: _FloatingParticle(
              size:       sz,
              color:      colors[i],
              isCircle:   circle,
              controller: _outcomeController,
              delay:      (i * 0.07).clamp(0.0, 0.7),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FloatingParticle — geometric shape that rises and fades out
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingParticle extends StatelessWidget {
  final double size;
  final Color color;
  final bool isCircle;
  final AnimationController controller;
  final double delay;

  const _FloatingParticle({
    required this.size,
    required this.color,
    required this.isCircle,
    required this.controller,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(delay.clamp(0.0, 0.9), 1.0, curve: Curves.easeOut),
    );
    final offsetY = Tween<double>(begin: 0, end: -140).animate(curved);
    final opacity = Tween<double>(begin: 0.9, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(
          (delay + 0.30).clamp(0.0, 1.0),
          1.0,
          curve: Curves.easeIn,
        ),
      ),
    );
    final rotation = Tween<double>(begin: 0, end: isCircle ? 0 : pi / 2)
        .animate(curved);

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, offsetY.value),
        child: Opacity(
          opacity: opacity.value.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: rotation.value,
            child: Container(
              width:  size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isCircle ? null : BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CandidateCard — animated candidate chip
// ─────────────────────────────────────────────────────────────────────────────

/// A candidate chip that plays a bounce + glow animation when it becomes locked.
/// Locked cards are not draggable and display a lock icon.
class _CandidateCard extends StatefulWidget {
  final Candidate candidate;
  final bool isLocked;

  const _CandidateCard({required this.candidate, required this.isLocked});

  @override
  State<_CandidateCard> createState() => _CandidateCardState();
}

class _CandidateCardState extends State<_CandidateCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    // Bounce: normal → pop → slight undershoot → settle
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.92), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Glow: fades in then out alongside the bounce
    _glow = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 60),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(_CandidateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger animation the moment this card becomes locked.
    if (widget.isLocked && !oldWidget.isLocked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: widget.isLocked
                  ? AppColors.accentBright.withOpacity(0.1)
                  : AppColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isLocked
                    ? AppColors.accentBright
                    : AppColors.border,
                width: widget.isLocked ? 1.5 : 1,
              ),
              // Glow effect during lock animation
              boxShadow: widget.isLocked && _glow.value > 0
                  ? [
                      BoxShadow(
                        color: AppColors.accentBright.withOpacity(
                          _glow.value * 0.6,
                        ),
                        blurRadius: 12 * _glow.value,
                        spreadRadius: 2 * _glow.value,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLocked)
                  Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.lock_outline,
                      size: 12,
                      color: AppColors.accentBright,
                    ),
                  ),
                Text(
                  widget.candidate.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isLocked
                        ? AppColors.accentBright
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Locked cards are not draggable.
    if (widget.isLocked) return chip;

    return Draggable<Candidate>(
      data: widget.candidate,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.9, child: chip),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: chip),
      child: chip,
    );
  }
}
