import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/home_page.dart';
import 'pages/result_page.dart';
import 'pages/history_page.dart';
import 'pages/qui_a_menti/qui_a_menti_intro.dart';
import 'pages/parcours_joueur_page.dart';
import 'pages/lineup/lineup_match_page.dart';
import 'pages/coup_doeil/quiz_test_intro.dart';

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
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
        textTheme: GoogleFonts.poppinsTextTheme().apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ).copyWith(
          bodyLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          bodyMedium: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          labelLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7F4F),
          primary: const Color(0xFF1E7F4F),
          secondary: const Color(0xFF2FA36B),
          surface: Colors.white,
          background: const Color(0xFFF5F6F8),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1E7F4F),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            textStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF1E7F4F)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),

        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF1E7F4F),
          contentTextStyle: TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/quiz_test': (context) => const QuizTestIntro(),
        '/result_page': (context) => const ResultPage(score: 0),
        '/history_page': (context) => const HistoryPage(),
        '/qui_a_menti': (context) => const QuiAMentiIntro(),
        '/parcours_joueur': (context) => const ParcoursJoueurPage(),
        '/lineup_match': (context) =>
            const LineupMatchPage(difficulty: 'Moyenne'),
      },
    );
  }
}
