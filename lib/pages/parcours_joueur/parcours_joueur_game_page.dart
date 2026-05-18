// parcours_joueur_game_page.dart
//
// "Parcours Joueur" game (v0.4.0 test version).
//
// Flow (Coup d'Œil style): 5 random players, full career shown (oldest →
// recent, name hidden), one guess each, wrong → next. 3 unlockable hints
// (nationalité / âge / poste), −2 pts each. +10 per player found, floored
// at 0 per player (never negative). Max = 50.
//
// Answer matching: accents ignored + last-name-only accepted, fuzzy ≥ 0.8,
// compared to the single target player's name.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:diacritic/diacritic.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../constants/app_colors.dart';
import '../../data/api_exception.dart';
import '../../data/difficulty_plans.dart';
import '../../data/parcours_joueur_api.dart';
import '../../models/parcours_joueur.dart';
import '../../models/parcours_result.dart';
import '../../services/theme_service.dart';
import 'club_logo.dart';
import 'parcours_joueur_score_page.dart';
import 'package:quiz_foot/utils/navigation.dart';

enum _MatchResult { correct, almost, wrong }

class ParcoursJoueurGamePage extends StatefulWidget {
  /// One of the keys in [kParcoursDifficultyPlans].
  final String difficulty;

  const ParcoursJoueurGamePage({super.key, this.difficulty = 'Pro'});

  @override
  State<ParcoursJoueurGamePage> createState() => _ParcoursJoueurGamePageState();
}

class _ParcoursJoueurGamePageState extends State<ParcoursJoueurGamePage> {
  static const int _pointsPerPlayer = 10;
  static const int _hintCost = 2;

  // ── State ──────────────────────────────────────────────────────────────────
  List<ParcoursPlayer> _all = [];
  List<ParcoursPlayer> _selected = [];
  final List<ParcoursResult> _results = [];
  int _current = 0;
  int _score = 0;

  /// Hints revealed for the CURRENT player: 'nat' | 'age' | 'pos'.
  final Set<String> _hintsUsed = {};

  bool _answered = false;
  bool _lastCorrect = false;

  bool _isLoading = true;
  String? _error;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  // Feedback banner
  String _feedback = '';
  Color _feedbackColor = AppColors.accentBright;
  bool _feedbackVisible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ClubLogoIndex.instance.ensureLoaded();
      final players = await ParcoursJoueurApi.fetchPlayers();
      final valid = players.where((p) => p.clubs.isNotEmpty).toList();
      if (valid.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Aucun joueur disponible pour le moment.';
        });
        return;
      }
      _all = valid;
      _startGame();
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.userMessage;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = 'Erreur inattendue. Réessaie.';
      });
    }
  }

  /// Picks a random player at [level]; if none, climbs one level up
  /// (Coup d'Œil behaviour). Absolute fallback: the median player.
  ParcoursPlayer _pick(List<ParcoursPlayer> pool, int level) {
    final matching = pool.where((p) => p.level == level).toList();
    if (matching.isEmpty) {
      final maxLevel = pool
          .map((p) => p.level ?? 0)
          .fold<int>(0, (a, b) => a > b ? a : b);
      if (level < maxLevel) return _pick(pool, level + 1);
      return pool[(pool.length * 0.5).toInt()];
    }
    matching.shuffle();
    return matching.first;
  }

  void _startGame() {
    final plan = kParcoursDifficultyPlans[widget.difficulty] ?? const [];
    final needed = plan.fold<int>(
      0,
      (s, step) => s + step.values.fold<int>(0, (a, b) => a + b),
    );

    // Not enough players at all → error (Coup d'Œil-style guard).
    if (_all.length < needed) {
      setState(() {
        _isLoading = false;
        _error =
            'Pas assez de joueurs pour la difficulté ${widget.difficulty}.';
      });
      return;
    }

    final remaining = List<ParcoursPlayer>.from(_all);
    final selected = <ParcoursPlayer>[];
    for (final step in plan) {
      step.forEach((level, count) {
        for (int i = 0; i < count; i++) {
          final p = _pick(remaining, level);
          selected.add(p);
          remaining.remove(p);
        }
      });
    }
    // Always shown easiest → hardest.
    selected.sort(
      (a, b) => (a.level ?? 999).compareTo(b.level ?? 999),
    );

    setState(() {
      _selected = selected;
      _results.clear();
      _current = 0;
      _score = 0;
      _hintsUsed.clear();
      _answered = false;
      _feedbackVisible = false;
      _isLoading = false;
      _controller.clear();
    });
  }

  // ── Answer matching ────────────────────────────────────────────────────────

  String _norm(String s) =>
      removeDiacritics(s.toLowerCase())
          .replaceAll(RegExp(r"[.'’‘`]"), '')
          .trim();

