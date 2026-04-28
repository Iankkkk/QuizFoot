import 'dart:async';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../data/lineup_game_data.dart';
import '../../models/match_model.dart';
import '../../models/multiplayer_game.dart';
import '../../services/multiplayer_service.dart';
import 'multiplayer_game_page.dart';

class MultiplayerPreviewPage extends StatefulWidget {
  final String roomCode;
  final String pseudo;
  final String opponentPseudo;
  final String matchId;
  final String difficulty;

  const MultiplayerPreviewPage({
    super.key,
    required this.roomCode,
    required this.pseudo,
    required this.opponentPseudo,
    required this.matchId,
    required this.difficulty,
  });

  @override
  State<MultiplayerPreviewPage> createState() => _MultiplayerPreviewPageState();
}

class _MultiplayerPreviewPageState extends State<MultiplayerPreviewPage>
    with TickerProviderStateMixin {
  static const int _countdownSeconds = 8;

  Match? _match;
  bool _matchLoading = true;

  late final AnimationController _progressController;
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  Timer? _navTimer;
  StreamSubscription<MultiplayerGame?>? _sub;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _countdownSeconds),
    );
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));

    _sub = MultiplayerService.instance.watchGame(widget.roomCode).listen(_onGameUpdate);
    _loadMatch();
  }

  Future<void> _loadMatch() async {
    try {
      final matches = await loadMatches();
      final match = matches.firstWhere(
        (m) => m.matchId == widget.matchId,
        orElse: () => throw Exception('Match introuvable'),
      );
      if (!mounted) return;
      setState(() { _match = match; _matchLoading = false; });
      _entranceController.forward();
      _progressController.forward();
      _navTimer = Timer(const Duration(seconds: _countdownSeconds), _goToGame);
    } catch (_) {
      if (mounted) setState(() => _matchLoading = false);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _entranceController.dispose();
    _navTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _onGameUpdate(MultiplayerGame? game) {
    if (_navigating) return;
    if (game == null || (game.abandoned && game.abandonedBy != widget.pseudo)) {
      _navigating = true;
      _navTimer?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La partie a été annulée.'),
            backgroundColor: AppColors.red,
          ),
        );
        Navigator.of(context)
          ..pop() // preview
          ..pop(); // waiting
      }
    }
  }

  void _goToGame() {
    if (_navigating) return;
    _navigating = true;
    _navTimer?.cancel();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MultiplayerGamePage(
          roomCode: widget.roomCode,
          pseudo: widget.pseudo,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_matchLoading || _match == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.accentBright)),
      );
    }

    final match = _match!;
    final hasScore = match.homeGoals != null && match.awayGoals != null;
    final hasPens = match.penalties != null && match.penalties!.isNotEmpty;
    final folder = _leagueFolder(match.competition);
    final diffColor = AppColors.forDifficulty(widget.difficulty);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, color: AppColors.textSecondary, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.pseudo}  vs  ${widget.opponentPseudo}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: diffColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      widget.difficulty,
                      style: TextStyle(
                        color: diffColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      children: [
                        _buildCompetitionHeader(match),
                        const SizedBox(height: 20),
                        _buildMatchupBadge(),
                        const SizedBox(height: 20),
                        _buildMatchCard(match, hasScore, hasPens, folder),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (_, __) {
                      final remaining = (_countdownSeconds * (1 - _progressController.value)).ceil();
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: 1 - _progressController.value,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation(AppColors.accentBright),
                              minHeight: 3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Début dans $remaining s...',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchupBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.pseudo,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'VS',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.6),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
          ),
          Text(
            widget.opponentPseudo,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitionHeader(Match match) {
    return Column(
      children: [
        _buildCompetitionLogo(match.competition),
        const SizedBox(height: 10),
        Text(
          match.competition.toUpperCase(),
          style: const TextStyle(
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  static const _coloredLogos = {'Euro', 'Coupe du Monde'};

  Widget _buildCompetitionLogo(String competition) {
    final img = Image.asset(
      'assets/logos/competitions/$competition.png',
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.emoji_events_outlined,
        color: AppColors.accentBright,
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
                Expanded(child: _buildTeamColumn(name: match.homeTeam, color: match.colorHome, folder: folder)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      hasScore
                          ? Text(
                              '${match.homeGoals}  –  ${match.awayGoals}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
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
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(child: _buildTeamColumn(name: match.awayTeam, color: match.colorAway, folder: folder)),
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
                const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 13),
                const SizedBox(width: 6),
                Text(
                  match.date,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamColumn({required String name, required String color, String? folder}) {
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
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String? _leagueFolder(String competition) {
  final c = competition.toLowerCase();
  if (c.contains('euro') || c.contains('coupe du monde') || c.contains('world cup') ||
      c.contains('ligue des nations') || c.contains('copa')) return 'pays';
  if (c.contains('champions league') || c.contains('ligue des champions')) return 'Champions League';
  if (c.contains('ligue 1') || c.contains('coupe de france') || c.contains('coupe de la ligue')) return 'France - Ligue 1';
  if (c.contains('premier league') || c.contains('community shield') || c.contains('fa cup')) return 'England - Premier League';
  if (c.contains('laliga') || c.contains('la liga') || c.contains('liga')) return 'Spain - La Liga';
  if (c.contains('bundesliga') && !c.contains('austria')) return 'Germany - Bundesliga';
  if (c.contains('serie a')) return 'Italy - Serie A';
  if (c.contains('eredivisie')) return 'Netherlands - Eredivisie';
  if (c.contains('liga portugal')) return 'Portugal - Liga Portugal';
  if (c.contains('jupiler')) return 'Belgium - Jupiler Pro League';
  return null;
}

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
    default:           return const Color(0xFF2D3148);
  }
}

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
    final bg = _parseColor(colorName);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2D3148), width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: bg.computeLuminance() < 0.4 ? Colors.white : Colors.black87,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
