// lineup_match_page.dart
//
// Game page for "Compos" — find all players of an iconic match.
//
// Rules:
//   • Type a player's last name to find him
//   • 6 errors max before defeat
//   • Hint (numbers) costs 3 points
//   • "Passer" reveals one player (no point awarded)
//   • Score = 1 pt per player found (hint deducts 3)

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
import 'lineup_score_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

int _difficultyToLevel(String difficulty) {
  switch (difficulty) {
    case 'Très Facile':
      return 1;
    case 'Facile':
      return 2;
    case 'Moyenne':
      return 3;
    case 'Difficile':
      return 4;
    case 'Impossible':
      return 5;
    default:
      return 3;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LineupMatchPage
// ─────────────────────────────────────────────────────────────────────────────

class LineupMatchPage extends StatefulWidget {
  const LineupMatchPage({super.key, required this.difficulty});
  final String difficulty;

  @override
  State<LineupMatchPage> createState() => _LineupMatchPageState();
}

class _LineupMatchPageState extends State<LineupMatchPage>
    with SingleTickerProviderStateMixin {
  // ── Data ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  Match? _selectedMatch;
  List<Lineup> _lineups = [];

  // ── Game state ────────────────────────────────────────────────────────────
  final Set<String> _foundPlayers = {};
  final Set<String> _passedPlayers = {}; // revealed via "Passer" — no point
  int _errors = 0;
  int _score = 0;
  bool _showNumbersHint = false;
  bool _gameOver = false;

  static const int _maxErrors = 6;

  // ── Tabs ──────────────────────────────────────────────────────────────────
  late TabController _tabController;

  // ── Input ─────────────────────────────────────────────────────────────────
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  // ── Feedback ──────────────────────────────────────────────────────────────
  String? _feedbackText;
  Color _feedbackColor = AppColors.accentBright;
  Timer? _feedbackTimer;

  // ── Timing ────────────────────────────────────────────────────────────────
  late final DateTime _startTime;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _tabController = TabController(length: 2, vsync: this);
    _loadMatches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final matches = await loadMatches();
      final level = _difficultyToLevel(widget.difficulty);
      final filtered = matches.where((m) => m.level == level).toList();

      if (filtered.isEmpty) {
        _showFeedback('Aucun match pour cette difficulté', AppColors.red);
        setState(() => _isLoading = false);
        return;
      }

      final picked = (List<Match>.from(filtered)..shuffle()).first;
      setState(() => _selectedMatch = picked);
      await _loadLineups(picked.matchId);
    } on ApiException catch (e) {
      _showFeedback(e.userMessage, AppColors.red);
      setState(() => _isLoading = false);
    } catch (_) {
      _showFeedback('Erreur inattendue. Réessaie.', AppColors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLineups(String matchId) async {
    try {
      final all = await loadLineups(matchId);
      setState(() {
        _lineups = all.where((l) => l.matchId == matchId).toList();
        _foundPlayers.clear();
        _passedPlayers.clear();
        _errors = 0;
        _score = 0;
        _isLoading = false;
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
    _feedbackTimer = Timer(const Duration(milliseconds: 2000), () {
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
      final fullNorm = _norm(l.playerName);
      final lastNorm = _norm(_lastName(l.playerName));
      if (fullNorm == answer ||
          lastNorm == answer ||
          lastNorm.similarityTo(answer) >= 0.8) {
        exactMatches.add(l);
      } else if (lastNorm.similarityTo(answer) >= 0.4) {
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
        for (final p in newFound) _foundPlayers.add(p.playerName);
        _score += newFound.length;
      });
      final label = newFound.length > 1
          ? '${newFound.length} joueurs trouvés ! (+${newFound.length})'
          : '${_lastName(newFound.first.playerName)} ✓  (+1)';
      _showFeedback(label, AppColors.accentBright);
      _inputController.clear();
      _inputFocus.requestFocus();
      _checkVictory();
      return;
    }

    // Already found / passed
    if (alreadyFound.isNotEmpty) {
      HapticFeedback.lightImpact();
      _showFeedback('Déjà trouvé !', AppColors.amber);
      _inputController.clear();
      _inputFocus.requestFocus();
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
    setState(() => _errors++);
    _showFeedback(
      'Pas dans cette compo  (${_maxErrors - _errors} restante${_maxErrors - _errors > 1 ? 's' : ''})',
      AppColors.red,
    );
    _inputController.clear();
    _inputFocus.requestFocus();

    if (_errors >= _maxErrors) {
      Future.delayed(
        const Duration(milliseconds: 700),
        () => _endGame(defeat: true),
      );
    }
  }

  /// Ends the game early (player gives up).
  Future<void> _passPlayer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Terminer la partie ?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Les réponses manquantes seront révélées.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Continuer',
              style: TextStyle(color: AppColors.accentBright),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Terminer',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) _endGame(defeat: false);
  }

  void _checkVictory() {
    if (_foundPlayers.length + _passedPlayers.length == _lineups.length) {
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
      MaterialPageRoute(
        builder: (_) => LineupScorePage(
          match: _selectedMatch!,
          lineups: _lineups,
          foundPlayers: Set.from(_foundPlayers),
          passedPlayers: Set.from(_passedPlayers),
          score: _score,
          errors: _errors,
          timeTaken: timeTaken,
          defeat: defeat,
          difficulty: widget.difficulty,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int get _totalPlayers => _lineups.length;
  int get _revealedCount => _foundPlayers.length + _passedPlayers.length;

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
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accentBright),
              )
            : Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        _buildAppBar(),
                        _buildStatusBar(),
                        _buildTabBar(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: _buildTeamContent(
                            _selectedMatch?.homeTeam ?? '',
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: _buildTeamContent(
                            _selectedMatch?.awayTeam ?? '',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildInputBar(),
                ],
              ),
      ),
    );
  }

  // ── Widget builders ───────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedMatch?.matchName ?? 'Compos',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_selectedMatch?.competition ?? ''}  ·  ${_selectedMatch?.date ?? ''}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Score pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$_score pts',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Progress bar (found/total) + 6-segment error bar.
  Widget _buildStatusBar() {
    final pct = _totalPlayers == 0 ? 0.0 : _revealedCount / _totalPlayers;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress row
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.accentBright,
                    ),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_revealedCount / $_totalPlayers',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Error bar — 6 segments, red when used
          Row(
            children: [
              ...List.generate(_maxErrors, (i) {
                final used = i < _errors;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < _maxErrors - 1 ? 4 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: used ? AppColors.red : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 10),
              Text(
                _errors == 0
                    ? '0 erreur'
                    : '$_errors erreur${_errors > 1 ? 's' : ''}  ·  ${_maxErrors - _errors} restante${_maxErrors - _errors > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _errors >= 4 ? AppColors.red : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.card,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.accentBright,
        indicatorWeight: 2,
        labelColor: AppColors.accentBright,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
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
        const Text(
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
          itemBuilder: (_, i) => _PlayerCard(
            player: starters[i],
            isFound: _foundPlayers.contains(starters[i].playerName),
            isPassed: _passedPlayers.contains(starters[i].playerName),
            showNumber: _showNumbersHint,
          ),
        ),
        if (subs.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
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
              itemBuilder: (_, i) => SizedBox(
                width: 72,
                child: _PlayerCard(
                  player: subs[i],
                  isFound: _foundPlayers.contains(subs[i].playerName),
                  isPassed: _passedPlayers.contains(subs[i].playerName),
                  showNumber: _showNumbersHint,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Inline feedback
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _feedbackText != null
                  ? Padding(
                      key: ValueKey(_feedbackText),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _feedbackText!,
                        style: TextStyle(
                          color: _feedbackColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : const SizedBox(key: ValueKey('empty'), height: 0),
            ),

            // Input row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocus,
                    enabled: !_gameOver,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nom du joueur...',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.accentBright,
                          width: 1.5,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _checkPlayer(),
                  ),
                ),
                const SizedBox(width: 8),

                // Validate
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBright,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _gameOver ? null : _checkPlayer,
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),

                // Hint (numbers, -3 pts)
                GestureDetector(
                  onTap: _showNumbersHint || _gameOver ? null : _askNumbersHint,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _showNumbersHint ? AppColors.border : AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: _showNumbersHint
                          ? AppColors.textSecondary
                          : AppColors.amber,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Passer
                GestureDetector(
                  onTap: _gameOver ? null : _passPlayer,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.skip_next_rounded,
                      size: 20,
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

  Future<void> _askNumbersHint() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Afficher les numéros ?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Les numéros de tous les joueurs seront révélés.\nCoûte 3 points.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Afficher  (-3 pts)'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() {
        _showNumbersHint = true;
        _score -= 3;
      });
      _showFeedback('Numéros affichés  (-3 pts)', AppColors.amber);
    }
  }

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
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Continuer',
                  style: TextStyle(color: AppColors.accentBright),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
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

// ─────────────────────────────────────────────────────────────────────────────
// _PlayerCard
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final Lineup player;
  final bool isFound;
  final bool isPassed; // revealed via "Passer" — shown in amber
  final bool showNumber;

  const _PlayerCard({
    required this.player,
    required this.isFound,
    required this.isPassed,
    required this.showNumber,
  });

  String get _displayName => player.playerName.trim().split(' ').last;

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

    return AnimatedContainer(
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
              Image.asset(
                'assets/images/shirt.png',
                width: 30,
                height: 30,
                color: _shirtColor,
              ),
              if ((revealed || showNumber) && player.playerNumber > 0)
                Positioned(
                  top: 9,
                  child: Text(
                    '${player.playerNumber}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            revealed ? _displayName : player.position,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: revealed ? FontWeight.w700 : FontWeight.w500,
              color: _nameColor,
            ),
          ),
        ],
      ),
    );
  }
}
