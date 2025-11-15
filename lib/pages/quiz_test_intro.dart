import 'package:flutter/material.dart';
import 'dart:math';
import 'quiz_test.dart';

class QuizTestIntro extends StatelessWidget {
  const QuizTestIntro({super.key});

  final List<String> difficulties = const [
    "Très Facile",
    "Facile",
    "Moyenne",
    "Difficile",
    "Impossible",
  ];

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case "Très Facile":
        return Colors.green.shade400;
      case "Facile":
        return Colors.lightGreen.shade600;
      case "Moyenne":
        return Colors.amber.shade700;
      case "Difficile":
        return Colors.orange.shade700;
      case "Impossible":
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  final List<IconData> ruleIcons = const [
    Icons.photo_camera,
    Icons.format_list_numbered,
    Icons.timer_off,
    Icons.keyboard,
    Icons.star,
    Icons.skip_next,
  ];

  final List<String> rules = const [
    "Devine le joueur à partir de sa photo.",
    "10 photos seront affichés.",
    "Il n'y a aucune limite de temps",
    "Tape le NOM DE FAMILLE du joueur dans la zone prévue.",
    "Chaque bonne réponse te rapporte un point..",
    "Tu peux passer si tu bloques.",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fond avec dégradé vert
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFa8e063), Color(0xFF56ab2f)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Soccer field lines
          CustomPaint(
            size: Size.infinite,
            painter: SoccerFieldLinesPainter(),
          ),
          // Bouncing balls in background
          const Positioned.fill(child: BouncingBallsBackground()),
          Positioned(
            top: 50,
            left: 30,
            child: Opacity(
              opacity: 0.1,
              child: Icon(Icons.sports_soccer, size: 50, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 100,
            right: 50,
            child: Opacity(
              opacity: 0.1,
              child: Icon(Icons.sports_soccer, size: 60, color: Colors.white),
            ),
          ),
          Positioned(
            top: 200,
            right: 150,
            child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.sports_soccer, size: 40, color: Colors.white),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.95, end: 1.05),
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: Icon(
                        Icons.sports_soccer,
                        size: 80,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Bienvenue dans Coup d'œil !",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Règles du jeu :",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(rules.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  ruleIcons[index],
                                  size: 20,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rules[index],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: difficulties.length,
                      itemBuilder: (context, index) {
                        final diff = difficulties[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: _DifficultyButton(
                            label: diff,
                            color: _getDifficultyColor(diff),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QuizTest(difficulty: diff),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SoccerFieldLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final width = size.width;
    final height = size.height;

    // Draw outer rectangle (field border)
    final fieldRect = Rect.fromLTWH(width * 0.05, height * 0.05, width * 0.9, height * 0.9);
    canvas.drawRect(fieldRect, paint);

    // Center circle
    final center = Offset(width / 2, height / 2);
    final centerCircleRadius = min(width, height) * 0.15;
    canvas.drawCircle(center, centerCircleRadius, paint);

    // Center line
    canvas.drawLine(
      Offset(width / 2, height * 0.05),
      Offset(width / 2, height * 0.95),
      paint,
    );

    // Penalty areas (top and bottom)
    final penaltyWidth = width * 0.3;
    final penaltyHeight = height * 0.15;

    // Top penalty area
    final topPenaltyRect = Rect.fromCenter(
      center: Offset(width / 2, height * 0.05 + penaltyHeight / 2),
      width: penaltyWidth,
      height: penaltyHeight,
    );
    canvas.drawRect(topPenaltyRect, paint);

    // Bottom penalty area
    final bottomPenaltyRect = Rect.fromCenter(
      center: Offset(width / 2, height * 0.95 - penaltyHeight / 2),
      width: penaltyWidth,
      height: penaltyHeight,
    );
    canvas.drawRect(bottomPenaltyRect, paint);

    // Penalty spots
    final penaltySpotRadius = 4.0;
    final topSpot = Offset(width / 2, height * 0.05 + penaltyHeight * 0.65);
    final bottomSpot = Offset(width / 2, height * 0.95 - penaltyHeight * 0.65);
    canvas.drawCircle(topSpot, penaltySpotRadius, paint..style = PaintingStyle.fill);
    canvas.drawCircle(bottomSpot, penaltySpotRadius, paint..style = PaintingStyle.fill);

    // Corner arcs
    final cornerRadius = 15.0;
    final corners = [
      Offset(fieldRect.left, fieldRect.top),
      Offset(fieldRect.right, fieldRect.top),
      Offset(fieldRect.left, fieldRect.bottom),
      Offset(fieldRect.right, fieldRect.bottom),
    ];
    for (var corner in corners) {
      final rect = Rect.fromCircle(center: corner, radius: cornerRadius);
      final startAngle = (corner == corners[0] || corner == corners[2]) ? 0.0 : (pi / 2).toDouble();
      final sweepAngle = (pi / 2).toDouble();
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BouncingBallsBackground extends StatefulWidget {
  const BouncingBallsBackground({super.key});

  @override
  State<BouncingBallsBackground> createState() => _BouncingBallsBackgroundState();
}

class _BouncingBallsBackgroundState extends State<BouncingBallsBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Ball> balls = [];
  final int ballCount = 10;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < ballCount; i++) {
      balls.add(_Ball(
        position: Offset(random.nextDouble(), random.nextDouble()),
        velocity: Offset((random.nextDouble() - 0.5) * 0.002, (random.nextDouble() - 0.5) * 0.002),
        radius: 6 + random.nextDouble() * 6,
        color: Colors.white.withOpacity(0.15 + random.nextDouble() * 0.15),
      ));
    }
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1000))
      ..addListener(_update)
      ..repeat();
  }

  void _update() {
    for (var ball in balls) {
      final newPos = ball.position + ball.velocity;
      double dx = newPos.dx;
      double dy = newPos.dy;
      if (dx < 0 || dx > 1) {
        ball.velocity = Offset(-ball.velocity.dx, ball.velocity.dy);
        dx = dx.clamp(0.0, 1.0);
      }
      if (dy < 0 || dy > 1) {
        ball.velocity = Offset(ball.velocity.dx, -ball.velocity.dy);
        dy = dy.clamp(0.0, 1.0);
      }
      ball.position = Offset(dx, dy);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _BallsPainter(balls, constraints.biggest),
      );
    });
  }
}

class _Ball {
  Offset position;
  Offset velocity;
  final double radius;
  final Color color;

  _Ball({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.color,
  });
}

class _BallsPainter extends CustomPainter {
  final List<_Ball> balls;
  final Size size;

  _BallsPainter(this.balls, this.size);

  @override
  void paint(Canvas canvas, Size _) {
    final paint = Paint();
    for (var ball in balls) {
      paint.color = ball.color;
      final pos = Offset(ball.position.dx * size.width, ball.position.dy * size.height);
      canvas.drawCircle(pos, ball.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BallsPainter oldDelegate) => true;
}

class _DifficultyButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DifficultyButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_DifficultyButton> createState() => _DifficultyButtonState();
}

class _DifficultyButtonState extends State<_DifficultyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _controller.drive(Tween(begin: 1.0, end: 0.95));
  }

  void _onTapDown(TapDownDetails details) {
    _controller.reverse();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.forward();
  }

  void _onTapCancel() {
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: [
        widget.color.withOpacity(0.85),
        widget.color,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black45.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 2,
                  color: Colors.black26,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}