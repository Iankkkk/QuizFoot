import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diacritic/diacritic.dart';
import 'package:string_similarity/string_similarity.dart';
import '../models/player.dart';
import '../data/players_data.dart';
import '../data/api_exception.dart';

class QuizTest extends StatefulWidget {
  final String difficulty;
  final String? category;
  const QuizTest({super.key, required this.difficulty, this.category});

  @override
  State<QuizTest> createState() => _QuizTestState();
}

final Map<String, List<Map<int, int>>> difficultyPlans = {
  "Très Facile": [
    {1: 8},
    {2: 2},
  ],
  "Facile": [
    {1: 1},
    {2: 5},
    {3: 3},
    {4: 1},
  ],
  "Moyenne": [
    {3: 3},
    {4: 3},
    {5: 4},
  ],
  "Difficile": [
    {4: 1},
    {5: 3},
    {6: 3},
    {7: 2},
    {8: 1},
  ],
  "Impossible": [
    {8: 2},
    {9: 4},
    {10: 4},
  ],
};

class QuestionResult {
  final String playerName;
  final bool correct;
  final bool attempted; // au moins une mauvaise réponse avant de passer
  final int points;

  const QuestionResult({required this.playerName, required this.correct, required this.attempted, required this.points});
}

class _QuizTestState extends State<QuizTest> {
  List<Player> _players = [];
  List<Player> _selectedPlayers = [];
  List<Player> _playerPool = [];
  int _currentQuestion = 0;
  int _score = 0;
  String _answer = '';
  final TextEditingController _controller = TextEditingController();
  final List<QuestionResult> _questionResults = [];
  bool _hadWrongAttempt = false;

  DateTime? _quizStartTime;
  bool _isLoading = true;

  DateTime? _questionStartTime;
  Timer? _questionTimer;
  Duration _elapsed = Duration.zero;
  bool _photoLoaded = false;

  // --- Feedback and photo scale fields ---
  bool _showCorrectFeedback = false;
  double _photoScale = 1.0;
  Color _feedbackColor = Colors.green;

  String _feedbackMessage = '';
  Color _feedbackBannerColor = Colors.green;
  bool _feedbackVisible = false;
  String? _feedbackMeme;

  final String _memeCorrect = 'assets/images/correct.jpg';
  final String _memeWrong = 'assets/images/wrong.jpg';

  @override
  void initState() {
    super.initState();
    _loadPlayersAndStartQuiz();
  }

