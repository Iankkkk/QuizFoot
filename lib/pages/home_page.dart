import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:quiz_foot/pages/quiz_test.dart';
import 'lineup_match_page.dart';
import 'parcours_joueur_page.dart';
import 'result_page.dart';
import 'qui_a_menti.dart';

// =======================
// FOND ANIMÉ (ballons)
// =======================
class AnimatedBallBackground extends StatefulWidget {
  const AnimatedBallBackground({super.key});

  @override
  _AnimatedBallBackgroundState createState() => _AnimatedBallBackgroundState();
}

class _AnimatedBallBackgroundState extends State<AnimatedBallBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  late List<Ball> _balls;
  ui.Image? _ballImage;

  @override
  void initState() {
    super.initState();
    _loadBallImage();
    _balls = List.generate(5, (index) {
      return Ball(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: 20 + _random.nextDouble() * 20,
        speed: (0.05 + _random.nextDouble() * 0.25) / 2, // vitesse divisée par 2
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(() {
        setState(() {
          for (var ball in _balls) {
            ball.y += ball.speed / 60;
            if (ball.y > 1.1) ball.y = -0.1;
          }
        });
      })
      ..repeat();
  }

  Future<void> _loadBallImage() async {
    final data = await rootBundle.load('assets/images/ball.png');
    final bytes = data.buffer.asUint8List();
    final image = await decodeImageFromList(bytes);
    setState(() {
      _ballImage = image;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ballImage == null) return const Center(child: CircularProgressIndicator());
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: BallPainter(_balls, _ballImage!),
    );
  }
}

class Ball {
  double x;
  double y;
  double radius;
  double speed;

  Ball({required this.x, required this.y, required this.radius, required this.speed});
}

class BallPainter extends CustomPainter {
  final List<Ball> balls;
  final ui.Image ballImage;
  BallPainter(this.balls, this.ballImage);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // Dégradé sombre et texturé
    final Gradient gradient = LinearGradient(
      colors: [
        Color(0xFF0E1A11), // vert très foncé, presque noir
        Color(0xFF1E5128), // vert bouteille profond
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final Paint backgroundPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, backgroundPaint);

    // Ajout d'une légère texture (bruit/grain simple)
    final Paint texturePaint = Paint()
      ..color = const Color(0x22000000)
      ..blendMode = BlendMode.softLight;
    for (int i = 0; i < 120; i++) {
      final double dx = (size.width) * (i / 120.0) + (i.isEven ? 4 : -4);
      final double dy = (size.height) * ((i * 37 % 100) / 100.0);
      canvas.drawCircle(Offset(dx, dy), 1.3, texturePaint);
    }

    for (var ball in balls) {
      final double imgWidth = ball.radius;
      final double imgHeight = ball.radius;
      final Offset offset = Offset(
        ball.x * size.width - imgWidth / 2,
        ball.y * size.height - imgHeight / 2,
      );
      canvas.drawImageRect(
        ballImage,
        Rect.fromLTWH(0, 0, ballImage.width.toDouble(), ballImage.height.toDouble()),
        Rect.fromLTWH(offset.dx, offset.dy, imgWidth, imgHeight),
        Paint(),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =======================
// PAGE D'ACCUEIL REFAITE
// =======================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Contenu principal selon l'onglet sélectionné
  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildGamesPage();
      case 2:
        return _buildHistoryContent();
      case 3:
        return _buildProfileContent();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    final List<String> phrases = [
      "Le foot, c’est dans la tête. Et un peu dans les doigts aussi.",
      "Apparemment tu connais le Football ? Prouve-le.",
      "CR7 ou Messi ? Peu importe, tant que tu gagnes.",
      "Chaque jour, un nouveau défi t’attend.",
      "Ton cerveau est ton meilleur pied.",
    ];
    final randomPhrase = (phrases..shuffle()).first;

    final List<String> anecdotes = [
      "En 2007, Messi a marqué un but quasi identique à celui de Maradona en 1986, 21 ans jour pour jour après.",
      "Le Brésil n’a jamais perdu un match de Coupe du Monde lorsqu’il menait à la mi-temps.",
      "Oliver Kahn a été élu meilleur joueur d’une Coupe du Monde en 2002, une première pour un gardien.",
      "Steven Gerrard n’a jamais remporté la Premier League malgré 17 saisons à Liverpool.",
    ];
    final randomAnecdote = (anecdotes..shuffle()).first;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 36),
            // Logo & nom
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: Image.asset('assets/images/logo.png'),
                  ),
                ),
                const SizedBox(width: 18),
                const Text(
                  'TEMPO',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w900,
                    fontSize: 36,
                    letterSpacing: 2,
                    color: Color(0xFFFCFFFD),
                    shadows: [
                      Shadow(
                        color: Color(0x33000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Le jeu, dans la tête.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Color(0xFFB8F2E6),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            // Phrase du jour style MPG
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF174423).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3CAE3A), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.format_quote, color: Color(0xFF3CAE3A), size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        randomPhrase,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFFB8F2E6),
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Anecdote du jour
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF16291A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3CAE3A), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "⚽ Anecdote du jour",
                      style: TextStyle(
                        color: Color(0xFF3CAE3A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      randomAnecdote,
                      style: const TextStyle(color: Color(0xFFB8F2E6), fontSize: 14.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Stats section MPG style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2F1A).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFF3CAE3A), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tes stats',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFFFCFFFD),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _StatItem(label: "Parties jouées", value: "127"),
                        _StatItem(label: "Score moyen", value: "7.4"),
                        _StatItem(label: "Jeu préféré", value: "Coup d’œil"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Section "À la une" style MPG
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: const [
                  Text(
                    'À la une',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                      color: Color(0xFFFCFFFD),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: const [
                  _HighlightCard(
                    title: "🔥 Nouveau mode Compos",
                    subtitle: "Revis les matchs mythiques et devine les compos !",
                    color: Color(0xFF2E8B57),
                  ),
                  _HighlightCard(
                    title: "⭐ 1000 parties jouées",
                    subtitle: "Merci à la communauté Tempo !",
                    color: Color(0xFF3CAE3A),
                  ),
                  _HighlightCard(
                    title: "⚽ Zidane ou Platini ?",
                    subtitle: "Teste ton flair dans Qui a menti ?",
                    color: Color(0xFF1E5128),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesPage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          children: [
            _MpgGameButton(
              title: "Coup d’œil",
              onTap: () => _showDifficultyDialog(context),
              icon: Icons.remove_red_eye,
              color: const Color(0xFF3CAE3A),
            ),
            const SizedBox(height: 14),
            _MpgGameButton(
              title: "Qui a menti ?",
              onTap: () => Navigator.pushNamed(context, '/qui_a_menti'),
              icon: Icons.psychology_alt_rounded,
              color: const Color(0xFF2E8B57),
            ),
            const SizedBox(height: 14),
            _MpgGameButton(
              title: "Parcours Joueur",
              onTap: () => Navigator.pushNamed(context, '/parcours_joueur'),
              icon: Icons.emoji_events,
              color: const Color(0xFF1E5128),
            ),
            const SizedBox(height: 14),
            _MpgGameButton(
              title: "Compos",
              onTap: () => Navigator.pushNamed(context, '/lineup_match'),
              icon: Icons.sports_soccer,
              color: const Color(0xFF174423),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent() {
    return const Center(
      child: Text(
        'Historique des scores...',
        style: TextStyle(color: Colors.white, fontSize: 22),
      ),
    );
  }

  Widget _buildProfileContent() {
    return const Center(
      child: Text(
        'Profil utilisateur...',
        style: TextStyle(color: Colors.white, fontSize: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedBallBackground(),
          _buildContent(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        selectedItemColor: Color(0xFF3CAE3A),
        unselectedItemColor: Colors.white70,
        backgroundColor: Color(0xFF1E5128),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer),
            label: 'Jeux',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ================
// DIALOGUE DIFFICULTÉ
// ================
void _showDifficultyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Choisis la difficulté"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _difficultyButton(context, "Très Facile"),
          _difficultyButton(context, "Facile"),
          _difficultyButton(context, "Moyenne"),
          _difficultyButton(context, "Difficile"),
          _difficultyButton(context, "Impossible"),
        ],
      ),
    ),
  );
}

Widget _difficultyButton(BuildContext context, String difficulty) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => QuizTest(difficulty: difficulty)),
        );
      },
      child: Text(difficulty),
    ),
  );
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF3CAE3A),
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB8F2E6),
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _HighlightCard({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.96),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF3CAE3A), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              color: Color(0xFFFCFFFD),
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              color: Color(0xFFB8F2E6),
              fontWeight: FontWeight.w400,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

// MPG-style game button for the games tab
class _MpgGameButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  const _MpgGameButton({
    required this.title,
    required this.onTap,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.97),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFB8F2E6), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 34),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 19,
                    color: Color(0xFFFCFFFD),
                  ),
                ),
              ),
              const Icon(Icons.play_arrow_rounded, color: Color(0xFFFCFFFD), size: 30),
            ],
          ),
        ),
      ),
    );
  }
}