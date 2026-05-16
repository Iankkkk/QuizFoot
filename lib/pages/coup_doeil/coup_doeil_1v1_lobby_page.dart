import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../data/difficulty_plans.dart';
import '../../data/players_data.dart';
import '../../models/player.dart';
import '../../services/coup_doeil_1v1_service.dart';
import '../../services/game_history_service.dart';
import '../../main.dart' show routeObserver;
import 'coup_doeil_1v1_waiting_room_page.dart';
import 'package:quiz_foot/utils/navigation.dart';

class CoupDoeil1v1LobbyPage extends StatefulWidget {
  const CoupDoeil1v1LobbyPage({super.key});

  @override
  State<CoupDoeil1v1LobbyPage> createState() => _CoupDoeil1v1LobbyPageState();
}

class _CoupDoeil1v1LobbyPageState extends State<CoupDoeil1v1LobbyPage>
    with RouteAware {
  static const List<String> _difficulties = [
    'Amateur',
    'Semi-Pro',
    'Pro',
    'International',
    'Légende',
  ];

  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    FocusScope.of(context).unfocus();
    _codeController.clear();
    setState(() => _error = null);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _codeController.dispose();
    super.dispose();
  }

  // ── Create : catégorie → difficulté ───────────────────────────────────────

  void _showCreatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryPicker(
        onSelected: (category) {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.card,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _DifficultyPicker(
                difficulties: _difficulties,
                onSelected: (difficulty) {
                  Navigator.pop(context);
                  _createRoom(category, difficulty);
                },
              ),
            );
          });
        },
      ),
    );
  }

  Future<void> _createRoom(String? category, String difficulty) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pseudo = await GameHistoryService.instance.getPseudo() ?? '';
      if (pseudo.isEmpty) throw Exception('Pseudo introuvable');

      final allPlayers = await loadPlayers();
      final filtered = category == null
          ? allPlayers
          : allPlayers.where((p) => p.categories.contains(category)).toList();
      final selected = _selectPlayers(filtered, difficulty);
      if (selected.length < 10)
        throw Exception('Pas assez de joueurs pour cette sélection.');

      // Validation des photos côté host : remplace les URL cassées par d'autres
      // joueurs du pool jusqu'à avoir 10 photos qui chargent.
      final validated = await _ensureWorkingPhotos(selected, filtered);
      if (validated.length < 10)
        throw Exception('Pas assez de photos disponibles. Réessaie.');

      final code = await CoupDoeil1v1Service.instance.createRoom(
        pseudo: pseudo,
        difficulty: difficulty,
        category: category,
        questionNames: validated.map((p) => p.name).toList(),
      );

      if (!mounted) return;
      Navigator.push(
        context,
        namedRoute(CoupDoeil1v1WaitingRoomPage(
          roomCode: code,
          pseudo: pseudo,
          isHost: true,
        )),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Join ───────────────────────────────────────────────────────────────────

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Le code doit faire 6 caractères');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pseudo = await GameHistoryService.instance.getPseudo() ?? '';
      if (pseudo.isEmpty) throw Exception('Pseudo introuvable');
      await CoupDoeil1v1Service.instance.joinRoom(code: code, pseudo: pseudo);
      if (!mounted) return;
      Navigator.push(
        context,
        namedRoute(CoupDoeil1v1WaitingRoomPage(
          roomCode: code,
          pseudo: pseudo,
          isHost: false,
        )),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Player selection ───────────────────────────────────────────────────────

  List<Player> _selectPlayers(List<Player> players, String difficulty) {
    final remaining = List<Player>.from(players)..shuffle();
    final selected = <Player>[];
    for (final step in kDifficultyPlans[difficulty] ?? []) {
      step.forEach((level, count) {
        for (int i = 0; i < count; i++) {
          final match = _pickRandom(remaining, level);
          if (match != null) {
            selected.add(match);
            remaining.remove(match);
          }
        }
      });
    }
    return selected;
  }

  Player? _pickRandom(List<Player> players, int level) {
    final matching = players.where((p) => p.level == level).toList()..shuffle();
    if (matching.isNotEmpty) return matching.first;
    final fallback = players.toList()
      ..sort(
        (a, b) => (a.level - level).abs().compareTo((b.level - level).abs()),
      );
    return fallback.isEmpty ? null : fallback.first;
  }

  // ── Photo validation ───────────────────────────────────────────────────────

  Future<bool> _imageLoads(String url) async {
    try {
      final completer = Completer<bool>();
      final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, __) { if (!completer.isCompleted) completer.complete(true); },
        onError: (_, __) { if (!completer.isCompleted) completer.complete(false); },
      );
      stream.addListener(listener);
      final ok = await completer.future.timeout(const Duration(seconds: 6), onTimeout: () => false);
      stream.removeListener(listener);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<List<Player>> _ensureWorkingPhotos(List<Player> selected, List<Player> pool) async {
    // Test les 10 sélectionnés en parallèle
    final results = await Future.wait(
      selected.map((p) async => (await _imageLoads(p.imageUrl)) ? p : null),
    );
    final valid = results.whereType<Player>().toList();

    if (valid.length >= 10) return valid;

    // Pioche dans le pool restant pour combler
    final remaining = List<Player>.from(pool)
      ..removeWhere((p) => selected.contains(p))
      ..shuffle();
    for (final p in remaining) {
      if (valid.length >= 10) break;
      if (await _imageLoads(p.imageUrl)) valid.add(p);
    }
    return valid;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Coup d'Œil 1v1",
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A2333), AppColors.bg],
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
                      '👁️',
                      style: TextStyle(
                        fontSize: 110,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Coup d'Œil 1v1",
                        style: TextStyle(
                          color: Color(0xFF58A6FF),
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Affronte un ami sur les mêmes 10 photos\nLe meilleur score l\'emporte !',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Règles ────────────────────────────────────────
                  Container(
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
                            Icon(
                              Icons.info_outline,
                              color: AppColors.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Règles du jeu',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...[
                          (
                            '🖼️',
                            '10 photos seront affichées, les mêmes pour vous deux',
                          ),
                          ('⏱️', '30 secondes maximum par photo'),
                          (
                            '🏃',
                            'Plus tu réponds vite, plus tu gagnes de points',
                          ),
                          ('🏆', 'Le plus grand score l\'emporte'),
                        ].map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.$1, style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    r.$2,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Créer ─────────────────────────────────────────
                  _SectionCard(
                    icon: Icons.add_circle_outline,
                    title: 'Créer une partie',
                    subtitle:
                        'Choisis la catégorie et la difficulté, puis partage le code',
                    color: AppColors.accentBright,
                    onTap: _loading ? null : _showCreatePicker,
                  ),

                  const SizedBox(height: 16),

                  // ── Rejoindre ─────────────────────────────────────
                  Container(
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
                            Icon(
                              Icons.login_outlined,
                              color: Color(0xFF58A6FF),
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Rejoindre une partie',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]'),
                            ),
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'CODE',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.4),
                              fontSize: 22,
                              letterSpacing: 6,
                              fontWeight: FontWeight.w800,
                            ),
                            filled: true,
                            fillColor: AppColors.bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Color(0xFF58A6FF),
                                width: 1.5,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _joinRoom(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF58A6FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _loading ? null : _joinRoom,
                            child: Text(
                              'Rejoindre',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Error ─────────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.red.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppColors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  if (_loading) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentBright,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets locaux ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CategoryPicker extends StatefulWidget {
  final void Function(String? category) onSelected;
  const _CategoryPicker({required this.onSelected});

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  List<String> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      if (mounted)
        setState(() {
          _categories = cats;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choisir la catégorie',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _categoryTile('Toutes les catégories', null),
                      ..._categories.map((c) => _categoryTile(c, c)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryTile(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => widget.onSelected(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.accentBright.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accentBright.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.accentBright,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.accentBright,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
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

class _DifficultyPicker extends StatelessWidget {
  final List<String> difficulties;
  final void Function(String) onSelected;
  const _DifficultyPicker({
    required this.difficulties,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choisir la difficulté',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...difficulties.map((diff) {
              final color = AppColors.forDifficulty(diff);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => onSelected(diff),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.3)),
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
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
