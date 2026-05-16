// pitch_widgets.dart
//
// Shared, behaviour-identical pitch widgets for the Compos feature.
// Extracted verbatim from lineup_match_page.dart (the 1v1 copies were
// functionally identical — only formatting differed).
//   • PitchPainter   — pitch background (grass, stripes, markings)
//   • RipplePainter  — expanding ring played when a chip is revealed
//   • PlayerCard     — fallback grid card (non-pitch formations)

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/lineup_model.dart';
import 'lineup_visuals.dart';

class PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base green
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = Color(0xFF1A5C2A),
    );

    // Alternating stripes
    const stripeColor = Color(0xFF1E6830);
    const stripes = 8;
    final stripeH = h / stripes;
    for (int i = 0; i < stripes; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeH, w, stripeH),
        Paint()..color = stripeColor,
      );
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const p = 10.0; // pitch padding

    // Outer border
    canvas.drawRect(Rect.fromLTRB(p, p, w - p, h - p), line);

    // Center line
    canvas.drawLine(Offset(p, h / 2), Offset(w - p, h / 2), line);

    // Center circle
    canvas.drawCircle(Offset(w / 2, h / 2), h * 0.09, line);

    // Center dot
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // Penalty areas
    final penW = w * 0.55;
    final penH = h * 0.13;
    final penLeft = (w - penW) / 2;

    // Top (away goal)
    canvas.drawRect(Rect.fromLTRB(penLeft, p, penLeft + penW, p + penH), line);
    // Bottom (home goal)
    canvas.drawRect(
      Rect.fromLTRB(penLeft, h - p - penH, penLeft + penW, h - p),
      line,
    );

    // Goal areas
    final goalW = w * 0.28;
    final goalH = h * 0.05;
    final goalLeft = (w - goalW) / 2;

    canvas.drawRect(
      Rect.fromLTRB(goalLeft, p, goalLeft + goalW, p + goalH),
      line,
    );
    canvas.drawRect(
      Rect.fromLTRB(goalLeft, h - p - goalH, goalLeft + goalW, h - p),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PlayerCard extends StatelessWidget {
  final Lineup player;
  final bool isFound;
  final bool isPassed;
  final String? hintContent;
  final VoidCallback? onTap;

  const PlayerCard({
    super.key,
    required this.player,
    required this.isFound,
    required this.isPassed,
    this.hintContent,
    this.onTap,
  });

  String get _displayName => player.playerName.trim();
  String get _hiddenLabel => hintContent ?? player.position;

  Color get _borderColor {
    if (isFound) return AppColors.accentBright;
    if (isPassed) return AppColors.amber;
    return AppColors.border;
  }

  Color get _bgColor {
    if (isFound) return AppColors.accentBright.withValues(alpha: 0.10);
    if (isPassed) return AppColors.amber.withValues(alpha: 0.08);
    return AppColors.card;
  }

  Color get _shirtColor {
    if (isFound) return AppColors.accentBright;
    if (isPassed) return AppColors.amber;
    return AppColors.border;
  }

  Color get _nameColor {
    if (isFound) return AppColors.accentBright;
    if (isPassed) return AppColors.amber;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final revealed = isFound || isPassed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: revealed ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor, width: revealed ? 1.5 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/images/shirt.png',
                  width: 30,
                  height: 30,
                  color: _shirtColor,
                ),
                if (revealed && player.playerNumber > 0)
                  Positioned(
                    top: 9,
                    child: Text(
                      '${player.playerNumber}',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: labelColor(_shirtColor),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              revealed ? _displayName : _hiddenLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: revealed ? FontWeight.w700 : FontWeight.w500,
                color: hintContent != null && !revealed
                    ? AppColors.accentBright
                    : _nameColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Unified player chip (pitch + bench). Behaviour preserved exactly from the
// former _PitchChip / _SubChip (solo & 1v1):
//   • isSub                 → bench layout (fixed Ø32, smaller name, centered)
//   • splitColorTextOutline → solo=true (4-way black outline on 2-colour
//     teams), 1v1=false (single soft shadow). The ONLY behavioural divergence.
class PitchChip extends StatefulWidget {
  final Lineup? player;
  final bool isFound;
  final bool isPassed;
  final String? hintContent;
  final VoidCallback? onTap;
  final double? chipRadius; // required when !isSub; ignored when isSub
  final Color teamColor;
  final Color? teamColor2;
  final bool isSub;
  final bool splitColorTextOutline;

  const PitchChip({
    super.key,
    required this.player,
    required this.isFound,
    required this.isPassed,
    required this.teamColor,
    this.chipRadius,
    this.teamColor2,
    this.hintContent,
    this.onTap,
    this.isSub = false,
    this.splitColorTextOutline = true,
  });

  @override
  State<PitchChip> createState() => PitchChipState();
}

class PitchChipState extends State<PitchChip> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;
  late AnimationController _rippleCtrl;
  late Animation<double> _rippleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.55), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1.55, end: 0.78), weight: 16),
      TweenSequenceItem(tween: Tween(begin: 0.78, end: 1.22), weight: 14),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.90), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.10), weight: 11),
      TweenSequenceItem(tween: Tween(begin: 1.10, end: 0.96), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.03), weight: 9),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 10),
    ]).animate(_ctrl);
    _glow = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 80),
    ]).animate(_ctrl);
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _rippleAnim = CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(PitchChip old) {
    super.didUpdateWidget(old);
    if (!old.isFound && widget.isFound) {
      _ctrl.forward(from: 0);
      _rippleCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  String get _shortName {
    if (widget.player == null) return '';
    return widget.player!.playerName.trim();
  }

  @override
  Widget build(BuildContext context) {
    final revealed = widget.isFound || widget.isPassed;
    final double d = widget.isSub ? 32 : widget.chipRadius! * 2;

    String label;
    if (revealed) {
      label = widget.player!.playerNumber > 0
          ? '${widget.player!.playerNumber}'
          : '✓';
    } else if (widget.hintContent != null) {
      label = widget.hintContent!;
    } else {
      label = '?';
    }

    final numFontSize = widget.isSub ? 10.0 : (d < 28 ? 8.0 : 10.0);

    // Not found → empty circle (transparent + white border)
    // Passed    → amber fill
    // Found     → team colors
    final Color c1 = widget.isPassed ? AppColors.amber : widget.teamColor;
    final Color c2 = widget.isPassed
        ? AppColors.amber
        : (widget.teamColor2 ?? widget.teamColor);

    final bool filled = revealed; // only fill when found/passed

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.player == null || revealed ? null : widget.onTap,
      child: SizedBox(
        width: widget.isSub ? 32 : d + 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: widget.isSub
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            SizedBox(
              width: d,
              height: d,
              child: AnimatedBuilder(
                animation: Listenable.merge([_ctrl, _rippleCtrl]),
                builder: (_, __) => Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(d, d),
                      painter: RipplePainter(
                        progress: _rippleAnim.value,
                        chipRadius: d / 2,
                        color: c1,
                      ),
                    ),
                    Transform.scale(
                      scale: _scale.value,
                      child: Container(
                        width: d,
                        height: d,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: filled
                              ? LinearGradient(
                                  colors: [c1, c1, c2, c2],
                                  stops: [0.0, 0.5, 0.5, 1.0],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                          color: filled ? null : Colors.white.withOpacity(0.10),
                          border: Border.all(
                            color: Colors.white,
                            width: filled ? 1.5 : 1.2,
                          ),
                          boxShadow: [
                            const BoxShadow(
                              color: Color(0x55000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                            BoxShadow(
                              color: c1.withOpacity(_glow.value * 0.8),
                              blurRadius: _glow.value * 24,
                              spreadRadius: _glow.value * 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: filled && c1 == c2
                                  ? labelColor(c1)
                                  : Colors.white,
                              fontSize: numFontSize,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              shadows:
                                  widget.splitColorTextOutline &&
                                      filled &&
                                      c1 != c2
                                  ? [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 2,
                                        offset: Offset(-1, -1),
                                      ),
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 2,
                                        offset: Offset(1, -1),
                                      ),
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 2,
                                        offset: Offset(-1, 1),
                                      ),
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 2,
                                        offset: Offset(1, 1),
                                      ),
                                    ]
                                  : [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 3,
                                      ),
                                    ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.isSub
                ? revealed
                : (revealed && widget.chipRadius! >= 13)) ...[
              SizedBox(height: widget.isSub ? 2 : 1),
              widget.isSub
                  ? Text(
                      _shortName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.isFound
                            ? AppColors.accentBright
                            : AppColors.amber,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    )
                  : SizedBox(
                      width: d + 30,
                      child: Text(
                        _shortName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isFound
                              ? const Color.fromARGB(255, 181, 237, 187)
                              : AppColors.amber,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final double progress;
  final double chipRadius;
  final Color color;

  const RipplePainter({
    required this.progress,
    required this.chipRadius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = chipRadius + progress * 32;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final strokeWidth = 3.0 * (1.0 - progress * 0.6);
    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(RipplePainter old) => old.progress != progress;
}
