import 'dart:ui' show Offset;

/// The four directions an arrow may point. Arrows never move diagonally.
enum Dir {
  up(0, -1),
  right(1, 0),
  down(0, 1),
  left(-1, 0);

  const Dir(this.dx, this.dy);
  final int dx;
  final int dy;

  Offset get offset => Offset(dx.toDouble(), dy.toDouble());

  static Dir fromStep(Cell from, Cell to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    return Dir.values.firstWhere((d) => d.dx == dx && d.dy == dy);
  }
}

/// A single dot / cell position on the board.
class Cell {
  const Cell(this.x, this.y);
  final int x;
  final int y;

  Cell step(Dir d, [int n = 1]) => Cell(x + d.dx * n, y + d.dy * n);

  Offset get center => Offset(x + 0.5, y + 0.5);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.x == x && other.y == y;

  @override
  int get hashCode => x * 1000 + y;

  @override
  String toString() => '($x,$y)';
}

/// A snake-like arrow occupying one or more adjacent cells.
/// [cells] runs from tail to head; the arrow escapes in [dir].
class Arrow {
  const Arrow({
    required this.id,
    required this.cells,
    required this.dir,
    required this.colorIndex,
  });

  final int id;
  final List<Cell> cells;
  final Dir dir;
  final int colorIndex;

  Cell get head => cells.last;
  int get length => cells.length;
}

/// A fully generated, always-solvable puzzle.
class Level {
  const Level({
    required this.number,
    required this.width,
    required this.height,
    required this.shape,
    required this.mask,
    required this.arrows,
  });

  final int number;
  final int width;
  final int height;
  final String shape;
  final Set<Cell> mask;
  final List<Arrow> arrows;

  bool inBounds(Cell c) => c.x >= 0 && c.y >= 0 && c.x < width && c.y < height;
}
