import 'models.dart';

sealed class TapResult {
  const TapResult();
}

class TapMissed extends TapResult {
  const TapMissed();
}

class TapEscaped extends TapResult {
  const TapEscaped(this.arrow, this.travel);
  final Arrow arrow;

  /// Cells between the head and the board edge.
  final int travel;
}

class TapBlocked extends TapResult {
  const TapBlocked(this.arrow, this.blocker, this.distance);
  final Arrow arrow;
  final Arrow blocker;

  /// Steps the arrow can travel before it hits [blocker].
  final int distance;
}

/// The rules of a single level, with no Flutter dependencies.
class GameState {
  GameState(this.level, {this.maxHearts = 3}) : hearts = maxHearts {
    for (final a in level.arrows) {
      remaining[a.id] = a;
      for (final c in a.cells) {
        _board[c] = a.id;
      }
    }
  }

  final Level level;
  final int maxHearts;
  int hearts;
  int mistakes = 0;
  int moves = 0;
  final Map<int, Arrow> remaining = {};
  final Map<Cell, int> _board = {};

  bool get won => remaining.isEmpty;
  bool get lost => hearts <= 0;
  bool get over => won || lost;
  int get total => level.arrows.length;
  int get cleared => total - remaining.length;

  /// 3 stars for a flawless clear, minus one per mistake (minimum 1).
  int get stars => (3 - mistakes).clamp(1, 3);

  Arrow? arrowAt(Cell c) {
    final id = _board[c];
    return id == null ? null : remaining[id];
  }

  /// Returns the first arrow in [a]'s escape path and how far away it is.
  (Arrow, int)? blockerOf(Arrow a) {
    var c = a.head.step(a.dir);
    var steps = 0;
    while (level.inBounds(c)) {
      final id = _board[c];
      if (id != null && id != a.id) return (remaining[id]!, steps);
      c = c.step(a.dir);
      steps++;
    }
    return null;
  }

  bool canEscape(Arrow a) => blockerOf(a) == null;

  TapResult tap(Cell c) {
    if (over) return const TapMissed();
    final arrow = arrowAt(c);
    if (arrow == null) return const TapMissed();
    moves++;
    final block = blockerOf(arrow);
    if (block != null) {
      hearts--;
      mistakes++;
      return TapBlocked(arrow, block.$1, block.$2);
    }
    remaining.remove(arrow.id);
    for (final cell in arrow.cells) {
      _board.remove(cell);
    }
    var travel = 0;
    var p = arrow.head.step(arrow.dir);
    while (level.inBounds(p)) {
      travel++;
      p = p.step(arrow.dir);
    }
    return TapEscaped(arrow, travel);
  }

  /// An arrow that can escape right now, or null once the level is cleared.
  /// Prefers the longest such arrow, since it frees up the most space.
  Arrow? hint() {
    Arrow? best;
    for (final a in remaining.values) {
      if (canEscape(a) && (best == null || a.length > best.length)) best = a;
    }
    return best;
  }

  /// Points for finishing: a base score for the level, a bonus per star,
  /// and a speed bonus.
  int score(Duration time) {
    final base = 100 + level.number * 20;
    final speed = (180 - time.inSeconds).clamp(0, 180);
    return base + stars * 50 + speed;
  }
}
