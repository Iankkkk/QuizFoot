// lineup_match_page.dart
//
// Game page for "Compos" — find all players of an iconic match.
//
// Rules:
//   • Type a player's last name to find him
//   • 6 errors max before defeat
//   • Hint (numbers) costs 3 points
//   • "Passer" ends the game (with confirmation)
//   • Score = 1 pt per player found (hint deducts 3, can go negative)
//
// Layout:
//   • If both formations are supported → full pitch view (home bottom / away top)
//   • Otherwise → classic tab view (fallback)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:diacritic/diacritic.dart';
import 'package:string_similarity/string_similarity.dart';
import '../../constants/app_colors.dart';
import '../../data/lineup_game_data.dart';
import '../../data/api_exception.dart';
import '../../models/match_model.dart';
import '../../models/lineup_model.dart';
import '../../models/game_result.dart';
import '../../services/game_history_service.dart';
import 'formation_layout.dart';
import 'lineup_score_page.dart';
import 'lineup_visuals.dart';
import 'pitch_widgets.dart';
import 'package:quiz_foot/utils/navigation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LineupMatchPage
// ─────────────────────────────────────────────────────────────────────────────

class LineupMatchPage extends StatefulWidget {
  const LineupMatchPage({
    super.key,
    required this.difficulty,
    this.eras,
    this.preselectedMatch,
  });
  final String difficulty;
  final Set<String>? eras;
  final Match? preselectedMatch;

  @override
  State<LineupMatchPage> createState() => _LineupMatchPageState();
}

