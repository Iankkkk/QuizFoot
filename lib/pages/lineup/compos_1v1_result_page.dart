import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../data/lineup_game_data.dart';
import '../../models/lineup_model.dart';
import '../../models/match_model.dart';
import '../../models/compos_1v1_game.dart';
import '../../services/compos_1v1_service.dart';
import 'compos_1v1_lobby_page.dart';
import 'compos_1v1_preview_page.dart';

class Compos1v1ResultPage extends StatefulWidget {
  final MultiplayerGame game;
  final String pseudo;
  final Match match;
  final List<Lineup> lineups;
  final Duration timeTaken;
  final bool abandoned;

  const Compos1v1ResultPage({
    super.key,
    required this.game,
    required this.pseudo,
    required this.match,
    required this.lineups,
    required this.timeTaken,
    required this.abandoned,
  });

  @override
  State<Compos1v1ResultPage> createState() => _Compos1v1ResultPageState();
}

class _Compos1v1ResultPageState extends State<Compos1v1ResultPage>
    with TickerProviderStateMixin {

  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;

  // ── Rematch ───────────────────────────────────────────────────────────────
  bool _rematchRequested = false;
  bool _opponentReady = false;
  StreamSubscription<MultiplayerGame?>? _rematchSub;
  Timer? _rematchTimeout;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceScale = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    );
    _entranceOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _rematchSub?.cancel();
    _rematchTimeout?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  bool _isHost() => widget.game.playerOrder.isNotEmpty &&
      widget.game.playerOrder[0] == widget.pseudo;

  void _onRematchTap() {
    if (_rematchRequested) return;
    setState(() => _rematchRequested = true);
    MultiplayerService.instance.requestRematch(
      code: widget.game.roomCode,
      pseudo: widget.pseudo,
    );
    _rematchSub = MultiplayerService.instance
        .watchGame(widget.game.roomCode)
        .listen(_onRematchUpdate);
    _rematchTimeout = Timer(const Duration(seconds: 20), _onRematchTimeout);
  }

  void _onRematchUpdate(MultiplayerGame? game) {
    if (game == null || !mounted) return;

    final opponentReady = game.rematch[_opponentPseudo] == true;
    if (opponentReady && !_opponentReady) {
      setState(() => _opponentReady = true);
    }

    final bothReady = game.rematch[widget.pseudo] == true &&
        game.rematch[_opponentPseudo] == true;

    if (bothReady) {
      // Host crée la room, guest attend rematchCode
      if (_isHost() && game.rematchCode == null) {
        _createRematchRoom();
      } else if (!_isHost() && game.rematchCode != null && game.rematchMatchId != null) {
        _joinRematchRoom(game.rematchCode!, game.rematchMatchId!);
      }
    }
  }

  Future<void> _createRematchRoom() async {
    _rematchSub?.cancel();
    _rematchTimeout?.cancel();
    try {
      final matches = await loadMatches();
      final candidates = matches
          .where((m) => m.level == widget.game.difficulty && m.matchId != widget.game.matchId)
          .toList();
      final pool = candidates.isNotEmpty ? candidates : matches.where((m) => m.matchId != widget.game.matchId).toList();
      if (pool.isEmpty || !mounted) return;
      final newMatch = pool[Random().nextInt(pool.length)];
      final newCode = await MultiplayerService.instance.createRoom(
        pseudo: widget.pseudo,
        matchId: newMatch.matchId,
        difficulty: widget.game.difficulty,
      );
      await MultiplayerService.instance.joinRoom(code: newCode, pseudo: _opponentPseudo);
      await MultiplayerService.instance.writeRematchRoom(
        oldCode: widget.game.roomCode,
        newCode: newCode,
        newMatchId: newMatch.matchId,
      );
      if (!mounted) return;
      _goToPreview(newCode, newMatch.matchId);
    } catch (_) {
      if (mounted) _goToLobby();
    }
  }

  void _joinRematchRoom(String newCode, String newMatchId) {
    _rematchSub?.cancel();
    _rematchTimeout?.cancel();
    _goToPreview(newCode, newMatchId);
  }

  void _onRematchTimeout() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_opponentPseudo n\'a pas répondu'),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _goToLobby();
  }

  void _goToPreview(String roomCode, String matchId) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => Compos1v1PreviewPage(
          roomCode: roomCode,
          pseudo: widget.pseudo,
          opponentPseudo: _opponentPseudo,
          matchId: matchId,
          difficulty: widget.game.difficulty,
        ),
      ),
      (r) => r.isFirst,
    );
  }

  void _goToLobby() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Compos1v1LobbyPage()),
      (r) => r.isFirst,
    );
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  bool get _isDraw => widget.game.winner == '__draw__';
  bool get _iWon => !_isDraw && widget.game.winner == widget.pseudo;

  String get _opponentPseudo => widget.game.playerOrder.firstWhere(
    (p) => p != widget.pseudo,
    orElse: () => 'Adversaire',
  );

  int get _myFound =>
      widget.game.foundPlayers.where((f) => f.foundBy == widget.pseudo).length -
      (widget.game.bonusCounts[widget.pseudo] ?? 0);

  int get _oppFound =>
      widget.game.foundPlayers.where((f) => f.foundBy == _opponentPseudo).length -
      (widget.game.bonusCounts[_opponentPseudo] ?? 0);

  int get _myErrors => widget.game.players[widget.pseudo]?.errors ?? 0;

  String get _timerLabel {
    final m = widget.timeTaken.inMinutes;
    final s = widget.timeTaken.inSeconds % 60;
    return '${m}m${s.toString().padLeft(2, '0')}s';
  }

  String? _foundBy(Lineup player) {
    final fp = widget.game.foundPlayers
        .where((f) => f.name == player.playerName)
        .firstOrNull;
    return fp?.foundBy;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildAnimatedScoreCard(),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'DÉTAIL',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildPlayerList()),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Résultats',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedScoreCard() {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (_, __) => FadeTransition(
        opacity: _entranceOpacity,
        child: ScaleTransition(
          scale: _entranceScale,
          child: _buildScoreCard(),
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final Color outcomeColor = widget.abandoned
        ? AppColors.amber
        : _isDraw
            ? AppColors.amber
            : _iWon
                ? AppColors.accentBright
                : AppColors.red;

    final String outcomeLabel = widget.abandoned
        ? '⚠️ Partie interrompue'
        : _isDraw
            ? '🤝 Match nul'
            : _iWon
                ? '🏆 Victoire !'
                : '💀 Défaite';

    final total = widget.lineups.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: outcomeColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              widget.match.matchName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              outcomeLabel,
              style: TextStyle(
                color: outcomeColor,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            // Score duel
            Row(
              children: [
                Expanded(child: _PlayerScoreCol(
                  pseudo: widget.pseudo,
                  found: _myFound,
                  total: total,
                  errors: _myErrors,
                  isMe: true,
                  isWinner: _iWon && !widget.abandoned && !_isDraw,
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$_myFound – $_oppFound',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(child: _PlayerScoreCol(
                  pseudo: _opponentPseudo,
                  found: _oppFound,
                  total: total,
                  errors: widget.game.players[_opponentPseudo]?.errors ?? 0,
                  isMe: false,
                  isWinner: !_iWon && !widget.abandoned && !_isDraw,
                )),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  icon: Icons.close_rounded,
                  label: '$_myErrors/3',
                  sublabel: 'erreurs',
                  color: _myErrors >= 2 ? AppColors.red : AppColors.textSecondary,
                ),
                _StatChip(
                  icon: Icons.timer_outlined,
                  label: _timerLabel,
                  sublabel: 'temps',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerList() {
    final homeStarters = widget.lineups
        .where((l) => l.teamName == widget.match.homeTeam && l.starter)
        .toList();
    final homeSubs = widget.lineups
        .where((l) => l.teamName == widget.match.homeTeam && !l.starter)
        .toList();
    final awayStarters = widget.lineups
        .where((l) => l.teamName == widget.match.awayTeam && l.starter)
        .toList();
    final awaySubs = widget.lineups
        .where((l) => l.teamName == widget.match.awayTeam && !l.starter)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _buildTeamBlock(widget.match.homeTeam, homeStarters, homeSubs),
        const SizedBox(height: 12),
        _buildTeamBlock(widget.match.awayTeam, awayStarters, awaySubs),
      ],
    );
  }

  Widget _buildTeamBlock(String teamName, List<Lineup> starters, List<Lineup> subs) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              teamName,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          Container(height: 1, color: AppColors.border),
          ...[...starters, ...subs].map(_buildPlayerRow),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Lineup p) {
    final foundBy = _foundBy(p);
    final foundByMe = foundBy == widget.pseudo;
    final foundByOpp = foundBy != null && !foundByMe;

    final Color color;
    final IconData icon;
    if (foundByMe) {
      color = AppColors.accentBright;
      icon = Icons.check_circle_outline;
    } else if (foundByOpp) {
      color = Color(0xFF58A6FF);
      icon = Icons.person_outline;
    } else {
      color = AppColors.red;
      icon = Icons.cancel_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p.playerName,
              style: TextStyle(
                color: foundByMe ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: foundByMe ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
          if (foundByMe)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'moi',
                style: TextStyle(
                  color: AppColors.accentBright,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (foundByOpp)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _opponentPseudo,
                style: TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              p.starter ? p.position : 'REM',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: Text('Accueil', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _rematchRequested ? AppColors.border : AppColors.accentBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _rematchRequested ? null : _onRematchTap,
              child: _rematchRequested
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _opponentReady ? AppColors.accentBright : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _opponentReady ? '$_opponentPseudo est prêt !' : 'En attente...',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _opponentReady ? AppColors.accentBright : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  : Text('Revanche ! ⚔️', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PlayerScoreCol extends StatelessWidget {
  final String pseudo;
  final int found;
  final int total;
  final int errors;
  final bool isMe;
  final bool isWinner;

  const _PlayerScoreCol({
    required this.pseudo,
    required this.found,
    required this.total,
    required this.errors,
    required this.isMe,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (found / total * 100).round() : 0;
    final color = isWinner ? AppColors.accentBright : AppColors.textSecondary;
    return Column(
      children: [
        Text(
          pseudo,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isMe ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$pct%',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '$found trouvé${found > 1 ? 's' : ''}',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
        Text(sublabel, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
