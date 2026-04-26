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
import 'formation_layout.dart';
import 'lineup_score_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _parseTeamColor(String? name) {
  switch (name?.toLowerCase().trim()) {
    case 'blanc':
      return const Color(0xFFF0F0F0);
    case 'noir':
      return const Color.fromARGB(255, 0, 0, 0);
    case 'rouge':
      return const Color(0xFFDC2626);
    case 'bleu':
      return const Color(0xFF1D4ED8);
    case 'bleu clair':
      return const Color(0xFF60A5FA);
    case 'bleu foncé':
      return const Color.fromARGB(255, 12, 3, 77);
    case 'vert':
      return const Color(0xFF16A34A);
    case 'jaune':
      return const Color(0xFFFACC15);
    case 'orange':
      return const Color.fromARGB(255, 225, 104, 6);
    case 'violet':
      return const Color.fromARGB(255, 121, 12, 200);
    default:
      return const Color(0xFF4A5568);
  }
}

// Returns null if no second color → flat circle
Color? _parseTeamColor2(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  return _parseTeamColor(name);
}

Color _labelColor(Color bg) =>
    bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

int _difficultyToLevel(String difficulty) {
  switch (difficulty) {
    case 'Amateur':
      return 1;
    case 'Semi-Pro':
      return 2;
    case 'Pro':
      return 3;
    case 'International':
      return 4;
    case 'Légende':
      return 5;
    default:
      return 3;
  }
}

String? _leagueFolder(String competition) {
  final c = competition.toLowerCase();
  if (c.contains('euro') ||
      c.contains('coupe du monde') ||
      c.contains('world cup') ||
      c.contains('ligue des nations') ||
      c.contains('copa') ||
      c.contains('barrage coupe du monde'))
    return 'pays';
  if (c.contains('champions league') || c.contains('ligue des champions'))
    return 'Champions League';
  if (c.contains('ligue 1') ||
      c.contains('coupe de france') ||
      c.contains('coupe de la ligue'))
    return 'France - Ligue 1';
  if (c.contains('premier league') ||
      c.contains('community shield') ||
      c.contains('fa cup'))
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

Widget _teamLogoSmall(
  String name,
  String colorName,
  String? folder, {
  double size = 28,
}) {
  final bg = _parseTeamColor(colorName);
  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
  final fallback = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: bg,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF2D3148), width: 1.5),
    ),
    child: Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          color: bg.computeLuminance() < 0.4 ? Colors.white : Colors.black87,
        ),
      ),
    ),
  );
  if (folder == null) return fallback;
  final fileName = folder == 'pays'
      ? removeDiacritics(name.toLowerCase())
      : name;
  return Image.asset(
    'assets/logos/$folder/$fileName.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => fallback,
  );
}

