import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_exception.dart';

Future<List<String>> loadAnecdotes() async {
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
    return jsonList.map((item) => item['anecdote'] as String).toList();
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
