import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/result_page.dart';
import 'pages/history_page.dart';
import 'pages/qui_a_menti.dart';
import 'pages/parcours_joueur_page.dart';
import 'pages/lineup_match_page.dart';
import 'pages/quiz_test_intro.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Football',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        fontFamily: 'Oswald', // ← Oswald par défaut pour tous les textes
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
          displayMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
          displaySmall: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          bodyLarge: TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
          bodyMedium: TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
          labelLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 20), // pour les boutons
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/quiz_test': (context) => const QuizTestIntro(),
        '/result_page': (context) => const ResultPage(score: 0),
        '/history_page': (context) => const HistoryPage(),
        '/qui_a_menti': (context) => const QuiAMentiPage(),
        '/parcours_joueur': (context) => const ParcoursJoueurPage(),
        '/lineup_match': (context) => const LineupMatchPage(),
      },
    );
  }
}
