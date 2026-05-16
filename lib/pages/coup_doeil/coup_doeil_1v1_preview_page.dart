import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/coup_doeil_1v1_game.dart';
import '../../models/player.dart';
import '../../services/coup_doeil_1v1_service.dart';
import 'coup_doeil_1v1_game_page.dart';
import 'package:quiz_foot/utils/navigation.dart';

class CoupDoeil1v1PreviewPage extends StatefulWidget {
  final String roomCode;
  final String pseudo;
  final String opponentPseudo;
  final List<Player> questions;
  final String difficulty;
  final String? category;

  const CoupDoeil1v1PreviewPage({
    super.key,
    required this.roomCode,
    required this.pseudo,
    required this.opponentPseudo,
    required this.questions,
    required this.difficulty,
    this.category,
  });

  @override
  State<CoupDoeil1v1PreviewPage> createState() =>
      _CoupDoeil1v1PreviewPageState();
}

class _CoupDoeil1v1PreviewPageState extends State<CoupDoeil1v1PreviewPage>
    with TickerProviderStateMixin {
  static const int _countdownSeconds = 8;

  late final AnimationController _progressController;
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  Timer? _navTimer;
  StreamSubscription<CoupDoeil1v1Game?>? _sub;
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

    _sub = CoupDoeil1v1Service.instance
        .watchGame(widget.roomCode)
        .listen(_onGameUpdate);

    _entranceController.forward();
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

  void _onGameUpdate(CoupDoeil1v1Game? game) {
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
      namedRoute(CoupDoeil1v1GamePage(
        roomCode: widget.roomCode,
        pseudo: widget.pseudo,
        opponentPseudo: widget.opponentPseudo,
        questions: widget.questions,
        difficulty: widget.difficulty,
        category: widget.category,
      )),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
                        _buildGameHeader(),
                        const SizedBox(height: 24),
                        _buildVersusBadge(),
                        const SizedBox(height: 24),
                        _buildInfoCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: AnimatedBuilder(
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
                            AppColors.accentBright,
                          ),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Début dans $remaining s...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildGameHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.accentBright.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accentBright.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.remove_red_eye_outlined,
            color: AppColors.accentBright,
            size: 38,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "COUP D'ŒIL 1V1",
          style: TextStyle(
            color: AppColors.accentBright,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.category ?? 'Tous les joueurs',
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

  // ── Versus badge (pseudos en avant) ────────────────────────────────────────

  Widget _buildVersusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _buildPseudoColumn(widget.pseudo, isMe: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'VS',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 2,
              ),
            ),
          ),
          Expanded(
            child: _buildPseudoColumn(widget.opponentPseudo, isMe: false),
          ),
        ],
      ),
    );
  }

  Widget _buildPseudoColumn(String pseudo, {required bool isMe}) {
    final color = isMe ? AppColors.accentBright : AppColors.textPrimary;
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isMe ? AppColors.accentBright : AppColors.border,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              pseudo.isNotEmpty ? pseudo[0].toUpperCase() : '?',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          pseudo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ── Info card (rules) ──────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _infoRow('📸', '${widget.questions.length} photos affichées'),
          const SizedBox(height: 12),
          _infoRow('⏱️', '30 secondes max par photo'),
          const SizedBox(height: 12),
          _infoRow('🏃', 'Plus tu réponds vite, plus tu gagnes de points'),
          const SizedBox(height: 12),
          _infoRow('🏆', 'Le plus grand score gagne'),
        ],
      ),
    );
  }

  Widget _infoRow(String emoji, String label) {
    return Row(
      children: [
        Text(emoji, style: TextStyle(fontSize: 16)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
