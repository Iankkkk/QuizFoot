import 'package:flutter/material.dart';
import 'package:diacritic/diacritic.dart';
import '../models/player_career.dart';
import '../data/players_career_data.dart';
import '../data/api_exception.dart';

class ParcoursJoueurPage extends StatefulWidget {
  const ParcoursJoueurPage({super.key});

  @override
  State<ParcoursJoueurPage> createState() => _ParcoursJoueurPageState();
}

class _ParcoursJoueurPageState extends State<ParcoursJoueurPage> {
  List<PlayerCareer> _players = [];
  PlayerCareer? _currentPlayer;
  bool _isLoading = true;
  String _answer = '';
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    try {
      final players = await loadCareerPlayers();
      players.shuffle(); // mélange aléatoire
      setState(() {
        _players = players;
        _currentPlayer = _players.first;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.userMessage),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur inattendue. Réessaie.'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _checkAnswer() {
    final trimmedAnswer = removeDiacritics(_answer.trim().toLowerCase());
    final correctAnswer = removeDiacritics(_currentPlayer!.name.toLowerCase());

    bool isCorrect = trimmedAnswer == correctAnswer;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCorrect
              ? '✅ Bonne réponse !'
              : '❌ Mauvaise réponse ! La bonne réponse était : ${_currentPlayer!.name}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isCorrect ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    if (_players.indexOf(_currentPlayer!) < _players.length - 1) {
      setState(() {
        _currentPlayer = _players[_players.indexOf(_currentPlayer!) + 1];
        _answer = '';
        _controller.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fin du parcours !")),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentPlayer == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Parcours Joueur"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carrière du joueur
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._currentPlayer!.careerClubs.map(
                      (club) => Text(
                        '• ${club.clubName} (${club.startYear}-${club.endYear})',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Champ de saisie
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Quel joueur est-ce ?",
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _answer = value);
              },
              onSubmitted: (_) {
                if (_answer.trim().isNotEmpty) _checkAnswer();
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _answer.trim().isEmpty ? null : _checkAnswer,
              child: const Text("Valider"),
            ),
          ],
        ),
      ),
    );
  }
}