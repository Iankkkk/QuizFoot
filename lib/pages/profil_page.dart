import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/game_result.dart';
import '../services/game_history_service.dart';
import '../services/theme_service.dart';

class ProfilPage extends StatefulWidget {
  final String pseudo;
  const ProfilPage({super.key, required this.pseudo});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  List<GameResult> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  Future<void> _load() async {
    final results = await GameHistoryService.instance.getAll();
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  // ── Stats calculées ────────────────────────────────────────────────────────

  List<GameResult> get _coupDoeil =>
      _results.where((r) => r.gameType == GameType.coupDoeil).toList();

  List<GameResult> get _compos =>
      _results.where((r) => r.gameType == GameType.compos).toList();

  List<GameResult> get _multiplayerCompos =>
      _results.where((r) => r.gameType == GameType.multiplayerCompos).toList();

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }

  Duration get _totalTime => _results.fold(
        Duration.zero,
        (acc, r) => acc + r.timeTaken,
      );

  int get _composCompleted =>
      _compos.where((r) => r.details['found'] == r.details['total']).length;

  int get _multiplayerWins =>
      _multiplayerCompos.where((r) => r.details['won'] == true && r.details['abandoned'] != true).length;

  int get _multiplayerLosses =>
      _multiplayerCompos.where((r) => r.details['won'] == false && r.details['abandoned'] != true).length;

  double get _coupDoeilAvg => _coupDoeil.isEmpty
      ? 0
      : _coupDoeil.fold(0.0, (s, r) => s + r.normalizedScore) / _coupDoeil.length;

