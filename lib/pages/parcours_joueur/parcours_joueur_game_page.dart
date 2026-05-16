// parcours_joueur_game_page.dart
//
// "Parcours Joueur" game (v0.4.0 test version).
//
// Flow (Coup d'Œil style):
//   1. initState → fetch players, pick 5 random ones with a career.
//   2. Per player: the full career is shown (oldest → recent), name hidden.
//      The player types one guess. Wrong → next player. 3 hints unlockable
//      (nationalité / âge / poste), each costs 2 pts.
//   3. Scoring: +10 per player found, −2 per hint, floored at 0 per player
//      (never negative). Max = 50.
//   4. After 5 players → minimal end card (score recap page comes later).
//
// Answer matching: accents ignored + last-name-only accepted, fuzzy ≥ 0.8,
// compared to the single target player's name.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:diacritic/diacritic.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../constants/app_colors.dart';
import '../../data/api_exception.dart';
import '../../data/parcours_joueur_api.dart';
import '../../models/parcours_joueur.dart';

class ParcoursJoueurGamePage extends StatefulWidget {
  const ParcoursJoueurGamePage({super.key});

  @override
  State<ParcoursJoueurGamePage> createState() => _ParcoursJoueurGamePageState();
}

class _ParcoursJoueurGamePageState extends State<ParcoursJoueurGamePage> {
  static const int _playersPerGame = 5;
  static const int _pointsPerPlayer = 10;
  static const int _hintCost = 2;

  // ── State ──────────────────────────────────────────────────────────────────
  List<ParcoursPlayer> _all = [];
  List<ParcoursPlayer> _selected = [];
  int _current = 0;
  int _score = 0;
  int _foundCount = 0;

  /// Hints revealed for the CURRENT player: 'nat' | 'age' | 'pos'.
  final Set<String> _hintsUsed = {};

  /// True once the current player has been answered/skipped (locks input).
  bool _answered = false;

  bool _isLoading = true;
  String? _error;
  bool _finished = false;

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
      final players = await ParcoursJoueurApi.fetchPlayers();
      // Only keep players that actually have a career to display.
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
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erreur inattendue. Réessaie.';
      });
    }
  }

  void _startGame() {
    final pool = List<ParcoursPlayer>.from(_all)..shuffle();
    setState(() {
      _selected = pool.take(_playersPerGame).toList();
      _current = 0;
      _score = 0;
      _foundCount = 0;
      _hintsUsed.clear();
      _answered = false;
      _feedbackVisible = false;
      _finished = false;
      _isLoading = false;
      _controller.clear();
    });
  }

  // ── Answer matching ────────────────────────────────────────────────────────

  String _norm(String s) =>
      removeDiacritics(s.toLowerCase()).replaceAll('.', '').trim();

  String _lastName(String full) => full.trim().split(' ').last;

  bool _matches(String guess, String name) {
    final g = _norm(guess);
    if (g.isEmpty) return false;
    final full = _norm(name);
    final last = _norm(_lastName(name));
    if (g == full || g == last) return true;
    if (g.similarityTo(full) >= 0.8) return true;
    if (g.similarityTo(last) >= 0.8) return true;
    return false;
  }

  // ── Game actions ───────────────────────────────────────────────────────────

  ParcoursPlayer get _player => _selected[_current];

  void _submit() {
    if (_answered) return;
    final guess = _controller.text.trim();
    if (guess.isEmpty) return;

    final correct = _matches(guess, _player.name);
    if (correct) {
      final pts = (_pointsPerPlayer - _hintCost * _hintsUsed.length)
          .clamp(0, _pointsPerPlayer);
      HapticFeedback.mediumImpact();
      setState(() {
        _score += pts;
        _foundCount++;
        _answered = true;
      });
      _showFeedback(
        '✅ Bravo ! ${_player.name} (+$pts pts)',
        AppColors.accentBright,
      );
    } else {
      setState(() => _answered = true);
      _showFeedback(
        '❌ Raté ! C\'était ${_player.name}',
        AppColors.red,
      );
    }
    Future.delayed(const Duration(milliseconds: 1400), _next);
  }

  void _skip() {
    if (_answered) return;
    setState(() => _answered = true);
    _showFeedback('⏩ Passé — c\'était ${_player.name}', AppColors.textSecondary);
    Future.delayed(const Duration(milliseconds: 1200), _next);
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
      setState(() => _finished = true);
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
        if (_finished) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
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
        child: CircularProgressIndicator(color: AppColors.accentBright),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  color: AppColors.textSecondary, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBright,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _load,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (_finished) return _buildEndCard();
    return _buildGame();
  }

  // ── End card (minimal — full results page comes later) ─────────────────────

  Widget _buildEndCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏁', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              'Partie terminée',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$_score',
              style: TextStyle(
                color: AppColors.accentBright,
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            Text(
              'points  ·  $_foundCount/${_selected.length} trouvés',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Accueil',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBright,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _startGame,
                    child: const Text('Rejouer ↺',
                        style:
                            TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
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
        Expanded(child: _buildCareer()),
        if (_feedbackVisible) _buildFeedback(),
        if (!keyboardOpen) _buildHints(),
        _buildInput(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final leave = await _confirmQuit();
              if (leave && mounted) Navigator.of(context).pop();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child:
                  Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_current + 1) / _selected.length,
                backgroundColor: AppColors.border,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.accentBright),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_current + 1}/${_selected.length}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$_score pts',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareer() {
    final clubs = _player.clubs;
    final nat = _player.nationalTeam;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUEL EST CE JOUEUR ?',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < clubs.length; i++)
                  _careerRow(clubs[i], last: i == clubs.length - 1 && nat.isEmpty),
                if (nat.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      border: Border(
                        top: BorderSide(color: AppColors.border),
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Text(
                      'SÉLECTION NATIONALE',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  for (int i = 0; i < nat.length; i++)
                    _careerRow(nat[i], last: i == nat.length - 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _careerRow(CareerEntry e, {required bool last}) {
    final stats = (e.matches == null && e.goals == null)
        ? ''
        : '${e.matches ?? '–'} (${e.goals ?? '–'})';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              e.years,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (e.loan)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.arrow_forward,
                        size: 13, color: AppColors.textSecondary),
                  ),
                Flexible(
                  child: Text(
                    e.team,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (stats.isNotEmpty)
            Text(
              stats,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHints() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _hintChip('nat', 'Nationalité', _player.nationality),
          const SizedBox(width: 8),
          _hintChip('age', 'Âge', _player.age?.toString() ?? '?'),
          const SizedBox(width: 8),
          _hintChip('pos', 'Poste', _player.position),
        ],
      ),
    );
  }

  Widget _hintChip(String type, String label, String value) {
    final used = _hintsUsed.contains(type);
    return Expanded(
      child: GestureDetector(
        onTap: used || _answered ? null : () => _useHint(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: used
                ? AppColors.accentBright.withValues(alpha: 0.10)
                : AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: used ? AppColors.accentBright : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: used
                      ? AppColors.accentBright
                      : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                used ? (value.isEmpty ? '—' : value) : '−$_hintCost pts',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: used
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: _feedbackColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _feedbackColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        _feedback,
        style: TextStyle(
          color: _feedbackColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _answered ? null : _skip,
              child:
                  const Text('Passer', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: !_answered,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Nom du joueur...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  borderSide:
                      BorderSide(color: AppColors.accentBright, width: 2),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBright,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.border,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _answered ? null : _submit,
            child: const Text('OK',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
