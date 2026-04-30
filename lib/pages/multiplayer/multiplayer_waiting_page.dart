import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../data/lineup_game_data.dart';
import '../../models/match_model.dart';
import '../../models/multiplayer_game.dart';
import '../../services/multiplayer_service.dart';
import 'multiplayer_preview_page.dart';

class MultiplayerWaitingPage extends StatefulWidget {
  final String roomCode;
  final String pseudo;
  final bool isHost;
  final Match? match;
  final String? difficulty;

  const MultiplayerWaitingPage({
    super.key,
    required this.roomCode,
    required this.pseudo,
    this.isHost = true,
    this.match,
    this.difficulty,
  });

  @override
  State<MultiplayerWaitingPage> createState() => _MultiplayerWaitingPageState();
}

class _MultiplayerWaitingPageState extends State<MultiplayerWaitingPage> {
  StreamSubscription<MultiplayerGame?>? _sub;
  String? _opponentPseudo;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _sub = MultiplayerService.instance.watchGame(widget.roomCode).listen(_onGameUpdate);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onGameUpdate(MultiplayerGame? game) {
    if (_navigating) return;

    // Room supprimée par le host
    if (game == null) {
      _navigating = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('La partie a été annulée.'), backgroundColor: AppColors.red),
        );
        Navigator.pop(context);
      }
      return;
    }

    // Afficher l'adversaire dès qu'il rejoint
    final opponent = game.playerOrder.firstWhere(
      (p) => p != widget.pseudo,
      orElse: () => '',
    );
    if (opponent.isNotEmpty && opponent != _opponentPseudo) {
      setState(() => _opponentPseudo = opponent);
    }

    // Naviguer vers le jeu quand la partie démarre
    if (game.status == GameStatus.playing && !_navigating) {
      _navigating = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerPreviewPage(
            roomCode: widget.roomCode,
            pseudo: widget.pseudo,
            opponentPseudo: _opponentPseudo ?? '?',
            matchId: game.matchId,
            difficulty: game.difficulty,
          ),
        ),
      );
    }
  }



  Future<void> _cancelRoom() async {
    if (widget.isHost) {
      await MultiplayerService.instance.deleteRoom(widget.roomCode);
    }
    if (mounted) Navigator.pop(context);
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code copié !'),
        duration: Duration(seconds: 1),
        backgroundColor: AppColors.accentBright,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'En attente...',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),

            // ── Code ──────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    'Code de la partie',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _copyCode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.roomCode,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.copy_outlined,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Partage ce code à ton adversaire',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── Joueurs ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _PlayerSlot(pseudo: widget.pseudo, ready: true),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _PlayerSlot(
                    pseudo: _opponentPseudo,
                    ready: _opponentPseudo != null,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Annuler ───────────────────────────────────────────
            TextButton(
              onPressed: _cancelRoom,
              child: Text(
                'Annuler',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  final String? pseudo;
  final bool ready;

  const _PlayerSlot({this.pseudo, required this.ready});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ready
                ? AppColors.accentBright.withOpacity(0.15)
                : AppColors.border.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: ready ? AppColors.accentBright : AppColors.border,
            ),
          ),
          child: Icon(
            ready ? Icons.person : Icons.person_outline,
            color: ready ? AppColors.accentBright : AppColors.textSecondary,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: pseudo != null
              ? Text(
                  pseudo!,
                  style: TextStyle(
                    color: ready ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                )
              : Row(
                  children: [
                    Text(
                      'En attente',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
        ),
        if (ready)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentBright.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Prêt',
              style: TextStyle(
                color: AppColors.accentBright,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
