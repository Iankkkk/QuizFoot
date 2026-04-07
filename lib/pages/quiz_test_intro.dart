import 'package:flutter/material.dart';
import 'quiz_test.dart';
import '../data/players_data.dart';

// ── Palette ───────────────────────────────────────────────────────
const _bg = Color(0xFF171923);
const _card = Color(0xFF1E2130);
const _border = Color(0xFF2D3148);
const _accent = Color(0xFF2EA043);
const _accentBright = Color(0xFF3FB950);
const _textPrimary = Color(0xFFE6EDF3);
const _textSecondary = Color(0xFF8B949E);
// ─────────────────────────────────────────────────────────────────

class QuizTestIntro extends StatefulWidget {
  const QuizTestIntro({super.key});

  @override
  State<QuizTestIntro> createState() => _QuizTestIntroState();
}

class _QuizTestIntroState extends State<QuizTestIntro> {
  final List<String> difficulties = const [
    "Très Facile",
    "Facile",
    "Moyenne",
    "Difficile",
    "Impossible",
  ];

  final List<IconData> ruleIcons = const [
    Icons.photo_camera_outlined,
    Icons.format_list_numbered,
    Icons.timer_off_outlined,
    Icons.keyboard_outlined,
    Icons.star_outline,
    Icons.skip_next_outlined,
  ];

  final List<String> rules = const [
    "Devine le joueur à partir de sa photo.",
    "10 photos seront affichées.",
    "Tape le NOM DE FAMILLE du joueur.",
    "Plus tu trouves rapidement, plus tu marques de points.",
    "Tu peux passer si tu bloques.",
  ];

  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final players = await loadPlayers();
      final cats =
          players
              .expand((p) => p.categories)
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      setState(() => _categories = cats);
    } catch (_) {}
  }

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case "Très Facile":
        return const Color(0xFF238636);
      case "Facile":
        return const Color(0xFF2EA043);
      case "Moyenne":
        return const Color(0xFFD29922);
      case "Difficile":
        return const Color(0xFFDA3633);
      case "Impossible":
        return const Color(0xFF8957E5);
      default:
        return _textSecondary;
    }
  }

  void _showDifficultyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          decoration: const BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: _border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Choisis la difficulté",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...difficulties.map((diff) {
                  final color = _getDifficultyColor(diff);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizTest(
                                difficulty: diff,
                                category: _selectedCategory,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                diff,
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
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Coup d'œil",
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // ── Logo ─────────────────────────────────────────────
            Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: 72,
                height: 72,
              ),
            ),
            const SizedBox(height: 16),

            // ── Règles ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Règles du jeu",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(rules.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(ruleIcons[i], size: 18, color: _accentBright),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rules[i],
                              style: const TextStyle(
                                fontSize: 14,
                                color: _textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Catégorie ────────────────────────────────────────
            const Text(
              "Catégorie",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _categories.isEmpty
                  ? Row(
                      children: List.generate(
                        4,
                        (_) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 72,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _border),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        _CategoryChip(
                          label: "Toutes",
                          selected: _selectedCategory == null,
                          onTap: () => setState(() => _selectedCategory = null),
                        ),
                        ..._categories.map(
                          (cat) => _CategoryChip(
                            label: cat,
                            selected: _selectedCategory == cat,
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 28),

            // ── Bouton jouer ─────────────────────────────────────
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showDifficultyPicker(context),
              child: const Text(
                "Jouer !",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          color: selected ? _accentBright.withOpacity(0.15) : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _accentBright : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? _accentBright : _textSecondary,
          ),
        ),
      ),
    );
  }
}
