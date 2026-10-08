import 'dart:math';

import 'package:flutter/material.dart';

/// What Arrowy, the game's mascot, is doing.
enum MascotPose {
  /// Thumbs up: approval, help, settings.
  thumbsUp,

  /// Waving hello.
  wave,

  /// Both arms up: level complete.
  cheer,

  /// Pointing to the side: hints.
  point,

  /// Drooping arms and a tear: mistakes and game over.
  sad,
}

/// Arrowy: a cheerful yellow arrow with a face, arms and legs, drawn in code
/// so it stays sharp at any size. It bobs gently, and waves when waving.
class Mascot extends StatefulWidget {
  const Mascot({
    super.key,
    this.pose = MascotPose.thumbsUp,
    this.size = 120,
    this.animate = true,
  });

  final MascotPose pose;

  /// Height in logical pixels. Width is about 85% of the height.
  final double size;
  final bool animate;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(Mascot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 0.85,
      height: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(painter: MascotPainter(widget.pose, _c)),
      ),
    );
  }
}

class MascotPainter extends CustomPainter {
  MascotPainter(this.pose, this.anim) : super(repaint: anim);

  final MascotPose pose;
  final Animation<double> anim;

  static const _yellow = Color(0xFFFFCB3D);
  static const _yellowLight = Color(0xFFFFE58A);
  static const _yellowShade = Color(0xFFF2A81D);
  static const _outline = Color(0xFF3B2A12);
  static const _limb = Color(0xFFE8553A);
  static const _shoe = Color(0xFF3A7BFF);
  static const _blush = Color(0xFFFF8FA3);

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 100 x 118 grid, then scaled to fit.
    final scale = min(size.width / 100, size.height / 118);
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 118 * scale) / 2,
    );
    canvas.scale(scale);

    final t = anim.value * 2 * pi;
    final bob = pose == MascotPose.sad ? sin(t) * 0.8 : sin(t) * 2.2;

    _ground(canvas, bob);
    canvas.translate(0, bob - 1);
    _legs(canvas, t);
    _arms(canvas, t, behind: true);
    _body(canvas);
    _face(canvas, t);
    _arms(canvas, t, behind: false);
    canvas.restore();
  }

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _ground(Canvas canvas, double bob) {
    final w = 46 - bob * 2;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 114), width: w, height: 6),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
  }

  Path _bodyPath() => Path()
    ..moveTo(50, 4)
    ..lineTo(93, 48)
    ..lineTo(71, 48)
    ..lineTo(71, 90)
    ..quadraticBezierTo(71, 96, 65, 96)
    ..lineTo(35, 96)
    ..quadraticBezierTo(29, 96, 29, 90)
    ..lineTo(29, 48)
    ..lineTo(7, 48)
    ..close();

  void _body(Canvas canvas) {
    final body = _bodyPath();
    canvas.drawPath(body, Paint()..color = _yellow);
    // Shading on the right, and a glossy highlight on the left.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      const Rect.fromLTWH(58, 0, 50, 100),
      Paint()..color = _yellowShade.withValues(alpha: 0.45),
    );
    final gloss = Path()
      ..moveTo(48, 12)
      ..lineTo(20, 41)
      ..lineTo(28, 41)
      ..close();
    canvas.drawPath(gloss, Paint()..color = _yellowLight);
    canvas.drawRRect(
      RRect.fromLTRBR(33, 52, 37, 86, const Radius.circular(2)),
      Paint()..color = _yellowLight.withValues(alpha: 0.8),
    );
    canvas.restore();
    canvas.drawPath(body, _stroke(_outline, 3.2));
  }

  void _face(Canvas canvas, double t) {
    final ink = Paint()..color = _outline;
    final white = Paint()..color = Colors.white;
    // Blink for a moment once per cycle.
    final blink = (anim.value > 0.92) ? 0.15 : 1.0;
    final sad = pose == MascotPose.sad;
    for (final x in [42.0, 58.0]) {
      final eye = Rect.fromCenter(
        center: Offset(x, 60),
        width: 6.4,
        height: 8.4 * blink,
      );
      canvas.drawOval(eye, ink);
      if (blink == 1) canvas.drawCircle(Offset(x + 1.2, 58), 1.4, white);
      if (sad) {
        // Worried brows.
        final dx = x < 50 ? 1.0 : -1.0;
        canvas.drawLine(
          Offset(x - 3.5 * dx, 54.5),
          Offset(x + 3 * dx, 51.5),
          _stroke(_outline, 1.6),
        );
      }
    }
    final blush = Paint()..color = _blush.withValues(alpha: 0.75);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(36, 67), width: 7, height: 4.5),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(64, 67), width: 7, height: 4.5),
      blush,
    );

    switch (pose) {
      case MascotPose.sad:
        final mouth = Path()
          ..moveTo(45, 72)
          ..quadraticBezierTo(50, 67.5, 55, 72);
        canvas.drawPath(mouth, _stroke(_outline, 2));
        // A tear that slowly runs down the cheek.
        final drop = 64 + (anim.value * 14) % 14;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(60.5, drop), width: 3.2, height: 4.4),
          Paint()..color = const Color(0xFF5BC0FF),
        );
      case MascotPose.cheer:
        final mouth = Path()
          ..moveTo(44, 67)
          ..quadraticBezierTo(50, 77, 56, 67)
          ..close();
        canvas.drawPath(mouth, ink);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(50, 72), width: 5, height: 2.6),
          Paint()..color = const Color(0xFFFF6B81),
        );
      case MascotPose.point:
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(50, 70), width: 5, height: 5.5),
          ink,
        );
      default:
        final mouth = Path()
          ..moveTo(45, 67.5)
          ..quadraticBezierTo(50, 73, 55, 67.5);
        canvas.drawPath(mouth, _stroke(_outline, 2));
    }
  }

  void _legs(Canvas canvas, double t) {
    final step = pose == MascotPose.cheer ? sin(t * 2) * 2 : 0.0;
    for (final (x, foot, lift) in [(41.0, 36.0, step), (59.0, 64.0, -step)]) {
      final leg = Path()
        ..moveTo(x, 94)
        ..lineTo(x + (foot - x) * 0.3, 106 - lift.clamp(0, 3));
      canvas.drawPath(leg, _stroke(_outline, 8));
      canvas.drawPath(leg, _stroke(_limb, 5));
      final shoe = Rect.fromCenter(
        center: Offset(foot, 109 - lift.clamp(0, 3)),
        width: 15,
        height: 8,
      );
      canvas.drawOval(shoe.inflate(1.4), Paint()..color = _outline);
      canvas.drawOval(shoe, Paint()..color = _shoe);
      canvas.drawOval(
        Rect.fromCenter(
          center: shoe.center.translate(-2.5, -1.6),
          width: 5,
          height: 2.2,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }
  }

  void _limbPath(Canvas canvas, List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 3) {
      p.quadraticBezierTo(pts[1].dx, pts[1].dy, pts[2].dx, pts[2].dy);
    } else {
      for (final o in pts.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(p, _stroke(_outline, 8));
    canvas.drawPath(p, _stroke(_limb, 5));
  }

  void _hand(
    Canvas canvas,
    Offset c, {
    bool thumb = false,
    bool finger = false,
  }) {
    if (thumb) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(-0.5, -8.5),
          width: 5.6,
          height: 11,
        ),
        const Radius.circular(2.8),
      );
      canvas.drawRRect(r.inflate(1.4), Paint()..color = _outline);
      canvas.drawRRect(r, Paint()..color = _limb);
    }
    if (finger) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(6.5, -0.5), width: 9, height: 4.2),
        const Radius.circular(2.1),
      );
      canvas.drawRRect(r.inflate(1.4), Paint()..color = _outline);
      canvas.drawRRect(r, Paint()..color = _limb);
    }
    canvas.drawCircle(c, 5.6, Paint()..color = _outline);
    canvas.drawCircle(c, 4.3, Paint()..color = _limb);
  }

  /// Draws the arms. The left arm is drawn [behind] the body in some poses.
  void _arms(Canvas canvas, double t, {required bool behind}) {
    if (behind) return;
    const l = Offset(30, 72), r = Offset(70, 72);
    switch (pose) {
      case MascotPose.thumbsUp:
        _limbPath(canvas, [l, const Offset(20, 78), const Offset(18, 88)]);
        _hand(canvas, const Offset(18, 89));
        final lift = sin(t) * 1.5;
        _limbPath(canvas, [r, Offset(86, 72 + lift), Offset(86, 60 + lift)]);
        _hand(canvas, Offset(86, 58 + lift), thumb: true);
      case MascotPose.wave:
        _limbPath(canvas, [l, const Offset(20, 78), const Offset(18, 88)]);
        _hand(canvas, const Offset(18, 89));
        final a = -pi / 2.6 + sin(t * 2) * 0.35;
        final elbow = r + const Offset(14, -2);
        final hand = elbow + Offset(cos(a), sin(a)) * 16;
        _limbPath(canvas, [r, elbow, hand]);
        _hand(canvas, hand);
      case MascotPose.cheer:
        final w = sin(t * 2) * 3;
        _limbPath(canvas, [l, Offset(14, 64 + w), Offset(10, 48 + w)]);
        _hand(canvas, Offset(10, 46 + w));
        _limbPath(canvas, [r, Offset(86, 64 - w), Offset(90, 48 - w)]);
        _hand(canvas, Offset(90, 46 - w));
      case MascotPose.point:
        _limbPath(canvas, [l, const Offset(20, 78), const Offset(18, 88)]);
        _hand(canvas, const Offset(18, 89));
        final push = sin(t * 2) * 1.5;
        _limbPath(canvas, [r, Offset(84 + push, 70)]);
        _hand(canvas, Offset(86 + push, 70), finger: true);
      case MascotPose.sad:
        _limbPath(canvas, [l, const Offset(24, 82), const Offset(25, 92)]);
        _hand(canvas, const Offset(25, 93));
        _limbPath(canvas, [r, const Offset(76, 82), const Offset(75, 92)]);
        _hand(canvas, const Offset(75, 93));
    }
  }

  @override
  bool shouldRepaint(MascotPainter old) => old.pose != pose;
}

/// The mascot with a speech bubble beside it.
class MascotSays extends StatelessWidget {
  const MascotSays({
    super.key,
    required this.text,
    this.pose = MascotPose.thumbsUp,
    this.size = 90,
    this.bubbleColor = Colors.white,
    this.textColor = const Color(0xFF2B2250),
  });

  final String text;
  final MascotPose pose;
  final double size;
  final Color bubbleColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Mascot(pose: pose, size: size),
        const SizedBox(width: 4),
        Flexible(
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.45),
            child: CustomPaint(
              painter: _BubbleTail(bubbleColor),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleTail extends CustomPainter {
  _BubbleTail(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - 14;
    final path = Path()
      ..moveTo(4, y - 8)
      ..lineTo(-9, y + 6)
      ..lineTo(10, y + 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubbleTail old) => old.color != color;
}