  Future<void> _loadPlayersAndStartQuiz() async {
    try {
      final allPlayers = await loadPlayers();
      final players = widget.category == null
          ? allPlayers
          : allPlayers
                .where((p) => p.categories.contains(widget.category))
                .toList();

      final requiredLevels = (difficultyPlans[widget.difficulty] ?? [])
          .expand((step) => step.keys)
          .toSet();

      final matchingCount = players
          .where((p) => requiredLevels.contains(p.level))
          .length;

      if (players.length < 10 || matchingCount < 10) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.category != null
                    ? 'Pas assez de joueurs pour la catégorie "${widget.category}" en difficulté ${widget.difficulty}.'
                    : 'Pas assez de joueurs pour cette difficulté.',
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final remainingPlayers = List<Player>.from(players);
      List<Player> selected = [];

      final plan = difficultyPlans[widget.difficulty] ?? [];

      for (var step in plan) {
        step.forEach((level, count) {
          for (int i = 0; i < count; i++) {
            final player = _pickRandomPlayer(remainingPlayers, [level]);
            selected.add(player);
            remainingPlayers.remove(player);
          }
        });
      }

      setState(() {
        _players = players;
        _selectedPlayers = selected;
        _playerPool = remainingPlayers..shuffle();
        _quizStartTime = DateTime.now();
        _isLoading = false;
        _photoLoaded = false;
      });
    } on ApiException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.userMessage),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('ERROR: $e\n$stack');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('DEBUG: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 15),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _questionTimer?.cancel();
    super.dispose();
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _elapsed = Duration.zero;
    _questionStartTime = DateTime.now();
    setState(() {
      _elapsed = Duration.zero;
    });
    _questionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _elapsed = DateTime.now().difference(_questionStartTime!);
      });
    });
  }

  int _computePoints(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 4) return 5;
    if (seconds < 7) return 4;
    if (seconds < 10) return 3;
    if (seconds < 20) return 2;
    return 1;
  }

  // ✅ Modifié uniquement ici
  Future<void> _submitAnswer() async {
    final trimmedAnswer = removeDiacritics(_answer.trim().toLowerCase());
    final correctAnswer = removeDiacritics(
      _selectedPlayers[_currentQuestion].name.toLowerCase(),
    );

    // Vérifier contre tous les noms acceptés, garder le meilleur score
    final allCorrect = _selectedPlayers[_currentQuestion].allNames
        .map((n) => removeDiacritics(n.toLowerCase()))
        .toList();
    double similarity = allCorrect
        .map((n) => trimmedAnswer.similarityTo(n))
        .reduce((a, b) => a > b ? a : b);

    bool isCorrect = similarity > 0.8;
    bool almostCorrect = !isCorrect && similarity > 0.4;

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      Future.delayed(
        const Duration(milliseconds: 80),
        HapticFeedback.mediumImpact,
      );
      setState(() {
        _showCorrectFeedback = true;
        _photoScale = 1.05;
        _feedbackColor = Colors.green;
      });
      final elapsed = DateTime.now().difference(_questionStartTime!);
      final points = _computePoints(elapsed);
      _score += points;
      _questionResults.add(QuestionResult(
        playerName: _selectedPlayers[_currentQuestion].name,
        correct: true,
        attempted: true,
        points: points,
      ));
    }

    String snackMessage;
    Color snackColor;
    String memeAsset;

    if (isCorrect) {
      _controller.clear();
      snackMessage = '✅ Bonne réponse ! Suuuuuuuuu !!';
      snackColor = Colors.green[700]!;
      _showFeedback(snackMessage, snackColor, meme: _memeCorrect);
      _questionTimer?.cancel();
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() {
          _showCorrectFeedback = false;
          _photoScale = 1.0;
        });
        _nextQuestion();
      });
    } else if (almostCorrect) {
      _hadWrongAttempt = true;
      HapticFeedback.heavyImpact();
      Future.delayed(
        const Duration(milliseconds: 60),
        HapticFeedback.heavyImpact,
      );
      setState(() {
        _showCorrectFeedback = true;
        _photoScale = 1.05;
        _feedbackColor = Colors.orange;
      });
      snackMessage = '🟡 T\'y es presque grand...';
      snackColor = Colors.orange[700]!;
      _showFeedback(snackMessage, snackColor, meme: _memeWrong);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _showCorrectFeedback = false;
          _photoScale = 1.0;
        });
      });
    } else {
      _questionResults.add(QuestionResult(
        playerName: _selectedPlayers[_currentQuestion].name,
        correct: false,
        attempted: true,
        points: 0,
      ));
      setState(() {
        _showCorrectFeedback = true;
        _photoScale = 1.05;
        _feedbackColor = Colors.red;
      });
      _controller.clear();
      snackMessage =
          '❌ Nan !! T\'es trompé ! La bonne réponse était : ${_selectedPlayers[_currentQuestion].name}';
      snackColor = Colors.red[700]!;
      _showFeedback(snackMessage, snackColor, meme: _memeWrong);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _showCorrectFeedback = false;
          _photoScale = 1.0;
        });
      });
      _questionTimer?.cancel();
      _nextQuestion();
    }
  }

  void _nextQuestion() {
    if (_currentQuestion < _selectedPlayers.length - 1) {
      setState(() {
        _currentQuestion++;
        _answer = '';
        _photoLoaded = false;
        _hadWrongAttempt = false;
      });
    } else {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _showScorePage();
      });
    }
  }

  void _skipQuestion() {
    _controller.clear();
    final correctAnswer = _selectedPlayers[_currentQuestion].name;
    _questionResults.add(QuestionResult(
      playerName: correctAnswer,
      correct: false,
      attempted: _hadWrongAttempt,
      points: 0,
    ));
    _showFeedback(
      '⏩ Passée ! C\'était : $correctAnswer',
      const Color(0xFF8B949E),
    );
    _questionTimer?.cancel();
    _nextQuestion();
  }

  int _currentPoints() {
    final seconds = _elapsed.inSeconds;
    if (seconds < 4) return 5;
    if (seconds < 7) return 4;
    if (seconds < 15) return 3;
    if (seconds < 30) return 2;
    return 1;
  }

  String _currentPointsLabel() {
    final pts = _currentPoints();
    return '+$pts pt${pts > 1 ? 's' : ''}';
  }

  Color _currentPointsColor() {
    switch (_currentPoints()) {
      case 5:
        return const Color(0xFF3FB950);
      case 4:
        return const Color(0xFF7CB95A);
      case 3:
        return const Color(0xFFD29922);
      case 2:
        return const Color(0xFFE87820);
      default:
        return const Color(0xFFDA3633);
    }
  }

  Future<void> _saveResult(int score, int total, Duration timeTaken) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList('quizHistory') ?? [];

    final now = DateTime.now();
    final formattedDate =
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    String entry = '$formattedDate — Score: $score / $total';

    if (score == total) {
      entry += ' — Temps: ${timeTaken.inMinutes}m ${timeTaken.inSeconds % 60}s';
    }

    history.add(entry);
    await prefs.setStringList('quizHistory', history);
  }

  void _showScorePage() async {
    final quizEndTime = DateTime.now();
    final duration = quizEndTime.difference(_quizStartTime!);

    await _saveResult(_score, _selectedPlayers.length, duration);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ScorePage(
          score: _score,
          total: _selectedPlayers.length,
          timeTaken: duration,
          results: List.unmodifiable(_questionResults),
          difficulty: widget.difficulty,
          category: widget.category,
        ),
      ),
    );
  }

  void _showFeedback(String message, Color color, {String? meme}) {
    setState(() {
      _feedbackMessage = message;
      _feedbackBannerColor = color;
      _feedbackMeme = meme;
      _feedbackVisible = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _feedbackVisible = false);
    });
  }

  void _showQuitDialog() {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2130),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quitter la partie ?', style: TextStyle(color: Color(0xFFE6EDF3), fontWeight: FontWeight.w700)),
        content: const Text('Ta progression sera perdue.', style: TextStyle(color: Color(0xFF8B949E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuer', style: TextStyle(color: Color(0xFF3FB950), fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Quitter', style: TextStyle(color: Color(0xFFDA3633), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _imageUrl(String url) {
    if (kIsWeb) {
      return Uri.base
          .resolve('api/image')
          .replace(queryParameters: {'url': url})
          .toString();
    }
    return url;
  }

  void _replaceCurrentPlayer() {
    if (_playerPool.isEmpty) return;
    setState(() {
      _selectedPlayers[_currentQuestion] = _playerPool.removeAt(0);
      _photoLoaded = false;
    });
  }

  Player _pickRandomPlayer(List<Player> players, List<int> levels) {
    final filtered = players.where((p) => levels.contains(p.level)).toList();
    if (filtered.isEmpty) {
      final maxLevel = players
          .map((p) => p.level)
          .reduce((a, b) => a > b ? a : b);
      for (int lvl in levels) {
        if (lvl < maxLevel) {
          return _pickRandomPlayer(players, [lvl + 1]);
        }
      }
      return players[(players.length * (0.5)).toInt()];
    }
    filtered.shuffle();
    return filtered.first;
  }

  Widget _buildTimer() {
    final minutes = _elapsed.inMinutes;
    final seconds = _elapsed.inSeconds % 60;

    return Text(
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFFE6EDF3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _selectedPlayers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    const bg = Color(0xFF171923);
    const cardBg = Color(0xFF1E2130);
    const border = Color(0xFF2D3148);
    const accentBright = Color(0xFF3FB950);
    const textPrimary = Color(0xFFE6EDF3);
    const textSecondary = Color(0xFF8B949E);

    final total = _selectedPlayers.length;
    final current = _currentQuestion;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showQuitDialog();
      },
      child: Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Bouton retour uniquement
                GestureDetector(
                  onTap: _showQuitDialog,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(animation);
          return SlideTransition(
            position: slide,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Column(
          key: ValueKey(_currentQuestion),
          children: [
            // ── Photo plein écran ────────────────────────────────
            Flexible(
              flex: 5,
              child: AnimatedScale(
                scale: _photoScale,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      panEnabled: true,
                      child: Image.network(
                        key: ValueKey(_selectedPlayers[_currentQuestion].imageUrl),
                        _imageUrl(_selectedPlayers[_currentQuestion].imageUrl),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            if (!_photoLoaded) {
                              _photoLoaded = true;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _startQuestionTimer();
                              });
                            }
                            return child;
                          }
                          return Container(
                            color: cardBg,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: accentBright,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _replaceCurrentPlayer(),
                          );
                          return Container(
                            color: cardBg,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: accentBright,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Dégradé bas pour transition douce
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [bg, bg.withOpacity(0)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _showCorrectFeedback ? 0.35 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(color: _feedbackColor),
                      ),
                    ),
                    // Révélation du nom sur bonne réponse
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: (_showCorrectFeedback && _feedbackColor == Colors.green) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
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
            ),

            // ── Section basse ────────────────────────────────────
            Flexible(
              flex: keyboardOpen ? 6 : 4,
              child: Container(
                color: bg,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress + score total (masqué quand clavier ouvert)
                      if (!keyboardOpen) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (current + 1) / total,
                                  backgroundColor: const Color(0xFF2D3148),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        accentBright,
                                      ),
                                  minHeight: 3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${current + 1}/$total${widget.category != null ? " · ${widget.category}" : ""}',
                              style: const TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$_score pt${_score > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Timer + Points courants groupés dans un pill
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D3148),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: Color(0xFFE6EDF3),
                                ),
                                const SizedBox(width: 5),
                                _buildTimer(),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  width: 1,
                                  height: 14,
                                  color: const Color(0xFF3D4460),
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
                      ),
                      const SizedBox(height: 8),

                      // Feedback banner
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _feedbackVisible
                            ? Container(
                                key: const ValueKey('fb'),
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _feedbackBannerColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _feedbackBannerColor.withOpacity(
                                      0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (_feedbackMeme != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.asset(
                                          _feedbackMeme!,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    if (_feedbackMeme != null)
                                      const SizedBox(width: 10),
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
                            : const SizedBox.shrink(key: ValueKey('nofb')),
                      ),

                      // TextField
                      TextField(
                        autofocus: false,
                        controller: _controller,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nom du joueur...',
                          hintStyle: const TextStyle(color: textSecondary),
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: textSecondary,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: cardBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: accentBright,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) => setState(() => _answer = value),
                        onSubmitted: (_) {
                          if (_answer.trim().isNotEmpty) _submitAnswer();
                        },
                      ),
                      const SizedBox(height: 12),

                      // Boutons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textPrimary,
                                side: const BorderSide(color: textSecondary),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _skipQuestion,
                              child: const Text(
                                'Passer',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentBright,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: accentBright
                                    .withOpacity(0.35),
                                disabledForegroundColor: Colors.white
                                    .withOpacity(0.5),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: _answer.trim().isEmpty
                                  ? null
                                  : _submitAnswer,
                              child: const Text(
                                'Valider ✓',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    ); // PopScope
  }
}

class ScorePage extends StatelessWidget {
  final int score;
  final int total;
  final Duration timeTaken;
  final List<QuestionResult> results;
  final String difficulty;
  final String? category;

  const ScorePage({
    super.key,
    required this.score,
    required this.total,
    required this.timeTaken,
    required this.results,
    required this.difficulty,
    this.category,
  });

  static const _bg       = Color(0xFF171923);
  static const _card     = Color(0xFF1E2130);
  static const _border   = Color(0xFF2D3148);
  static const _accent   = Color(0xFF3FB950);
  static const _textPrimary   = Color(0xFFE6EDF3);
  static const _textSecondary = Color(0xFF8B949E);

  IconData _rowIcon(QuestionResult r) {
    if (r.correct) return Icons.check;
    if (r.attempted) return Icons.close;
    return Icons.arrow_forward;
  }

  Color _rowColor(QuestionResult r) {
    if (r.correct) return _accent;
    if (r.attempted) return const Color(0xFFDA3633);
    return _textSecondary;
  }

  String _scoreMessage() {
    final maxScore = total * 5;
    final ratio = score / maxScore;
    if (ratio == 1.0) return 'Score parfait 🏆';
    if (ratio >= 0.75) return 'Super score ! T\'es un bon !';
    if (ratio >= 0.5)  return 'Pas mal grand ! Continue !';
    if (ratio >= 0.3)  return 'C\'est moyen... Applique toi !';
    return 'Clairement un mauvais score. Ressaisis toi.';
  }

  Color _scoreColor() {
    final ratio = score / (total * 5);
    if (ratio >= 0.75) return _accent;
    if (ratio >= 0.5)  return const Color(0xFFD29922);
    return const Color(0xFFDA3633);
  }

  @override
  Widget build(BuildContext context) {
    final minutes = timeTaken.inMinutes;
    final seconds = timeTaken.inSeconds % 60;
    final maxScore = total * 5;
    final correct = results.where((r) => r.correct).length;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(Icons.arrow_back, color: _textPrimary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Résultats', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            // ── Score principal ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
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
                      '/ $maxScore pts',
                      style: const TextStyle(fontSize: 16, color: _textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _scoreMessage(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: _textPrimary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    // Stats rapides
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatChip(icon: Icons.check_circle_outline, label: '$correct', sublabel: 'correctes', color: _accent),
                        _StatChip(icon: Icons.cancel_outlined, label: '${results.where((r) => !r.correct && r.attempted).length}', sublabel: 'ratées', color: const Color(0xFFDA3633)),
                        _StatChip(icon: Icons.arrow_forward, label: '${results.where((r) => !r.correct && !r.attempted).length}', sublabel: 'passées', color: _textSecondary),
                        _StatChip(icon: Icons.timer_outlined, label: '${minutes}m${seconds.toString().padLeft(2,'0')}', sublabel: 'temps', color: _textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Récap par question ───────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Détail', style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = results[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _rowColor(r).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_rowIcon(r), color: _rowColor(r), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            r.playerName,
                            style: TextStyle(
                              color: r.correct ? _textPrimary : _textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          r.correct ? '+${r.points} pt${r.points > 1 ? 's' : ''}' : '—',
                          style: TextStyle(
                            color: _rowColor(r),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Boutons ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Accueil', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizTest(
                              difficulty: difficulty,
                              category: category,
                            ),
                          ),
                        );
                      },
                      child: const Text('Rejouer ↺', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.sublabel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
        Text(sublabel, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
      ],
    );
  }
}
