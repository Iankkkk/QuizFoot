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
import '../../constants/app_colors.dart';
import '../../data/qui_a_menti_api.dart';
import '../../data/api_exception.dart';
import '../../models/claim.dart';
import 'qui_a_menti_score.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuiAMentiGame
// ─────────────────────────────────────────────────────────────────────────────

class QuiAMentiGame extends StatefulWidget {
  const QuiAMentiGame({super.key});

  @override
  State<QuiAMentiGame> createState() => _QuiAMentiGameState();
}

class _QuiAMentiGameState extends State<QuiAMentiGame> {
  // ── State ──────────────────────────────────────────────────────────────────

  bool _isLoading = true;

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
    _loadClaim();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  /// Fetches a random claim from the API and initialises game state.
  Future<void> _loadClaim() async {
    try {
      final claims = await QuiAMentiApi.fetchRandomClaim();
      if (claims.isEmpty) throw Exception('Aucun claim trouvé.');

      final picked = claims[Random().nextInt(claims.length)];

      if (picked.candidates.length != 10) {
        throw Exception('Ce claim ne contient pas exactement 10 joueurs.');
      }

      // Shuffle candidates so the order is unpredictable each game.
      final shuffled = List<Candidate>.from(picked.candidates)..shuffle();

      setState(() {
        _claim = picked;
        _toClassify = shuffled;
        _trueBucket = [];
        _falseBucket = [];
        _isLoading = false;
      });

      _startCountdown();
    } on ApiException catch (e) {
      _showError(e.userMessage);
    } catch (_) {
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
        const SnackBar(
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
    final bool invertedPerfect = correct == 0; // everything is flipped
    final bool lastAttempt = _validationCount >= 3;

    setState(() => _lastScore = correct);

    if (perfect || invertedPerfect || lastAttempt) {
      // Short pause so the score banner is visible before navigating.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _endGame(timedOut: false, correctCount: correct);
      });
    } else {
      // Lock 1 card in VRAI + 1 in FAUX only if score strictly exceeds
      // current locked count + 2, ensuring at least 1 unknown correct card
      // remains among the unlocked ones (prevents trivial deduction).
      if (correct > _lockedCardNames.length + 2) {
        setState(() => _revealOnePerBucket());
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

  /// Locks one correctly-placed card in the VRAI bucket and one in the FAUX
  /// bucket. Locked cards cannot be moved and act as confirmed hints.
  void _revealOnePerBucket() {
    // Pick 1 from VRAI (a true candidate correctly placed there)
    final trueRevealable = _trueBucket
        .where((c) => c.isTrue && !_lockedCardNames.contains(c.name))
        .toList();
    if (trueRevealable.isNotEmpty) {
      _lockedCardNames.add(
        trueRevealable[Random().nextInt(trueRevealable.length)].name,
      );
    }

    // Pick 1 from FAUX (a false candidate correctly placed there)
    final falseRevealable = _falseBucket
        .where((c) => !c.isTrue && !_lockedCardNames.contains(c.name))
        .toList();
    if (falseRevealable.isNotEmpty) {
      _lockedCardNames.add(
        falseRevealable[Random().nextInt(falseRevealable.length)].name,
      );
    }
  }

  // ── End game ──────────────────────────────────────────────────────────────

  /// Stops the timer, computes the final score, and navigates to [QuiAMentiScore].
  void _endGame({required bool timedOut, int? correctCount}) {
    _countdownTimer?.cancel();

    // If called from the timer, compute the correct count from current state.
    final int correct = correctCount ?? _computeCorrectCount();

    // Points based on which attempt yielded 10/10. Zero if failed or timed out.
    int points = 0;
    if (correct == 10) {
      if (_validationCount == 1)
        points = 100;
      else if (_validationCount == 2)
        points = 60;
      else
        points = 30;
    }

    final timeTaken = DateTime.now().difference(_startTime);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuiAMentiScore(
          points: points,
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
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.red),
      );
    }
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
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentBright,
                  ),
                )
              : Column(
                  children: [
                    _buildAppBar(),
                    _buildClaimCard(),
                    if (_lastScore != null) _buildScoreBanner(_lastScore!),
                    const SizedBox(height: 4),
                    Expanded(child: _buildGameArea()),
                    _buildValidateButton(),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Private widget builders ───────────────────────────────────────────────

  /// Top bar: back button | title | validation dots | countdown timer.
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
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
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Qui a menti ?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          // 3 dots — filled red for each validation used
          Row(
            children: List.generate(3, (i) {
              final used = i < _validationCount;
              return Container(
                margin: const EdgeInsets.only(left: 5),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: used ? AppColors.red : AppColors.border,
                ),
              );
            }),
          ),
          const SizedBox(width: 12),
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

  /// Banner showing the score of the last validation (e.g. "6/10 corrects").
  /// Color scales from red (0) to green (10).
  Widget _buildScoreBanner(int score) {
    final Color color;
    if (score == 10)
      color = AppColors.accentBright;
    else if (score >= 8)
      color = AppColors.accentBright;
    else if (score >= 6)
      color = AppColors.amber;
    else
      color = AppColors.red;

    final String label = score == 10
        ? '10/10 — Parfait ! 🎉'
        : score == 0
        ? '0/10 — Tout est inversé 😅'
        : '$score/10 corrects';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.equalizer_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Card that displays the claim statement.
  Widget _buildClaimCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.campaign_outlined,
            color: AppColors.accentBright,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _claim.claim,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
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
              const SizedBox(height: 6),
              // Candidate cards in a scrollable wrap
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: bucket.map(_buildCandidateCard).toList(),
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
                ? AppColors.accentBright.withOpacity(0.05)
                : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovered ? AppColors.accentBright : AppColors.border,
              width: isHovered ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'À classer  ${_toClassify.length} restant${_toClassify.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              _toClassify.isEmpty
                  ? const Text(
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

  /// A single candidate chip.
  ///   • Locked cards: green border + lock icon, not draggable.
  ///   • Normal: dark background, draggable.
  Widget _buildCandidateCard(Candidate c) {
    final bool isLocked = _lockedCardNames.contains(c.name);

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isLocked
            ? AppColors.accentBright.withOpacity(0.1)
            : AppColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLocked ? AppColors.accentBright : AppColors.border,
          width: isLocked ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLocked)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.lock_outline,
                size: 12,
                color: AppColors.accentBright,
              ),
            ),
          Text(
            c.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isLocked ? AppColors.accentBright : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );

    // Locked cards are not wrapped in Draggable.
    if (isLocked) return chip;

    return Draggable<Candidate>(
      data: c,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.9, child: chip),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: chip),
      child: chip,
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
              side: const BorderSide(color: AppColors.border),
            ),
            title: const Text(
              'Quitter la partie ?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'Ta progression sera perdue.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Continuer',
                  style: TextStyle(color: AppColors.accentBright),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Quitter',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}