Widget _competitionLogoSmall(String competition) {
  final img = Image.asset(
    'assets/logos/competitions/$competition.png',
    width: 36,
    height: 36,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
  );
  if (_coloredCompLogos.contains(competition)) return img;
  return ColorFiltered(
    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    child: img,
  );
}

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

      List<Match> filtered;

      final level = _difficultyToLevel(widget.difficulty);
      filtered = matches.where((m) {
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
        _hints.clear();
        _wrongAnswers.clear();
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
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
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
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            Text(
              'Équipe : ${player.teamName}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              canHint
                  ? '$remaining indice${remaining > 1 ? 's' : ''} restant${remaining > 1 ? 's' : ''}'
                  : 'Tu as utilisé tes $_maxFreeHints indices.',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          if (canHint) ...[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('letter'),
              child: const Text(
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
                child: const Text(
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

  // ── Computed ──────────────────────────────────────────────────────────────

  int get _totalPlayers => _lineups.length;
  int get _revealedCount => _foundPlayers.length + _passedPlayers.length;

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
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentBright,
                  ),
                )
              : Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          _buildAppBar(),
                          _buildStatusBar(),
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
                ),
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    final match = _selectedMatch;
    final folder = match != null ? _leagueFolder(match.competition) : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
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
                    child: const Icon(
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
                    _competitionLogoSmall(match.competition),
                    const SizedBox(width: 6),
                    Text(
                      '${match.competition}  ·  ${match.date}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Ligne 2 : logo home + titre centré + logo away
          Row(
            children: [
              if (match != null)
                _teamLogoSmall(
                  match.homeTeam,
                  match.colorHome,
                  folder,
                  size: 48,
                )
              else
                const SizedBox(width: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  match?.matchName ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
                _teamLogoSmall(
                  match.awayTeam,
                  match.colorAway,
                  folder,
                  size: 48,
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

  Widget _buildStatusBar() {
    final pct = _totalPlayers == 0 ? 0.0 : _revealedCount / _totalPlayers;
    final errorColor = _errors >= 4 ? AppColors.red : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: AppColors.card,
      child: Row(
        children: [
          Text(
            '$_revealedCount/$_totalPlayers',
            style: const TextStyle(
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
                valueColor: const AlwaysStoppedAnimation(
                  AppColors.accentBright,
                ),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _errors > 0 ? _showWrongAnswers : null,
            child: Row(
              children: List.generate(
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
          itemBuilder: (_, i) {
            final p = starters[i];
            return _PlayerCard(
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
              itemBuilder: (_, i) {
                final p = subs[i];
                return SizedBox(
                  width: 72,
                  child: _PlayerCard(
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
                  CustomPaint(size: size, painter: _PitchPainter()),

                  // ── Team labels — left side, near each GK zone ──
                  Positioned(
                    left: 16,
                    top: size.height * 0.06,
                    child: Text(
                      match.awayTeam.toUpperCase(),
                      style: const TextStyle(
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
                      style: const TextStyle(
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
    final double availableY = size.height * 0.40;
    final double spacePerLine = totalLines > 1
        ? availableY / (totalLines - 1)
        : availableY;
    final double chipRadius = (spacePerLine * 0.38).clamp(12.0, 18.0);
    final Color teamColor = isHomeTeam
        ? _parseTeamColor(match.colorHome)
        : _parseTeamColor(match.colorAway);
    final Color? teamColor2 = isHomeTeam
        ? _parseTeamColor2(match.colorHome2)
        : _parseTeamColor2(match.colorAway2);

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
            child: _PitchChip(
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
      decoration: const BoxDecoration(
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
              _parseTeamColor(match.colorHome),
              _parseTeamColor2(match.colorHome2),
            ),
          ),
          Container(width: 1, height: 60, color: AppColors.border),
          Expanded(
            child: _buildBenchTeam(
              match.awayTeam,
              awaySubs,
              _parseTeamColor(match.colorAway),
              _parseTeamColor2(match.colorAway2),
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
            style: const TextStyle(
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
              return _SubChip(
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
                    style: const TextStyle(
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
          border: const Border(top: BorderSide(color: AppColors.border)),
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
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nom de joueur...',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                      prefixIcon: const Icon(
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
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.accentBright,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
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
                  child: const Text(
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
                    child: const Icon(
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

  void _showWrongAnswers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        decoration: const BoxDecoration(
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
              const Text(
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
                      const Icon(Icons.close, color: AppColors.red, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        w,
                        style: const TextStyle(
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

// ─────────────────────────────────────────────────────────────────────────────
// _PitchPainter
// ─────────────────────────────────────────────────────────────────────────────

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base green
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF1A5C2A),
    );

    // Alternating stripes
    const stripeColor = Color(0xFF1E6830);
    const stripes = 8;
    final stripeH = h / stripes;
    for (int i = 0; i < stripes; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeH, w, stripeH),
        Paint()..color = stripeColor,
      );
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const p = 10.0; // pitch padding

    // Outer border
    canvas.drawRect(Rect.fromLTRB(p, p, w - p, h - p), line);

    // Center line
    canvas.drawLine(Offset(p, h / 2), Offset(w - p, h / 2), line);

    // Center circle
    canvas.drawCircle(Offset(w / 2, h / 2), h * 0.09, line);

    // Center dot
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // Penalty areas
    final penW = w * 0.55;
    final penH = h * 0.13;
    final penLeft = (w - penW) / 2;

    // Top (away goal)
    canvas.drawRect(Rect.fromLTRB(penLeft, p, penLeft + penW, p + penH), line);
    // Bottom (home goal)
    canvas.drawRect(
      Rect.fromLTRB(penLeft, h - p - penH, penLeft + penW, h - p),
      line,
    );

    // Goal areas
    final goalW = w * 0.28;
    final goalH = h * 0.05;
    final goalLeft = (w - goalW) / 2;

    canvas.drawRect(
      Rect.fromLTRB(goalLeft, p, goalLeft + goalW, p + goalH),
      line,
    );
    canvas.drawRect(
      Rect.fromLTRB(goalLeft, h - p - goalH, goalLeft + goalW, h - p),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// _PitchChip  —  player chip on the pitch
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
    required this.player,
    required this.isFound,
    required this.isPassed,
    required this.chipRadius,
    required this.teamColor,
    this.teamColor2,
    this.hintContent,
    this.onTap,
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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
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
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
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
  void dispose() {
    _ctrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  String get _shortName {
    if (widget.player == null) return '';
    return widget.player!.playerName.trim();
  }

  @override
  Widget build(BuildContext context) {
    final revealed = widget.isFound || widget.isPassed;
    final d = widget.chipRadius * 2;

    String label;
    if (revealed) {
      label = widget.player!.playerNumber > 0
          ? '${widget.player!.playerNumber}'
          : '✓';
    } else if (widget.hintContent != null) {
      label = widget.hintContent!;
    } else {
      label = '?';
    }

    final numFontSize = d < 28 ? 8.0 : 10.0;

    // Not found → empty circle (transparent + white border)
    // Passed    → amber fill
    // Found     → team colors
    final Color c1 = widget.isPassed ? AppColors.amber : widget.teamColor;
    final Color c2 = widget.isPassed
        ? AppColors.amber
        : (widget.teamColor2 ?? widget.teamColor);

    final bool filled = revealed; // only fill when found/passed

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.player == null || revealed ? null : widget.onTap,
      child: SizedBox(
        width: d + 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: d,
              height: d,
              child: AnimatedBuilder(
                animation: Listenable.merge([_ctrl, _rippleCtrl]),
                builder: (_, __) => Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(d, d),
                      painter: _RipplePainter(
                        progress: _rippleAnim.value,
                        chipRadius: d / 2,
                        color: c1,
                      ),
                    ),
                    Transform.scale(
                      scale: _scale.value,
                      child: Container(
                        width: d,
                        height: d,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: filled
                              ? LinearGradient(
                                  colors: [c1, c1, c2, c2],
                                  stops: const [0.0, 0.5, 0.5, 1.0],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                          color: filled ? null : Colors.white.withOpacity(0.10),
                          border: Border.all(
                            color: Colors.white,
                            width: filled ? 1.5 : 1.2,
                          ),
                          boxShadow: [
                            const BoxShadow(
                              color: Color(0x55000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                            BoxShadow(
                              color: c1.withOpacity(_glow.value * 0.8),
                              blurRadius: _glow.value * 24,
                              spreadRadius: _glow.value * 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: filled && c1 == c2 ? _labelColor(c1) : Colors.white,
                              fontSize: numFontSize,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              shadows: filled && c1 != c2
                                  ? const [
                                      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(-1, -1)),
                                      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, -1)),
                                      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(-1, 1)),
                                      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
                                    ]
                                  : const [Shadow(color: Colors.black54, blurRadius: 3)],
                            ),
                          ),
                        ),
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
                  _shortName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isFound
                        ? const Color.fromARGB(255, 181, 237, 187)
                        : AppColors.amber,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
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
// _SubChip  —  compact chip for bench players
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
    required this.player,
    required this.isFound,
    required this.isPassed,
    required this.teamColor,
    this.teamColor2,
    this.hintContent,
    this.onTap,
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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
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
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
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
  void dispose() {
    _ctrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  String get _shortName => widget.player.playerName.trim();

  @override
  Widget build(BuildContext context) {
    final revealed = widget.isFound || widget.isPassed;

    final String label;
    if (revealed) {
      label = widget.player.playerNumber > 0
          ? '${widget.player.playerNumber}'
          : '✓';
    } else if (widget.hintContent != null) {
      label = widget.hintContent!;
    } else {
      label = '?';
    }

    const double d = 32;

    final Color c1 = widget.isPassed ? AppColors.amber : widget.teamColor;
    final Color c2 = widget.isPassed
        ? AppColors.amber
        : (widget.teamColor2 ?? widget.teamColor);
    final bool filled = revealed;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: revealed ? null : widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: d,
            height: d,
            child: AnimatedBuilder(
              animation: Listenable.merge([_ctrl, _rippleCtrl]),
              builder: (_, __) => Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(d, d),
                    painter: _RipplePainter(
                      progress: _rippleAnim.value,
                      chipRadius: d / 2,
                      color: c1,
                    ),
                  ),
                  Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: d,
                      height: d,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: filled
                            ? LinearGradient(
                                colors: [c1, c1, c2, c2],
                                stops: const [0.0, 0.5, 0.5, 1.0],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: filled ? null : Colors.white.withOpacity(0.10),
                        border: Border.all(
                          color: Colors.white,
                          width: filled ? 1.5 : 1.2,
                        ),
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                          BoxShadow(
                            color: c1.withOpacity(_glow.value * 0.8),
                            blurRadius: _glow.value * 24,
                            spreadRadius: _glow.value * 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: filled && c1 == c2 ? _labelColor(c1) : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            shadows: filled && c1 != c2
                                ? const [
                                    Shadow(color: Colors.black, blurRadius: 2, offset: Offset(-1, -1)),
                                    Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, -1)),
                                    Shadow(color: Colors.black, blurRadius: 2, offset: Offset(-1, 1)),
                                    Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
                                  ]
                                : const [Shadow(color: Colors.black54, blurRadius: 3)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (revealed) ...[
            const SizedBox(height: 2),
            SizedBox(
              width: 72,
              child: Text(
                _shortName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.isFound
                      ? AppColors.accentBright
                      : AppColors.amber,
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PlayerCard  —  card for fallback list view
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final Lineup player;
  final bool isFound;
  final bool isPassed;
  final String? hintContent;
  final VoidCallback? onTap;

  const _PlayerCard({
    required this.player,
    required this.isFound,
    required this.isPassed,
    this.hintContent,
    this.onTap,
  });

  String get _displayName => player.playerName.trim();
  String get _hiddenLabel => hintContent ?? player.position;

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
                Image.asset(
                  'assets/images/shirt.png',
                  width: 30,
                  height: 30,
                  color: _shirtColor,
                ),
                if (revealed && player.playerNumber > 0)
                  Positioned(
                    top: 9,
                    child: Text(
                      '${player.playerNumber}',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: _labelColor(_shirtColor),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              revealed ? _displayName : _hiddenLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: revealed ? FontWeight.w700 : FontWeight.w500,
                color: hintContent != null && !revealed
                    ? AppColors.accentBright
                    : _nameColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RipplePainter
// ─────────────────────────────────────────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  final double progress;
  final double chipRadius;
  final Color color;

  const _RipplePainter({
    required this.progress,
    required this.chipRadius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = chipRadius + progress * 32;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final strokeWidth = 3.0 * (1.0 - progress * 0.6);
    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}
