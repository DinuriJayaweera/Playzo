import 'package:flutter/material.dart';

import '../../game/shapes.dart';

/// A tiny dot-matrix picture of a board shape, built from the shape's own
/// outline so it always matches the level.
class ShapeIcon extends StatelessWidget {
  const ShapeIcon({super.key, required this.shape, this.size = 16, this.color = Colors.white});
  final BoardShape shape;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _ShapePainter(shape, color));
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.color);
  final BoardShape shape;
  final Color color;

  static const _res = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / _res;
    final paint = Paint()..color = color;
    for (final c in shape.mask(_res, _res)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(c.x * step, c.y * step, step * 0.92, step * 0.92),
          Radius.circular(step * 0.3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.shape != shape || old.color != color;
}
