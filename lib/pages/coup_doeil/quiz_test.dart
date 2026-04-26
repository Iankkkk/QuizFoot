// quiz_test.dart
//
// The Coup d'œil game screen. Displays one player photo at a time and asks
// the player to type the player's name. Points are awarded based on speed.
//
// Flow:
//   1. initState → _loadPlayersAndStartQuiz()
//      Fetches players (from cache or API), builds a question sequence
//      according to [kDifficultyPlans], then shows the first photo.
//   2. Per question:
//      - Photo loads → _startQuestionTimer() → timer ticks every 100ms
//      - Player types → _submitAnswer() → correct / almost / wrong feedback
//      - Or player taps "Passer" → _skipQuestion()
//      - _nextQuestion() advances the index or ends the game
//   3. Last question answered → 2s pause → _showScorePage()

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diacritic/diacritic.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../constants/app_colors.dart';
import '../../data/difficulty_plans.dart';
import '../../data/players_data.dart';
import '../../data/api_exception.dart';
import '../../models/player.dart';
import '../../models/question_result.dart';
import 'quiz_score_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuizTest — StatefulWidget
// ─────────────────────────────────────────────────────────────────────────────

class QuizTest extends StatefulWidget {
  /// One of the keys in [kDifficultyPlans] (e.g. 'Pro').
  final String difficulty;

  /// Optional category filter. null means all categories are included.
  final String? category;

  const QuizTest({super.key, required this.difficulty, this.category});

  @override
  State<QuizTest> createState() => _QuizTestState();
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuizTestState
// ─────────────────────────────────────────────────────────────────────────────

class _QuizTestState extends State<QuizTest> {

  // ── Asset paths ───────────────────────────────────────────────────────────
  static const String _memeCorrect = 'assets/images/correct.jpg';
  static const String _memeWrong   = 'assets/images/wrong.jpg';

  // ── Quiz state ────────────────────────────────────────────────────────────

  /// Players selected for this quiz session (one per question).
  List<Player> _selectedPlayers = [];

  /// Remaining players not yet used — pulled from to replace broken images.
  List<Player> _playerPool = [];

  /// Index of the current question (0-based).
  int _currentQuestion = 0;

  /// Total points accumulated so far.
  int _score = 0;

  /// Current value of the text field.
  String _answer = '';

  final TextEditingController _controller = TextEditingController();

  /// Ordered list of outcomes, one entry added per answered/skipped question.
  final List<QuestionResult> _questionResults = [];

  /// True if the player has typed at least one wrong answer for the current
  /// question. Used to distinguish "wrong then skipped" vs "just skipped".
  bool _hadWrongAttempt = false;

  // ── Timer ─────────────────────────────────────────────────────────────────

  /// Timestamp of when the current question's photo finished loading.
  /// The timer is computed relative to this, not to when the widget mounted.
  DateTime? _questionStartTime;

  /// Wall-clock start of the entire quiz, used for the total duration.
  DateTime? _quizStartTime;

  /// Periodic timer that updates [_elapsed] every 100ms.
  Timer? _questionTimer;

  /// Elapsed time for the current question, updated by [_questionTimer].
  Duration _elapsed = Duration.zero;

  /// Guards against the timer starting before the photo is fully displayed.
  /// Reset to false whenever a new photo URL is loaded.
  bool _photoLoaded = false;

  // ── Loading state ─────────────────────────────────────────────────────────

  /// True while players are being fetched and the question list is being built.
  bool _isLoading = true;

  // ── Visual feedback state ─────────────────────────────────────────────────

  /// True between the moment of answer submission and the question transition.
  /// Triggers an animated color overlay on the photo.
  bool _showPhotoOverlay = false;

  /// Color of the photo overlay (green / orange / red).
  Color _photoOverlayColor = Colors.green;

  /// Scale factor for the photo — briefly increased to 1.05 on each answer.
  double _photoScale = 1.0;

  // ── Feedback banner state ─────────────────────────────────────────────────

  String _feedbackMessage    = '';
  Color  _feedbackBannerColor = AppColors.accentBright;
  bool   _feedbackVisible    = false;
  String? _feedbackMeme;       // asset path, or null if no meme

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadPlayersAndStartQuiz();
  }

