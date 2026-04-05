import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player.dart';
import 'api_exception.dart';
import 'data_cache.dart';
import 'package:http/http.dart' as http;

const _prefKey = 'players_json';
const _prefExpiry = 'players_expiry';
const _persistTtl = Duration(hours: 6);

Future<List<Player>> loadPlayers() async {
  // 1. Cache in-memory
  final cached = DataCache.instance.players;
  if (cached != null) return cached;

  // 2. Cache persistant (SharedPreferences)
  try {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    final expiryStr = prefs.getString(_prefExpiry);
    if (stored != null && expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isBefore(expiry)) {
        final List<dynamic> jsonList = json.decode(stored);
        final players = jsonList
            .map((e) => Player.fromJson(Map<String, dynamic>.from(e)))
            .where((p) => p.isValid)
            .toList();
        DataCache.instance.setPlayers(players);
        return players;
      }
    }
  } catch (_) {}

  // 3. API
  final url = Uri.parse('https://sheetdb.io/api/v1/awu5uvi0qdn9s');
  try {
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw ApiException(
        type: ApiErrorType.serverError,
        message: 'Impossible de charger les joueurs : ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList = json.decode(response.body);
    final players = jsonList
        .map((jsonItem) => Player.fromJson(jsonItem))
        .where((p) => p.isValid)
        .toList();

    // Sauvegarder en persistant
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString(_prefKey, json.encode(players.map((p) => p.toJson()).toList()));
      prefs.setString(_prefExpiry, DateTime.now().add(_persistTtl).toIso8601String());
    } catch (_) {}

    DataCache.instance.setPlayers(players);
    return players;
  } on SocketException {
    throw const ApiException(
      type: ApiErrorType.noInternet,
      message: 'Pas de connexion internet',
    );
  } on TimeoutException {
    throw const ApiException(
      type: ApiErrorType.timeout,
      message: 'Délai dépassé lors du chargement des joueurs',
    );
  } on FormatException {
    throw const ApiException(
      type: ApiErrorType.parseError,
      message: 'Données joueurs invalides',
    );
  }
}