  double get _composAvg => _compos.isEmpty
      ? 0
      : _compos.fold(0.0, (s, r) => s + r.normalizedScore) / _compos.length;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accentBright))
          : RefreshIndicator(
              color: AppColors.accentBright,
              backgroundColor: AppColors.card,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildGlobalStats(),
                    const SizedBox(height: 20),
                    _buildGameSection(
                      title: "Coup d'Œil",
                      icon: Icons.remove_red_eye_outlined,
                      results: _coupDoeil,
                      extraStats: [
                        _StatData('Score moyen', _coupDoeilAvg.toStringAsFixed(1)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildGameSection(
                      title: 'Compos',
                      icon: Icons.format_list_bulleted,
                      results: _compos,
                      extraStats: [
                        _StatData('Score moyen', _composAvg.toStringAsFixed(1)),
                        _StatData('Compos parfaites', '$_composCompleted'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMultiplayerSection(),
                    if (_results.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildMasterclass(),
                    ],
                    const SizedBox(height: 28),
                    if (_results.isNotEmpty) ...[
                      _sectionLabel('PARTIES RÉCENTES'),
                      const SizedBox(height: 12),
                      ..._results.take(15).map(_buildResultRow),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMasterclass() {
    final best = _results.reduce(
      (a, b) => a.normalizedScore > b.normalizedScore ? a : b,
    );
    final bestCat = best.details['category'] as String?;
    final String label;
    if (best.gameType == GameType.compos) {
      label = best.details['matchName'] as String? ?? 'Compos';
    } else if (best.gameType == GameType.multiplayerCompos) {
      final opp = best.details['opponentPseudo'] as String? ?? '?';
      label = 'Compos 1v1 · vs $opp';
    } else {
      label = (bestCat != null && bestCat.isNotEmpty)
          ? "Coup d'Œil · ${best.difficulty} · $bestCat"
          : "Coup d'Œil · ${best.difficulty}";
    }
    final date =
        '${best.playedAt.day}/${best.playedAt.month}/${best.playedAt.year % 100}';
    final mins = best.timeTaken.inMinutes;
    final secs = best.timeTaken.inSeconds % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ThemeService.instance.isDark
              ? [const Color(0xFF1A2E1A), const Color(0xFF1E2130)]
              : [const Color(0xFFE6F9F1), const Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentBright.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🏆', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Ta masterclass',
                style: TextStyle(
                  color: AppColors.accentBright,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                best.normalizedScore.toStringAsFixed(0),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'pts',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$date  ·  ${mins}m${secs.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = ThemeService.instance.isDark;
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accentBright, width: 2),
          ),
          child: Center(
            child: Text(
              widget.pseudo.isNotEmpty ? widget.pseudo[0].toUpperCase() : '?',
              style: TextStyle(
                color: AppColors.accentBright,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.pseudo,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${_results.length} partie${_results.length > 1 ? 's' : ''} jouée${_results.length > 1 ? 's' : ''}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => ThemeService.instance.toggle(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isDark ? '🌙' : '☀️', style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  isDark ? 'Sombre' : 'Clair',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _bestCoupDoeil => _coupDoeil.isEmpty
      ? '—'
      : '${_coupDoeil.map((r) => r.normalizedScore).reduce((a, b) => a > b ? a : b).toStringAsFixed(0)} pts';

  String get _bestCompos => _compos.isEmpty
      ? '—'
      : '${_compos.map((r) => r.normalizedScore).reduce((a, b) => a > b ? a : b).toStringAsFixed(0)}%';

  Widget _buildGlobalStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _StatTile(label: 'Parties', value: '${_results.length}', small: true)),
          _divider(),
          Expanded(child: _StatTile(label: 'Temps total', value: _formatDuration(_totalTime), small: true)),
          _divider(),
          Expanded(child: _StatTile(label: "Meilleur Coup d'Œil", value: _bestCoupDoeil, small: true)),
          _divider(),
          Expanded(child: _StatTile(label: 'Meilleur Compos', value: _bestCompos, small: true)),
        ],
      ),
    );
  }

  Widget _buildGameSection({
    required String title,
    required IconData icon,
    required List<GameResult> results,
    required List<_StatData> extraStats,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accentBright, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '${results.length} partie${results.length > 1 ? 's' : ''}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (results.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: extraStats
                  .map((s) => _StatTile(label: s.label, value: s.value))
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Pas encore de partie jouée.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiplayerSection() {
    final mp = _multiplayerCompos;
    final total = mp.length;
    final wins = _multiplayerWins;
    final losses = _multiplayerLosses;
    final winRate = total > 0 ? (wins / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, color: Color(0xFF58A6FF), size: 16),
              const SizedBox(width: 8),
              Text(
                'Compos 1v1',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '$total partie${total > 1 ? 's' : ''}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          if (mp.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatTile(label: 'Victoires', value: '$wins'),
                _StatTile(label: 'Défaites', value: '$losses'),
                _StatTile(label: '% victoires', value: '$winRate%'),
              ],
            ),
            const SizedBox(height: 14),
            ...mp.take(3).map(_buildMultiplayerRow),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Pas encore de partie jouée.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiplayerRow(GameResult r) {
    final won = r.details['won'] == true;
    final abandoned = r.details['abandoned'] == true;
    final opponent = r.details['opponentPseudo'] as String? ?? '?';
    final matchName = r.details['matchName'] as String? ?? '';
    final foundByMe = r.details['foundByMe'] as int? ?? 0;
    final foundByOpp = r.details['foundByOpponent'] as int? ?? 0;
    final date = '${r.playedAt.day}/${r.playedAt.month}/${r.playedAt.year % 100}';

    final Color tagColor;
    final String tagText;
    if (abandoned) {
      tagColor = AppColors.amber;
      tagText = 'Abandon';
    } else if (won) {
      tagColor = AppColors.accentBright;
      tagText = 'Victoire';
    } else {
      tagColor = AppColors.red;
      tagText = 'Défaite';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tagText,
              style: TextStyle(
                color: tagColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs $opponent',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (matchName.isNotEmpty)
                  Text(
                    matchName,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$foundByMe – $foundByOpp',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                date,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(GameResult r) {
    if (r.gameType == GameType.multiplayerCompos) {
      return _buildMultiplayerRow(r);
    }
    final isCompos = r.gameType == GameType.compos;
    final cat = r.details['category'] as String?;
    final label = isCompos
        ? (r.details['matchName'] as String? ?? 'Compos')
        : (cat != null && cat.isNotEmpty)
            ? "Coup d'Œil · ${r.difficulty} · $cat"
            : "Coup d'Œil · ${r.difficulty}";
    final date = '${r.playedAt.day}/${r.playedAt.month}/${r.playedAt.year % 100}';
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
          Icon(
            isCompos ? Icons.format_list_bulleted : Icons.remove_red_eye_outlined,
            color: AppColors.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                date,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              Text(
                r.normalizedScore.toStringAsFixed(0),
                style: TextStyle(
                  color: AppColors.accentBright,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      );

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: AppColors.border,
      );
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _StatData {
  final String label;
  final String value;
  const _StatData(this.label, this.value);
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool small;
  const _StatTile({required this.label, required this.value, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: small ? 14 : 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
