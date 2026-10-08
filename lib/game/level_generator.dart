import 'dart:math';

import 'models.dart';
import 'shapes.dart';

/// Tuning values that make each level a little harder than the one before.
class Difficulty {
  const Difficulty({
    required this.size,
    required this.maxLength,
    required this.straightness,
    required this.shuffle,
  });

  /// Board width in cells.
  final int size;

  /// Longest arrow, in cells.
  final int maxLength;

  /// Chance that an arrow keeps going straight instead of bending.
  final double straightness;

  /// How far the fill order may drift from a neat centre-out spiral.
  /// Higher values tangle arrows together more.
  final double shuffle;

  factory Difficulty.forLevel(int level) {
    final n = max(1, level);
    return Difficulty(
      size: min(18, (4 + 2.2 * sqrt(n - 1)).round()),
      maxLength: min(9, 2 + n ~/ 3),
      straightness: max(0.25, 0.7 - n * 0.01),
      shuffle: 0.15 + min(0.4, n * 0.01),
    );
  }
}

/// Smallest board on which each outline is still recognisable.
const _minSize = {'Star': 11, 'Ring': 11, 'Cross': 9, 'House': 9};

/// Picks the board outline for a level. The first few levels are plain
/// rectangles; after that the shapes rotate, with a rectangle every so often.
BoardShape shapeForLevel(int level) {
  if (level <= 2) return boardShapes.first;
  final others = boardShapes.length - 1;
  final i = (level - 3) % others;
  return boardShapes[1 + i];
}

/// Generates the puzzle for [level]. Generation is deterministic, so a level
/// is identical every time it is played.
///
/// Arrows are placed from the centre outwards. Each new arrow must have a
/// clear escape path past every arrow already placed. Removing the arrows in
/// the reverse of the placement order therefore always works, so every level
/// is solvable and can never reach a dead end.
Level generateLevel(int level) {
  final rnd = Random(level * 7919 + 104729);
  final diff = Difficulty.forLevel(level);
  final shape = shapeForLevel(level);

  var width = diff.size;
  if (shape.name != 'Rectangle') {
    width = max(width, _minSize[shape.name] ?? 7);
  }
  final height = shape.name == 'Rectangle' ? (width * 1.25).round() : width;
  final mask = shape.mask(width, height);

  final cx = width / 2, cy = height / 2;
  final maxDist = sqrt(cx * cx + cy * cy);
  final order = mask.toList()
    ..sort((a, b) => a.x != b.x ? a.x - b.x : a.y - b.y);
  final keys = {
    for (final c in order)
      c:
          sqrt(pow(c.x + 0.5 - cx, 2) + pow(c.y + 0.5 - cy, 2)) / maxDist +
          rnd.nextDouble() * diff.shuffle,
  };
  order.sort((a, b) => keys[a]!.compareTo(keys[b]!));

  final occupied = <Cell>{};
  final arrows = <Arrow>[];

  bool rayClear(Cell head, Dir dir, Set<Cell> own) {
    var c = head.step(dir);
    while (c.x >= 0 && c.y >= 0 && c.x < width && c.y < height) {
      if (occupied.contains(c) || own.contains(c)) return false;
      c = c.step(dir);
    }
    return true;
  }

  List<Cell> grow(Cell start, int length) {
    final path = [start];
    Dir? last;
    while (path.length < length) {
      final options = Dir.values.where((d) {
        final n = path.last.step(d);
        return mask.contains(n) && !occupied.contains(n) && !path.contains(n);
      }).toList();
      if (options.isEmpty) break;
      Dir next;
      if (last != null &&
          options.contains(last) &&
          rnd.nextDouble() < diff.straightness) {
        next = last;
      } else {
        next = options[rnd.nextInt(options.length)];
      }
      path.add(path.last.step(next));
      last = next;
    }
    return path;
  }

  for (final start in order) {
    if (occupied.contains(start)) continue;

    List<Cell>? cells;
    Dir? dir;
    for (var attempt = 0; attempt < 14 && cells == null; attempt++) {
      final target = diff.maxLength <= 2
          ? 2
          : 2 + rnd.nextInt(diff.maxLength - 1);
      final path = grow(start, target);
      if (path.length < 2) break;
      final own = path.toSet();
      final candidates = <(List<Cell>, Dir)>[];
      for (final p in [path, path.reversed.toList()]) {
        final d = Dir.fromStep(p[p.length - 2], p.last);
        if (rayClear(p.last, d, own)) candidates.add((p, d));
      }
      if (candidates.isNotEmpty) {
        final pick = candidates[rnd.nextInt(candidates.length)];
        cells = pick.$1;
        dir = pick.$2;
      }
    }

    if (cells == null) {
      final dirs = Dir.values.toList()..shuffle(rnd);
      for (final d in dirs) {
        if (rayClear(start, d, const {})) {
          cells = [start];
          dir = d;
          break;
        }
      }
    }
    if (cells == null) continue; // leave a small gap in the shape

    occupied.addAll(cells);
    arrows.add(
      Arrow(
        id: arrows.length,
        cells: cells,
        dir: dir!,
        colorIndex: rnd.nextInt(1 << 16),
      ),
    );
  }

  _fillGaps(arrows, mask, occupied, width, height);

  return Level(
    number: level,
    width: width,
    height: height,
    shape: shape.name,
    mask: mask,
    arrows: arrows,
  );
}

/// Closes leftover gaps by extending an arrow's tail into a neighbouring empty
/// cell. Arrows leave in reverse placement order, so this is only allowed when
/// every arrow escaping through the gap was placed before (leaves after) the
/// extended arrow.
void _fillGaps(
  List<Arrow> arrows,
  Set<Cell> mask,
  Set<Cell> occupied,
  int width,
  int height,
) {
  var changed = true;
  while (changed) {
    changed = false;
    // The highest arrow id whose escape path crosses each cell.
    final lastRay = <Cell, int>{};
    for (final a in arrows) {
      var c = a.head.step(a.dir);
      while (c.x >= 0 && c.y >= 0 && c.x < width && c.y < height) {
        lastRay[c] = max(lastRay[c] ?? -1, a.id);
        c = c.step(a.dir);
      }
    }
    for (final gap in mask.difference(occupied)) {
      for (var i = 0; i < arrows.length; i++) {
        final a = arrows[i];
        final tail = a.cells.first;
        final adjacent = (tail.x - gap.x).abs() + (tail.y - gap.y).abs() == 1;
        if (!adjacent) continue;
        if (a.length == 1 && gap != tail.step(a.dir, -1)) continue;
        if ((lastRay[gap] ?? -1) >= a.id) continue;
        arrows[i] = Arrow(
          id: a.id,
          cells: [gap, ...a.cells],
          dir: a.dir,
          colorIndex: a.colorIndex,
        );
        occupied.add(gap);
        changed = true;
        break;
      }
    }
  }
}
