import 'dart:async';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import '../../data/lineup_game_data.dart';
import '../../data/api_exception.dart';
import '../../models/match_model.dart';
import 'lineup_match_page.dart';
import '../../constants/app_colors.dart';
import '../../services/theme_service.dart';
import 'package:quiz_foot/utils/navigation.dart';
import 'lineup_visuals.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

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
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

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

  Future<void> _loadMatch() async {
    try {
      if (widget.preselectedMatch != null) {
        setState(() {
          _match = widget.preselectedMatch;
          _isLoading = false;
        });
        _entranceController.forward();
        _progressController.forward();
        _navTimer = Timer(
          const Duration(seconds: _countdownSeconds),
          _goToGame,
        );
        return;
      }

      final matches = await loadMatches();
      final level = difficultyToLevel(widget.difficulty);

      final filtered = matches.where((m) {
        if (m.level != level) return false;
        final eras = widget.eras;
        if (eras == null || eras.isEmpty) return true;
        final yr = int.tryParse(
          RegExp(r'\d{4}').firstMatch(m.date)?.group(0) ?? '',
        );
        if (yr == null) return true;
        return eras.any((era) {
          if (era == 'Avant 2010') return yr < 2010;
          if (era == '2010-2019') return yr >= 2010 && yr <= 2019;
          if (era == '2020-2026') return yr >= 2020;
          return false;
        });
      }).toList();

      if (filtered.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Aucun match pour cette difficulté';
        });
        return;
      }

      final picked = (List<Match>.from(filtered)..shuffle()).first;
      setState(() {
        _match = picked;
        _isLoading = false;
      });
      _entranceController.forward();
      _progressController.forward();
      _navTimer = Timer(const Duration(seconds: _countdownSeconds), _goToGame);
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

  void _goToGame() {
    _navTimer?.cancel();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      namedRoute(LineupMatchPage(
        difficulty: widget.difficulty,
        eras: widget.eras,
        preselectedMatch: _match,
      )),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.accentBright),
              )
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
            Icon(Icons.sports_soccer, color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Retour',
                style: TextStyle(color: AppColors.accentBright),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview ───────────────────────────────────────────────────────────────

  Widget _buildPreview() {
    final match = _match!;
    final hasScore = match.homeGoals != null && match.awayGoals != null;
    final hasPens = match.penalties != null && match.penalties!.isNotEmpty;
    final folder = leagueFolder(match.competition);

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
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20,
              ),
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
          style: TextStyle(
            color: AppColors.accentBright,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          match.matchName,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  // Competitions qui gardent leurs couleurs d'origine
  static const _coloredLogos = {
    'Euro',
    'Coupe du Monde',
    "CAN",
    'Copa America',
  };

  Widget _buildCompetitionLogo(String competition) {
    final img = Image.asset(
      'assets/logos/competitions/$competition.png',
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.emoji_events_outlined,
        color: AppColors.accentBright,
        size: 34,
      ),
    );

    if (_coloredLogos.contains(competition)) return img;

    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        ThemeService.instance.isDark ? Colors.white : Colors.black87,
        BlendMode.srcIn,
      ),
      child: img,
    );
  }

  Widget _buildMatchCard(
    Match match,
    bool hasScore,
    bool hasPens,
    String? folder,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'vs',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                      if (hasPens) ...[
                        const SizedBox(height: 4),
                        Text(
                          'T.A.B. ${match.penalties}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
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
          Container(height: 1, color: AppColors.border),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.textSecondary,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  match.date,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
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
          style: TextStyle(
            color: AppColors.textPrimary,
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
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(AppColors.accentBright),
                minHeight: 3,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _goToGame,
              child: Text(
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

    final fileName = folder == 'pays'
        ? removeDiacritics(name.toLowerCase())
        : name;

    return Image.asset(
      'assets/logos/$folder/$fileName.png',
      width: 64,
      height: 64,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _buildFallback() {
    final bg = previewLogoColor(colorName, fallback: AppColors.border);
    final isDark = bg.computeLuminance() < 0.4;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1.5),
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
