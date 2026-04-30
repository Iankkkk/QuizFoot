// qui_a_menti_confetti.dart
//
// Shared full-screen confetti overlay used by both the game page
// (on perfect 10/10 first attempt) and the score page.

import 'dart:math';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuiAMentiConfetti — public shared widget
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen confetti overlay: ~32 colored pieces falling from the top.
/// Wrap in [IgnorePointer] so it doesn't block touch events.
class QuiAMentiConfetti extends StatelessWidget {
  final AnimationController controller;

  const QuiAMentiConfetti({super.key, required this.controller});

  static final _colors = [
    AppColors.accentBright,
    AppColors.amber,
    AppColors.orange,
    Color(0xFFE040FB), // purple
    Color(0xFF40C4FF), // light blue
    Color(0xFFFF5252), // red
    Color(0xFFFFD740), // yellow
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rng  = Random(7); // fixed seed → consistent layout across builds

    final pieces = List.generate(50, (i) {
      return _ConfettiPiece(
        controller:   controller,
        x:            rng.nextDouble() * size.width,
        screenHeight: size.height,
        delay:        rng.nextDouble() * 0.45,
        color:        _colors[i % _colors.length],
        width:        10.0 + rng.nextDouble() * 12,
        height:       8.0  + rng.nextDouble() * 10,
        angle:        rng.nextDouble() * pi,
      );
    });

    return SizedBox.expand(child: Stack(children: pieces));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ConfettiPiece — a single falling, rotating, fading rectangle
// ─────────────────────────────────────────────────────────────────────────────

class _ConfettiPiece extends StatelessWidget {
  final AnimationController controller;
  final double x;
  final double screenHeight;
  final double delay;
  final Color color;
  final double width;
  final double height;
  final double angle;

  const _ConfettiPiece({
    required this.controller,
    required this.x,
    required this.screenHeight,
    required this.delay,
    required this.color,
    required this.width,
    required this.height,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, 1.0, curve: Curves.easeIn),
    );

    final offsetY  = Tween<double>(begin: -20, end: screenHeight + 20).animate(curved);
    final opacity  = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval((delay + 0.6).clamp(0.0, 1.0), 1.0),
      ),
    );
    final rotation = Tween<double>(begin: 0, end: angle * 6).animate(curved);

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Positioned(
        left: x,
        top:  offsetY.value,
        child: Opacity(
          opacity: opacity.value.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: rotation.value,
            child: Container(
              width:  width,
              height: height,
              decoration: BoxDecoration(
                color:        color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
