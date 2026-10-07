import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playzo/app_state.dart';
import 'package:playzo/data/game_repository.dart';
import 'package:playzo/game/game_state.dart';
import 'package:playzo/game/level_generator.dart';
import 'package:playzo/game/models.dart';
import 'package:playzo/services/audio_service.dart';
import 'package:playzo/ui/screens/game_screen.dart';
import 'package:playzo/ui/theme.dart';
import 'package:playzo/ui/widgets/board_painter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SilentAudio extends AudioService {
  @override
  Future<void> init({required bool music, required bool sfx}) async {}
  @override
  Future<void> play(Sfx sfx) async {}
}

void main() {
  testWidgets('playing level 1 through to the win dialog saves progress',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late AppState app;
    await tester.runAsync(() async {
      sqfliteFfiInit();
      final repo = await GameRepository.open(
          factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      app = AppState(repo, SilentAudio());
      await app.load();
      await app.createPlayer('Tester');
    });

    await tester.pumpWidget(AppScope(
      state: app,
      child: MaterialApp(
        theme: buildTheme(),
        home: const GameScreen(levelNumber: 1),
      ),
    ));
    await tester.pump();

    final level = generateLevel(1);
    final board = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BoardPainter);
    final rect = tester.getRect(board);
    Offset at(Cell c) {
      final size = rect.size;
      final cell = (size.width / level.width) < (size.height / level.height)
          ? size.width / level.width
          : size.height / level.height;
      final origin = Offset((size.width - cell * level.width) / 2,
          (size.height - cell * level.height) / 2);
      return rect.topLeft + origin + c.center * cell;
    }

    // A wrong move first: it should cost exactly one heart.
    final shadow = GameState(level);
    final blocked = level.arrows.firstWhere((a) => !shadow.canEscape(a));
    await tester.tapAt(at(blocked.cells.first));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.heart_broken), findsOneWidget);

    // Then clear the board, always choosing an arrow with a free path.
    while (!shadow.won) {
      final a = shadow.hint()!;
      shadow.tap(a.head);
      await tester.tapAt(at(a.head));
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();

    expect(find.text('NEXT LEVEL'), findsOneWidget);
    expect(app.unlocked, 2);
    expect(app.results[1]!.stars, 2);
    expect(app.hints, GameRepository.startingHints + 1);
  });
}
