import 'package:flutter_test/flutter_test.dart';
import 'package:playzo/game/game_state.dart';
import 'package:playzo/game/level_generator.dart';
import 'package:playzo/game/models.dart';

/// Clears a level by always tapping some escapable arrow.
bool solveGreedy(Level level) {
  final game = GameState(level, maxHearts: 1);
  while (!game.won) {
    final a = game.hint();
    if (a == null) return false;
    final r = game.tap(a.head);
    if (r is! TapEscaped) return false;
  }
  return true;
}

void main() {
  test('levels 1-300 are always solvable without dead ends', () {
    for (var n = 1; n <= 300; n++) {
      final level = generateLevel(n);
      expect(level.arrows, isNotEmpty, reason: 'level $n');
      expect(solveGreedy(level), isTrue, reason: 'level $n');
    }
  });

  test('levels are deterministic', () {
    final a = generateLevel(42), b = generateLevel(42);
    expect(a.arrows.length, b.arrows.length);
    for (var i = 0; i < a.arrows.length; i++) {
      expect(a.arrows[i].cells, b.arrows[i].cells);
      expect(a.arrows[i].dir, b.arrows[i].dir);
    }
  });

  test('arrows fill the shape tightly and stay inside it', () {
    for (var n = 1; n <= 120; n++) {
      final level = generateLevel(n);
      final used = <Cell>{};
      for (final a in level.arrows) {
        for (final c in a.cells) {
          expect(level.mask.contains(c), isTrue);
          expect(used.add(c), isTrue, reason: 'cells overlap on level $n');
        }
        for (var i = 1; i < a.cells.length; i++) {
          final d = (a.cells[i].x - a.cells[i - 1].x).abs() +
              (a.cells[i].y - a.cells[i - 1].y).abs();
          expect(d, 1, reason: 'arrow cells must be adjacent');
        }
      }
      final fill = used.length / level.mask.length;
      expect(fill, greaterThan(0.9), reason: 'level $n fill $fill');
    }
  });

  test('difficulty grows with level', () {
    final early = generateLevel(1), later = generateLevel(40);
    expect(later.mask.length, greaterThan(early.mask.length));
    expect(later.arrows.length, greaterThan(early.arrows.length));
  });

  test('tapping a blocked arrow costs a heart', () {
    final level = generateLevel(10);
    final game = GameState(level);
    final blocked = level.arrows.firstWhere((a) => !game.canEscape(a));
    final r = game.tap(blocked.cells.first);
    expect(r, isA<TapBlocked>());
    expect(game.hearts, 2);
    expect(game.stars, 2);
  });
}