/// Returns all accepted name variants for the current player:
  /// full name + every trailing word combination.
  /// e.g. "Alessandro Del Piero" → ["Alessandro Del Piero", "Del Piero", "Piero"]
  List<String> _candidates() {
    final words = _player.name.trim().split(' ');
    return [
      for (int i = 0; i < words.length; i++)
        _norm(words.sublist(i).join(' ')),
    ];
  }

  /// correct  → similarity > 0.8  (same threshold as Compos & Coup d'Œil)
  /// almost   → similarity > 0.5  (same as Compos)
  /// wrong    → otherwise
  _MatchResult _evaluate(String guess) {
    final g = _norm(guess);
    if (g.isEmpty) return _MatchResult.wrong;
    final candidates = _candidates();
    if (candidates.contains(g)) return _MatchResult.correct;
    final best = candidates
        .map((c) => g.similarityTo(c))
        .reduce((a, b) => a > b ? a : b);
    if (best > 0.8) return _MatchResult.correct;
    if (best > 0.5) return _MatchResult.almost;
    return _MatchResult.wrong;
  }

  // ── Game actions ───────────────────────────────────────────────────────────

  ParcoursPlayer get _player => _selected[_current];

  void _submit() {
    if (_answered) return;
    final guess = _controller.text.trim();
    if (guess.isEmpty) return;

    final result = _evaluate(guess);

    if (result == _MatchResult.almost) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 60), HapticFeedback.heavyImpact);
      _showFeedback('Presque...', AppColors.amber);
      return;
    }

    final correct = result == _MatchResult.correct;
    if (correct) {
      final pts = (_pointsPerPlayer - _hintCost * _hintsUsed.length)
          .clamp(0, _pointsPerPlayer);
      HapticFeedback.mediumImpact();
      setState(() {
        _score += pts;
        _answered = true;
        _lastCorrect = true;
      });
      _showFeedback('Bravo ! ${_player.name}  ·  +$pts pts',
          AppColors.accentBright);
      _results.add(ParcoursResult(
        playerName: _player.name,
        found: true,
        attempted: true,
        points: pts,
        hintsUsed: _hintsUsed.length,
      ));
    } else {
      setState(() {
        _answered = true;
        _lastCorrect = false;
      });
      _showFeedback('Raté — c\'était ${_player.name}', AppColors.red);
      _results.add(ParcoursResult(
        playerName: _player.name,
        found: false,
        attempted: true,
        points: 0,
        hintsUsed: _hintsUsed.length,
      ));
    }
    Future.delayed(const Duration(milliseconds: 1500), _next);
  }

  void _skip() {
    if (_answered) return;
    setState(() {
      _answered = true;
      _lastCorrect = false;
    });
    _showFeedback('Passé — c\'était ${_player.name}', AppColors.textSecondary);
    _results.add(ParcoursResult(
      playerName: _player.name,
      found: false,
      attempted: false,
      points: 0,
      hintsUsed: _hintsUsed.length,
    ));
    Future.delayed(const Duration(milliseconds: 1300), _next);
  }

  void _useHint(String type) {
    if (_answered || _hintsUsed.contains(type)) return;
    HapticFeedback.selectionClick();
    setState(() => _hintsUsed.add(type));
  }

  void _next() {
    if (!mounted) return;
    if (_current < _selected.length - 1) {
      setState(() {
        _current++;
        _hintsUsed.clear();
        _answered = false;
        _feedbackVisible = false;
        _controller.clear();
      });
    } else {
      Navigator.pushReplacement(
        context,
        namedRoute(ParcoursJoueurScorePage(
          score: _score,
          total: _selected.length,
          results: List.unmodifiable(_results),
          difficulty: widget.difficulty,
        )),
      );
    }
  }

  void _showFeedback(String msg, Color color) {
    setState(() {
      _feedback = msg;
      _feedbackColor = color;
      _feedbackVisible = true;
    });
  }

  Future<bool> _confirmQuit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text('Quitter la partie ?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Ta progression sera perdue.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Continuer',
                style: TextStyle(color: AppColors.accentBright)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Quitter', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmQuit();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.accentBright));
    }
    if (_error != null) return _buildError();
    return _buildGame();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBright,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _load,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Game screen ────────────────────────────────────────────────────────────

  Widget _buildGame() {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: SingleChildScrollView(
              key: ValueKey(_current),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMysteryHero(),
                  const SizedBox(height: 14),
                  _buildCareerCard(),
                ],
              ),
            ),
          ),
        ),
        if (_feedbackVisible) _buildFeedback(),
        if (!keyboardOpen) _buildHints(),
        _buildInput(),
      ],
    );
  }

  Widget _buildHeader() {
    final progress = (_current + 1) / _selected.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          // Back button — borderless, juste l'icône
          GestureDetector(
            onTap: () async {
              final leave = await _confirmQuit();
              if (leave && mounted) Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textSecondary, size: 18),
            ),
          ),
          // Barre de progression épaisse + animée
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: progress - 1 / _selected.length, end: progress),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (_, val, __) => LinearProgressIndicator(
                      value: val,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBright),
                      minHeight: 7,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Joueur ${_current + 1} sur ${_selected.length}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Score pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentBright.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$_score pts',
                style: TextStyle(
                    color: AppColors.accentBright,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildMysteryHero() {
    final dark = ThemeService.instance.isDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: dark
              ? [const Color(0xFF1A2E22), const Color(0xFF111518)]
              : [const Color(0xFFDFF0E4), const Color(0xFFF0F4F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          // Numéro du joueur en fond — discret
          Positioned(
            right: -8,
            top: -12,
            child: Text(
              '0${_current + 1}',
              style: TextStyle(
                fontSize: 88,
                fontWeight: FontWeight.w900,
                color: AppColors.accentBright.withValues(alpha: dark ? 0.06 : 0.07),
                height: 1,
                letterSpacing: -4,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label "Joueur mystère"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentBright.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'JOUEUR MYSTÈRE',
                  style: TextStyle(
                    color: AppColors.accentBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Qui suis-je ?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Retrouve le joueur grâce à son parcours',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCareerCard() {
    final clubs = _player.clubs;
    final nat = _player.nationalTeam;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('EN CLUB', Icons.sports_soccer, top: true),
          for (int i = 0; i < clubs.length; i++)
            _careerRow(clubs[i], last: i == clubs.length - 1 && nat.isEmpty),
          if (nat.isNotEmpty) ...[
            _sectionHeader('SÉLECTION', Icons.public),
            for (int i = 0; i < nat.length; i++)
              _careerRow(nat[i], last: i == nat.length - 1, isNat: true),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, IconData icon, {bool top = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: top
            ? const BorderRadius.vertical(top: Radius.circular(17))
            : BorderRadius.zero,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              )),
        ],
      ),
    );
  }

  Widget _careerRow(CareerEntry e, {required bool last, bool isNat = false}) {
    final hasStats = e.matches != null || e.goals != null;
    final statsStr = hasStats
        ? '${e.matches ?? '—'} · ${e.goals ?? '—'}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isNat
            ? AppColors.accentBright.withValues(alpha: 0.03)
            : Colors.transparent,
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        borderRadius: last
            ? const BorderRadius.vertical(bottom: Radius.circular(17))
            : BorderRadius.zero,
      ),
      child: Row(
        children: [
          isNat
              ? NatFlag(teamName: e.team, size: 32)
              : ClubLogo(clubName: e.team, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(e.team,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                    if (e.loan) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('PRÊT',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            )),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(e.years,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
          if (hasStats)
            Text(statsStr,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                )),
        ],
      ),
    );
  }

  // ── Hints ──────────────────────────────────────────────────────────────────

  Widget _buildHints() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _hintChip('nat', Icons.public_rounded, 'Nationalité', _player.nationality),
          const SizedBox(width: 8),
          _hintChip('age', Icons.cake_outlined, 'Âge', _player.age != null ? '${_player.age} ans' : '?'),
          const SizedBox(width: 8),
          _hintChip('pos', Icons.sports_soccer, 'Poste', _player.position),
        ],
      ),
    );
  }

  Widget _hintChip(String type, IconData icon, String label, String value) {
    final used = _hintsUsed.contains(type);
    return Expanded(
      child: GestureDetector(
        onTap: (_answered || used) ? null : () => _useHint(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: used
                ? AppColors.accentBright.withValues(alpha: 0.1)
                : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: used
                  ? AppColors.accentBright.withValues(alpha: 0.5)
                  : AppColors.border,
              width: used ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: used
                    ? Icon(icon, size: 16, color: AppColors.accentBright, key: const ValueKey('icon_on'))
                    : Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textSecondary, key: const ValueKey('icon_off')),
              ),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(
                    color: used ? AppColors.accentBright : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  )),
              const SizedBox(height: 3),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                child: Text(
                  used ? (value.trim().isEmpty ? '—' : value) : '−$_hintCost pts',
                  key: ValueKey(used),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: used ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: used ? 12 : 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    final isAlmost = _feedbackColor == AppColors.amber;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        key: ValueKey(_feedback),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: _feedbackColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _feedbackColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              _lastCorrect
                  ? Icons.check_circle_rounded
                  : (isAlmost ? Icons.adjust_rounded : Icons.cancel_rounded),
              color: _feedbackColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_feedback,
                  style: TextStyle(
                    color: _feedbackColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // "Passer" — lien discret aligné à droite
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _answered ? null : _skip,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Passer →',
                  style: TextStyle(
                    color: _answered
                        ? AppColors.border
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // Champ + bouton OK
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: !_answered,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nom du joueur…',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.card,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: AppColors.accentBright, width: 2),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _answered ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: _answered
                        ? AppColors.border
                        : AppColors.accentBright,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text('OK',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
