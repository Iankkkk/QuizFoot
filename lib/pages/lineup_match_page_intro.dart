import 'package:flutter/material.dart';
import 'package:quiz_foot/pages/lineup_match_page.dart';

// ── Palette ───────────────────────────────────────────────────────
const _bg = Color(0xFF0D1117);
const _card = Color(0xFF161B22);
const _border = Color(0xFF30363D);
const _accentBright = Color(0xFF3FB950);
const _textPrimary = Color(0xFFE6EDF3);
const _textSecondary = Color(0xFF8B949E);
// ─────────────────────────────────────────────────────────────────

class LineupMatchPageIntro extends StatelessWidget {
  const LineupMatchPageIntro({super.key});

  static const List<String> _difficulties = [
    "Très Facile",
    "Facile",
    "Moyenne",
    "Difficile",
    "Impossible",
  ];

  static const List<IconData> _ruleIcons = [
    Icons.view_module_outlined,
    Icons.timer_off_outlined,
    Icons.keyboard_outlined,
    Icons.error_outline,
    Icons.emoji_events_outlined,
    Icons.star_outline,
    Icons.visibility_outlined,
  ];

  static const List<String> _rules = [
    "Devine les compositions d'équipe de matchs célèbres.",
    "Il n'y a aucune limite de temps.",
    "Tape le NOM DE FAMILLE du joueur.",
    "6 erreurs maximum sont autorisées.",
    "Les titulaires et les remplaçants sont à trouver.",
    "Chaque bonne réponse rapporte un point.",
    "Tu peux voir les numéros des joueurs, mais ça coûte 2 points !",
  ];

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case "Très Facile": return const Color(0xFF238636);
      case "Facile":      return const Color(0xFF2EA043);
      case "Moyenne":     return const Color(0xFFD29922);
      case "Difficile":   return const Color(0xFFDA3633);
      case "Impossible":  return const Color(0xFF8957E5);
      default:            return _textSecondary;
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
                              builder: (_) => LineupMatchPage(difficulty: diff),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
          "Compos",
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
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
              child: Image.asset('assets/images/logo.png', width: 72, height: 72),
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
