// quiz_test_intro.dart
//
// Entry point for the Coup d'œil game. Lets the player:
//   1. Read the rules
//   2. Pick a category (or keep "Toutes")
//   3. Pick a difficulty — which launches the game
//
// Categories are loaded asynchronously from the same players dataset
// used by the game, so the list is always consistent with what is available.

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../data/players_data.dart';
import '../../models/game_result.dart';
import '../../services/game_history_service.dart';
import '../../main.dart' show routeObserver;
import '../../services/theme_service.dart';
import 'quiz_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuizTestIntro
// ─────────────────────────────────────────────────────────────────────────────

class QuizTestIntro extends StatefulWidget {
  const QuizTestIntro({super.key});

  @override
  State<QuizTestIntro> createState() => _QuizTestIntroState();
}

class _QuizTestIntroState extends State<QuizTestIntro> with RouteAware {
  // ── Constants ──────────────────────────────────────────────────────────────

  /// Available difficulty labels, in ascending order.
  static const List<String> _difficulties = [
    'Amateur',
    'Semi-Pro',
    'Pro',
    'International',
    'Légende',
  ];

  /// Icons paired with each rule string (same index).
  static const List<IconData> _ruleIcons = [
    Icons.format_list_numbered,
    Icons.keyboard_outlined,
    Icons.timer_outlined,
    Icons.arrow_circle_right_outlined,
  ];

  /// Plain-text rules shown on the intro card.
  static const List<String> _rules = [
    '10 photos de joueurs seront affichées',
    'Tape le NOM DE FAMILLE du joueur',
    'Plus tu trouves rapidement, plus tu marques de points',
    'Tu peux passer si tu bloques',
  ];

  // ── State ──────────────────────────────────────────────────────────────────

  String? _selectedCategory;
  List<String> _categories = [];
  int _playerCount = 0;
  List<GameResult> _recentResults = [];
  GameResult? _bestResult;
  bool _historyLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadHistory();
  }

  Future<void> _loadCategories() async {
    try {
      final players = await loadPlayers();
      final categories =
          players
              .expand((p) => p.categories)
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (mounted)
        setState(() {
          _categories = categories;
          _playerCount = players.length;
        });
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final all = await GameHistoryService.instance.getAll();
      final coupDoeil = all
          .where((r) => r.gameType == GameType.coupDoeil)
          .toList();
      final recent = coupDoeil.take(5).toList();
      final best = coupDoeil.isEmpty
          ? null
          : coupDoeil.reduce(
              (a, b) => a.normalizedScore > b.normalizedScore ? a : b,
            );
      if (mounted)
        setState(() {
          _recentResults = recent;
          _bestResult = best;
          _historyLoaded = true;
        });
    } catch (_) {
      if (mounted) setState(() => _historyLoaded = true);
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  /// Opens the difficulty picker bottom sheet.
  /// Tapping a difficulty navigates to [QuizTest].
  void _openDifficultyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DifficultySheet(
        difficulties: _difficulties,
        onSelected: (difficulty) {
          Navigator.pop(context); // close the bottom sheet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  QuizTest(difficulty: difficulty, category: _selectedCategory),
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Catégorie',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _categories.isEmpty
                  ? _buildSkeletonChips()
                  : _buildChipRow(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBright,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _openDifficultyPicker,
                child: Text(
                  'Jouer !',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: ThemeService.instance.isDark
                      ? [const Color(0xFF1A2E1A), AppColors.bg]
                      : [const Color(0xFFD6F0E4), AppColors.bg],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Text(
                      '👁',
                      style: TextStyle(
                        fontSize: 110,
                        color: ThemeService.instance.isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.04),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Coup d'Œil",
                        style: TextStyle(
                          color: AppColors.accentBright,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reconnais les joueurs\nen un coup d\'œil',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: _playerCount),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOut,
                            builder: (_, val, __) => Text(
                              '$val joueurs',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (_bestResult != null) ...[
                            Text(
                              '  ·  ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Meilleur score : ${_bestResult!.normalizedScore.toStringAsFixed(0)} pts · ${_bestResult!.difficulty}',
                              style: TextStyle(
                                color: AppColors.accentBright,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Content ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRulesCard(),
                  const SizedBox(height: 28),
                  _buildRecentResults(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Private widget builders ───────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.card,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        "Coup d'œil",
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
    );
  }

  /// Card listing the game rules with icons.
  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Règles du jeu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          // One row per rule
          for (int i = 0; i < _rules.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_ruleIcons[i], size: 18, color: AppColors.accentBright),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _rules[i],
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Horizontal scrollable row of category chips.
  /// Shows skeleton chips while categories are loading.
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choix de la Catégorie',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _categories.isEmpty ? _buildSkeletonChips() : _buildChipRow(),
        ),
      ],
    );
  }

  /// Placeholder chips shown while the category list loads.
  Widget _buildSkeletonChips() {
    return Row(
      children: List.generate(
        4,
        (_) => Container(
          margin: const EdgeInsets.only(right: 8),
          width: 72,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  /// "Toutes" chip + one chip per category.
  Widget _buildChipRow() {
    return Row(
      children: [
        _CategoryChip(
          label: 'Toutes',
          selected: _selectedCategory == null,
          onTap: () => setState(() => _selectedCategory = null),
        ),
        for (final category in _categories)
          _CategoryChip(
            label: category,
            selected: _selectedCategory == category,
            onTap: () => setState(() => _selectedCategory = category),
          ),
      ],
    );
  }

  /// Green "Jouer !" button that opens the difficulty picker.
  Widget _buildRecentResults() {
    if (!_historyLoaded) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentBright,
          ),
        ),
      );
    }
    if (_recentResults.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mes dernières parties',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ..._recentResults.map((r) {
          final cat = r.details['category'] as String?;
          final mins = r.timeTaken.inMinutes;
          final secs = r.timeTaken.inSeconds % 60;
          final label = (cat != null && cat.isNotEmpty)
              ? '${r.difficulty} · $cat'
              : r.difficulty;
          final diffColor = AppColors.forDifficulty(r.difficulty);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: diffColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${mins}m${secs.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${r.normalizedScore.toStringAsFixed(0)} pts',
                  style: TextStyle(
                    color: AppColors.accentBright,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlayButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentBright,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _openDifficultyPicker,
      child: Text(
        'Jouer !',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DifficultySheet — private bottom sheet widget
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom sheet that lets the player pick a difficulty before starting.
/// Each difficulty is shown as a colored card.
class _DifficultySheet extends StatelessWidget {
  final List<String> difficulties;

  /// Called with the selected difficulty label when the user taps a card.
  final void Function(String difficulty) onSelected;

  const _DifficultySheet({
    required this.difficulties,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choisis la difficulté',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // One tappable card per difficulty
            for (final difficulty in difficulties)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DifficultyCard(
                  label: difficulty,
                  onTap: () => onSelected(difficulty),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DifficultyCard — private helper widget
// ─────────────────────────────────────────────────────────────────────────────

/// A single tappable difficulty option inside [_DifficultySheet].
class _DifficultyCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DifficultyCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forDifficulty(label);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              // Colored dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CategoryChip — private helper widget
// ─────────────────────────────────────────────────────────────────────────────

/// A toggleable category filter chip.
/// Highlighted in green when selected, muted when not.
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentBright.withOpacity(0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accentBright : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.accentBright : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
