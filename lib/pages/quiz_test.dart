import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diacritic/diacritic.dart';
import 'package:string_similarity/string_similarity.dart';
import '../models/player.dart';
import '../data/players_data.dart';

class QuizTest extends StatefulWidget {
  final String difficulty;
  const QuizTest({super.key, required this.difficulty});

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

class _QuizTestState extends State<QuizTest> {
  List<Player> _players = [];
  late List<Player> _selectedPlayers;
  int _currentQuestion = 0;
  int _score = 0;
  String _answer = '';
  final TextEditingController _controller = TextEditingController();

  DateTime? _quizStartTime;
  bool _isLoading = true;

  DateTime? _questionStartTime;
  Timer? _questionTimer;
  Duration _elapsed = Duration.zero;

  // --- Feedback and photo scale fields ---
  bool _showCorrectFeedback = false;
  double _photoScale = 1.0;
  Color _feedbackColor = Colors.green;

  final String _memeCorrect = 'assets/images/correct.jpg';
  final String _memeWrong = 'assets/images/wrong.jpg';

  @override
  void initState() {
    super.initState();
    _loadPlayersAndStartQuiz();
  }

  Future<void> _loadPlayersAndStartQuiz() async {
    final players = await loadPlayers();

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

    for (var p in selected) {
      print('Player: ${p.name}, Level: ${p.level}');
    }
    setState(() {
      _players = players;
      _selectedPlayers = selected;
      _quizStartTime = DateTime.now();
      _isLoading = false;
      _startQuestionTimer();
    });
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

    double similarity = trimmedAnswer.similarityTo(correctAnswer);

    bool isCorrect = similarity == 1.0;
    bool almostCorrect = !isCorrect && similarity > 0.4;

    if (isCorrect) {
      setState(() {
        _showCorrectFeedback = true;
        _photoScale = 1.05;
        _feedbackColor = Colors.green;
      });
      final elapsed = DateTime.now().difference(_questionStartTime!);
      final points = _computePoints(elapsed);
      _score += points;
    }

    String snackMessage;
    Color snackColor;
    String memeAsset;

    if (isCorrect) {
      _controller.clear();
      snackMessage = '✅ Bonne réponse ! Suuuuuuuuu !!';
      snackColor = Colors.green[700]!;
      memeAsset = _memeCorrect;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Image.asset(memeAsset, width: 80, height: 80, fit: BoxFit.cover),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  snackMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: snackColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
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
      setState(() {
        _showCorrectFeedback = true;
        _photoScale = 1.05;
        _feedbackColor = Colors.orange;
      });
      snackMessage = '🟡 T\'y es presque grand...';
      snackColor = Colors.orange[700]!;
      memeAsset = _memeWrong;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  snackMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: snackColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _showCorrectFeedback = false;
          _photoScale = 1.0;
        });
      });
    } else {
      setState(() {
        _showCorrectFeedback = true;
        _photoScale = 1.05;
        _feedbackColor = Colors.red;
      });
      _controller.clear();
      snackMessage =
          '❌ Nan !! T\'es trompé ! La bonne réponse était : ${_selectedPlayers[_currentQuestion].name}';
      snackColor = Colors.red[700]!;
      memeAsset = _memeWrong;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Image.asset(memeAsset, width: 80, height: 80, fit: BoxFit.cover),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  snackMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: snackColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
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
      });
      _startQuestionTimer();
    } else {
      _showScorePage();
    }
  }

  void _skipQuestion() {
    _controller.clear();

    String correctAnswer = _selectedPlayers[_currentQuestion].name;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '⏩ Question passée ! La bonne réponse était : $correctAnswer',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
    _questionTimer?.cancel();
    _nextQuestion();
  }

  String _currentPointsLabel() {
    final seconds = _elapsed.inSeconds;
    if (seconds < 4) return '5 points';
    if (seconds < 7) return '4 points';
    if (seconds < 15) return '3 points';
    if (seconds < 30) return '2 points';
    return '1 point';
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
        ),
      ),
    );
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
      '${minutes.toString().padLeft(2, '0')}m '
      '${seconds.toString().padLeft(2, '0')}s ',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Question ${_currentQuestion + 1} / ${_selectedPlayers.length}',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff66bb6a), Color(0xff1b5e20)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(animation);

              return SlideTransition(
                position: slide,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Column(
              key: ValueKey(_currentQuestion),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                    clipBehavior: Clip.antiAlias,
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
                              _selectedPlayers[_currentQuestion].imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.broken_image, size: 80),
                                );
                              },
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: _showCorrectFeedback ? 0.35 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(color: _feedbackColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTimer(),
                    Text(
                      _currentPointsLabel(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          autofocus: true,
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Entre le nom du joueur',
                            prefixIcon: const Icon(
                              Icons.person,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => _answer = value);
                          },
                          onSubmitted: (_) {
                            if (_answer.trim().isNotEmpty) _submitAnswer();
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[300],
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _skipQuestion,
                                child: const Text('Passer'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _answer.trim().isEmpty
                                    ? null
                                    : _submitAnswer,
                                child: const Text('Valider'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ScorePage extends StatelessWidget {
  final int score;
  final int total;
  final Duration timeTaken;

  const ScorePage({
    super.key,
    required this.score,
    required this.total,
    required this.timeTaken,
  });

  String _scoreMessage(int score, int minutes, int seconds) {
    if (score == 50) {
      return 'Score parfait !!\nTemps : ${minutes}m ${seconds}s';
    } else if (score >= 35) {
      return 'Super score ! Tié un bon !';
    } else if (score >= 25) {
      return 'Pas mal grand ! Continue !';
    } else if (score >= 15) {
      return 'C\'est moyen... Applique toi !';
    } else {
      return 'Clairement un mauvais score. Ressaisis toi.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = timeTaken.inMinutes;
    final seconds = timeTaken.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Résultat')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Score : $score points',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _scoreMessage(score, minutes, seconds),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: score >= 15 ? Colors.green : Colors.black,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
