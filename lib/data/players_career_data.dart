import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/player_career.dart';
import 'api_exception.dart';

Future<List<PlayerCareer>> loadCareerPlayers() async {
  final url = Uri.parse('https://sheetdb.io/api/v1/awu5uvi0qdn9s?sheet=ParcoursJoueur');
  try {
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw ApiException(
        type: ApiErrorType.serverError,
        message: 'Impossible de charger les joueurs carrière : ${response.statusCode}',
      );
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((jsonItem) => PlayerCareer.fromJson(jsonItem)).toList();
  } on SocketException {
    throw const ApiException(
      type: ApiErrorType.noInternet,
      message: 'Pas de connexion internet',
    );
  } on TimeoutException {
    throw const ApiException(
      type: ApiErrorType.timeout,
      message: 'Délai dépassé lors du chargement des carrières',
    );
  } on FormatException {
    throw const ApiException(
      type: ApiErrorType.parseError,
      message: 'Données carrières invalides',
    );
  }
}
