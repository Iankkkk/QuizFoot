import 'package:flutter/material.dart';
import 'package:quiz_foot/pages/lineup/lineup_match_preview_page.dart';

// ── Palette ───────────────────────────────────────────────────────
const _bg = Color(0xFF171923);
const _card = Color(0xFF1E2130);
const _border = Color(0xFF2D3148);
const _accentBright = Color(0xFF3FB950);
const _textPrimary = Color(0xFFE6EDF3);
const _textSecondary = Color(0xFF8B949E);
// ─────────────────────────────────────────────────────────────────

class LineupMatchPageIntro extends StatefulWidget {
  const LineupMatchPageIntro({super.key});

  @override
  State<LineupMatchPageIntro> createState() => _LineupMatchPageIntroState();
}

class _LineupMatchPageIntroState extends State<LineupMatchPageIntro> {
  static const List<String> _difficulties = [
    "Amateur",
    "Semi-Pro",
    "Pro",
    "International",
    "Légende",
  ];

  static const List<String> _eras = [
    "Toutes",
    "Avant 2010",
    "2010-2019",
    "2020-2026",
  ];

  static const List<IconData> _ruleIcons = [
    Icons.view_module_outlined,
    Icons.timer_off_outlined,
    Icons.keyboard_outlined,
    Icons.error_outline,
    Icons.emoji_events_outlined,
    Icons.star_outline,
    Icons.abc_outlined,
  ];

  static const List<String> _rules = [
    "Devine les compositions d'équipe de matchs célèbres.",
    "Il n'y a aucune limite de temps.",
    "Tape le NOM DE FAMILLE du joueur.",
    "6 erreurs maximum sont autorisées.",
    "Les titulaires et les remplaçants entrés en jeu sont à trouver.",
    "Chaque bonne réponse rapporte 1 point.",
    "Tu as 5 indices gratuits, en cliquant sur l'un des joueurs pour révéler la 1ère lettre de son nom OU son numéro",
  ];

  final Set<String> _selectedEras = {};

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case "Amateur":
        return const Color(0xFF238636);
      case "Semi-Pro":
        return const Color(0xFF2EA043);
      case "Pro":
        return const Color(0xFFD29922);
      case "International":
        return const Color(0xFFDA3633);
      case "Légende":
        return const Color(0xFF8957E5);
      default:
        return _textSecondary;
    }
  }

  void _showDifficultyPicker() {
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
                ..._difficulties.map((diff) {
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
                              builder: (_) => LineupMatchPreviewPage(
                                difficulty: diff,
                                eras: Set.from(_selectedEras),
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
                }),
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
          "Compos",
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

            Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 16),

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
                  ...List.generate(_rules.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_ruleIcons[i], size: 18, color: _accentBright),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _rules[i],
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

            const SizedBox(height: 28),

            // ── Catégorie ─────────────────────────────────────────
            const Text(
              'Catégorie',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _eras.map((era) {
                  final isAll = era == 'Toutes';
                  final selected = isAll
                      ? _selectedEras.isEmpty
                      : _selectedEras.contains(era);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isAll) {
                        _selectedEras.clear();
                      } else {
                        if (_selectedEras.contains(era)) {
                          _selectedEras.remove(era);
                        } else {
                          _selectedEras.add(era);
                          if (_selectedEras.length == 3) _selectedEras.clear();
                        }
                      }
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? _accentBright.withOpacity(0.15)
                            : _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? _accentBright : _border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        era,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? _accentBright : _textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 28),

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
              onPressed: _showDifficultyPicker,
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
