import 'package:flutter/material.dart';
import 'package:diacritic/diacritic.dart';
import 'package:collection/collection.dart';
import 'package:string_similarity/string_similarity.dart';
import '../data/lineup_game_data.dart';
import '../models/match_model.dart';
import '../models/lineup_model.dart';

class LineupMatchPage extends StatefulWidget {
  const LineupMatchPage({super.key});

  @override
  State<LineupMatchPage> createState() => _LineupMatchPageState();
}

class _LineupMatchPageState extends State<LineupMatchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  int _score = 0;
  int _errors = 0;

  List<Match> _matches = [];
  Match? _selectedMatch;

  List<Lineup> _lineups = [];
  bool _isLoading = true;

  final Set<String> _foundPlayers = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMatches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final matches = await loadMatches();
      setState(() {
        _matches = matches;
        if (matches.isNotEmpty) {
          _selectedMatch = (matches..shuffle()).first;
        }
      });
      if (_selectedMatch != null) {
        await _loadLineups(_selectedMatch!.matchId);
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des matchs : $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLineups(String matchId) async {
    setState(() => _isLoading = true);
    try {
      final allLineups = await loadLineups(matchId);

      // Filtrer uniquement les lineups du match sélectionné
      final matchLineups = allLineups
          .where((l) => l.matchId == matchId)
          .toList();

      // Trier d'abord les joueurs de home_team puis ceux de away_team
      matchLineups.sort((a, b) {
        if (a.teamName == _selectedMatch?.homeTeam &&
            b.teamName == _selectedMatch?.awayTeam) {
          return -1;
        } else if (a.teamName == _selectedMatch?.awayTeam &&
            b.teamName == _selectedMatch?.homeTeam) {
          return 1;
        } else {
          return 0;
        }
      });

      // Dédoublonner les joueurs par playerName
      final uniqueLineups = {
        for (var l in matchLineups) l.playerName: l,
      }.values.toList();

      setState(() {
        _lineups = uniqueLineups;
        _foundPlayers.clear();
        _score = 0;
        _errors = 0;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des lineups : $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _normalizeLastName(String fullName) {
    final normalized = removeDiacritics(
      fullName.toLowerCase(),
    ).replaceAll('.', '').trim();

    return normalized;
  }

  void _checkPlayer() {
    final inputRaw = _controller.text.trim();
    if (inputRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un nom de joueur.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final answerNormalized = removeDiacritics(
      inputRaw.toLowerCase(),
    ).replaceAll('.', '').trim();

    Lineup? exactMatch;
    Lineup? closeMatch;

    for (final lineup in _lineups) {
      final lastName = _normalizeLastName(lineup.playerName);

      if (lastName == answerNormalized) {
        exactMatch = lineup;
        break;
      }

      if (lastName.similarityTo(answerNormalized) >= 0.6) {
        closeMatch ??= lineup;
      }
    }

    // 🔴 PRIORITÉ ABSOLUE : joueur déjà trouvé
    if (exactMatch != null && _foundPlayers.contains(exactMatch.playerName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu as déjà trouvé ce joueur.'),
          duration: Duration(seconds: 1),
        ),
      );
      _controller.clear();
      return;
    }

    // ✅ Bonne réponse
    if (exactMatch != null) {
      setState(() {
        _foundPlayers.add(exactMatch!.playerName);
        _score++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Correct !'),
          duration: Duration(seconds: 1),
        ),
      );
      _controller.clear();
      return;
    }

    // 🟡 Presque (similarité)
    if (closeMatch != null && _foundPlayers.contains(closeMatch.playerName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu as déjà trouvé ce joueur.'),
          duration: Duration(seconds: 1),
        ),
      );
      _controller.clear();
      return;
    }

    if (closeMatch != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🟡 Essaye encore !'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // ❌ Faux
    setState(() {
      _errors++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ Faux !'), duration: Duration(seconds: 1)),
    );

    if (_errors >= 6) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Jeu terminé'),
          content: Text('Nombre d\'erreurs atteint. Score final: $_score'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _foundPlayers.clear();
                  _score = 0;
                  _errors = 0;
                });
              },
              child: const Text('Recommencer'),
            ),
          ],
        ),
      );
    }

    _controller.clear();
  }

  Widget _buildTeamFormation(String teamName) {
    final starters = _lineups
        .where((l) => l.teamName == teamName && l.starter)
        .toList();
    final substitutes = _lineups
        .where((l) => l.teamName == teamName && !l.starter)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Titulaires', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: starters.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final player = starters[index];
            final isFound = _foundPlayers.contains(player.playerName);
            return CircleAvatar(
              radius: 30,
              backgroundColor: isFound ? Colors.green : Colors.grey[300],
              child: isFound
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          player.playerName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          player.position,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      player.position,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Remplaçants', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: substitutes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final player = substitutes[index];
              final isFound = _foundPlayers.contains(player.playerName);
              return CircleAvatar(
                radius: 30,
                backgroundColor: isFound ? Colors.green : Colors.grey[300],
                child: isFound
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            player.playerName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            player.position,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        player.position,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compositions de match')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_selectedMatch != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _selectedMatch!.matchName,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    TabBar(
                      controller: _tabController,
                      tabs: [
                        Tab(text: _selectedMatch?.homeTeam ?? 'Home Team'),
                        Tab(text: _selectedMatch?.awayTeam ?? 'Away Team'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Tape un joueur',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _checkPlayer(),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _checkPlayer,
                      child: const Text('Valider'),
                    ),
                    const SizedBox(height: 10),
                    Text('Score: $_score'),
                    const SizedBox(height: 8),
                    Text('Erreurs restantes: ${6 - _errors}'),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 400,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          SingleChildScrollView(
                            child: _buildTeamFormation(
                              _selectedMatch?.homeTeam ?? '',
                            ),
                          ),
                          SingleChildScrollView(
                            child: _buildTeamFormation(
                              _selectedMatch?.awayTeam ?? '',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
