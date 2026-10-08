import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../theme.dart';

Color arrowColor(Arrow a) => arrowColors[a.colorIndex % arrowColors.length];

/// The route an arrow follows in cell units: through its body, then straight
/// on past the board edge. Moving an arrow means sliding a window of its own
/// length along this track, so bent arrows snake out like a train.
class ArrowTrack {
  ArrowTrack(this.arrow, {int extra = 40}) {
    final d = arrow.dir.offset;
    if (arrow.length == 1) points.add(arrow.head.center - d * 0.3);
    points.addAll(arrow.cells.map((c) => c.center));
    for (var k = 1; k <= extra; k++) {
      points.add(arrow.head.center + d * k.toDouble());
    }
    var total = 0.0;
    cumulative.add(0);
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
      cumulative.add(total);
    }
    length = arrow.length == 1 ? 0.3 : arrow.length - 1.0;
  }

  final Arrow arrow;
  final List<Offset> points = [];
  final List<double> cumulative = [];

  /// Visible length of the arrow's body.
  late final double length;

  Offset at(double s) {
    if (s <= 0) return points.first;
    var i = 1;
    while (i < cumulative.length - 1 && cumulative[i] < s) {
      i++;
    }
    final seg = cumulative[i] - cumulative[i - 1];
    final t = seg == 0 ? 0.0 : ((s - cumulative[i - 1]) / seg).clamp(0.0, 1.0);
    return Offset.lerp(points[i - 1], points[i], t)!;
  }

  /// The arrow's body when it has moved [shift] cells forward.
  List<Offset> body(double shift) {
    final a = shift, b = shift + length;
    final out = [at(a)];
    for (var i = 0; i < points.length; i++) {
      if (cumulative[i] > a && cumulative[i] < b) out.add(points[i]);
    }
    out.add(at(b));
    return out;
  }
}

enum MotionKind { escape, bump }

class ArrowMotion {
  ArrowMotion({
    required this.track,
    required this.kind,
    required this.start,
    required this.distance,
  }) : duration = kind == MotionKind.escape
           ? (distance / 20).clamp(0.3, 0.9)
           : 0.22 + distance * 0.03;

  final ArrowTrack track;
  final MotionKind kind;
  final double start;

  /// For an escape, how far to travel to leave the board; for a bump, how far
  /// the arrow gets before it hits the blocker.
  final double distance;
  final double duration;

  double progress(double now) => ((now - start) / duration).clamp(0.0, 1.0);
  bool done(double now) => now - start >= duration;

  double shift(double now) {
    final t = progress(now);
    if (kind == MotionKind.escape) {
      return Curves.easeInCubic.transform(t) * distance;
    }
    return sin(pi * t) * distance;
  }
}

/// Everything the painter needs for one frame.
class BoardScene {
  BoardScene({
    required this.level,
    required this.arrows,
    required this.motions,
    required this.clock,
    this.hintId,
    this.hintStart = 0,
    this.flashIds = const {},
    this.flashStart = 0,
    this.dotColor = const Color(0xFFCBC3E3),
  });

  final Level level;
  final Iterable<ArrowTrack> arrows;
  final Map<int, ArrowMotion> motions;

  /// Seconds since the level started; ticks every frame.
  final ValueListenable<double> clock;
  final int? hintId;
  final double hintStart;
  final Set<int> flashIds;
  final double flashStart;
  final Color dotColor;
}

class BoardPainter extends CustomPainter {
  BoardPainter(this.scene) : super(repaint: scene.clock);

  final BoardScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final level = scene.level;
    final cell = min(size.width / level.width, size.height / level.height);
    final origin = Offset(
      (size.width - cell * level.width) / 2,
      (size.height - cell * level.height) / 2,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(cell);

    // The dotted canvas: faint dots everywhere, bolder ones inside the shape.
    final faint = Paint()..color = scene.dotColor.withValues(alpha: 0.35);
    final dot = Paint()..color = scene.dotColor;
    for (var y = 0; y < level.height; y++) {
      for (var x = 0; x < level.width; x++) {
        final c = Cell(x, y);
        final inside = level.mask.contains(c);
        canvas.drawCircle(c.center, inside ? 0.09 : 0.06, inside ? dot : faint);
      }
    }

    final now = scene.clock.value;
    final flashing = scene.flashIds.isNotEmpty && now - scene.flashStart < 0.6;
    for (final track in scene.arrows) {
      final a = track.arrow;
      final motion = scene.motions[a.id];
      final shift = motion?.shift(now) ?? 0;
      var color = arrowColor(a);
      if (flashing && scene.flashIds.contains(a.id)) {
        final t = (now - scene.flashStart) / 0.6;
        final pulse = (sin(t * pi * 4) * 0.5 + 0.5) * (1 - t);
        color = Color.lerp(color, const Color(0xFFE11D48), pulse)!;
      }
      var glow = 0.0;
      if (scene.hintId == a.id && now - scene.hintStart < 4) {
        glow = sin((now - scene.hintStart) * pi * 2.5) * 0.5 + 0.5;
      }
      _drawArrow(canvas, track.body(shift), color, glow);
    }
    canvas.restore();
  }

  void _drawArrow(Canvas canvas, List<Offset> pts, Color color, double glow) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final end = pts.last;
    var dir = const Offset(0, -1);
    for (var i = pts.length - 2; i >= 0; i--) {
      final d = end - pts[i];
      if (d.distance > 0.001) {
        dir = d / d.distance;
        break;
      }
    }
    final normal = Offset(-dir.dy, dir.dx);
    final head = Path()
      ..moveTo(end.dx + dir.dx * 0.34, end.dy + dir.dy * 0.34)
      ..lineTo(
        end.dx + normal.dx * 0.27 - dir.dx * 0.06,
        end.dy + normal.dy * 0.27 - dir.dy * 0.06,
      )
      ..lineTo(
        end.dx - normal.dx * 0.27 - dir.dx * 0.06,
        end.dy - normal.dy * 0.27 - dir.dy * 0.06,
      )
      ..close();

    if (glow > 0) {
      final g = Paint()
        ..color = const Color(0xFFFFE14D).withValues(alpha: 0.4 + glow * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.55 + glow * 0.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.12);
      canvas.drawPath(path, g);
      canvas.drawPath(head, g..style = PaintingStyle.fill);
    }

    // Soft drop shadow for depth.
    canvas.save();
    canvas.translate(0.03, 0.07);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, shadow);
    canvas.drawPath(head, shadow..style = PaintingStyle.fill);
    canvas.restore();

    final body = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, body);
    canvas.drawPath(head, Paint()..color = color);

    // A glossy highlight along the body.
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.translate(-0.04, -0.05);
    canvas.drawPath(path, shine);
    canvas.restore();
    // A small tail cap so each arrow's start is easy to see.
    canvas.drawCircle(
      pts.first,
      0.1,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}

/// Converts a tap position on the board into a cell.
Cell? cellAt(Offset local, Size size, Level level) {
  final cell = min(size.width / level.width, size.height / level.height);
  final origin = Offset(
    (size.width - cell * level.width) / 2,
    (size.height - cell * level.height) / 2,
  );
  final p = (local - origin) / cell;
  final c = Cell(p.dx.floor(), p.dy.floor());
  return level.inBounds(c) ? c : null;
}
