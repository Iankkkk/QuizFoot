import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_exception.dart';

const _prefKey = 'anecdotes_json';
const _prefExpiry = 'anecdotes_expiry';
const _persistTtl = Duration(hours: 6);

Future<List<String>> loadAnecdotes() async {
  // 1. Cache persistant (SharedPreferences)
  try {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    final expiryStr = prefs.getString(_prefExpiry);
    if (stored != null && expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isBefore(expiry)) {
        return List<String>.from(json.decode(stored));
      }
    }
  } catch (_) {}

  // 2. API
  final url = Uri.parse(
    'https://sheetdb.io/api/v1/awu5uvi0qdn9s?sheet=Anecdotes',
  );
  try {
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw ApiException(
        type: ApiErrorType.serverError,
        message: 'Impossible de charger les anecdotes : ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList = json.decode(response.body);
    final anecdotes = jsonList.map((item) => item['anecdote'] as String).toList();

    // Sauvegarder en persistant
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString(_prefKey, json.encode(anecdotes));
      prefs.setString(_prefExpiry, DateTime.now().add(_persistTtl).toIso8601String());
    } catch (_) {}

    return anecdotes;
  } on SocketException {
    throw const ApiException(
      type: ApiErrorType.noInternet,
      message: 'Pas de connexion internet',
    );
  } on TimeoutException {
    throw const ApiException(
      type: ApiErrorType.timeout,
      message: 'Délai dépassé lors du chargement des anecdotes',
    );
  } on FormatException {
    throw const ApiException(
      type: ApiErrorType.parseError,
      message: 'Données invalides',
    );
  }
}
