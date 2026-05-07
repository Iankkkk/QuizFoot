import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/coup_doeil_1v1_game.dart';
import '../../models/game_result.dart';
import '../../models/player.dart';
import '../../services/game_history_service.dart';

class CoupDoeil1v1ResultPage extends StatefulWidget {
  final String pseudo;
  final String opponentPseudo;
  final String? winner; // pseudo | '__draw__' | null (abandon)
  final int myScore;
  final int opponentScore;
  final List<CdoQuestionResult> myResults;
  final List<CdoQuestionResult> opponentResults;
  final List<Player> questions;
  final String difficulty;
  final String? category;
  final bool abandoned;
  final String? abandonedBy;

  const CoupDoeil1v1ResultPage({
    super.key,
    required this.pseudo,
    required this.opponentPseudo,
    required this.winner,
    required this.myScore,
    required this.opponentScore,
    required this.myResults,
    required this.opponentResults,
    required this.questions,
    required this.difficulty,
    this.category,
    this.abandoned = false,
    this.abandonedBy,
  });

  @override
  State<CoupDoeil1v1ResultPage> createState() => _CoupDoeil1v1ResultPageState();
}

class _CoupDoeil1v1ResultPageState extends State<CoupDoeil1v1ResultPage> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveResult());
  }

  Future<void> _saveResult() async {
    final iWon = widget.winner == widget.pseudo;
    final isDraw = widget.winner == '__draw__';
    final iAbandoned = widget.abandonedBy == widget.pseudo;
    await GameHistoryService.instance.save(
      GameResult.multiplayerCoupDoeil(
        difficulty: widget.difficulty,
        category: widget.category,
        opponentPseudo: widget.opponentPseudo,
        myScore: widget.myScore,
        opponentScore: widget.opponentScore,
        myCorrect: widget.myResults.where((r) => r.correct).length,
        opponentCorrect: widget.opponentResults.where((r) => r.correct).length,
        total: widget.questions.length,
        won: iWon,
        draw: isDraw,
        abandoned: widget.abandoned,
        iAbandoned: iAbandoned,
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _iWon => widget.winner == widget.pseudo;
  bool get _isDraw => widget.winner == '__draw__';
  bool get _opponentAbandoned => widget.abandoned && widget.abandonedBy == widget.opponentPseudo;
  bool get _iAbandoned => widget.abandoned && widget.abandonedBy == widget.pseudo;

  String get _bannerText {
    if (_iAbandoned) return 'Tu as abandonné';
    if (_opponentAbandoned) return '${widget.opponentPseudo} a abandonné !';
    if (_isDraw) return 'Égalité !';
    if (_iWon) return '🏆 Tu as gagné !';
    return '${widget.opponentPseudo} a gagné';
  }

  Color get _bannerColor {
    if (_iAbandoned) return AppColors.textSecondary;
    if (_opponentAbandoned || _iWon) return AppColors.accentBright;
    if (_isDraw) return AppColors.amber;
    return AppColors.red;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildBanner(),
                    const SizedBox(height: 16),
                    _buildScoreCard(),
                    const SizedBox(height: 20),
                    _buildDetailLabel(),
                    const SizedBox(height: 10),
                    _buildQuestionList(),
                  ],
                ),
              ),
            ),
            _buildButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(Icons.home_outlined, color: AppColors.textPrimary, size: 20),
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

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: _bannerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bannerColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        _bannerText,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _bannerColor,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _ScoreColumn(
            pseudo: widget.pseudo,
            score: widget.myScore,
            correct: widget.myResults.where((r) => r.correct).length,
            total: widget.questions.length,
            isWinner: _iWon,
            isMe: true,
          )),
          Container(width: 1, height: 60, color: AppColors.border),
          Expanded(child: _ScoreColumn(
            pseudo: widget.opponentPseudo,
            score: widget.opponentScore,
            correct: widget.opponentResults.where((r) => r.correct).length,
            total: widget.questions.length,
            isWinner: widget.winner == widget.opponentPseudo,
            isMe: false,
          )),
        ],
      ),
    );
  }

  Widget _buildDetailLabel() {
    return Row(
      children: [
        Text(
          'DÉTAIL',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        // Column headers aligned with the two _ResultBadge (54px each + 8px gap)
        SizedBox(
          width: 54,
          child: Text(
            'Moi',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.accentBright,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 54,
          child: Text(
            widget.opponentPseudo,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionList() {
    return Column(
      children: List.generate(widget.questions.length, (i) {
        final player = widget.questions[i];
        final myR = i < widget.myResults.length ? widget.myResults[i] : null;
        final oppR = i < widget.opponentResults.length ? widget.opponentResults[i] : null;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Question index
              SizedBox(
                width: 22,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              // Player name
              Expanded(
                child: Text(
                  player.name,
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              // My result
              _ResultBadge(result: myR, isMe: true),
              const SizedBox(width: 8),
              // Opponent result
              _ResultBadge(result: oppR, isMe: false),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(
              'Accueil',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ScoreColumn extends StatelessWidget {
  final String pseudo;
  final int score;
  final int correct;
  final int total;
  final bool isWinner;
  final bool isMe;

  const _ScoreColumn({
    required this.pseudo,
    required this.score,
    required this.correct,
    required this.total,
    required this.isWinner,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWinner ? AppColors.accentBright : AppColors.textSecondary;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isWinner) ...[
              Text('🏆', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
            ],
            Text(
              pseudo,
              style: TextStyle(
                color: isMe ? AppColors.accentBright : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$score',
          style: TextStyle(
            color: color,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        Text(
          'pts',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          '$correct / $total ✅',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ResultBadge extends StatelessWidget {
  final CdoQuestionResult? result;
  final bool isMe;

  const _ResultBadge({required this.result, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return SizedBox(
        width: 54,
        child: Text('—', textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );
    }

    final String label;
    final Color color;

    if (result!.correct) {
      label = '+${result!.points}';
      color = AppColors.accentBright;
    } else if (result!.attempted) {
      label = '❌';
      color = AppColors.red;
    } else {
      label = '⏩';
      color = AppColors.textSecondary;
    }

    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
