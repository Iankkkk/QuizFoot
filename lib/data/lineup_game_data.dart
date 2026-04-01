import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/match_model.dart';
import '../models/lineup_model.dart';
import 'api_exception.dart';
import 'data_cache.dart';

Future<List<Match>> loadMatches() async {
  final cached = DataCache.instance.matches;
  if (cached != null) return cached;

  final url = Uri.parse('https://sheetdb.io/api/v1/awu5uvi0qdn9s?sheet=Matches');
  try {
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw ApiException(
        type: ApiErrorType.serverError,
        message: 'Impossible de charger les matchs : ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList = json.decode(response.body);
    final matches = jsonList.map((jsonItem) => Match.fromJson(jsonItem)).toList();
    DataCache.instance.setMatches(matches);
    return matches;
  } on SocketException {
    throw const ApiException(
      type: ApiErrorType.noInternet,
      message: 'Pas de connexion internet',
    );
  } on TimeoutException {
    throw const ApiException(
      type: ApiErrorType.timeout,
      message: 'Délai dépassé lors du chargement des matchs',
    );
  } on FormatException {
    throw const ApiException(
      type: ApiErrorType.parseError,
      message: 'Données matchs invalides',
    );
  }
}

Future<List<Lineup>> loadLineups(String matchId) async {
  final cached = DataCache.instance.lineups;
  if (cached != null) return cached;

  final url = Uri.parse('https://sheetdb.io/api/v1/awu5uvi0qdn9s?sheet=Lineups');
  try {
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw ApiException(
        type: ApiErrorType.serverError,
        message: 'Impossible de charger les lineups : ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList = json.decode(response.body);
    final lineups = jsonList.map((jsonItem) => Lineup.fromJson(jsonItem)).toList();
    DataCache.instance.setLineups(lineups);
    return lineups;
  } on SocketException {
    throw const ApiException(
      type: ApiErrorType.noInternet,
      message: 'Pas de connexion internet',
    );
  } on TimeoutException {
    throw const ApiException(
      type: ApiErrorType.timeout,
      message: 'Délai dépassé lors du chargement des lineups',
    );
  } on FormatException {
    throw const ApiException(
      type: ApiErrorType.parseError,
      message: 'Données lineups invalides',
    );
  }
}
