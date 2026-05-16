import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:diacritic/diacritic.dart';
import 'package:string_similarity/string_similarity.dart';
import '../../constants/app_colors.dart';
import '../../models/coup_doeil_1v1_game.dart';
import '../../models/player.dart';
import '../../services/coup_doeil_1v1_service.dart';
import 'coup_doeil_1v1_result_page.dart';
import 'package:quiz_foot/utils/navigation.dart';

class CoupDoeil1v1GamePage extends StatefulWidget {
  final String roomCode;
  final String pseudo;
  final String opponentPseudo;
  final List<Player> questions;
  final String difficulty;
  final String? category;

  const CoupDoeil1v1GamePage({
    super.key,
    required this.roomCode,
    required this.pseudo,
    required this.opponentPseudo,
    required this.questions,
    required this.difficulty,
    this.category,
  });

  @override
  State<CoupDoeil1v1GamePage> createState() => _CoupDoeil1v1GamePageState();
}

class _CoupDoeil1v1GamePageState extends State<CoupDoeil1v1GamePage>
    with WidgetsBindingObserver {

  static const int _maxSeconds = 30;
  static const String _memeCorrect = 'assets/images/correct.jpg';
  static const String _memeWrong   = 'assets/images/wrong.jpg';

  // ── Quiz state ─────────────────────────────────────────────────────────────

  int _currentQuestion = 0;
  int _score = 0;
  String _answer = '';
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final List<CdoQuestionResult> _questionResults = [];
  bool _hadWrongAttempt = false;

  // ── Timer ──────────────────────────────────────────────────────────────────

  DateTime? _questionStartTime;
  Timer? _questionTimer;
  Duration _elapsed = Duration.zero;
  bool _photoLoaded = false;

  // ── Visual feedback ────────────────────────────────────────────────────────

  bool _showPhotoOverlay = false;
  Color _photoOverlayColor = Colors.green;
  double _photoScale = 1.0;
  String _feedbackMessage = '';
  Color _feedbackBannerColor = AppColors.accentBright;
  bool _feedbackVisible = false;
  String? _feedbackMeme;

  // ── Post-game ──────────────────────────────────────────────────────────────

  bool _submitted = false;
  bool _waitingForOpponent = false;
  StreamSubscription<CoupDoeil1v1Game?>? _gameSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Timer? _pauseAbandonTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseAbandonTimer?.cancel();
      _pauseAbandonTimer = Timer(const Duration(seconds: 12), () {
        if (!_submitted) {
          CoupDoeil1v1Service.instance.abandonRoom(
            code: widget.roomCode,
            pseudo: widget.pseudo,
          );
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      _pauseAbandonTimer?.cancel();
    } else if (state == AppLifecycleState.detached && !_submitted) {
      _pauseAbandonTimer?.cancel();
      CoupDoeil1v1Service.instance.abandonRoom(
        code: widget.roomCode,
        pseudo: widget.pseudo,
      );
    }
  }

  @override
  void dispose() {
    _pauseAbandonTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _inputFocus.dispose();
    _questionTimer?.cancel();
    _gameSub?.cancel();
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _questionStartTime = DateTime.now();
    setState(() => _elapsed = Duration.zero);

    _questionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_questionStartTime!);
      setState(() => _elapsed = elapsed);

      if (elapsed.inSeconds >= _maxSeconds) {
        _questionTimer?.cancel();
        _autoSkip();
      }
    });
  }

  // ── Scoring ────────────────────────────────────────────────────────────────

  int _computePoints(Duration elapsed) {
    final s = elapsed.inSeconds;
    if (s < 6)  return 5;
    if (s < 9)  return 4;
    if (s < 12) return 3;
    if (s < 20) return 2;
    return 1;
  }

  int _currentPoints() {
    final s = _elapsed.inSeconds;
    if (s < 6)  return 5;
    if (s < 9)  return 4;
    if (s < 12) return 3;
    if (s < 20) return 2;
    return 1;
  }

  String _currentPointsLabel() {
    final pts = _currentPoints();
    return '+$pts pt${pts > 1 ? 's' : ''}';
  }

  Color _currentPointsColor() => AppColors.forPoints(_currentPoints());

  // ── Answer handling ────────────────────────────────────────────────────────

  Future<void> _submitAnswer() async {
    if (_waitingForOpponent) return;
    final typed = removeDiacritics(_answer.trim().toLowerCase());
    if (typed.isEmpty) return;

    final accepted = widget.questions[_currentQuestion].allNames
        .map((n) => removeDiacritics(n.toLowerCase()))
        .toList();
    final bestSim = accepted.map((n) => typed.similarityTo(n)).reduce((a, b) => a > b ? a : b);

    final isCorrect = bestSim > 0.8;
    final almostCorrect = !isCorrect && bestSim > 0.4;

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 80), HapticFeedback.mediumImpact);
      final points = _computePoints(DateTime.now().difference(_questionStartTime!));
      _score += points;
      _questionResults.add(CdoQuestionResult(
        playerName: widget.questions[_currentQuestion].name,
        correct: true,
        points: points,
        attempted: true,
      ));
      setState(() { _showPhotoOverlay = true; _photoScale = 1.05; _photoOverlayColor = Colors.green; });
      _controller.clear();
      _questionTimer?.cancel();
      _showFeedback('✅ Bonne réponse ! Suuuuuuuuu !!', Colors.green[700]!, meme: _memeCorrect);
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() { _showPhotoOverlay = false; _photoScale = 1.0; });
        _nextQuestion();
      });

    } else if (almostCorrect) {
      _hadWrongAttempt = true;
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 60), HapticFeedback.heavyImpact);
      setState(() { _showPhotoOverlay = true; _photoScale = 1.05; _photoOverlayColor = Colors.orange; });
      _showFeedback("🟡 T'y es presque grand...", Colors.orange[700]!, meme: _memeWrong);
      _inputFocus.requestFocus();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() { _showPhotoOverlay = false; _photoScale = 1.0; });
      });

    } else {
      _questionResults.add(CdoQuestionResult(
        playerName: widget.questions[_currentQuestion].name,
        correct: false,
        points: 0,
        attempted: true,
      ));
      setState(() { _showPhotoOverlay = true; _photoScale = 1.05; _photoOverlayColor = Colors.red; });
      _controller.clear();
      _questionTimer?.cancel();
      _showFeedback(
        '❌ Nan !! T\'es trompé ! C\'était : ${widget.questions[_currentQuestion].name}',
        Colors.red[700]!,
        meme: _memeWrong,
      );
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() { _showPhotoOverlay = false; _photoScale = 1.0; });
        _nextQuestion();
      });
    }
  }

  void _skipQuestion() {
    if (_waitingForOpponent) return;
    final name = widget.questions[_currentQuestion].name;
    _questionResults.add(CdoQuestionResult(
      playerName: name,
      correct: false,
      points: 0,
      attempted: _hadWrongAttempt,
    ));
    _controller.clear();
    _showFeedback("⏩ Passée ! C'était : $name", AppColors.textSecondary);
    _questionTimer?.cancel();
    _nextQuestion();
  }

  void _autoSkip() {
    if (_waitingForOpponent) return;
    final name = widget.questions[_currentQuestion].name;
    _questionResults.add(CdoQuestionResult(
      playerName: name,
      correct: false,
      points: 0,
      attempted: _hadWrongAttempt,
    ));
    _controller.clear();
    _showFeedback("⏰ Temps écoulé ! C'était : $name", AppColors.textSecondary);
    _nextQuestion();
  }

  void _nextQuestion() {
    if (_currentQuestion < widget.questions.length - 1) {
      setState(() {
        _currentQuestion++;
        _answer = '';
        _photoLoaded = false;
        _hadWrongAttempt = false;
      });
    } else {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _finishGame();
      });
    }
  }

  // ── Post-game ──────────────────────────────────────────────────────────────

  Future<void> _finishGame() async {
    if (_submitted || !mounted) return;
    _submitted = true;
    setState(() => _waitingForOpponent = true);

    await CoupDoeil1v1Service.instance.submitResults(
      code: widget.roomCode,
      pseudo: widget.pseudo,
      score: _score,
      results: _questionResults,
    );

    _gameSub = CoupDoeil1v1Service.instance.watchGame(widget.roomCode).listen((game) {
      if (game == null || !mounted) return;

      if (game.abandoned) {
        _gameSub?.cancel();
        if (game.abandonedBy != widget.pseudo) {
          _navigateToResult(game, forcedWinner: widget.pseudo);
        }
        return;
      }

      if (game.status == CdoGameStatus.finished) {
        _gameSub?.cancel();
        _navigateToResult(game);
      }
    });
  }

  void _navigateToResult(CoupDoeil1v1Game game, {String? forcedWinner}) {
    if (!mounted) return;
    final winner = forcedWinner ?? game.winner;
    final opponentData = game.players[widget.opponentPseudo];
    Navigator.pushReplacement(
      context,
      namedRoute(CoupDoeil1v1ResultPage(
        pseudo: widget.pseudo,
        opponentPseudo: widget.opponentPseudo,
        winner: winner,
        myScore: _score,
        opponentScore: opponentData?.score ?? 0,
        myResults: _questionResults,
        opponentResults: opponentData?.results ?? [],
        questions: widget.questions,
        difficulty: widget.difficulty,
        category: widget.category,
        abandoned: game.abandoned,
        abandonedBy: game.abandonedBy,
        roomCode: widget.roomCode,
      )),
    );
  }

  // ── Feedback ───────────────────────────────────────────────────────────────

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

  // ── Quit ───────────────────────────────────────────────────────────────────

  void _showQuitDialog() {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Quitter la partie ?',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Ton adversaire remportera automatiquement la partie.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continuer', style: TextStyle(color: AppColors.accentBright, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await CoupDoeil1v1Service.instance.abandonRoom(
                code: widget.roomCode,
                pseudo: widget.pseudo,
              );
              if (mounted) Navigator.pop(context);
            },
            child: Text('Quitter', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Image URL ──────────────────────────────────────────────────────────────

  String _imageUrl(String url) {
    if (kIsWeb) {
      return Uri.base.resolve('api/image').replace(queryParameters: {'url': url}).toString();
    }
    return url;
  }

  // ── Build helpers ──────────────────────────────────────────────────────────

  Widget _buildTimerText() {
    final minutes = _elapsed.inMinutes;
    final seconds = _elapsed.inSeconds % 60;
    return Text(
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('Aucune photo disponible.', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    if (_waitingForOpponent) return _buildWaitingScreen();

    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _showQuitDialog(); },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        extendBodyBehindAppBar: true,
        appBar: _buildOverlayAppBar(),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Column(
            key: ValueKey(_currentQuestion),
            children: [
              _buildPhotoSection(),
              _buildBottomSection(
                total: widget.questions.length,
                current: _currentQuestion,
                keyboardOpen: keyboardOpen,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Flexible(
      flex: 5,
      child: AnimatedScale(
        scale: _photoScale,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Stack(
          fit: StackFit.expand,
          children: [

            // ── Player photo ──────────────────────────────────────────────
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              panEnabled: true,
              child: Image.network(
                key: ValueKey(widget.questions[_currentQuestion].imageUrl),
                _imageUrl(widget.questions[_currentQuestion].imageUrl),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    if (!_photoLoaded) {
                      _photoLoaded = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _startQuestionTimer();
                      });
                    }
                    return child;
                  }
                  return Container(
                    color: AppColors.card,
                    child: Center(child: CircularProgressIndicator(color: AppColors.accentBright)),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.card,
                  child: Center(
                    child: Text('Photo indisponible', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              ),
            ),

            // ── Bottom gradient ───────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AppColors.bg, AppColors.bg.withOpacity(0)],
                    ),
                  ),
                ),
              ),
            ),

            // ── Answer overlay ────────────────────────────────────────────
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showPhotoOverlay ? 0.35 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(color: _photoOverlayColor),
              ),
            ),

            // ── Player name reveal on correct ─────────────────────────────
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: (_showPhotoOverlay && _photoOverlayColor == Colors.green) ? 1.0 : 0.0,
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
                      widget.questions[_currentQuestion].name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
              if (!keyboardOpen) ...[
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (current + 1) / total,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBright),
                          minHeight: 3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${current + 1}/$total${widget.category != null ? ' · ${widget.category}' : ''}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$_score pt${_score > 1 ? 's' : ''}',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // ── Timer pill ──────────────────────────────────────────────
              Row(
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
                        Icon(Icons.timer_outlined, size: 14, color: AppColors.textPrimary),
                        const SizedBox(width: 5),
                        _buildTimerText(),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 1, height: 14,
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
              ),
              const SizedBox(height: 8),

              // ── Feedback banner ─────────────────────────────────────────
              AnimatedSwitcher(
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
                            if (_feedbackMeme != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  _feedbackMeme!,
                                  width: 44, height: 44,
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
              ),

              // ── Text field ──────────────────────────────────────────────
              TextField(
                autofocus: false,
                focusNode: _inputFocus,
                controller: _controller,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Nom du joueur...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accentBright, width: 2),
                  ),
                ),
                onChanged: (v) => setState(() => _answer = v),
                onSubmitted: (_) {
                  if (_answer.trim().isNotEmpty) _submitAnswer();
                },
              ),
              const SizedBox(height: 12),

              // ── Action buttons ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.textSecondary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _skipQuestion,
                      child: Text('Passer', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBright,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.accentBright.withOpacity(0.35),
                        disabledForegroundColor: Colors.white.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _answer.trim().isEmpty ? null : _submitAnswer,
                      child: Text('Valider ✓', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48, height: 48,
                  child: CircularProgressIndicator(color: AppColors.accentBright, strokeWidth: 3),
                ),
                const SizedBox(height: 24),
                Text(
                  'En attente de ${widget.opponentPseudo}...',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ton score : $_score pts',
                  style: TextStyle(
                    color: AppColors.accentBright,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_questionResults.where((r) => r.correct).length} / ${widget.questions.length} correctes',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
