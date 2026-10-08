import 'package:flutter_test/flutter_test.dart';
import 'package:playzo/data/game_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late GameRepository repo;

  setUp(() async {
    sqfliteFfiInit();
    repo = await GameRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() => repo.close());

  test('first launch has no player, creating one selects it', () async {
    expect(await repo.currentPlayer(), isNull);
    final p = await repo.createPlayer('  Dinu ');
    expect(p.name, 'Dinu');
    expect(p.hints, GameRepository.startingHints);
    expect((await repo.currentPlayer())!.id, p.id);
  });

  test('progress unlocks the next level and keeps best results', () async {
    final p = await repo.createPlayer('A');
    expect(await repo.unlockedLevel(p.id), 1);
    expect(
      await repo.saveResult(
        playerId: p.id,
        level: 1,
        stars: 2,
        score: 300,
        timeMs: 9000,
      ),
      isTrue,
    );
    expect(
      await repo.saveResult(
        playerId: p.id,
        level: 1,
        stars: 3,
        score: 250,
        timeMs: 5000,
      ),
      isFalse,
    );
    expect(await repo.unlockedLevel(p.id), 2);
    final r = (await repo.results(p.id))[1]!;
    expect(r.stars, 3);
    expect(r.score, 300);
    expect(r.timeMs, 5000);
  });

  test('leaderboard ranks players by total score', () async {
    final a = await repo.createPlayer('Alice');
    final b = await repo.createPlayer('Bob');
    await repo.saveResult(
      playerId: a.id,
      level: 1,
      stars: 3,
      score: 100,
      timeMs: 1,
    );
    await repo.saveResult(
      playerId: b.id,
      level: 1,
      stars: 3,
      score: 200,
      timeMs: 1,
    );
    await repo.saveResult(
      playerId: b.id,
      level: 2,
      stars: 1,
      score: 50,
      timeMs: 1,
    );
    final board = await repo.leaderboard();
    expect(board.map((e) => e.name), ['Bob', 'Alice']);
    expect(board.first.totalScore, 250);
    expect(board.first.levels, 2);
  });

  test('settings and hints persist', () async {
    final p = await repo.createPlayer('A');
    expect(await repo.musicOn(), isTrue);
    await repo.setMusic(false);
    expect(await repo.musicOn(), isFalse);
    expect(await repo.themeMode(), 'system');
    await repo.setThemeMode('dark');
    expect(await repo.themeMode(), 'dark');
    await repo.setHints(p.id, 9);
    expect((await repo.playerById(p.id))!.hints, 9);
  });
}
