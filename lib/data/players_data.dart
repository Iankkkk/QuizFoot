import 'dart:convert';
import '../models/player.dart';
import 'package:http/http.dart' as http;

Future<List<Player>> loadPlayers() async {
  final url = Uri.parse('https://sheetdb.io/api/v1/awu5uvi0qdn9s');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((jsonItem) => Player.fromJson(jsonItem)).toList();
  } else {
    throw Exception('Impossible de charger les joueurs : ${response.statusCode}');
  }
}