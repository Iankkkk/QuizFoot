import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../data/players_data.dart';
import '../../models/coup_doeil_1v1_game.dart';
import '../../models/player.dart';
import '../../services/coup_doeil_1v1_service.dart';
import 'coup_doeil_1v1_preview_page.dart';

class CoupDoeil1v1WaitingRoomPage extends StatefulWidget {
  final String roomCode;
  final String pseudo;
  final bool isHost;

  const CoupDoeil1v1WaitingRoomPage({
    super.key,
    required this.roomCode,
    required this.pseudo,
    required this.isHost,
  });

  @override
  State<CoupDoeil1v1WaitingRoomPage> createState() => _CoupDoeil1v1WaitingRoomPageState();
}

class _CoupDoeil1v1WaitingRoomPageState extends State<CoupDoeil1v1WaitingRoomPage> {
  StreamSubscription<CoupDoeil1v1Game?>? _sub;
  String? _opponentPseudo;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _sub = CoupDoeil1v1Service.instance.watchGame(widget.roomCode).listen(_onGameUpdate);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onGameUpdate(CoupDoeil1v1Game? game) async {
    if (_navigating) return;

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

    // Update opponent pseudo as soon as they join
    final opponent = game.playerOrder.firstWhere(
      (p) => p != widget.pseudo,
      orElse: () => '',
    );
    if (opponent.isNotEmpty && opponent != _opponentPseudo) {
      setState(() => _opponentPseudo = opponent);
    }

    // Both players joined → load questions and start game
    if (game.status == CdoGameStatus.playing && game.questionNames.isNotEmpty && !_navigating) {
      _navigating = true;
      final questions = await _resolveQuestions(game.questionNames);
      if (!mounted) return;

      if (questions == null || questions.length < game.questionNames.length) {
        // Échec du chargement d'au moins une photo → abandon de la partie
        _navigating = false;
        await CoupDoeil1v1Service.instance.abandonRoom(
          code: widget.roomCode,
          pseudo: widget.pseudo,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec du chargement des photos. Réessaie.'),
            backgroundColor: AppColors.red,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CoupDoeil1v1PreviewPage(
            roomCode: widget.roomCode,
            pseudo: widget.pseudo,
            opponentPseudo: _opponentPseudo ?? opponent,
            questions: questions,
            difficulty: game.difficulty,
            category: game.category,
          ),
        ),
      );
    }
  }

  /// Retourne null si une photo est définitivement inaccessible (toutes les
  /// retries ont échoué), sinon la liste des joueurs avec leurs photos en cache.
  Future<List<Player>?> _resolveQuestions(List<String> names) async {
    try {
      final all = await loadPlayers();
      final byName = {for (final p in all) p.name: p};
      final players = names.map((n) => byName[n]).whereType<Player>().toList();
      if (!mounted) return players;
      // 5 retries avec backoff exponentiel : 1s, 2s, 4s, 8s, 16s = ~31s max par
      // photo, en parallèle donc le total reste ~31s.
      final results = await Future.wait(
        players.map((p) => _precacheWithRetry(p.imageUrl)),
      );
      if (results.contains(false)) return null;
      return players;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _precacheWithRetry(String url, {int retries = 4}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        if (!mounted) return false;
        await precacheImage(NetworkImage(url), context);
        return true;
      } catch (_) {
        if (i < retries) {
          await Future.delayed(Duration(seconds: 1 << i)); // 1, 2, 4, 8 s
        }
      }
    }
    return false;
  }

  Future<void> _cancel() async {
    if (widget.isHost) {
      await CoupDoeil1v1Service.instance.deleteRoom(widget.roomCode);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _navigating) return;
        await _cancel();
      },
      child: Scaffold(
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

            // ── Room code ──────────────────────────────────────────
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
                          Icon(Icons.copy_outlined, color: AppColors.textSecondary, size: 18),
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

            // ── Players ────────────────────────────────────────────
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                  _PlayerSlot(pseudo: _opponentPseudo, ready: _opponentPseudo != null),
                ],
              ),
            ),

            const Spacer(),

            TextButton(
              onPressed: _cancel,
              child: Text(
                'Annuler',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
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
                ? AppColors.accentBright.withValues(alpha: 0.15)
                : AppColors.border.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: ready ? AppColors.accentBright : AppColors.border),
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
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
        ),
        if (ready)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentBright.withValues(alpha: 0.12),
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
