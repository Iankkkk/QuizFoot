// parcours_joueur_api.dart
//
// Loads "Parcours Joueur" data from two SheetDB sheets and joins them by id:
//   • ParcoursJoueur        → player meta
//   • ParcoursJoueurDETAILS → career rows (ordered by seq)
// Same SheetDB project as Matches/Lineups. Cached 30 min via DataCache.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/parcours_joueur.dart';
import 'api_exception.dart';
import 'data_cache.dart';

class ParcoursJoueurApi {
  static const String baseUrl = "https://sheetdb.io/api/v1/awu5uvi0qdn9s";

  static Future<List<ParcoursPlayer>> fetchPlayers() async {
    final cached = DataCache.instance.parcoursPlayers;
    if (cached != null) return cached;

    try {
      final responses = await Future.wait([
        http
            .get(Uri.parse('$baseUrl?sheet=ParcoursJoueur'))
            .timeout(const Duration(seconds: 10)),
        http
            .get(Uri.parse('$baseUrl?sheet=ParcoursJoueurDETAILS'))
            .timeout(const Duration(seconds: 10)),
      ]);

      for (final r in responses) {
        if (r.statusCode != 200) {
          throw ApiException(
            type: ApiErrorType.serverError,
            message: 'Erreur API SheetDB : ${r.statusCode}',
          );
        }
      }

      final List<dynamic> playersJson = jsonDecode(responses[0].body);
      final List<dynamic> careersJson = jsonDecode(responses[1].body);

      // Group career rows by player id.
      final Map<int, List<CareerEntry>> careerByPlayer = {};
      for (final row in careersJson) {
        final pid = int.tryParse(row['id']?.toString() ?? '');
        if (pid == null) continue;
        careerByPlayer
            .putIfAbsent(pid, () => [])
            .add(CareerEntry.fromJson(row));
      }
      for (final list in careerByPlayer.values) {
        list.sort((a, b) => a.seq.compareTo(b.seq));
      }

      final players = <ParcoursPlayer>[];
      for (final pj in playersJson) {
        final pid = int.tryParse(pj['id']?.toString() ?? '');
        if (pid == null) continue;
        players.add(
          ParcoursPlayer.fromJson(pj, careerByPlayer[pid] ?? const []),
        );
      }

      DataCache.instance.setParcoursPlayers(players);
      return players;
    } on SocketException {
      throw const ApiException(
        type: ApiErrorType.noInternet,
        message: 'Pas de connexion internet',
      );
    } on TimeoutException {
      throw const ApiException(
        type: ApiErrorType.timeout,
        message: 'Délai dépassé lors du chargement des parcours',
      );
    } on FormatException {
      throw const ApiException(
        type: ApiErrorType.parseError,
        message: 'Données parcours invalides',
      );
    }
  }
}
