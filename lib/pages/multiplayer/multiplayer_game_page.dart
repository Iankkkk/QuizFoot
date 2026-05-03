import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:diacritic/diacritic.dart';
import 'package:string_similarity/string_similarity.dart';
import '../../constants/app_colors.dart';
import '../../services/theme_service.dart';
import '../../data/lineup_game_data.dart';
import '../../models/lineup_model.dart';
import '../../models/match_model.dart';
import '../../models/multiplayer_game.dart';
import '../../services/multiplayer_service.dart';
import '../lineup/formation_layout.dart';
import '../../models/game_result.dart';
import '../../services/game_history_service.dart';
import 'multiplayer_result_page.dart';

// ─────────────────────────────────────────────────────────────────────────────

class MultiplayerGamePage extends StatefulWidget {
  final String roomCode;
  final String pseudo;

  const MultiplayerGamePage({
    super.key,
    required this.roomCode,
    required this.pseudo,
  });

  @override
  State<MultiplayerGamePage> createState() => _MultiplayerGamePageState();
}

class _MultiplayerGamePageState extends State<MultiplayerGamePage>
    with TickerProviderStateMixin {
  // ── Stream ────────────────────────────────────────────────────────────────
  StreamSubscription<MultiplayerGame?>? _gameSub;
  MultiplayerGame? _game;

  // ── Data ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  Match? _match;
  List<Lineup> _lineups = [];

  // ── Local game state ──────────────────────────────────────────────────────
  final Map<String, String> _hints = {};
  final Set<String> _localFoundNames = {};
  static const int _maxFreeHints = 5;

  // ── Timer ─────────────────────────────────────────────────────────────────
  Timer? _tickTimer;
  int _secondsLeft = 60;
  bool _timerExpired = false;

  // ── Feedback toast ────────────────────────────────────────────────────────
  String? _feedbackText;
  Color _feedbackColor = AppColors.accentBright;
  Timer? _feedbackTimer;
  late AnimationController _toastCtrl;
  late Animation<double> _toastOpacity;
  late Animation<double> _toastSlide;

  // ── Input ─────────────────────────────────────────────────────────────────
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  // ── Tabs (fallback) ───────────────────────────────────────────────────────
  late TabController _tabController;

  // ── Submitting guard ──────────────────────────────────────────────────────
  bool _submitting = false;
  bool _resultSaved = false;
  bool _dialogShown = false;
  bool _firstTurnStarted = false;
  late final DateTime _startTime;

  // ── Opponent timeout enforcement ──────────────────────────────────────────
  Timer? _opponentOverflowTimer;
  bool _opponentOverflowScheduled = false;

  // ── Hint banner ───────────────────────────────────────────────────────────
  bool _showHintBanner = false;
  Timer? _hintBannerTimer;

  // ── Suffocation animation ─────────────────────────────────────────────────
  late AnimationController _suffocateCtrl;
  late Animation<double> _suffocatePulse;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _tabController = TabController(length: 2, vsync: this);
    _toastCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _toastOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 7),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 21),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 7),
    ]).animate(_toastCtrl);
    _toastSlide = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -20.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _toastCtrl, curve: Curves.easeOut));

    _suffocateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _suffocatePulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _suffocateCtrl, curve: Curves.easeInOut),
    );

    _gameSub = MultiplayerService.instance
        .watchGame(widget.roomCode)
        .listen(_onGameUpdate);
  }

  @override
  void dispose() {
    _gameSub?.cancel();
    _tickTimer?.cancel();
    _hintBannerTimer?.cancel();
    _opponentOverflowTimer?.cancel();
    _toastCtrl.dispose();
    _suffocateCtrl.dispose();
    _tabController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  // ── Stream handling ───────────────────────────────────────────────────────

  void _onGameUpdate(MultiplayerGame? game) {
    // Room supprimée
    if (game == null) {
      _tickTimer?.cancel();
      if (mounted) _showAbandonedDialog('La room a été supprimée.');
      return;
    }

    final previous = _game;
    _game = game;

    // Adversaire a abandonné
    if (game.abandoned && game.abandonedBy != widget.pseudo) {
      _tickTimer?.cancel();
      final wonByAbandon = game.foundPlayers.length >= 4;
      _saveResult(game, won: wonByAbandon, abandoned: true);
      if (mounted) _showAbandonedDialog('${game.abandonedBy ?? 'Adversaire'} a quitté la partie.');
      return;
    }

    // Load lineups once
    if (_isLoading && _lineups.isEmpty) {
      _loadLineups(game.matchId);
    }

    // Start first turn timer when the current-turn player enters the game
    if (game.turnStartedAt == null && _isMyTurn && !_firstTurnStarted) {
      _firstTurnStarted = true;
      MultiplayerService.instance.startFirstTurn(widget.roomCode);
    }

    // Suffocation animation
    final isSuffocating = _isMyTurn && game.suffocatedBy != null;
    if (isSuffocating && !_suffocateCtrl.isAnimating) {
      _suffocateCtrl.repeat(reverse: true);
    } else if (!isSuffocating && _suffocateCtrl.isAnimating) {
      _suffocateCtrl.stop();
      _suffocateCtrl.value = 0;
    }

    // Reset timer expiry flag on turn change OR when turnStartedAt is first set
    final turnChanged = previous?.currentTurn != game.currentTurn ||
        previous?.suffocatedBy != game.suffocatedBy;
    final timerJustStarted = previous?.turnStartedAt == null && game.turnStartedAt != null;
    if (turnChanged || timerJustStarted) {
      if (turnChanged) _timerExpired = false;
      _restartTick(game);
      // Hint banner: show after 20s of inactivity on my turn
      if (turnChanged) {
        _hintBannerTimer?.cancel();
        _showHintBanner = false;
        if (_isMyTurn) {
          _hintBannerTimer = Timer(const Duration(seconds: 20), () {
            if (mounted) setState(() => _showHintBanner = true);
          });
        }
        _opponentOverflowTimer?.cancel();
        _opponentOverflowScheduled = false;
      }
    }

    // Detect opponent hint use → show notification
    final opponentPseudoForHints = game.playerOrder.firstWhere(
      (p) => p != widget.pseudo, orElse: () => '');
    if (opponentPseudoForHints.isNotEmpty) {
      final prevHints = previous?.players[opponentPseudoForHints]?.hintsUsed ?? 0;
      final curHints = game.players[opponentPseudoForHints]?.hintsUsed ?? 0;
      if (curHints > prevHints) {
        _showFeedback(
          '$opponentPseudoForHints a utilisé un indice ($curHints/$_maxFreeHints)',
          AppColors.amber,
        );
      }
    }

    // Game finished normally
    if (game.status == GameStatus.finished && !game.abandoned && mounted) {
      _tickTimer?.cancel();
      final isDraw = game.winner == '__draw__';
      _saveResult(game, won: !isDraw && game.winner == widget.pseudo, abandoned: false);
      _showEndScreen(game);
      return;
    }

    if (mounted) setState(() {});
  }

  void _showAbandonedDialog(String message) {
    if (_dialogShown) return;
    _dialogShown = true;
    if (_match == null) {
      if (mounted) { Navigator.of(context).pop(); }
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.amber),
        ),
        title: Text(
          '⚠️ Partie interrompue',
          style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w800, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBright,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => MultiplayerResultPage(
                    game: _game!,
                    pseudo: widget.pseudo,
                    match: _match!,
                    lineups: _lineups,
                    timeTaken: DateTime.now().difference(_startTime),
                    abandoned: true,
                  ),
                ));
              },
              child: Text('Résultats', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _restartTick(MultiplayerGame game) {
    _tickTimer?.cancel();
    if (game.turnStartedAt == null) return;

    final deadline = game.turnStartedAt!.add(
      Duration(seconds: game.effectiveTimerSeconds),
    );

    _tickTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final remaining = deadline.difference(DateTime.now()).inSeconds;
      final clamped = remaining.clamp(0, game.effectiveTimerSeconds);
      setState(() => _secondsLeft = clamped);

      if (clamped <= 0 && !_timerExpired && _isMyTurn) {
        _timerExpired = true;
        _onTimerExpired();
      }
      // If opponent's timer expired and they're not reacting, force the turn
      if (clamped <= 0 && !_isMyTurn && !_opponentOverflowScheduled) {
        _opponentOverflowScheduled = true;
        _opponentOverflowTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && !_isMyTurn) {
            MultiplayerService.instance.forceOpponentTimeout(
              code: widget.roomCode,
              waitingPseudo: widget.pseudo,
            );
          }
        });
      }
    });
  }

  Future<void> _loadLineups(String matchId) async {
    try {
      final matches = await loadMatches();
      final match = matches.firstWhere(
        (m) => m.matchId == matchId,
        orElse: () => throw Exception('Match introuvable'),
      );
      final lineups = await loadLineups(matchId);
      if (mounted) {
        setState(() {
          _match = match;
          _lineups = lineups.where((l) => l.matchId == matchId).toList();
          _isLoading = false;
          _tabController = TabController(length: 2, vsync: this);
        });
        if (_game != null) _restartTick(_game!);
      }
    } catch (e) {
      if (mounted) _showFeedback('Erreur chargement match', AppColors.red);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _isMyTurn => _game?.currentTurn == widget.pseudo;

  String _norm(String s) =>
      removeDiacritics(s.toLowerCase()).replaceAll('.', '').trim();

  String _lastName(String fullName) => fullName.trim().split(' ').last;

  Set<String> get _serverFoundNames =>
      _game?.foundPlayers.map((f) => f.name).toSet() ?? {};

  Set<String> get _allFoundNames => _serverFoundNames.union(_localFoundNames);

  // ── Game actions ──────────────────────────────────────────────────────────

  Future<void> _checkPlayer() async {
    if (!_isMyTurn || _submitting) return;
    final raw = _inputController.text.trim();
    if (raw.isEmpty) return;

    final answer = _norm(raw);
    final alreadyFound = _allFoundNames;

    final List<Lineup> allMatched = [];
    bool isClose = false;

    for (final l in _lineups) {
      if (alreadyFound.contains(l.playerName)) continue;
      bool exact = false;
      double bestSim = 0.0;
      for (final name in l.allNames) {
        final fullN = _norm(name);
        final lastN = _norm(_lastName(name));
        if (fullN == answer || lastN == answer || lastN.similarityTo(answer) >= 0.8) {
          exact = true;
          break;
        }
        final sim = lastN.similarityTo(answer);
        if (sim > bestSim) bestSim = sim;
      }
      if (exact) allMatched.add(l);
      else if (bestSim >= 0.5) isClose = true;
    }

    // Already found by someone
    if (allMatched.isEmpty) {
      for (final l in _lineups) {
        if (!alreadyFound.contains(l.playerName)) continue;
        for (final name in l.allNames) {
          if (_norm(name) == answer || _norm(_lastName(name)) == answer) {
            HapticFeedback.lightImpact();
            _showFeedback('Déjà trouvé !', AppColors.amber);
            _inputController.clear();
            return;
          }
        }
      }
    }

    if (allMatched.isNotEmpty) {
      HapticFeedback.mediumImpact();
      _inputController.clear();
      _inputFocus.unfocus();
      final label = allMatched.length > 1
          ? '${_lastName(allMatched.first.playerName)} × ${allMatched.length} ✓'
          : '${_lastName(allMatched.first.playerName)} ✓';
      _showFeedback(label, AppColors.accentBright);
      _hintBannerTimer?.cancel();
      setState(() {
        for (final m in allMatched) _localFoundNames.add(m.playerName);
        _showHintBanner = false;
      });
      _submitting = true;
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        if (allMatched.length == 1) {
          await MultiplayerService.instance.submitCorrectAnswer(
            code: widget.roomCode,
            pseudo: widget.pseudo,
            playerName: allMatched.first.playerName,
          );
        } else {
          await MultiplayerService.instance.submitMultipleCorrectAnswers(
            code: widget.roomCode,
            pseudo: widget.pseudo,
            playerNames: allMatched.map((m) => m.playerName).toList(),
          );
        }
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    if (isClose) {
      HapticFeedback.lightImpact();
      _showFeedback('Presque...', AppColors.amber);
      return;
    }

    // Wrong
    HapticFeedback.heavyImpact();
    _inputController.clear();
    _inputFocus.unfocus();
    final player = _game?.players[widget.pseudo];
    final remaining = player == null ? 0 : (3 - player.errors - 1);
    _showFeedback(
      'Pas dans cette compo  ($remaining erreur${remaining > 1 ? 's' : ''} restante${remaining > 1 ? 's' : ''})',
      AppColors.red,
    );
    _submitting = true;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      await MultiplayerService.instance.submitError(
        code: widget.roomCode,
        pseudo: widget.pseudo,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _onTimerExpired() async {
    if (!mounted || _submitting) return;
    final player = _game?.players[widget.pseudo];
    final remaining = player == null ? 0 : (2 - player.errors).clamp(0, 3);
    _showFeedback(
      'Temps écoulé... +1 erreur ($remaining restante${remaining > 1 ? 's' : ''})',
      AppColors.red,
    );
    _submitting = true;
    try {
      await MultiplayerService.instance.submitError(
        code: widget.roomCode,
        pseudo: widget.pseudo,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _passPlayer() async {
    if (!_isMyTurn || _submitting) return;
    _inputController.clear();
    _inputFocus.unfocus();
    final player = _game?.players[widget.pseudo];
    final remaining = player == null ? 0 : (2 - player.errors).clamp(0, 3);
    _showFeedback(
      'Passé... +1 erreur ($remaining restante${remaining > 1 ? 's' : ''})',
      AppColors.amber,
    );
    _submitting = true;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      await MultiplayerService.instance.submitError(
        code: widget.roomCode,
        pseudo: widget.pseudo,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _activateSuffocation() async {
    final game = _game;
    if (game == null || _isMyTurn) return;
    final me = game.players[widget.pseudo];
    if (me == null || me.suffocationsLeft <= 0) return;
    if (game.suffocatedBy != null) return;
    await MultiplayerService.instance.activateSuffocation(
      code: widget.roomCode,
      pseudo: widget.pseudo,
    );
  }

  Future<void> _onChipTap(Lineup player) async {
    if (!_isMyTurn) return;
    if (_inputFocus.hasFocus) { _inputFocus.unfocus(); return; }
    if (_allFoundNames.contains(player.playerName)) return;
    if (_hints.containsKey(player.playerName)) return;

    final remaining = _maxFreeHints - _hints.length;
    final canHint = remaining > 0;
    final hasNumber = player.playerNumber > 0;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Indice',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Poste : ${player.position}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Text('Équipe : ${player.teamName}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            Text(
              canHint
                  ? '$remaining indice${remaining > 1 ? 's' : ''} restant${remaining > 1 ? 's' : ''}'
                  : 'Tu as utilisé tes $_maxFreeHints indices.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          if (canHint) ...[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('letter'),
              child: Text('1ère lettre',
                  style: TextStyle(color: AppColors.accentBright, fontWeight: FontWeight.w700)),
            ),
            if (hasNumber)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('number'),
                child: Text('Numéro',
                    style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700)),
              ),
          ],
        ],
      ),
    );

    if (choice != null) {
      HapticFeedback.lightImpact();
      final first = player.playerName.trim();
      setState(() => _hints[player.playerName] =
          choice == 'letter' ? first[0].toUpperCase() : '${player.playerNumber}');
      MultiplayerService.instance.recordHintUsed(code: widget.roomCode, pseudo: widget.pseudo);
    }
  }

  void _showFeedback(String text, Color color) {
    _feedbackTimer?.cancel();
    setState(() { _feedbackText = text; _feedbackColor = color; });
    _toastCtrl.forward(from: 0);
    _feedbackTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  Future<void> _saveResult(MultiplayerGame game, {required bool won, required bool abandoned}) async {
    if (_resultSaved || _match == null) return;
    _resultSaved = true;
    final opponentPseudo = game.playerOrder.firstWhere(
      (p) => p != widget.pseudo, orElse: () => '?');
    final foundByMe = game.foundPlayers.where((f) => f.foundBy == widget.pseudo).length;
    final foundByOpp = game.foundPlayers.where((f) => f.foundBy == opponentPseudo).length;
    final myErrors = game.players[widget.pseudo]?.errors ?? 0;
    final result = GameResult.multiplayerCompos(
      difficulty: game.difficulty,
      matchId: _match!.matchId,
      matchName: _match!.matchName,
      opponentPseudo: opponentPseudo,
      won: won,
      abandoned: abandoned,
      foundByMe: foundByMe,
      foundByOpponent: foundByOpp,
      totalPlayers: _lineups.length,
      myErrors: myErrors,
      timeTaken: DateTime.now().difference(_startTime),
    );
    await GameHistoryService.instance.save(result);
  }

  void _showEndScreen(MultiplayerGame game) {
    if (_dialogShown) return;
    _dialogShown = true;
    final isDraw = game.winner == '__draw__';
    final iWon = !isDraw && game.winner == widget.pseudo;
    final opponentPseudo = game.playerOrder.firstWhere(
      (p) => p != widget.pseudo,
      orElse: () => 'Adversaire',
    );
    final borderColor = isDraw ? AppColors.amber : iWon ? AppColors.accentBright : AppColors.red;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        title: Text(
          isDraw ? '🤝 Match nul !' : iWon ? '🏆 Victoire !' : '💀 Éliminé',
          style: TextStyle(
            color: borderColor,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isDraw
                  ? 'Personne n\'a pris l\'avantage. Match nul !'
                  : iWon
                  ? '$opponentPseudo a été éliminé.'
                  : 'Tu as fait trop d\'erreurs.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _ScoreSummary(game: game, pseudo: widget.pseudo),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBright,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                if (_match != null) {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => MultiplayerResultPage(
                      game: game,
                      pseudo: widget.pseudo,
                      match: _match!,
                      lineups: _lineups,
                      timeTaken: DateTime.now().difference(_startTime),
                      abandoned: false,
                    ),
                  ));
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Résultats', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  bool get _isPitchMode {
    final m = _match;
    if (m == null) return false;
    return isFormationSupported(m.formationHome) &&
        isFormationSupported(m.formationAway);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = _game;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (game?.status == GameStatus.finished) { Navigator.of(context).pop(); return; }
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border)),
            title: Text('Quitter la partie ?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            content: Text('Ton adversaire sera déclaré vainqueur.', style: TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Continuer', style: TextStyle(color: AppColors.accentBright))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Quitter', style: TextStyle(color: AppColors.red))),
            ],
          ),
        ) ?? false;
        if (leave && mounted) {
          await MultiplayerService.instance.abandonRoom(code: widget.roomCode, pseudo: widget.pseudo);
          if (_game != null) _saveResult(_game!, won: false, abandoned: true);
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => _inputFocus.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: _isLoading || game == null
            ? Center(child: CircularProgressIndicator(color: AppColors.accentBright))
            : Stack(
                children: [
                  Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            _buildAppBar(game),
                            _buildStatusBar(game),
                            if (!_isPitchMode) _buildTabBar(),
                          ],
                        ),
                      ),
                      // ── Hint banner (above pitch, no overlap with chips) ─
                      if (_isMyTurn && _showHintBanner) _buildHintBanner(),
                      Expanded(
                        child: _isPitchMode ? _buildPitchView(game) : _buildTabView(game),
                      ),
                      _buildInputBar(game),
                    ],
                  ),
                  // ── Suffocation urgency border ───────────────────────────
                  if (_isMyTurn && game.suffocatedBy != null)
                    _buildSuffocationBorder(),
                  // ── Waiting overlay ─────────────────────────────────────
                  if (!_isMyTurn && game.status == GameStatus.playing)
                    _buildWaitingOverlay(game),
                  // ── Toast (always on top, visible above overlay) ─────────
                  _buildToast(),
                ],
              ),
      ),
    ),  // Scaffold
    );  // PopScope
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(MultiplayerGame game) {
    final match = _match;
    final folder = match != null ? _leagueFolder(match.competition) : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (match != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _competitionLogoSmall(match.competition),
                    const SizedBox(width: 6),
                    Text(
                      '${match.competition}  ·  ${match.date}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              // Room code badge (right)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.roomCode,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (match != null)
                _teamLogoSmall(match.homeTeam, match.colorHome, folder, size: 32)
              else
                SizedBox(
      width: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  match?.matchName ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (match != null)
                _teamLogoSmall(match.awayTeam, match.colorAway, folder, size: 32)
              else
                SizedBox(
      width: 32),
            ],
          ),
        ],
      ),
    );
  }

  // ── Status bar ────────────────────────────────────────────────────────────

  Widget _buildStatusBar(MultiplayerGame game) {
    final myData = game.players[widget.pseudo];
    final opponentPseudo = game.playerOrder.firstWhere(
      (p) => p != widget.pseudo,
      orElse: () => '?',
    );
    final opponentData = game.players[opponentPseudo];
    final total = _lineups.length;
    final found = _allFoundNames.length;
    final pct = total == 0 ? 0.0 : found / total;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: AppColors.card,
      child: Column(
        children: [
          // Progress
          Row(
            children: [
              Text(
                '$found/$total',
                style: TextStyle(
                  color: AppColors.accentBright,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(AppColors.accentBright),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Timer
              _TimerPill(secondsLeft: _secondsLeft, isMyTurn: _isMyTurn),
            ],
          ),
          const SizedBox(height: 8),
          // Players row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PlayerStatus(
                pseudo: widget.pseudo,
                errors: myData?.errors ?? 0,
                isTurn: _isMyTurn,
                isMe: true,
              ),
              Text(
                'VS',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              _PlayerStatus(
                pseudo: opponentPseudo,
                errors: opponentData?.errors ?? 0,
                isTurn: !_isMyTurn,
                isMe: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: AppColors.card,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.accentBright,
        indicatorWeight: 2,
        labelColor: AppColors.accentBright,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: [
          Tab(text: _match?.homeTeam ?? 'Équipe 1'),
          Tab(text: _match?.awayTeam ?? 'Équipe 2'),
        ],
      ),
    );
  }

  // ── Tab view ──────────────────────────────────────────────────────────────

  Widget _buildTabView(MultiplayerGame game) {
    return TabBarView(
      controller: _tabController,
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: _buildTeamContent(_match?.homeTeam ?? '', game),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: _buildTeamContent(_match?.awayTeam ?? '', game),
        ),
      ],
    );
  }

  Widget _buildTeamContent(String teamName, MultiplayerGame game) {
    final starters = _lineups.where((l) => l.teamName == teamName && l.starter).toList();
    final subs = _lineups.where((l) => l.teamName == teamName && !l.starter).toList();
    final found = _allFoundNames;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TITULAIRES',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10,
                fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: starters.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.78),
          itemBuilder: (_, i) {
            final p = starters[i];
            return _PlayerCard(
              player: p,
              isFound: found.contains(p.playerName),
              isPassed: false,
              hintContent: _hints[p.playerName],
              onTap: () => _onChipTap(p),
            );
          },
        ),
        if (subs.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('REMPLAÇANTS',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10,
                  fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = subs[i];
                return SizedBox(
                  width: 72,
                  child: _PlayerCard(
                    player: p,
                    isFound: found.contains(p.playerName),
                    isPassed: false,
                    hintContent: _hints[p.playerName],
                    onTap: () => _onChipTap(p),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ── Pitch view ────────────────────────────────────────────────────────────

  Widget _buildPitchView(MultiplayerGame game) {
    final match = _match!;
    final found = _allFoundNames;
    final homeStart = _lineups.where((l) => l.teamName == match.homeTeam && l.starter).toList();
    final awayStart = _lineups.where((l) => l.teamName == match.awayTeam && l.starter).toList();
    final homeSubs = _lineups.where((l) => l.teamName == match.homeTeam && !l.starter).toList();
    final awaySubs = _lineups.where((l) => l.teamName == match.awayTeam && !l.starter).toList();

    final homeSlots = assignPlayersToSlots(homeStart, match.formationHome);
    final awaySlots = assignPlayersToSlots(awayStart, match.formationAway);
    final homeLines = kFormationLines[match.formationHome]!;
    final awayLines = kFormationLines[match.formationAway]!;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return Stack(
                children: [
                  CustomPaint(size: size, painter: _PitchPainter()),
                  Positioned(
                    left: 16, top: size.height * 0.06,
                    child: Text(match.awayTeam.toUpperCase(),
                        style: TextStyle(color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  ),
                  Positioned(
                    right: 16, bottom: size.height * 0.06,
                    child: Text(match.homeTeam.toUpperCase(),
                        style: TextStyle(color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  ),
                  ..._buildTeamChips(
                    slots: awaySlots, lines: awayLines,
                    isHomeTeam: false, size: size, found: found, match: match,
                  ),
                  ..._buildTeamChips(
                    slots: homeSlots, lines: homeLines,
                    isHomeTeam: true, size: size, found: found, match: match,
                  ),
                ],
              );
            },
          ),
        ),
        _buildBench(homeSubs: homeSubs, awaySubs: awaySubs, found: found, match: match),
      ],
    );
  }

  List<Widget> _buildTeamChips({
    required List<Lineup?> slots,
    required List<List<String>> lines,
    required bool isHomeTeam,
    required Size size,
    required Set<String> found,
    required Match match,
  }) {
    final totalLines = lines.length;
    final double availableY = size.height * 0.40;
    final double spacePerLine = totalLines > 1 ? availableY / (totalLines - 1) : availableY;
    final double chipRadius = (spacePerLine * 0.38).clamp(12.0, 18.0);
    final Color teamColor = isHomeTeam ? _parseTeamColor(match.colorHome) : _parseTeamColor(match.colorAway);
    final Color? teamColor2 = isHomeTeam ? _parseTeamColor2(match.colorHome2) : _parseTeamColor2(match.colorAway2);

    final widgets = <Widget>[];
    int slotIdx = 0;
    for (int li = 0; li < lines.length; li++) {
      final line = lines[li];
      for (int si = 0; si < line.length; si++) {
        final player = slots[slotIdx++];
        final frac = slotFraction(
          lineIndex: li, slotIndex: si,
          totalSlotsInLine: line.length, totalLines: totalLines, isHomeTeam: isHomeTeam,
        );
        widgets.add(Positioned(
          left: frac.dx * size.width - chipRadius - 15,
          top: frac.dy * size.height - chipRadius - 2,
          child: _PitchChip(
            player: player,
            isFound: player != null && found.contains(player.playerName),
            isPassed: false,
            hintContent: player != null ? _hints[player.playerName] : null,
            onTap: player == null ? null : () => _onChipTap(player),
            chipRadius: chipRadius,
            teamColor: teamColor,
            teamColor2: teamColor2,
          ),
        ));
      }
    }
    return widgets;
  }

  Widget _buildBench({
    required List<Lineup> homeSubs,
    required List<Lineup> awaySubs,
    required Set<String> found,
    required Match match,
  }) {
    if (homeSubs.isEmpty && awaySubs.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildBenchTeam(match.homeTeam, homeSubs,
              _parseTeamColor(match.colorHome), _parseTeamColor2(match.colorHome2), found)),
          Container(width: 1, height: 60, color: AppColors.border),
          Expanded(child: _buildBenchTeam(match.awayTeam, awaySubs,
              _parseTeamColor(match.colorAway), _parseTeamColor2(match.colorAway2), found)),
        ],
      ),
    );
  }

  Widget _buildBenchTeam(String teamName, List<Lineup> subs, Color c1, Color? c2, Set<String> found) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 4),
          child: Text(teamName.toUpperCase(),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 8,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: subs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final sub = subs[i];
              return _SubChip(
                player: sub,
                isFound: found.contains(sub.playerName),
                isPassed: false,
                hintContent: _hints[sub.playerName],
                onTap: () => _onChipTap(sub),
                teamColor: c1,
                teamColor2: c2,
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar(MultiplayerGame game) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocus,
                enabled: _isMyTurn && game.status == GameStatus.playing,
                style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: _isMyTurn ? 'Nom de joueur...' : 'En attente de l\'adversaire...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  prefixIcon: Icon(Icons.person_search_rounded,
                      color: AppColors.accentBright, size: 22),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accentBright, width: 1.2)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accentBright, width: 2)),
                  disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border)),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _checkPlayer(),
              ),
            ),
            const SizedBox(width: 8),
            if (_isMyTurn && game.status == GameStatus.playing) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.amber,
                  disabledForegroundColor: AppColors.amber.withValues(alpha: 0.45),
                  side: BorderSide(color: AppColors.amber.withValues(alpha: 0.5)),
                  disabledMouseCursor: SystemMouseCursors.forbidden,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ).copyWith(
                  side: WidgetStateProperty.resolveWith((states) => BorderSide(
                    color: states.contains(WidgetState.disabled)
                        ? AppColors.amber.withValues(alpha: 0.25)
                        : AppColors.amber.withValues(alpha: 0.5),
                  )),
                ),
                onPressed: _submitting ? null : _passPlayer,
                child: Text('Passer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 8),
            ],
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isMyTurn && game.status == GameStatus.playing ? _checkPlayer : null,
              child: Text('OK', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hint banner ───────────────────────────────────────────────────────────

  Widget _buildHintBanner() {
    return GestureDetector(
      onTap: () {
        _hintBannerTimer?.cancel();
        setState(() => _showHintBanner = false);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFF0D1826),
          border: Border(
            top: BorderSide(color: AppColors.accentBright.withValues(alpha: 0.25)),
            bottom: BorderSide(color: AppColors.accentBright.withValues(alpha: 0.25)),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 14, color: AppColors.accentBright),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Clique sur un joueur pour obtenir un indice',
                style: TextStyle(
                  color: AppColors.accentBright,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.close, size: 14, color: AppColors.accentBright.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  // ── Toast ─────────────────────────────────────────────────────────────────

  Widget _buildToast() {
    return Positioned(
      left: 24, right: 24, bottom: 92,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _toastCtrl,
          builder: (_, __) => Opacity(
            opacity: _toastOpacity.value,
            child: Transform.translate(
              offset: Offset(0, _toastSlide.value),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                  decoration: BoxDecoration(
                    color: _feedbackColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                  child: Text(
                    _feedbackText ?? '',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 14, shadows: [Shadow(color: Colors.black38, blurRadius: 4)]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Suffocation urgency border ────────────────────────────────────────────

  Widget _buildSuffocationBorder() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _suffocatePulse,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.red.withValues(alpha: 0.3 + _suffocatePulse.value * 0.55),
                width: 4 + _suffocatePulse.value * 3,
              ),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Opacity(
                  opacity: _suffocatePulse.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '😤 SUFFOCATION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Waiting overlay ───────────────────────────────────────────────────────

  Widget _buildWaitingOverlay(MultiplayerGame game) {
    final opponentPseudo = game.playerOrder.firstWhere(
      (p) => p != widget.pseudo,
      orElse: () => 'Adversaire',
    );
    final me = game.players[widget.pseudo];
    final suffocationsLeft = me?.suffocationsLeft ?? 0;
    final opponentInRed = _secondsLeft <= 15;
    final canSuffocate = suffocationsLeft > 0 && game.suffocatedBy == null;
    final suffocateEnabled = canSuffocate && !opponentInRed;
    final isSuffocated = game.suffocatedBy == widget.pseudo;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
      width: 32, height: 32,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              '$opponentPseudo joue...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            // Timer de l'adversaire
            if (_secondsLeft > 0)
              Text(
                '$_secondsLeft s',
                style: TextStyle(
                  color: _secondsLeft <= 10 ? AppColors.red : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Text(
                _opponentOverflowScheduled ? 'Reprise dans quelques secondes...' : '0 s',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 32),

            // Suffocation button
            if (isSuffocated)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '😤 Suffocation activée !',
                  style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              )
            else if (canSuffocate)
              Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: suffocateEnabled
                          ? AppColors.red.withValues(alpha: 0.15)
                          : AppColors.border.withValues(alpha: 0.3),
                      foregroundColor: suffocateEnabled
                          ? AppColors.red
                          : AppColors.textSecondary,
                      elevation: 0,
                      side: BorderSide(
                        color: suffocateEnabled
                            ? AppColors.red.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onPressed: suffocateEnabled ? _activateSuffocation : null,
                    icon: Text('😤', style: TextStyle(fontSize: 16, color: suffocateEnabled ? null : AppColors.textSecondary)),
                    label: Text(
                      'Suffocation ($suffocationsLeft restant${suffocationsLeft > 1 ? 's' : ''})',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  if (!suffocateEnabled) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Adversaire déjà dans le rouge',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              )
            else if (suffocationsLeft == 0)
              Text(
                'Plus de suffocations',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TimerPill
// ─────────────────────────────────────────────────────────────────────────────

class _TimerPill extends StatelessWidget {
  final int secondsLeft;
  final bool isMyTurn;

  const _TimerPill({required this.secondsLeft, required this.isMyTurn});

  @override
  Widget build(BuildContext context) {
    final isUrgent = secondsLeft <= 10;
    final color = isUrgent ? AppColors.red : (isMyTurn ? AppColors.accentBright : AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$secondsLeft s',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PlayerStatus
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerStatus extends StatelessWidget {
  final String pseudo;
  final int errors;
  final bool isTurn;
  final bool isMe;

  const _PlayerStatus({
    required this.pseudo,
    required this.errors,
    required this.isTurn,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isTurn)
          Container(
            width: 6, height: 6, margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
                color: AppColors.accentBright, shape: BoxShape.circle),
          ),
        Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              pseudo,
              style: TextStyle(
                color: isTurn ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isTurn ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            Row(
              children: List.generate(3, (i) => Container(
                width: 7, height: 7,
                margin: EdgeInsets.only(left: i > 0 ? 3 : 0, right: i < 2 && !isMe ? 3 : 0),
                decoration: BoxDecoration(
                  color: i < errors ? AppColors.red : AppColors.border,
                  shape: BoxShape.circle,
                ),
              )),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ScoreSummary
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreSummary extends StatelessWidget {
  final MultiplayerGame game;
  final String pseudo;

  const _ScoreSummary({required this.game, required this.pseudo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: game.playerOrder.map((p) {
        final data = game.players[p];
        final foundByMe = game.foundPlayers.where((f) => f.foundBy == p).length;
        final isMe = p == pseudo;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(
                p,
                style: TextStyle(
                  color: isMe ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '$foundByMe trouvé${foundByMe > 1 ? 's' : ''}',
                style: TextStyle(color: AppColors.accentBright, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Row(
                children: List.generate(3, (i) => Container(
                  width: 7, height: 7,
                  margin: EdgeInsets.only(left: i > 0 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: i < (data?.errors ?? 0) ? AppColors.red : AppColors.border,
                    shape: BoxShape.circle,
                  ),
                )),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers (mirrored from lineup_match_page.dart — private there)
// ─────────────────────────────────────────────────────────────────────────────

Color _parseTeamColor(String? name) {
  switch (name?.toLowerCase().trim()) {
    case 'blanc':      return Color(0xFFF0F0F0);
    case 'noir':       return Color(0xFF000000);
    case 'rouge':      return Color(0xFFDC2626);
    case 'bleu':       return Color(0xFF1D4ED8);
    case 'bleu clair': return Color(0xFF60A5FA);
    case 'bleu foncé': return Color(0xFF0C034D);
    case 'vert':       return Color(0xFF16A34A);
    case 'jaune':      return Color(0xFFFACC15);
    case 'orange':     return Color(0xFFE16806);
    case 'violet':     return Color(0xFF790CC8);
    default:           return Color(0xFF4A5568);
  }
}

Color? _parseTeamColor2(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  return _parseTeamColor(name);
}

Color _labelColor(Color bg) =>
    bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

String? _leagueFolder(String competition) {
  final c = competition.toLowerCase();
  if (c.contains('euro') || c.contains('coupe du monde') || c.contains('world cup') ||
      c.contains('ligue des nations') || c.contains('copa') || c.contains('barrage'))
    return 'pays';
  if (c.contains('champions league') || c.contains('ligue des champions'))
    return 'Champions League';
  if (c.contains('ligue 1') || c.contains('coupe de france') || c.contains('coupe de la ligue'))
    return 'France - Ligue 1';
  if (c.contains('premier league') || c.contains('community shield') || c.contains('fa cup'))
    return 'England - Premier League';
  if (c.contains('laliga') || c.contains('la liga') || c.contains('liga'))
    return 'Spain - La Liga';
  if (c.contains('bundesliga') && !c.contains('austria'))
    return 'Germany - Bundesliga';
  if (c.contains('serie a')) return 'Italy - Serie A';
  if (c.contains('eredivisie')) return 'Netherlands - Eredivisie';
  if (c.contains('liga portugal')) return 'Portugal - Liga Portugal';
  if (c.contains('jupiler')) return 'Belgium - Jupiler Pro League';
  return null;
}

const _coloredCompLogos = {'Euro', 'Coupe du Monde'};

Widget _teamLogoSmall(String name, String colorName, String? folder, {double size = 28}) {
  final bg = _parseTeamColor(colorName);
  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
  final fallback = Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: bg, shape: BoxShape.circle,
      border: Border.all(color: Color(0xFF2D3148), width: 1.5),
    ),
    child: Center(
      child: Text(initial, style: TextStyle(
        fontSize: size * 0.38, fontWeight: FontWeight.w800,
        color: bg.computeLuminance() < 0.4 ? Colors.white : Colors.black87,
      )),
    ),
  );
  if (folder == null) return fallback;
  final fileName = folder == 'pays' ? removeDiacritics(name.toLowerCase()) : name;
  return Image.asset('assets/logos/$folder/$fileName.png',
      width: size, height: size, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback);
}

Widget _competitionLogoSmall(String competition) {
  final img = Image.asset('assets/logos/competitions/$competition.png',
      width: 36, height: 36, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink());
  if (_coloredCompLogos.contains(competition)) return img;
  return ColorFiltered(
      colorFilter: ColorFilter.mode(ThemeService.instance.isDark ? Colors.white : Colors.black87, BlendMode.srcIn), child: img);
}

// ─────────────────────────────────────────────────────────────────────────────
// _PitchPainter
// ─────────────────────────────────────────────────────────────────────────────

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Color(0xFF1A5C2A));
    const stripes = 8;
    final stripeH = h / stripes;
    for (int i = 0; i < stripes; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * stripeH, w, stripeH),
          Paint()..color = Color(0xFF1E6830));
    }
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke ..strokeWidth = 1.0;
    const p = 10.0;
    canvas.drawRect(Rect.fromLTRB(p, p, w - p, h - p), line);
    canvas.drawLine(Offset(p, h / 2), Offset(w - p, h / 2), line);
    canvas.drawCircle(Offset(w / 2, h / 2), h * 0.09, line);
    canvas.drawCircle(Offset(w / 2, h / 2), 3, Paint()..color = Colors.white.withValues(alpha: 0.55));
    final penW = w * 0.55; final penH = h * 0.13; final penLeft = (w - penW) / 2;
    canvas.drawRect(Rect.fromLTRB(penLeft, p, penLeft + penW, p + penH), line);
    canvas.drawRect(Rect.fromLTRB(penLeft, h - p - penH, penLeft + penW, h - p), line);
    final goalW = w * 0.28; final goalH = h * 0.05; final goalLeft = (w - goalW) / 2;
    canvas.drawRect(Rect.fromLTRB(goalLeft, p, goalLeft + goalW, p + goalH), line);
    canvas.drawRect(Rect.fromLTRB(goalLeft, h - p - goalH, goalLeft + goalW, h - p), line);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// _RipplePainter
// ─────────────────────────────────────────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  final double progress;
  final double chipRadius;
  final Color color;
  const _RipplePainter({required this.progress, required this.chipRadius, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = chipRadius + progress * 32;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    canvas.drawCircle(center, radius, Paint()
      ..color = color.withValues(alpha: opacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * (1.0 - progress * 0.6));
  }
  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// _PitchChip
// ─────────────────────────────────────────────────────────────────────────────

class _PitchChip extends StatefulWidget {
  final Lineup? player;
  final bool isFound;
  final bool isPassed;
  final String? hintContent;
  final VoidCallback? onTap;
  final double chipRadius;
  final Color teamColor;
  final Color? teamColor2;

  const _PitchChip({
    required this.player, required this.isFound, required this.isPassed,
    required this.chipRadius, required this.teamColor,
    this.teamColor2, this.hintContent, this.onTap,
  });

  @override
  State<_PitchChip> createState() => _PitchChipState();
}

class _PitchChipState extends State<_PitchChip> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;
  late AnimationController _rippleCtrl;
  late Animation<double> _rippleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.55), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1.55, end: 0.78), weight: 16),
      TweenSequenceItem(tween: Tween(begin: 0.78, end: 1.22), weight: 14),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.90), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.10), weight: 11),
      TweenSequenceItem(tween: Tween(begin: 1.10, end: 0.96), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.03), weight: 9),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 10),
    ]).animate(_ctrl);
    _glow = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 80),
    ]).animate(_ctrl);
    _rippleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _rippleAnim = CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_PitchChip old) {
    super.didUpdateWidget(old);
    if (!old.isFound && widget.isFound) {
      _ctrl.forward(from: 0);
      _rippleCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _rippleCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final revealed = widget.isFound || widget.isPassed;
    final d = widget.chipRadius * 2;
    String label;
    if (revealed) {
      label = widget.player!.playerNumber > 0 ? '${widget.player!.playerNumber}' : '✓';
    } else if (widget.hintContent != null) {
      label = widget.hintContent!;
    } else {
      label = '?';
    }
    final c1 = widget.isPassed ? AppColors.amber : widget.teamColor;
    final c2 = widget.isPassed ? AppColors.amber : (widget.teamColor2 ?? widget.teamColor);
    final numFontSize = d < 28 ? 8.0 : 10.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.player == null || revealed ? null : widget.onTap,
      child: SizedBox(
        width: d + 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: d, height: d,
              child: AnimatedBuilder(
                animation: Listenable.merge([_ctrl, _rippleCtrl]),
                builder: (_, __) => Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(size: Size(d, d),
                        painter: _RipplePainter(progress: _rippleAnim.value, chipRadius: d / 2, color: c1)),
                    Transform.scale(
                      scale: _scale.value,
                      child: Container(
                        width: d, height: d,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: revealed ? LinearGradient(
                            colors: [c1, c1, c2, c2], stops: [0.0, 0.5, 0.5, 1.0],
                            begin: Alignment.centerLeft, end: Alignment.centerRight,
                          ) : null,
                          color: revealed ? null : Colors.white.withValues(alpha: 0.10),
                          border: Border.all(color: Colors.white, width: revealed ? 1.5 : 1.2),
                          boxShadow: [
                            const BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2)),
                            BoxShadow(color: c1.withValues(alpha: _glow.value * 0.8),
                                blurRadius: _glow.value * 24, spreadRadius: _glow.value * 5),
                          ],
                        ),
                        child: Center(child: Text(label, style: TextStyle(
                          color: revealed && c1 == c2 ? _labelColor(c1) : Colors.white,
                          fontSize: numFontSize, fontWeight: FontWeight.w800, height: 1,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                        ))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (revealed && widget.chipRadius >= 13) ...[
              const SizedBox(height: 1),
              SizedBox(
                width: d + 30,
                child: Text(
                  widget.player!.playerName.trim(),
                  textAlign: TextAlign.center,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isFound ? Color(0xFFB5EDBB) : AppColors.amber,
                    fontSize: 9, fontWeight: FontWeight.w700, height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SubChip
// ─────────────────────────────────────────────────────────────────────────────

class _SubChip extends StatefulWidget {
  final Lineup player;
  final bool isFound;
  final bool isPassed;
  final String? hintContent;
  final VoidCallback? onTap;
  final Color teamColor;
  final Color? teamColor2;

  const _SubChip({
    required this.player, required this.isFound, required this.isPassed,
    required this.teamColor, this.teamColor2, this.hintContent, this.onTap,
  });

  @override
  State<_SubChip> createState() => _SubChipState();
}

class _SubChipState extends State<_SubChip> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;
  late AnimationController _rippleCtrl;
  late Animation<double> _rippleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.55), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1.55, end: 0.78), weight: 16),
      TweenSequenceItem(tween: Tween(begin: 0.78, end: 1.22), weight: 14),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.90), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.10), weight: 11),
      TweenSequenceItem(tween: Tween(begin: 1.10, end: 0.96), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.03), weight: 9),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 10),
    ]).animate(_ctrl);
    _glow = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 80),
    ]).animate(_ctrl);
    _rippleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _rippleAnim = CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_SubChip old) {
    super.didUpdateWidget(old);
    if (!old.isFound && widget.isFound) {
      _ctrl.forward(from: 0);
      _rippleCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _rippleCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final revealed = widget.isFound || widget.isPassed;
    final String label;
    if (revealed) {
      label = widget.player.playerNumber > 0 ? '${widget.player.playerNumber}' : '✓';
    } else if (widget.hintContent != null) {
      label = widget.hintContent!;
    } else {
      label = '?';
    }
    const double d = 32;
    final c1 = widget.isPassed ? AppColors.amber : widget.teamColor;
    final c2 = widget.isPassed ? AppColors.amber : (widget.teamColor2 ?? widget.teamColor);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: revealed ? null : widget.onTap,
      child: SizedBox(
        width: 32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: d, height: d,
              child: AnimatedBuilder(
                animation: Listenable.merge([_ctrl, _rippleCtrl]),
                builder: (_, __) => Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(size: Size(d, d),
                        painter: _RipplePainter(progress: _rippleAnim.value, chipRadius: d / 2, color: c1)),
                    Transform.scale(
                      scale: _scale.value,
                      child: Container(
                        width: d, height: d,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: revealed ? LinearGradient(
                            colors: [c1, c1, c2, c2], stops: [0.0, 0.5, 0.5, 1.0],
                            begin: Alignment.centerLeft, end: Alignment.centerRight,
                          ) : null,
                          color: revealed ? null : Colors.white.withValues(alpha: 0.10),
                          border: Border.all(color: Colors.white, width: revealed ? 1.5 : 1.2),
                          boxShadow: [
                            const BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2)),
                            BoxShadow(color: c1.withValues(alpha: _glow.value * 0.8),
                                blurRadius: _glow.value * 24, spreadRadius: _glow.value * 5),
                          ],
                        ),
                        child: Center(child: Text(label, style: TextStyle(
                          color: revealed && c1 == c2 ? _labelColor(c1) : Colors.white,
                          fontSize: 10, fontWeight: FontWeight.w800, height: 1,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                        ))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (revealed) ...[
              const SizedBox(height: 2),
              Text(widget.player.playerName.trim(),
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isFound ? AppColors.accentBright : AppColors.amber,
                    fontSize: 7, fontWeight: FontWeight.w700, height: 1.2,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PlayerCard
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final Lineup player;
  final bool isFound;
  final bool isPassed;
  final String? hintContent;
  final VoidCallback? onTap;

  const _PlayerCard({
    required this.player, required this.isFound, required this.isPassed,
    this.hintContent, this.onTap,
  });

  Color get _borderColor {
    if (isFound) return AppColors.accentBright;
    if (isPassed) return AppColors.amber;
    return AppColors.border;
  }

  Color get _bgColor {
    if (isFound) return AppColors.accentBright.withValues(alpha: 0.10);
    if (isPassed) return AppColors.amber.withValues(alpha: 0.08);
    return AppColors.card;
  }

  Color get _shirtColor {
    if (isFound) return AppColors.accentBright;
    if (isPassed) return AppColors.amber;
    return AppColors.border;
  }

  Color get _nameColor {
    if (isFound) return AppColors.accentBright;
    if (isPassed) return AppColors.amber;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final revealed = isFound || isPassed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: revealed ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor, width: revealed ? 1.5 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Image.asset('assets/images/shirt.png', width: 30, height: 30, color: _shirtColor),
                if (revealed && player.playerNumber > 0)
                  Positioned(
                    top: 9,
                    child: Text('${player.playerNumber}', style: TextStyle(
                      fontSize: 8, fontWeight: FontWeight.w800, color: _labelColor(_shirtColor),
                    )),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              revealed ? player.playerName.trim() : (hintContent ?? player.position),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: revealed ? FontWeight.w700 : FontWeight.w500,
                color: hintContent != null && !revealed ? AppColors.accentBright : _nameColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
