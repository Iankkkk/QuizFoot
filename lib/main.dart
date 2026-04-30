import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/result_page.dart';
import 'pages/qui_a_menti/qui_a_menti_intro.dart';
import 'pages/parcours_joueur_page.dart';
import 'pages/lineup/lineup_match_page.dart';
import 'pages/coup_doeil/quiz_test_intro.dart';
import 'data/lineup_game_data.dart';
import 'services/theme_service.dart';
import 'constants/app_colors.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ThemeService.instance.load();
  final prefs = await SharedPreferences.getInstance();
  final pseudo = prefs.getString('pseudo') ?? '';
  preloadComposData();
  runApp(MyApp(hasPseudo: pseudo.isNotEmpty));
}

class MyApp extends StatefulWidget {
  final bool hasPseudo;
  const MyApp({super.key, required this.hasPseudo});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  ThemeData _buildTheme(bool isDark) {
    final bg = AppColors.bg;
    final accent = AppColors.accentBright;
    final textPrimary = AppColors.textPrimary;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.spaceGroteskTextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ).copyWith(
        bodyLarge:   GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: textPrimary),
        bodyMedium:  GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w500, color: textPrimary),
        titleLarge:  GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: textPrimary),
        titleMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: textPrimary),
        labelLarge:  GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: textPrimary),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        secondary: accent,
        surface: AppColors.card,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.card,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: accent,
        contentTextStyle: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.instance.isDark;
    return MaterialApp(
      title: 'Quiz Football',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(isDark),
      navigatorObservers: [routeObserver],
      home: widget.hasPseudo ? const HomePage() : const OnboardingPage(),
      routes: {
        '/quiz_test':      (context) => const QuizTestIntro(),
        '/result_page':    (context) => const ResultPage(score: 0),
        '/qui_a_menti':    (context) => const QuiAMentiIntro(),
        '/parcours_joueur': (context) => const ParcoursJoueurPage(),
        '/lineup_match':   (context) => const LineupMatchPage(difficulty: 'Pro'),
      },
    );
  }
}