  @override
  void dispose() {
    _controller.dispose();
    _questionTimer?.cancel();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  /// Loads the player list, validates that enough players exist for the
  /// chosen difficulty and category, then builds the question sequence.
  Future<void> _loadPlayersAndStartQuiz() async {
    try {
      final allPlayers = await loadPlayers();

      // Apply category filter if one was selected on the intro page.
      final players = widget.category == null
          ? allPlayers
          : allPlayers.where((p) => p.categories.contains(widget.category)).toList();

      // Check that enough players exist at the required levels.
      final requiredLevels = (kDifficultyPlans[widget.difficulty] ?? [])
          .expand((step) => step.keys)
          .toSet();
      final matchingCount = players.where((p) => requiredLevels.contains(p.level)).length;

      if (players.length < 10 || matchingCount < 10) {
        // Not enough players — go back and show an error.
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              widget.category != null
                  ? 'Pas assez de joueurs pour la catégorie "${widget.category}" en difficulté ${widget.difficulty}.'
                  : 'Pas assez de joueurs pour cette difficulté.',
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }

      // Build the question list following the difficulty plan.
      final remainingPlayers = List<Player>.from(players);
      final selected = <Player>[];
      final plan = kDifficultyPlans[widget.difficulty] ?? [];

      for (final step in plan) {
        step.forEach((level, count) {
          for (int i = 0; i < count; i++) {
            final player = _pickRandomPlayer(remainingPlayers, [level]);
            selected.add(player);
            remainingPlayers.remove(player);
          }
        });
      }

      setState(() {
        _selectedPlayers = selected;
        _playerPool      = remainingPlayers..shuffle(); // reserve pool for image replacements
        _quizStartTime   = DateTime.now();
        _isLoading       = false;
        _photoLoaded     = false;
      });

    } on ApiException catch (apiError) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiError.userMessage),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (error, stack) {
      // Catch-all for unexpected errors — shown in debug builds only.
      debugPrint('QuizTest error: $error\n$stack');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur inattendue : $error'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 15),
        ));
      }
    }
  }

  /// Picks a random player matching one of the given [levels].
  /// If no player matches, recursively tries the next level up.
  /// Last resort: returns the player at the median index.
  Player _pickRandomPlayer(List<Player> players, List<int> levels) {
    final matching = players.where((p) => levels.contains(p.level)).toList();

    if (matching.isEmpty) {
      // No match at this level — climb up one level and retry.
      final maxLevel = players.map((p) => p.level).reduce((a, b) => a > b ? a : b);
      for (final level in levels) {
        if (level < maxLevel) return _pickRandomPlayer(players, [level + 1]);
      }
      // Absolute fallback: median player.
      return players[(players.length * 0.5).toInt()];
    }

    matching.shuffle();
    return matching.first;
  }

  /// Swaps the current player for a fresh one from the pool.
  /// Called by the image [errorBuilder] when a photo fails to load.
  void _replaceCurrentPlayer() {
    if (_playerPool.isEmpty) return;
    setState(() {
      _selectedPlayers[_currentQuestion] = _playerPool.removeAt(0);
      _photoLoaded = false; // ensures the timer only starts after the new photo loads
    });
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  /// Starts (or restarts) the per-question timer.
  /// Only called from the image's [loadingBuilder] once the photo is ready.
  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _questionStartTime = DateTime.now();
    setState(() => _elapsed = Duration.zero);

    _questionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(_questionStartTime!);
      });
    });
  }

  // ── Scoring ───────────────────────────────────────────────────────────────

  /// Returns the points a correct answer is worth right now,
  /// based on the elapsed time on the current question.
  ///
  ///  < 6s  → 5 pts  |  < 9s  → 4 pts  |  < 12s → 3 pts
  ///  < 20s → 2 pts  |  20s+  → 1 pt
  int _computePoints(Duration elapsed) {
    final seconds = elapsed.inSeconds;
    if (seconds < 6)  return 5;
    if (seconds < 9)  return 4;
    if (seconds < 12) return 3;
    if (seconds < 20) return 2;
    return 1;
  }

  /// Points the player would earn if they answered correctly right now.
  int _currentPoints() {
    final seconds = _elapsed.inSeconds;
    if (seconds < 6)  return 5;
    if (seconds < 9)  return 4;
    if (seconds < 12) return 3;
    if (seconds < 20) return 2;
    return 1;
  }

  /// Formatted label shown in the timer pill (e.g. "+5 pts").
  String _currentPointsLabel() {
    final pts = _currentPoints();
    return '+$pts pt${pts > 1 ? 's' : ''}';
  }

  /// Color of the points label — transitions from green to red as time passes.
  Color _currentPointsColor() => AppColors.forPoints(_currentPoints());

  // ── Answer handling ───────────────────────────────────────────────────────

  /// Evaluates the current answer against all accepted names for the player.
  /// Uses fuzzy similarity so minor typos are forgiven.
  ///
  /// Outcomes:
  ///   similarity > 0.8  → correct answer  (double medium haptic, green feedback)
  ///   similarity > 0.4  → almost correct  (double heavy haptic, orange feedback)
  ///   otherwise         → wrong answer    (no haptic, red feedback, auto-advance)
  Future<void> _submitAnswer() async {
    final typedAnswer = removeDiacritics(_answer.trim().toLowerCase());

    // Compute similarity against every accepted name — keep the best score.
    final acceptedNames = _selectedPlayers[_currentQuestion].allNames
        .map((name) => removeDiacritics(name.toLowerCase()))
        .toList();
    final bestSimilarity = acceptedNames
        .map((name) => typedAnswer.similarityTo(name))
        .reduce((a, b) => a > b ? a : b);

    final bool isCorrect    = bestSimilarity > 0.8;
    final bool almostCorrect = !isCorrect && bestSimilarity > 0.4;

    if (isCorrect) {
      // ── Correct ──────────────────────────────────────────────────────────
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 80), HapticFeedback.mediumImpact);

      final points = _computePoints(DateTime.now().difference(_questionStartTime!));
      _score += points;
      _questionResults.add(QuestionResult(
        playerName: _selectedPlayers[_currentQuestion].name,
        correct: true,
        attempted: true,
        points: points,
      ));

      setState(() {
        _showPhotoOverlay  = true;
        _photoScale        = 1.05;
        _photoOverlayColor = Colors.green;
      });
      _controller.clear();
      _questionTimer?.cancel();
      _showFeedback('✅ Bonne réponse ! Suuuuuuuuu !!', Colors.green[700]!, meme: _memeCorrect);

      // Brief pause so the player sees the result before moving on.
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() { _showPhotoOverlay = false; _photoScale = 1.0; });
        _nextQuestion();
      });

    } else if (almostCorrect) {
      // ── Almost correct ───────────────────────────────────────────────────
      _hadWrongAttempt = true;
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 60), HapticFeedback.heavyImpact);

      setState(() {
        _showPhotoOverlay  = true;
        _photoScale        = 1.05;
        _photoOverlayColor = Colors.orange;
      });
      _showFeedback("🟡 T'y es presque grand...", Colors.orange[700]!, meme: _memeWrong);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() { _showPhotoOverlay = false; _photoScale = 1.0; });
      });

    } else {
      // ── Wrong answer ─────────────────────────────────────────────────────
      // No haptic for a wrong answer — only vibrate on near-misses and successes.
      _questionResults.add(QuestionResult(
        playerName: _selectedPlayers[_currentQuestion].name,
        correct: false,
        attempted: true,
        points: 0,
      ));

      setState(() {
        _showPhotoOverlay  = true;
        _photoScale        = 1.05;
        _photoOverlayColor = Colors.red;
      });
      _controller.clear();
      _showFeedback(
        '❌ Nan !! T\'es trompé ! La bonne réponse était : ${_selectedPlayers[_currentQuestion].name}',
        Colors.red[700]!,
        meme: _memeWrong,
      );

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() { _showPhotoOverlay = false; _photoScale = 1.0; });
      });

      _questionTimer?.cancel();
      _nextQuestion();
    }
  }

  /// Skips the current question without penalising the score.
  /// Records whether the player had already attempted an answer.
  void _skipQuestion() {
    final playerName = _selectedPlayers[_currentQuestion].name;

    _questionResults.add(QuestionResult(
      playerName: playerName,
      correct: false,
      attempted: _hadWrongAttempt, // true if the player typed something wrong first
      points: 0,
    ));

    _controller.clear();
    _showFeedback("⏩ Passée ! C'était : $playerName", AppColors.textSecondary);
    _questionTimer?.cancel();
    _nextQuestion();
  }

  // ── Question progression ──────────────────────────────────────────────────

  /// Advances to the next question, or ends the game on the last one.
  void _nextQuestion() {
    if (_currentQuestion < _selectedPlayers.length - 1) {
      setState(() {
        _currentQuestion++;
        _answer          = '';
        _photoLoaded     = false;
        _hadWrongAttempt = false;
      });
    } else {
      // Last question answered — short pause so the player can see the result.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _showScorePage();
      });
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  /// Saves the result to history and navigates to [QuizScorePage].
  Future<void> _showScorePage() async {
    final duration = DateTime.now().difference(_quizStartTime!);
    await _saveResultToHistory(_score, _selectedPlayers.length, duration);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScorePage(
          score:      _score,
          total:      _selectedPlayers.length,
          timeTaken:  duration,
          results:    List.unmodifiable(_questionResults),
          difficulty: widget.difficulty,
          category:   widget.category,
        ),
      ),
    );
  }

  /// Shows a confirmation dialog before letting the player leave mid-game.
  /// Also hooked into the Android system back gesture via [PopScope].
  void _showQuitDialog() {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Quitter la partie ?',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Ta progression sera perdue.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continuer',
              style: TextStyle(color: AppColors.accentBright, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text(
              'Quitter',
              style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Feedback banner ───────────────────────────────────────────────────────

  /// Shows the inline feedback banner for 3 seconds, then hides it.
  void _showFeedback(String message, Color color, {String? meme}) {
    setState(() {
      _feedbackMessage     = message;
      _feedbackBannerColor = color;
      _feedbackMeme        = meme;
      _feedbackVisible     = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _feedbackVisible = false);
    });
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  /// Appends a summary entry to the quiz history stored in SharedPreferences.
  Future<void> _saveResultToHistory(int score, int total, Duration timeTaken) async {
    final prefs   = await SharedPreferences.getInstance();
    final history = prefs.getStringList('quizHistory') ?? [];

    final now   = DateTime.now();
    final date  = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    var entry   = '$date — Score: $score / $total';

    if (score == total) {
      entry += ' — Temps: ${timeTaken.inMinutes}m ${timeTaken.inSeconds % 60}s';
    }

    history.add(entry);
    await prefs.setStringList('quizHistory', history);
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// On web, routes the image through a Vercel proxy to bypass CORS / hotlink
  /// restrictions. On mobile, returns the URL unchanged.
  String _imageUrl(String url) {
    if (kIsWeb) {
      return Uri.base
          .resolve('api/image')
          .replace(queryParameters: {'url': url})
          .toString();
    }
    return url;
  }

  // ── Build helpers ─────────────────────────────────────────────────────────

  /// Formatted MM:SS timer text shown inside the timer pill.
  Widget _buildTimerText() {
    final minutes = _elapsed.inMinutes;
    final seconds = _elapsed.inSeconds % 60;
    return Text(
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Show a minimal loading screen while players are being fetched.
    if (_isLoading || _selectedPlayers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final int total       = _selectedPlayers.length;
    final int current     = _currentQuestion;
    final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // PopScope intercepts the Android system back gesture and shows a
    // confirmation dialog instead of immediately leaving the game.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showQuitDialog();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        extendBodyBehindAppBar: true, // photo fills the full screen including under the AppBar
        appBar: _buildOverlayAppBar(),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve:  Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          // ValueKey forces a full widget rebuild on question change,
          // triggering the slide/fade transition.
          child: Column(
            key: ValueKey(_currentQuestion),
            children: [
              _buildPhotoSection(),
              _buildBottomSection(total: total, current: current, keyboardOpen: keyboardOpen),
            ],
          ),
        ),
      ),
    );
  }

  /// Transparent AppBar overlaid on the photo. Contains only the back button
  /// so the photo is as unobstructed as possible.
  PreferredSizeWidget _buildOverlayAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showQuitDialog,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-bleed photo with three overlaid layers:
  ///   1. Gradient fade at the bottom to blend into the dark section.
  ///   2. Semi-transparent color overlay on answer submission.
  ///   3. Player name reveal on a correct answer.
  Widget _buildPhotoSection() {
    return Flexible(
      flex: 5,
      child: AnimatedScale(
        scale:    _photoScale,
        duration: const Duration(milliseconds: 200),
        curve:    Curves.easeOut,
        child: Stack(
          fit: StackFit.expand,
          children: [

            // ── Player photo ──────────────────────────────────────────────
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              panEnabled: true,
              child: Image.network(
                // ValueKey ensures Flutter creates a fresh widget when the URL
                // changes (e.g. after a replacement), preventing stale frames.
                key: ValueKey(_selectedPlayers[_currentQuestion].imageUrl),
                _imageUrl(_selectedPlayers[_currentQuestion].imageUrl),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter, // crop from the bottom to keep the face visible
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    // Photo has fully loaded — start the timer once, on the first frame.
                    if (!_photoLoaded) {
                      _photoLoaded = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _startQuestionTimer();
                      });
                    }
                    return child;
                  }
                  // Still downloading — show a spinner.
                  return Container(
                    color: AppColors.card,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.accentBright),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  // Broken image — swap silently for another player from the pool.
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _replaceCurrentPlayer(),
                  );
                  return Container(
                    color: AppColors.card,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.accentBright),
                    ),
                  );
                },
              ),
            ),

            // ── Bottom gradient ───────────────────────────────────────────
            // Smooth visual transition between the photo and the dark bottom section.
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end:   Alignment.topCenter,
                      colors: [AppColors.bg, AppColors.bg.withOpacity(0)],
                    ),
                  ),
                ),
              ),
            ),

            // ── Answer feedback overlay ───────────────────────────────────
            // Semi-transparent color flash on correct / almost / wrong.
            IgnorePointer(
              child: AnimatedOpacity(
                opacity:  _showPhotoOverlay ? 0.35 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(color: _photoOverlayColor),
              ),
            ),

            // ── Player name reveal ────────────────────────────────────────
            // On a correct answer, the player's name fades in over the photo.
            // Helps the player memorise the face-name association.
            IgnorePointer(
              child: AnimatedOpacity(
                opacity:  (_showPhotoOverlay && _photoOverlayColor == Colors.green) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                curve:    Curves.easeOut,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _selectedPlayers[_currentQuestion].name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  /// Dark section below the photo. Contains progress, timer, feedback banner,
  /// text field, and action buttons.
  ///
  /// Wrapped in [SingleChildScrollView] so content never overflows on small
  /// screens or when the keyboard is open. The flex ratio shifts from 4 to 6
  /// when the keyboard opens, giving the bottom section more space.
  Widget _buildBottomSection({
    required int total,
    required int current,
    required bool keyboardOpen,
  }) {
    return Flexible(
      flex: keyboardOpen ? 6 : 4,
      child: Container(
        color: AppColors.bg,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Progress row ────────────────────────────────────────────
              // Hidden when keyboard is open to save vertical space.
              if (!keyboardOpen) ...[
                _buildProgressRow(current: current, total: total),
                const SizedBox(height: 8),
              ],

              // ── Timer pill ──────────────────────────────────────────────
              _buildTimerPill(),
              const SizedBox(height: 8),

              // ── Feedback banner ─────────────────────────────────────────
              _buildFeedbackBanner(),

              // ── Text field ──────────────────────────────────────────────
              _buildTextField(),
              const SizedBox(height: 12),

              // ── Action buttons ──────────────────────────────────────────
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// Progress bar + "X/Y · Category" label + total score.
  Widget _buildProgressRow({required int current, required int total}) {
    return Row(
      children: [
        // Progress bar
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (current + 1) / total,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentBright),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // "3/10 · Ligue 1"
        Text(
          '${current + 1}/$total${widget.category != null ? ' · ${widget.category}' : ''}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        // Total points accumulated so far
        Text(
          '$_score pt${_score > 1 ? 's' : ''}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// Pill showing ⏱ MM:SS | +X pts. The points label changes color as time passes.
  Widget _buildTimerPill() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppColors.textPrimary),
              const SizedBox(width: 5),
              _buildTimerText(),
              // Vertical separator
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 1,
                height: 14,
                color: AppColors.separator,
              ),
              Text(
                _currentPointsLabel(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _currentPointsColor(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Animated feedback banner that appears below the timer pill.
  /// Uses [AnimatedSwitcher] for a smooth fade in/out.
  Widget _buildFeedbackBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _feedbackVisible
          ? Container(
              key: const ValueKey('visible'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _feedbackBannerColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _feedbackBannerColor.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  // Optional meme image (shown on correct and wrong answers)
                  if (_feedbackMeme != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        _feedbackMeme!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      _feedbackMessage,
                      style: TextStyle(
                        color: _feedbackBannerColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('hidden')),
    );
  }

  /// Player name input field. autofocus is off so the keyboard doesn't
  /// open automatically when the question loads.
  Widget _buildTextField() {
    return TextField(
      autofocus: false,
      controller: _controller,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Nom du joueur...',
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentBright, width: 2),
        ),
      ),
      onChanged: (value) => setState(() => _answer = value),
      // Allow submitting with the keyboard's done/return button.
      onSubmitted: (_) {
        if (_answer.trim().isNotEmpty) _submitAnswer();
      },
    );
  }

  /// "Passer" (skip) and "Valider ✓" (submit) buttons.
  /// "Valider" is visually disabled when the field is empty, but stays visible.
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.textSecondary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _skipQuestion,
            child: const Text('Passer', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBright,
              foregroundColor: Colors.white,
              // Keeps the button visible when disabled (instead of going invisible).
              disabledBackgroundColor: AppColors.accentBright.withOpacity(0.35),
              disabledForegroundColor: Colors.white.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _answer.trim().isEmpty ? null : _submitAnswer,
            child: const Text(
              'Valider ✓',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
