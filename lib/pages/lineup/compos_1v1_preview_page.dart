import 'dart:async';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/theme_service.dart';
import '../../data/lineup_game_data.dart';
import '../../models/match_model.dart';
import '../../models/compos_1v1_game.dart';
import '../../services/compos_1v1_service.dart';
import 'compos_1v1_game_page.dart';
import 'package:quiz_foot/utils/navigation.dart';
import 'lineup_visuals.dart';

class Compos1v1PreviewPage extends StatefulWidget {
  final String roomCode;
  final String pseudo;
  final String opponentPseudo;
  final String matchId;
  final String difficulty;

  const Compos1v1PreviewPage({
    super.key,
    required this.roomCode,
    required this.pseudo,
    required this.opponentPseudo,
    required this.matchId,
    required this.difficulty,
  });

  @override
  State<Compos1v1PreviewPage> createState() => _Compos1v1PreviewPageState();
}

class _Compos1v1PreviewPageState extends State<Compos1v1PreviewPage>
    with TickerProviderStateMixin {
  static const int _countdownSeconds = 10;

  Match? _match;
  bool _matchLoading = true;
  String _currentMatchId = '';
  List<Match> _allMatches = [];

  late AnimationController _progressController;
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  Timer? _navTimer;
  StreamSubscription<MultiplayerGame?>? _sub;
  bool _navigating = false;

  bool _iAmReady = false;
  String? _changeRequestedBy;

  @override
  void initState() {
    super.initState();
    _currentMatchId = widget.matchId;

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _countdownSeconds),
    );
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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

    _sub = MultiplayerService.instance
        .watchGame(widget.roomCode)
        .listen(_onGameUpdate);
    _loadMatch(_currentMatchId, firstLoad: true);
  }

  Future<void> _loadMatch(String matchId, {bool firstLoad = false}) async {
    if (!mounted) return;
    setState(() => _matchLoading = true);
    try {
      if (_allMatches.isEmpty) {
        _allMatches = await loadMatches();
      }
      final match = _allMatches.firstWhere(
        (m) => m.matchId == matchId,
        orElse: () => throw Exception('Match introuvable'),
      );
      if (!mounted) return;
      setState(() {
        _match = match;
        _matchLoading = false;
        _currentMatchId = matchId;
      });
      if (firstLoad) {
        _entranceController.forward();
      }
      _startCountdown();
    } catch (_) {
      if (mounted) setState(() => _matchLoading = false);
    }
  }

  void _startCountdown() {
    _navTimer?.cancel();
    _progressController.reset();
    _progressController.forward();
    _navTimer = Timer(const Duration(seconds: _countdownSeconds), _goToGame);
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
          SnackBar(
            content: Text('La partie a été annulée.'),
            backgroundColor: AppColors.red,
          ),
        );
        Navigator.of(context)
          ..pop()
          ..pop();
      }
      return;
    }

    // Match changed → reload
    if (game.matchId != _currentMatchId) {
      setState(() {
        _iAmReady = false;
        _changeRequestedBy = null;
      });
      _loadMatch(game.matchId);
      return;
    }

    // Both ready → navigate immediately
    final bothReady = game.previewReady.contains(widget.pseudo) &&
        game.previewReady.contains(widget.opponentPseudo);
    if (bothReady) {
      _goToGame();
      return;
    }

    final newChangeRequest = game.previewChangeRequest;
    if (newChangeRequest != _changeRequestedBy) {
      setState(() => _changeRequestedBy = newChangeRequest);
    }
  }

  void _goToGame() {
    if (_navigating) return;
    _navigating = true;
    _navTimer?.cancel();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      namedRoute(
        Compos1v1GamePage(roomCode: widget.roomCode, pseudo: widget.pseudo),
      ),
    );
  }

  Future<void> _onReadyTap() async {
    if (_iAmReady) return;
    setState(() => _iAmReady = true);
    await MultiplayerService.instance.markPreviewReady(
      code: widget.roomCode,
      pseudo: widget.pseudo,
    );
  }

  Future<void> _onRequestChange() async {
    setState(() => _changeRequestedBy = widget.pseudo);
    await MultiplayerService.instance.requestChangeMatch(
      code: widget.roomCode,
      pseudo: widget.pseudo,
    );
  }

  Future<void> _onAcceptChange() async {
    final level = difficultyToLevel(widget.difficulty);
    final pool = _allMatches
        .where((m) => m.level == level && m.matchId != _currentMatchId)
        .toList();
    if (pool.isEmpty) return;
    pool.shuffle();
    final newMatch = pool.first;
    setState(() {
      _changeRequestedBy = null;
      _iAmReady = false;
    });
    await MultiplayerService.instance.acceptChangeMatch(
      code: widget.roomCode,
      newMatchId: newMatch.matchId,
    );
  }

  Future<void> _onRefuseChange() async {
    setState(() => _changeRequestedBy = null);
    await MultiplayerService.instance.refuseChangeMatch(code: widget.roomCode);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_matchLoading || _match == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentBright),
        ),
      );
    }

    final match = _match!;
    final hasScore = match.homeGoals != null && match.awayGoals != null;
    final hasPens = match.penalties != null && match.penalties!.isNotEmpty;
    final folder = leagueFolder(match.competition);
    final diffColor = AppColors.forDifficulty(widget.difficulty);

    final iRequestedChange = _changeRequestedBy == widget.pseudo;
    final opponentRequestedChange = _changeRequestedBy == widget.opponentPseudo;

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: AppColors.textSecondary,
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.pseudo}  vs  ${widget.opponentPseudo}',
                          style: TextStyle(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: diffColor.withValues(alpha: 0.4),
                      ),
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
                  // Opponent requested change → show accept/refuse
                  if (opponentRequestedChange) ...[
                    _buildChangeRequestBanner(),
                    const SizedBox(height: 12),
                  ],

                  // Ready button
                  GestureDetector(
                    onTap: _iAmReady ? null : _onReadyTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _iAmReady
                            ? AppColors.accentBright.withValues(alpha: 0.15)
                            : AppColors.accentBright,
                        borderRadius: BorderRadius.circular(14),
                        border: _iAmReady
                            ? Border.all(
                                color: AppColors.accentBright,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _iAmReady
                                ? Icons.check_circle_outline_rounded
                                : Icons.rocket_launch_rounded,
                            color: _iAmReady
                                ? AppColors.accentBright
                                : Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _iAmReady
                                ? 'En attente de ${widget.opponentPseudo}...'
                                : 'C\'est parti !',
                            style: TextStyle(
                              color: _iAmReady
                                  ? AppColors.accentBright
                                  : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Change match button / waiting state
                  if (iRequestedChange)
                    _buildWaitingChip(
                      'En attente de ${widget.opponentPseudo}...',
                    )
                  else if (!opponentRequestedChange &&
                      _changeRequestedBy == null)
                    GestureDetector(
                      onTap: _onRequestChange,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shuffle_rounded,
                              color: AppColors.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Changer la compo',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Auto-start countdown
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (_, __) {
                      final remaining =
                          (_countdownSeconds * (1 - _progressController.value))
                              .ceil();
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: 1 - _progressController.value,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.accentBright.withValues(alpha: 0.4),
                              ),
                              minHeight: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Début automatique dans $remaining s',
                            style: TextStyle(
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.6),
                              fontSize: 12,
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

  Widget _buildChangeRequestBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            '${widget.opponentPseudo} veut changer la compo',
            style: TextStyle(
              color: AppColors.amber,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _onRefuseChange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        'Non',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _onAcceptChange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.accentBright,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Oui, changer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingChip(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
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
            style: TextStyle(
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
            style: TextStyle(
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
                Expanded(
                  child: _buildTeamColumn(
                    name: match.homeTeam,
                    color: match.colorHome,
                    folder: folder,
                  ),
                ),
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
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _TeamLogo extends StatelessWidget {
  final String name;
  final String colorName;
  final String? folder;

  const _TeamLogo({required this.name, required this.colorName, this.folder});

  @override
  Widget build(BuildContext context) {
    final fallback = _buildFallback();
    if (folder == null) return fallback;
    final fileName =
        folder == 'pays' ? removeDiacritics(name.toLowerCase()) : name;
    return Image.asset(
      'assets/logos/$folder/$fileName.png',
      width: 64,
      height: 64,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _buildFallback() {
    final bg = previewLogoColor(colorName, fallback: const Color(0xFF2D3148));
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Color(0xFF2D3148), width: 1.5),
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
