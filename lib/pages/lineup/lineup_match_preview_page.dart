import 'dart:async';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import '../../data/lineup_game_data.dart';
import '../../data/api_exception.dart';
import '../../models/match_model.dart';
import 'lineup_match_page.dart';

const _bg            = Color(0xFF171923);
const _card          = Color(0xFF1E2130);
const _border        = Color(0xFF2D3148);
const _accentBright  = Color(0xFF3FB950);
const _textPrimary   = Color(0xFFE6EDF3);
const _textSecondary = Color(0xFF8B949E);

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _parseColor(String? name) {
  switch (name?.toLowerCase().trim()) {
    case 'blanc':      return const Color(0xFFF0F0F0);
    case 'noir':       return const Color(0xFF1A1A1A);
    case 'rouge':      return const Color(0xFFDC2626);
    case 'bleu':       return const Color(0xFF1D4ED8);
    case 'bleu clair': return const Color(0xFF60A5FA);
    case 'bleu foncé': return const Color(0xFF0C0A4D);
    case 'vert':       return const Color(0xFF16A34A);
    case 'jaune':      return const Color(0xFFFACC15);
    case 'orange':     return const Color(0xFFE16806);
    case 'violet':     return const Color(0xFF790CC8);
    default:           return _border;
  }
}

/// Maps a competition name to the corresponding logos subfolder.
/// Returns null for multi-league competitions (UCL, etc.).
String? _leagueFolder(String competition) {
  final c = competition.toLowerCase();
  if (c.contains('euro') || c.contains('coupe du monde') || c.contains('world cup') || c.contains('ligue des nations') || c.contains('copa')) return 'pays';
  if (c.contains('champions league') || c.contains('ligue des champions')) return 'Champions League';
  if (c.contains('ligue 1') || c.contains('coupe de france') || c.contains('coupe de la ligue')) return 'France - Ligue 1';
  if (c.contains('premier league') || c.contains('community shield') || c.contains('fa cup')) return 'England - Premier League';
  if (c.contains('premier league')) return 'England - Premier League';
  if (c.contains('laliga') || c.contains('la liga')) return 'Spain - La Liga';
  if (c.contains('bundesliga') && !c.contains('austria')) return 'Germany - Bundesliga';
  if (c.contains('serie a'))        return 'Italy - Serie A';
  if (c.contains('eredivisie'))     return 'Netherlands - Eredivisie';
  if (c.contains('liga portugal'))  return 'Portugal - Liga Portugal';
  if (c.contains('jupiler'))        return 'Belgium - Jupiler Pro League';
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// LineupMatchPreviewPage
// ─────────────────────────────────────────────────────────────────────────────

class LineupMatchPreviewPage extends StatefulWidget {
  final String difficulty;
  final Set<String>? eras;
  final Match? preselectedMatch;

  const LineupMatchPreviewPage({
    super.key,
    required this.difficulty,
    this.eras,
    this.preselectedMatch,
  });

  @override
  State<LineupMatchPreviewPage> createState() => _LineupMatchPreviewPageState();
}

class _LineupMatchPreviewPageState extends State<LineupMatchPreviewPage>
    with TickerProviderStateMixin {

  bool _isLoading = true;
  Match? _match;
  String? _error;

  static const int _countdownSeconds = 7;

  late final AnimationController _progressController;
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _countdownSeconds),
    );
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim  = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));

    _loadMatch();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _entranceController.dispose();
    _navTimer?.cancel();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  int _difficultyToLevel(String d) {
    switch (d) {
      case 'Amateur': return 1;
      case 'Semi-Pro':      return 2;
      case 'Pro':     return 3;
      case 'International':   return 4;
      case 'Légende':  return 5;
      default:            return 3;
    }
  }

  Future<void> _loadMatch() async {
    try {
      if (widget.preselectedMatch != null) {
        setState(() { _match = widget.preselectedMatch; _isLoading = false; });
        _entranceController.forward();
        _progressController.forward();
        _navTimer = Timer(const Duration(seconds: _countdownSeconds), _goToGame);
        return;
      }

      final matches = await loadMatches();
      final level   = _difficultyToLevel(widget.difficulty);

      final filtered = matches.where((m) {
        if (m.level != level) return false;
        final eras = widget.eras;
        if (eras == null || eras.isEmpty) return true;
        final yr = int.tryParse(RegExp(r'\d{4}').firstMatch(m.date)?.group(0) ?? '');
        if (yr == null) return true;
        return eras.any((era) {
          if (era == 'Avant 2010') return yr < 2010;
          if (era == '2010-2019')  return yr >= 2010 && yr <= 2019;
          if (era == '2020-2026')  return yr >= 2020;
          return false;
        });
      }).toList();

      if (filtered.isEmpty) {
        setState(() { _isLoading = false; _error = 'Aucun match pour cette difficulté'; });
        return;
      }

      final picked = (List<Match>.from(filtered)..shuffle()).first;
      setState(() { _match = picked; _isLoading = false; });
      _entranceController.forward();
      _progressController.forward();
      _navTimer = Timer(const Duration(seconds: _countdownSeconds), _goToGame);
    } on ApiException catch (e) {
      setState(() { _isLoading = false; _error = e.userMessage; });
    } catch (_) {
      setState(() { _isLoading = false; _error = 'Erreur inattendue. Réessaie.'; });
    }
  }

  void _goToGame() {
    _navTimer?.cancel();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LineupMatchPage(
          difficulty: widget.difficulty,
          eras: widget.eras,
          preselectedMatch: _match,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _accentBright))
            : _error != null
                ? _buildError()
                : _buildPreview(),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_soccer, color: _textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: _textSecondary, fontSize: 15)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour', style: TextStyle(color: _accentBright)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview ───────────────────────────────────────────────────────────────

  Widget _buildPreview() {
    final match   = _match!;
    final hasScore = match.homeGoals != null && match.awayGoals != null;
    final hasPens  = match.penalties != null && match.penalties!.isNotEmpty;
    final folder   = _leagueFolder(match.competition);

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  children: [
                    _buildCompetitionHeader(match),
                    const SizedBox(height: 28),
                    _buildMatchCard(match, hasScore, hasPens, folder),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildBottom(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back, color: _textPrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitionHeader(Match match) {
    return Column(
      children: [
        // Competition logo
        _buildCompetitionLogo(match.competition),
        const SizedBox(height: 10),
        Text(
          match.competition.toUpperCase(),
          style: const TextStyle(
            color: _accentBright,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          match.matchName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  // Competitions qui gardent leurs couleurs d'origine
  static const _coloredLogos = {'Euro', 'Coupe du Monde'};

  Widget _buildCompetitionLogo(String competition) {
    final img = Image.asset(
      'assets/logos/competitions/$competition.png',
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.emoji_events_outlined,
        color: _accentBright,
        size: 34,
      ),
    );

    if (_coloredLogos.contains(competition)) return img;

    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      child: img,
    );
  }

  Widget _buildMatchCard(Match match, bool hasScore, bool hasPens, String? folder) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Home team
                Expanded(
                  child: _buildTeamColumn(
                    name: match.homeTeam,
                    color: match.colorHome,
                    folder: folder,
                  ),
                ),
                // Score
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      hasScore
                          ? Text(
                              '${match.homeGoals}  –  ${match.awayGoals}',
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                              ),
                            )
                          : const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'vs',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                      if (hasPens) ...[
                        const SizedBox(height: 4),
                        Text(
                          'T.A.B. ${match.penalties}',
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Away team
                Expanded(
                  child: _buildTeamColumn(
                    name: match.awayTeam,
                    color: match.colorAway,
                    folder: folder,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Container(height: 1, color: _border),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_outlined, color: _textSecondary, size: 13),
                const SizedBox(width: 6),
                Text(
                  match.date,
                  style: const TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamColumn({
    required String name,
    required String color,
    String? folder,
  }) {
    return Column(
      children: [
        _TeamLogo(name: name, colorName: color, folder: folder),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildBottom() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _progressController,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1 - _progressController.value,
                backgroundColor: _border,
                valueColor: const AlwaysStoppedAnimation(_accentBright),
                minHeight: 3,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _goToGame,
              child: const Text(
                'Commencer  →',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TeamLogo — logo asset avec fallback cercle coloré + initiale
// ─────────────────────────────────────────────────────────────────────────────

class _TeamLogo extends StatelessWidget {
  final String name;
  final String colorName;
  final String? folder;

  const _TeamLogo({required this.name, required this.colorName, this.folder});

  @override
  Widget build(BuildContext context) {
    final fallback = _buildFallback();

    if (folder == null) return fallback;

    final fileName = folder == 'pays' ? removeDiacritics(name.toLowerCase()) : name;

    return Image.asset(
      'assets/logos/$folder/$fileName.png',
      width: 64,
      height: 64,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _buildFallback() {
    final bg      = _parseColor(colorName);
    final isDark  = bg.computeLuminance() < 0.4;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: _border, width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
