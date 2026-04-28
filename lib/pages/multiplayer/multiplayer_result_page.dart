import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/lineup_model.dart';
import '../../models/match_model.dart';
import '../../models/multiplayer_game.dart';
import 'multiplayer_lobby_page.dart';

class MultiplayerResultPage extends StatefulWidget {
  final MultiplayerGame game;
  final String pseudo;
  final Match match;
  final List<Lineup> lineups;
  final Duration timeTaken;
  final bool abandoned;

  const MultiplayerResultPage({
    super.key,
    required this.game,
    required this.pseudo,
    required this.match,
    required this.lineups,
    required this.timeTaken,
    required this.abandoned,
  });

  @override
  State<MultiplayerResultPage> createState() => _MultiplayerResultPageState();
}

class _MultiplayerResultPageState extends State<MultiplayerResultPage>
    with TickerProviderStateMixin {

  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;

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
    _entranceController.dispose();
    super.dispose();
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  bool get _iWon => widget.game.winner == widget.pseudo;

  String get _opponentPseudo => widget.game.playerOrder.firstWhere(
    (p) => p != widget.pseudo,
    orElse: () => 'Adversaire',
  );

  int get _myFound =>
      widget.game.foundPlayers.where((f) => f.foundBy == widget.pseudo).length;

  int get _oppFound =>
      widget.game.foundPlayers.where((f) => f.foundBy == _opponentPseudo).length;

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
            const Padding(
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
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
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
        : _iWon
            ? AppColors.accentBright
            : AppColors.red;

    final String outcomeLabel = widget.abandoned
        ? '⚠️ Partie interrompue'
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
              style: const TextStyle(
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
                  isWinner: _iWon && !widget.abandoned,
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$_myFound – $_oppFound',
                    style: const TextStyle(
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
                  isWinner: !_iWon && !widget.abandoned,
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
              style: const TextStyle(
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
      color = const Color(0xFF58A6FF);
      icon = Icons.person_outline;
    } else {
      color = AppColors.red;
      icon = Icons.cancel_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
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
                style: const TextStyle(
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
                style: const TextStyle(
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
              style: const TextStyle(
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
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Accueil', style: TextStyle(fontWeight: FontWeight.w600)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MultiplayerLobbyPage()),
                (r) => r.isFirst,
              ),
              child: const Text(
                'Nouvelle partie ↺',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
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
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
        Text(sublabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
