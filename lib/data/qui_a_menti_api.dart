import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/claim.dart';
import 'api_exception.dart';
import 'data_cache.dart';

class QuiAMentiApi {
  static const String baseUrl = "https://sheetdb.io/api/v1/g2jtj2ps4cm5o";

  static Future<List<Claim>> fetchRandomClaim() async {
    final cached = DataCache.instance.claims;
    if (cached != null) return cached;

    try {
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw ApiException(
          type: ApiErrorType.serverError,
          message: 'Erreur API SheetDB : ${response.statusCode}',
        );
      }

      final List<dynamic> data = jsonDecode(response.body);
      final claims = data.map((json) => Claim.fromJson(json)).toList();
      DataCache.instance.setClaims(claims);
      return claims;
    } on SocketException {
      throw const ApiException(
        type: ApiErrorType.noInternet,
        message: 'Pas de connexion internet',
      );
    } on TimeoutException {
      throw const ApiException(
        type: ApiErrorType.timeout,
        message: 'Délai dépassé lors du chargement des claims',
      );
    } on FormatException {
      throw const ApiException(
        type: ApiErrorType.parseError,
        message: 'Données claims invalides',
      );
    }
  }
}
