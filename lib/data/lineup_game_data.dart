import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match_model.dart';
import '../models/lineup_model.dart';
import 'api_exception.dart';
import 'data_cache.dart';

const _matchesKey    = 'matches_json';
const _matchesExpiry = 'matches_expiry';
const _lineupsKey    = 'lineups_json';
const _lineupsExpiry = 'lineups_expiry';
const _persistTtl    = Duration(hours: 6);

Future<List<Match>> loadMatches() async {
  // 1. Cache in-memory
  final cached = DataCache.instance.matches;
  if (cached != null) return cached;

  // 2. Cache persistant
  try {
    final prefs = await SharedPreferences.getInstance();
    final stored    = prefs.getString(_matchesKey);
    final expiryStr = prefs.getString(_matchesExpiry);
    if (stored != null && expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isBefore(expiry)) {
        final List<dynamic> jsonList = json.decode(stored);
        final matches = jsonList.map((e) => Match.fromJson(Map<String, dynamic>.from(e))).toList();
        DataCache.instance.setMatches(matches);
        return matches;
      }
    }
  } catch (_) {}

  // 3. API
  final url = Uri.parse('https://sheetdb.io/api/v1/awu5uvi0qdn9s?sheet=Matches');
  try {
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw ApiException(type: ApiErrorType.serverError, message: 'Impossible de charger les matchs : ${response.statusCode}');
    }
    final List<dynamic> jsonList = json.decode(response.body);
    final matches = jsonList.map((e) => Match.fromJson(e)).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString(_matchesKey, response.body);
      prefs.setString(_matchesExpiry, DateTime.now().add(_persistTtl).toIso8601String());
    } catch (_) {}
    DataCache.instance.setMatches(matches);
    return matches;
  } on SocketException {
    throw const ApiException(type: ApiErrorType.noInternet, message: 'Pas de connexion internet');
  } on TimeoutException {
    throw const ApiException(type: ApiErrorType.timeout, message: 'Délai dépassé lors du chargement des matchs');
  } on FormatException {
    throw const ApiException(type: ApiErrorType.parseError, message: 'Données matchs invalides');
  }
}

Future<List<Lineup>> loadLineups(String matchId) async {
  // 1. Cache in-memory
  final cached = DataCache.instance.lineups;
  if (cached != null) return cached;

  // 2. Cache persistant
  try {
    final prefs = await SharedPreferences.getInstance();
    final stored    = prefs.getString(_lineupsKey);
    final expiryStr = prefs.getString(_lineupsExpiry);
    if (stored != null && expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isBefore(expiry)) {
        final List<dynamic> jsonList = json.decode(stored);
        final lineups = jsonList.map((e) => Lineup.fromJson(Map<String, dynamic>.from(e))).toList();
        DataCache.instance.setLineups(lineups);
        return lineups;
      }
    }
  } catch (_) {}

  // 3. API
  final url = Uri.parse('https://sheetdb.io/api/v1/awu5uvi0qdn9s?sheet=Lineups');
  try {
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw ApiException(type: ApiErrorType.serverError, message: 'Impossible de charger les lineups : ${response.statusCode}');
    }
    final List<dynamic> jsonList = json.decode(response.body);
    final lineups = jsonList.map((e) => Lineup.fromJson(e)).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString(_lineupsKey, response.body);
      prefs.setString(_lineupsExpiry, DateTime.now().add(_persistTtl).toIso8601String());
    } catch (_) {}
    DataCache.instance.setLineups(lineups);
    return lineups;
  } on SocketException {
    throw const ApiException(type: ApiErrorType.noInternet, message: 'Pas de connexion internet');
  } on TimeoutException {
    throw const ApiException(type: ApiErrorType.timeout, message: 'Délai dépassé lors du chargement des lineups');
  } on FormatException {
    throw const ApiException(type: ApiErrorType.parseError, message: 'Données lineups invalides');
  }
}

/// Précharge Matches + Lineups en parallèle au lancement.
Future<void> preloadComposData() async {
  await Future.wait([loadMatches(), loadLineups('')]);
}
