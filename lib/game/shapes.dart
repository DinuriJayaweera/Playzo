import 'dart:math';

import 'models.dart';

/// A board outline. Arrows are packed tightly inside the shape.
class BoardShape {
  const BoardShape(this.name, this._inside);

  final String name;

  /// Tests a point in normalised coordinates, where u and v run from -1 to 1
  /// and v grows downwards.
  final bool Function(double u, double v) _inside;

  Set<Cell> mask(int width, int height) {
    final cells = <Cell>{};
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final u = (x + 0.5) / width * 2 - 1;
        final v = (y + 0.5) / height * 2 - 1;
        if (_inside(u, v)) cells.add(Cell(x, y));
      }
    }
    return cells;
  }
}

bool _inPolygon(double u, double v, List<Point<double>> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.y > v) != (b.y > v) &&
        u < (b.x - a.x) * (v - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

List<Point<double>> _regular(int points, double radius, double rotation,
    {double innerRadius = 0}) {
  final total = innerRadius > 0 ? points * 2 : points;
  return List.generate(total, (i) {
    final r = innerRadius > 0 && i.isOdd ? innerRadius : radius;
    final a = rotation + i * 2 * pi / total;
    return Point(r * cos(a), r * sin(a));
  });
}

final _star = _regular(5, 1.08, -pi / 2, innerRadius: 0.5);
final _hexagon = _regular(6, 1.05, 0);
final _triangle = [
  const Point(0.0, -1.02),
  const Point(1.02, 1.0),
  const Point(-1.02, 1.0),
];
final _house = [
  const Point(0.0, -1.02),
  const Point(1.02, -0.1),
  const Point(0.75, -0.1),
  const Point(0.75, 1.02),
  const Point(-0.75, 1.02),
  const Point(-0.75, -0.1),
  const Point(-1.02, -0.1),
];

const _rectangle = BoardShape('Rectangle', _always);
bool _always(double u, double v) => true;

final List<BoardShape> boardShapes = [
  _rectangle,
  BoardShape('Heart', (u, v) {
    final x = u * 1.2;
    final y = -v * 1.08 + 0.12;
    final a = x * x + y * y - 1;
    return a * a * a - x * x * y * y * y <= 0;
  }),
  BoardShape('Circle', (u, v) => u * u + v * v <= 1.04),
  BoardShape('Triangle', (u, v) => _inPolygon(u, v, _triangle)),
  BoardShape('Diamond', (u, v) => u.abs() + v.abs() <= 1.05),
  BoardShape('Star', (u, v) => _inPolygon(u, v - 0.1, _star)),
  BoardShape('Hexagon', (u, v) => _inPolygon(u, v, _hexagon)),
  BoardShape('Cross', (u, v) => u.abs() <= 0.4 || v.abs() <= 0.4),
  BoardShape('Ring', (u, v) {
    final r = u * u + v * v;
    return r <= 1.04 && r >= 0.16;
  }),
  BoardShape('House', (u, v) => _inPolygon(u, v, _house)),
];

BoardShape shapeByName(String name) =>
    boardShapes.firstWhere((s) => s.name == name, orElse: () => _rectangle);
