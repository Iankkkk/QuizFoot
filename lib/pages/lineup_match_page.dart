import 'package:flutter/material.dart';
import 'package:diacritic/diacritic.dart';
import 'package:collection/collection.dart';
import 'package:string_similarity/string_similarity.dart';
import '../data/lineup_game_data.dart';
import '../models/match_model.dart';
import '../models/lineup_model.dart';

class LineupMatchPage extends StatefulWidget {
  const LineupMatchPage({super.key, required this.difficulty});

  final String difficulty;

  @override
  State<LineupMatchPage> createState() => _LineupMatchPageState();
}

int _difficultyToLevel(String difficulty) {
  switch (difficulty) {
    case 'Très Facile':
      return 1;
    case 'Facile':
      return 2;
    case 'Moyenne':
      return 3;
    case 'Difficile':
      return 4;
    case 'Impossible':
      return 5;
    default:
      return 3; // fallback safe
  }
}

class _LineupMatchPageState extends State<LineupMatchPage>
    with SingleTickerProviderStateMixin {
  String get difficulty => widget.difficulty;
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

      final int targetLevel = _difficultyToLevel(difficulty);

      final filteredMatches = matches
          .where((m) => m.level == targetLevel)
          .toList();

      setState(() {
        _matches = filteredMatches;

        if (filteredMatches.isNotEmpty) {
          _selectedMatch = (filteredMatches..shuffle()).first;
        } else {
          _selectedMatch = null;
        }
      });

      if (_selectedMatch == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun match disponible pour cette difficulté'),
          ),
        );
      }
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

      setState(() {
        _lineups = matchLineups;
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
    print(normalized);
    return normalized;
  }

  void _checkPlayer() {
    FocusScope.of(
      context,
    ).unfocus(); //fermer le clavier quand le user a validé une réponse

    final inputRaw = _controller.text.trim();
    if (inputRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un nom de joueur.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final answerNormalized = removeDiacritics(
      inputRaw.toLowerCase(),
    ).replaceAll('.', '').trim();

    final List<Lineup> exactMatches = [];
    final List<Lineup> closeMatches = [];

    for (final lineup in _lineups) {
      final lastName = _normalizeLastName(lineup.playerName);

      if (lastName == answerNormalized) {
        exactMatches.add(lineup);
      } else if (lastName.similarityTo(answerNormalized) >= 0.6) {
        closeMatches.add(lineup);
      }
    }

    final notFoundExact = exactMatches
        .where((l) => !_foundPlayers.contains(l.playerName))
        .toList();

    if (exactMatches.isNotEmpty && notFoundExact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu as déjà trouvé ce joueur.'),
          duration: Duration(seconds: 2),
        ),
      );
      _controller.clear();
      return;
    }

    // ✅ bonne(s) réponse(s)
    if (notFoundExact.isNotEmpty) {
      setState(() {
        for (final player in notFoundExact) {
          _foundPlayers.add(player.playerName);
        }
        _score += notFoundExact.length;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${notFoundExact.length} joueur(s) trouvé(s) !'),
          duration: const Duration(seconds: 2),
        ),
      );

      _controller.clear();
      return;
    }

    // 🔁 proche mais déjà trouvé
    final closeAlreadyFound = closeMatches
        .where((l) => _foundPlayers.contains(l.playerName))
        .toList();

    if (closeAlreadyFound.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu as déjà trouvé ce joueur.'),
          duration: Duration(seconds: 2),
        ),
      );
      _controller.clear();
      return;
    }

    // 🟡 presque
    final closeNotFound = closeMatches
        .where((l) => !_foundPlayers.contains(l.playerName))
        .toList();

    if (closeNotFound.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🟡 Essaye encore !'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // ❌ faux
    setState(() {
      _errors++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ Faux !'), duration: Duration(seconds: 2)),
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

            return PlayerShirt(player: player, isFound: isFound);
          },
        ),
        const SizedBox(height: 16),
        Text('Remplaçants', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: substitutes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final player = substitutes[index];
              final isFound = _foundPlayers.contains(player.playerName);

              return PlayerShirt(player: player, isFound: isFound);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compos')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_selectedMatch != null)
                      Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(
                                _selectedMatch!.matchName,
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabController,
                      tabs: [
                        Tab(text: _selectedMatch?.homeTeam ?? 'Home Team'),
                        Tab(text: _selectedMatch?.awayTeam ?? 'Away Team'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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

class PlayerShirt extends StatelessWidget {
  final Lineup player;
  final bool isFound;

  const PlayerShirt({super.key, required this.player, required this.isFound});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: isFound ? 1.35 : 1.0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.elasticOut,
          child: AnimatedOpacity(
            opacity: isFound ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 300),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/images/shirt.png',
                  width: 34,
                  height: 34,
                  color: Colors.black,
                  colorBlendMode: isFound ? null : BlendMode.modulate,
                ),

                if (isFound && player.playerNumber != null)
                  Positioned(
                    top: 12,
                    child: Text(
                      player.playerNumber.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (isFound) ...[
          const SizedBox(height: 4),
          Text(
            player.playerName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],
        const SizedBox(height: 1),

        // Poste (toujours visible)
        Text(
          player.position,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
