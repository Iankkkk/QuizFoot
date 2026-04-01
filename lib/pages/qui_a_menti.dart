import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quiz_foot/data/qui_a_menti_api.dart';
import 'package:quiz_foot/data/api_exception.dart';

/// Modèle minimal pour un "candidat" à classer.
class Candidate {
  final String name;       // Nom complet affiché sur la carte
  final bool isTrueForClaim; // Indique si (selon nos données) l'affirmation est vraie pour ce joueur

  Candidate({required this.name, required this.isTrueForClaim});

  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      name: json['name'] ?? 'Inconnu',
      isTrueForClaim: json['isTrue']?.toString().toLowerCase() == 'true',
    );
  }
}

/// Page de jeu "Qui a menti ?"
class QuiAMentiPage extends StatefulWidget {
  const QuiAMentiPage({super.key});

  @override
  State<QuiAMentiPage> createState() => _QuiAMentiPageState();
}

class _QuiAMentiPageState extends State<QuiAMentiPage> {
  String claim = ""; // <-- claim désormais chargé dynamiquement

  List<Candidate> _allCandidates = [];
  late List<Candidate> _toClassify;
  final List<Candidate> _trueBucket = [];
  final List<Candidate> _falseBucket = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
  try {
    // On récupère tous les claims
    final claims = await QuiAMentiApi.fetchRandomClaim();

    if (claims.isEmpty) {
      throw Exception("Aucun claim trouvé.");
    }

    // Claim aléatoire
    final rnd = Random();
    final picked = claims[rnd.nextInt(claims.length)];

    // Construction des 10 candidats
    final candidates = picked.candidates
        .map((p) => Candidate(name: p.name, isTrueForClaim: p.isTrue))
        .toList();

    if (candidates.length != 10) {
      throw Exception("Le claim sélectionné ne contient pas exactement 10 joueurs (trouvés: ${candidates.length}).");
    }

    setState(() {
      claim = picked.claim;
      _allCandidates = candidates;
      _toClassify = List<Candidate>.from(_allCandidates);
      _toClassify.shuffle();
      _trueBucket.clear();
      _falseBucket.clear();
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


  void _moveCandidate(Candidate c, List<Candidate> target) {
    if (target.length >= 5) return; // Limite max de 5 cartes

    setState(() {
      _toClassify.remove(c);
      _trueBucket.remove(c);
      _falseBucket.remove(c);
      target.add(c);
    });
  }

  Widget _draggableCard(Candidate c) {
    return Draggable<Candidate>(
      data: c,
      child: _candidateChip(c),
      feedback: Material(
        color: Colors.transparent,
        child: _candidateChip(c, elevated: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _candidateChip(c),
      ),
    );
  }

  Widget _candidateChip(Candidate c, {bool elevated = false}) {
    return Card(
      elevation: elevated ? 4 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          c.name,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _dropZone({
    required String title,
    required List<Candidate> bucket,
  }) {
    return DragTarget<Candidate>(
      onWillAccept: (_) => true,
      onAccept: (candidate) => _moveCandidate(candidate, bucket),
      builder: (context, candidateData, rejected) {
        return Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12, width: 1.2),
          ),
          child: Column(
            children: [
              Text(
                "$title (${bucket.length}/5)",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in bucket) _draggableCard(c),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toClassifyColumn() {
  return DragTarget<Candidate>(
    onWillAccept: (_) => true,
    onAccept: (candidate) {
      setState(() {
        _trueBucket.remove(candidate);
        _falseBucket.remove(candidate);
        if (!_toClassify.contains(candidate)) {
          _toClassify.add(candidate);
        }
      });
    },
    builder: (context, candidateData, rejected) {
      return Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "À classer",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _toClassify) _draggableCard(c),
              ],
            ),
          ],
        ),
      );
    },
  );
}


  void _validate() {
    if (_trueBucket.length != 5 || _falseBucket.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Tu dois mettre exactement 5 joueurs dans chaque colonne !"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    int correct = 0;
    for (var c in _trueBucket) {
      if (c.isTrueForClaim) correct++;
    }
    for (var c in _falseBucket) {
      if (!c.isTrueForClaim) correct++;
    }

    final success = correct == 10;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "🎉 Bravo, tout est correct !"
              : "Tu as $correct/10 bonnes réponses. Essaie encore 😉",
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );

    if (success) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Qui a menti ?"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Card(
                      color: Colors.amber.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.campaign, size: 26),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                claim,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: _dropZone(title: "✅ VRAI", bucket: _trueBucket)),
                                Expanded(child: _dropZone(title: "❌ FAUX", bucket: _falseBucket)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _toClassifyColumn(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _validate,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Valider", style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
