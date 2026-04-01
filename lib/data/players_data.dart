import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/player.dart';
import 'api_exception.dart';
import 'package:http/http.dart' as http;

Future<List<Player>> loadPlayers() async {
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
    return jsonList
        .map((jsonItem) => Player.fromJson(jsonItem))
        .where((p) => p.isValid)
        .toList();
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