class _LineupMatchPageState extends State<LineupMatchPage>
    with TickerProviderStateMixin {
  // ── Data ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  Match? _selectedMatch;
  List<Lineup> _lineups = [];

  // ── Game state ────────────────────────────────────────────────────────────
  final Set<String> _foundPlayers = {};
  final Set<String> _passedPlayers = {};
  int _foundCount = 0;
  final Map<String, String> _hints = {};
  final List<String> _wrongAnswers = [];
  int _errors = 0;
  int _score = 0;
  bool _gameOver = false;

  static const int _maxErrors = 6;
  static const int _maxFreeHints = 5;

  // ── Tabs (fallback only) ──────────────────────────────────────────────────
  late TabController _tabController;

  // ── Input ─────────────────────────────────────────────────────────────────
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  // ── Feedback toast ────────────────────────────────────────────────────────
  String? _feedbackText;
  Color _feedbackColor = AppColors.accentBright;
  Timer? _feedbackTimer;
  late AnimationController _toastCtrl;
  late Animation<double> _toastOpacity;
  late Animation<double> _toastSlide;

  // ── Hint banner ───────────────────────────────────────────────────────────
  bool _showHintBanner = false;
  Timer? _hintBannerTimer;

  // ── Timing ────────────────────────────────────────────────────────────────
  late final DateTime _startTime;

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
    _loadMatches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _toastCtrl.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    _feedbackTimer?.cancel();
    _hintBannerTimer?.cancel();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    if (widget.preselectedMatch != null) {
      setState(() => _selectedMatch = widget.preselectedMatch);
      await _loadLineups(widget.preselectedMatch!.matchId);
      return;
    }
    try {
      final matches = await loadMatches();
      final history = await GameHistoryService.instance.getAll();
      final playedIds = history
          .where((r) => r.gameType == GameType.compos)
          .map((r) => r.details['matchId'] as String? ?? '')
          .toSet();

      final level = difficultyToLevel(widget.difficulty);
      List<Match> filtered = matches.where((m) {
        if (m.level != level) return false;
        final eras = widget.eras;
        if (eras == null || eras.isEmpty) return true;
        final yearMatch = RegExp(r'\d{4}').firstMatch(m.date);
        final year = int.tryParse(yearMatch?.group(0) ?? '');
        if (year == null) return true;
        return eras.any((era) {
          if (era == 'Avant 2010') return year < 2010;
          if (era == '2010-2019') return year >= 2010 && year <= 2019;
          if (era == '2020-2026') return year >= 2020;
          return false;
        });
      }).toList();

      if (filtered.isEmpty) {
        await _showErrorAndPop('Aucun match disponible pour cette combinaison difficulté / période.\nEssaie d\'autres filtres.');
        return;
      }

      // Exclure les matchs déjà joués ; si tous joués, tout réafficher
      final unplayed = filtered
          .where((m) => !playedIds.contains(m.matchId))
          .toList();
      final pool = unplayed.isNotEmpty ? unplayed : filtered;

      final picked = (List<Match>.from(pool)..shuffle()).first;
      setState(() => _selectedMatch = picked);
      await _loadLineups(picked.matchId);
    } on ApiException catch (e) {
      await _showErrorAndPop(e.userMessage);
    } catch (_) {
      await _showErrorAndPop('Erreur inattendue. Réessaie.');
    }
  }

  Future<void> _showErrorAndPop(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Impossible de lancer la partie',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Text(message,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            child: Text('Retour',
                style: TextStyle(color: AppColors.accentBright)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLineups(String matchId) async {
    try {
      final all = await loadLineups(matchId);
      setState(() {
        _lineups = all.where((l) => l.matchId == matchId).toList();
        _foundPlayers.clear();
        _passedPlayers.clear();
        _foundCount = 0;
        _hints.clear();
        _wrongAnswers.clear();
        _errors = 0;
        _score = 0;
        _isLoading = false;
        _showHintBanner = false;
      });
      _hintBannerTimer?.cancel();
      _hintBannerTimer = Timer(const Duration(seconds: 20), () {
        if (mounted) setState(() => _showHintBanner = true);
      });
    } on ApiException catch (e) {
      _showFeedback(e.userMessage, AppColors.red);
      setState(() => _isLoading = false);
    } catch (_) {
      _showFeedback('Erreur inattendue. Réessaie.', AppColors.red);
      setState(() => _isLoading = false);
    }
  }

  // ── Game logic ────────────────────────────────────────────────────────────

  void _showFeedback(String text, Color color) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackText = text;
      _feedbackColor = color;
    });
    _toastCtrl.forward(from: 0);
    _feedbackTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  String _norm(String s) =>
      removeDiacritics(s.toLowerCase()).replaceAll('.', '').trim();

  String _lastName(String fullName) => fullName.trim().split(' ').last;

  void _checkPlayer() {
    final raw = _inputController.text.trim();
    if (raw.isEmpty) return;

    final answer = _norm(raw);

    final List<Lineup> exactMatches = [];
    final List<Lineup> closeMatches = [];

    for (final l in _lineups) {
      bool isExact = false;
      double bestSim = 0.0;

      for (final name in l.allNames) {
        final fullNorm = _norm(name);
        final lastNorm = _norm(_lastName(name));
        if (fullNorm == answer ||
            lastNorm == answer ||
            lastNorm.similarityTo(answer) >= 0.8) {
          isExact = true;
          break;
        }
        final sim = lastNorm.similarityTo(answer);
        if (sim > bestSim) bestSim = sim;
      }

      if (isExact) {
        exactMatches.add(l);
      } else if (bestSim >= 0.5) {
        closeMatches.add(l);
      }
    }

    final alreadyFound = exactMatches
        .where(
          (l) =>
              _foundPlayers.contains(l.playerName) ||
              _passedPlayers.contains(l.playerName),
        )
        .toList();
    final newFound = exactMatches
        .where(
          (l) =>
              !_foundPlayers.contains(l.playerName) &&
              !_passedPlayers.contains(l.playerName),
        )
        .toList();

    // ✅ New correct answer(s)
    if (newFound.isNotEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        for (final p in newFound) {
          _foundPlayers.add(p.playerName);
        }
        _score += newFound.length;
        _foundCount += newFound.length;
      });
      final label = newFound.length > 1
          ? '${newFound.length} joueurs trouvés ! (+${newFound.length})'
          : '${_lastName(newFound.first.playerName)} ✓  (+1)';
      _showFeedback(label, AppColors.accentBright);
      _inputController.clear();
      _inputFocus.unfocus();
      _checkVictory();
      return;
    }

    // Already found / passed
    if (alreadyFound.isNotEmpty) {
      HapticFeedback.lightImpact();
      _showFeedback('Déjà trouvé !', AppColors.amber);
      _inputController.clear();
      _inputFocus.unfocus();
      return;
    }

    // 🟡 Close — let user refine without clearing
    final closeNotFound = closeMatches
        .where(
          (l) =>
              !_foundPlayers.contains(l.playerName) &&
              !_passedPlayers.contains(l.playerName),
        )
        .toList();
    if (closeNotFound.isNotEmpty) {
      HapticFeedback.lightImpact();
      _showFeedback('Presque...', AppColors.amber);
      _inputFocus.requestFocus();
      return;
    }

    // ❌ Wrong
    HapticFeedback.heavyImpact();
    setState(() {
      _errors++;
      _wrongAnswers.add(raw);
    });
    _showFeedback(
      'Pas dans cette compo  (${_maxErrors - _errors} erreurs restante${_maxErrors - _errors > 1 ? 's' : ''})',
      AppColors.red,
    );
    _inputController.clear();
    _inputFocus.unfocus();

    if (_errors >= _maxErrors) {
      Future.delayed(
        const Duration(milliseconds: 700),
        () => _endGame(defeat: true),
      );
    }
  }

  // First letter of the canonical last name, uppercased.
  String _firstLetter(Lineup l) {
    final name = l.playerName.trim();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  Future<void> _onChipTap(Lineup player) async {
    if (_gameOver) return;
    if (_inputFocus.hasFocus) {
      _inputFocus.unfocus();
      return;
    }
    if (_showHintBanner) {
      _hintBannerTimer?.cancel();
      setState(() => _showHintBanner = false);
    }
    // Nothing to reveal on already-resolved or already-hinted players.
    if (_foundPlayers.contains(player.playerName) ||
        _passedPlayers.contains(player.playerName) ||
        _hints.containsKey(player.playerName)) {
      return;
    }

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
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Poste : ${player.position}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            Text(
              'Équipe : ${player.teamName}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
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
            child: Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          if (canHint) ...[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('letter'),
              child: Text(
                '1ère lettre',
                style: TextStyle(
                  color: AppColors.accentBright,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (hasNumber)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('number'),
                child: Text(
                  'Numéro',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    if (choice != null) {
      HapticFeedback.lightImpact();
      final content = choice == 'letter'
          ? _firstLetter(player)
          : '${player.playerNumber}';
      setState(() => _hints[player.playerName] = content);
    }
  }

  Future<void> _passPlayer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Terminer la partie ?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Les réponses manquantes seront révélées.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Continuer',
              style: TextStyle(color: AppColors.accentBright),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Terminer', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) _endGame(defeat: false);
  }

  void _checkVictory() {
    if (_foundCount + _passedPlayers.length == _lineups.length) {
      Future.delayed(
        const Duration(milliseconds: 600),
        () => _endGame(defeat: false),
      );
    }
  }

  void _endGame({required bool defeat}) {
    if (_gameOver) return;
    setState(() => _gameOver = true);
    final timeTaken = DateTime.now().difference(_startTime);
    Navigator.pushReplacement(
      context,
      namedRoute(LineupScorePage(
        match: _selectedMatch!,
        lineups: _lineups,
        foundPlayers: Set.from(_foundPlayers),
        passedPlayers: Set.from(_passedPlayers),
        score: _score,
        errors: _errors,
        hintsUsed: _hints.length,
        wrongAnswers: List.from(_wrongAnswers),
        timeTaken: timeTaken,
        defeat: defeat,
        difficulty: widget.difficulty,
      )),
    );
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  int get _totalPlayers => _lineups.length;
  int get _revealedCount => _foundCount + _passedPlayers.length;

  bool get _isPitchMode {
    final m = _selectedMatch;
    if (m == null) return false;
    return isFormationSupported(m.formationHome) &&
        isFormationSupported(m.formationAway);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _showExitDialog();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: () => _inputFocus.unfocus(),
          behavior: HitTestBehavior.translucent,
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentBright,
                  ),
                )
              : Builder(builder: (context) {
                  final bool compact =
                      MediaQuery.of(context).viewInsets.bottom > 50;
                  return Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          _buildAppBar(compact: compact),
                          _buildStatusBar(compact: compact),
                          if (_showHintBanner) _buildHintBanner(),
                          if (!_isPitchMode) _buildTabBar(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          _isPitchMode ? _buildPitchView() : _buildTabView(),
                          _buildToast(),
                        ],
                      ),
                    ),
                    _buildInputBar(),
                  ],
                );
                }),
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar({bool compact = false}) {
    final match = _selectedMatch;
    final folder = match != null ? leagueFolder(match.competition) : null;
    return Container(
      padding: EdgeInsets.fromLTRB(12, compact ? 4 : 10, 12, compact ? 4 : 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Ligne 1 : flèche à gauche, compétition · date centré
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () async {
                    final leave = await _showExitDialog();
                    if (leave && mounted) Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
              ),
              if (match != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    competitionLogoSmall(match.competition),
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
            ],
          ),
          SizedBox(height: compact ? 6 : 12),
          // Ligne 2 : logo home + titre centré + logo away
          Row(
            children: [
              if (match != null)
                teamLogoSmall(
                  match.homeTeam,
                  match.colorHome,
                  folder,
                  size: compact ? 38 : 48,
                )
              else
                const SizedBox(width: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  match?.matchName ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              if (match != null)
                teamLogoSmall(
                  match.awayTeam,
                  match.colorAway,
                  folder,
                  size: compact ? 38 : 48,
                )
              else
                const SizedBox(width: 44),
            ],
          ),
        ],
      ),
    );
  }

  // ── Status bar ────────────────────────────────────────────────────────────

  Widget _buildHintBanner() {
    return GestureDetector(
      onTap: () {
        _hintBannerTimer?.cancel();
        setState(() => _showHintBanner = false);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        color: AppColors.accentBright.withValues(alpha: 0.10),
        child: Row(
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 14,
              color: AppColors.accentBright,
            ),
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
            Icon(Icons.close, size: 14, color: AppColors.accentBright),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar({bool compact = false}) {
    final pct = _totalPlayers == 0 ? 0.0 : _revealedCount / _totalPlayers;
    final errorColor = _errors >= 4 ? AppColors.red : AppColors.textSecondary;
    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 4 : 8, 16, compact ? 4 : 8),
      color: AppColors.card,
      child: Row(
        children: [
          Text(
            '$_revealedCount/$_totalPlayers',
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
          GestureDetector(
            onTap: _errors > 0 ? _showWrongAnswers : null,
            child: Row(
              children: [
                ...List.generate(
                  _maxErrors,
                  (i) => Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(left: i > 0 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i < _errors ? AppColors.red : AppColors.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_errors/${_maxErrors}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: errorColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Fallback: tab bar ─────────────────────────────────────────────────────

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
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: [
          Tab(text: _selectedMatch?.homeTeam ?? 'Équipe 1'),
          Tab(text: _selectedMatch?.awayTeam ?? 'Équipe 2'),
        ],
      ),
    );
  }

  // ── Fallback: tab view ────────────────────────────────────────────────────

  Widget _buildTabView() {
    return TabBarView(
      controller: _tabController,
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: _buildTeamContent(_selectedMatch?.homeTeam ?? ''),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: _buildTeamContent(_selectedMatch?.awayTeam ?? ''),
        ),
      ],
    );
  }

  Widget _buildTeamContent(String teamName) {
    final starters = _lineups
        .where((l) => l.teamName == teamName && l.starter)
        .toList();
    final subs = _lineups
        .where((l) => l.teamName == teamName && !l.starter)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TITULAIRES',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: starters.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (_, i) {
            final p = starters[i];
            return PlayerCard(
              player: p,
              isFound: _foundPlayers.contains(p.playerName),
              isPassed: _passedPlayers.contains(p.playerName),
              hintContent: _hints[p.playerName],
              onTap: () => _onChipTap(p),
            );
          },
        ),
        if (subs.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'REMPLAÇANTS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
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
                  child: PlayerCard(
                    player: p,
                    isFound: _foundPlayers.contains(p.playerName),
                    isPassed: _passedPlayers.contains(p.playerName),
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

  Widget _buildPitchView() {
    final match = _selectedMatch!;
    final homeStart = _lineups
        .where((l) => l.teamName == match.homeTeam && l.starter)
        .toList();
    final awayStart = _lineups
        .where((l) => l.teamName == match.awayTeam && l.starter)
        .toList();
    final homeSubs = _lineups
        .where((l) => l.teamName == match.homeTeam && !l.starter)
        .toList();
    final awaySubs = _lineups
        .where((l) => l.teamName == match.awayTeam && !l.starter)
        .toList();

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
                  // ── Pitch background ──
                  CustomPaint(size: size, painter: PitchPainter()),

                  // ── Team labels — left side, near each GK zone ──
                  Positioned(
                    left: 16,
                    top: size.height * 0.06,
                    child: Text(
                      match.awayTeam.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: size.height * 0.06,
                    child: Text(
                      match.homeTeam.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  // ── Away team chips (top half) ──
                  ..._buildTeamChips(
                    slots: awaySlots,
                    lines: awayLines,
                    isHomeTeam: false,
                    size: size,
                  ),

                  // ── Home team chips (bottom half) ──
                  ..._buildTeamChips(
                    slots: homeSlots,
                    lines: homeLines,
                    isHomeTeam: true,
                    size: size,
                  ),
                ],
              );
            },
          ),
        ),

        // ── Bench (subs) ──
        _buildBench(homeSubs: homeSubs, awaySubs: awaySubs),
      ],
    );
  }

  List<Widget> _buildTeamChips({
    required List<Lineup?> slots,
    required List<List<String>> lines,
    required bool isHomeTeam,
    required Size size,
  }) {
    final match = _selectedMatch!;
    final totalLines = lines.length;
    final double chipRadius = (size.shortestSide * 0.048).clamp(13.0, 18.0);
    final Color teamColor = isHomeTeam
        ? parseTeamColor(match.colorHome)
        : parseTeamColor(match.colorAway);
    final Color? teamColor2 = isHomeTeam
        ? parseTeamColor2(match.colorHome2)
        : parseTeamColor2(match.colorAway2);

    final widgets = <Widget>[];
    int slotIdx = 0;

    for (int li = 0; li < lines.length; li++) {
      final line = lines[li];
      for (int si = 0; si < line.length; si++) {
        final player = slots[slotIdx++];
        final frac = slotFraction(
          lineIndex: li,
          slotIndex: si,
          totalSlotsInLine: line.length,
          totalLines: totalLines,
          isHomeTeam: isHomeTeam,
        );

        final x = frac.dx * size.width;
        final y = frac.dy * size.height;

        widgets.add(
          Positioned(
            left: x - chipRadius - 15,
            top: y - chipRadius - 2,
            child: PitchChip(
              player: player,
              isFound:
                  player != null && _foundPlayers.contains(player.playerName),
              isPassed:
                  player != null && _passedPlayers.contains(player.playerName),
              hintContent: player != null ? _hints[player.playerName] : null,
              onTap: player == null ? null : () => _onChipTap(player),
              chipRadius: chipRadius,
              teamColor: teamColor,
              teamColor2: teamColor2,
            ),
          ),
        );
      }
    }
    return widgets;
  }

  // ── Bench bar ─────────────────────────────────────────────────────────────

  Widget _buildBench({
    required List<Lineup> homeSubs,
    required List<Lineup> awaySubs,
  }) {
    if (homeSubs.isEmpty && awaySubs.isEmpty) return const SizedBox.shrink();

    final match = _selectedMatch!;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildBenchTeam(
              match.homeTeam,
              homeSubs,
              parseTeamColor(match.colorHome),
              parseTeamColor2(match.colorHome2),
            ),
          ),
          Container(width: 1, height: 60, color: AppColors.border),
          Expanded(
            child: _buildBenchTeam(
              match.awayTeam,
              awaySubs,
              parseTeamColor(match.colorAway),
              parseTeamColor2(match.colorAway2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenchTeam(
    String teamName,
    List<Lineup> subs,
    Color teamColor,
    Color? teamColor2,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 4),
          child: Text(
            teamName.toUpperCase(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
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
              return PitchChip(
                isSub: true,
                player: sub,
                isFound: _foundPlayers.contains(sub.playerName),
                isPassed: _passedPlayers.contains(sub.playerName),
                hintContent: _hints[sub.playerName],
                onTap: () => _onChipTap(sub),
                teamColor: teamColor,
                teamColor2: teamColor2,
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildToast() {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 20,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _toastCtrl,
          builder: (_, __) => Opacity(
            opacity: _toastOpacity.value,
            child: Transform.translate(
              offset: Offset(0, _toastSlide.value),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: _feedbackColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _feedbackText ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
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

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocus,
                    enabled: !_gameOver,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nom de joueur...',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.person_search_rounded,
                        color: AppColors.accentBright,
                        size: 22,
                      ),
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.accentBright,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.accentBright,
                          width: 2,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _checkPlayer(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBright,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _gameOver ? null : _checkPlayer,
                  child: Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _gameOver ? null : _passPlayer,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      Icons.skip_next_rounded,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

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
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Continuer',
                  style: TextStyle(color: AppColors.accentBright),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Quitter', style: TextStyle(color: AppColors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showWrongAnswers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Liste des erreurs',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ..._wrongAnswers.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.close, color: AppColors.red, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        w,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
