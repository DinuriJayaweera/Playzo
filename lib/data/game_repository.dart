import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class Player {
  const Player({required this.id, required this.name, required this.hints});
  final int id;
  final String name;
  final int hints;
}

class LevelResult {
  const LevelResult({
    required this.level,
    required this.stars,
    required this.score,
    required this.timeMs,
  });
  final int level;
  final int stars;
  final int score;
  final int timeMs;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.name,
    required this.totalScore,
    required this.levels,
    required this.stars,
  });
  final int playerId;
  final String name;
  final int totalScore;
  final int levels;
  final int stars;
}

/// All persistent game data lives in a local SQLite database.
class GameRepository {
  GameRepository._(this._db);

  final Database _db;

  static const startingHints = 5;

  static Future<GameRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'playzo.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE players(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              hints INTEGER NOT NULL DEFAULT $startingHints,
              created_at INTEGER NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE level_results(
              player_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
              level INTEGER NOT NULL,
              stars INTEGER NOT NULL,
              best_score INTEGER NOT NULL,
              best_time_ms INTEGER NOT NULL,
              completed_at INTEGER NOT NULL,
              PRIMARY KEY(player_id, level)
            )''');
          await db.execute('''
            CREATE TABLE settings(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )''');
        },
      ),
    );
    return GameRepository._(db);
  }

  Future<void> close() => _db.close();

  // ---- settings ----

  Future<String?> _setting(String key) async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _setSetting(String key, String value) => _db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<bool> musicOn() async => (await _setting('music')) != '0';
  Future<bool> sfxOn() async => (await _setting('sfx')) != '0';
  Future<void> setMusic(bool on) => _setSetting('music', on ? '1' : '0');
  Future<void> setSfx(bool on) => _setSetting('sfx', on ? '1' : '0');

  /// 'system', 'light' or 'dark'.
  Future<String> themeMode() async => await _setting('theme') ?? 'system';
  Future<void> setThemeMode(String mode) => _setSetting('theme', mode);
  Future<bool> seenHelp() async => (await _setting('seen_help')) == '1';
  Future<void> markHelpSeen() => _setSetting('seen_help', '1');

  // ---- players ----

  Player _player(Map<String, Object?> row) => Player(
    id: row['id'] as int,
    name: row['name'] as String,
    hints: row['hints'] as int,
  );

  Future<List<Player>> players() async => (await _db.query(
    'players',
    orderBy: 'name COLLATE NOCASE',
  )).map(_player).toList();

  Future<Player?> playerById(int id) async {
    final rows = await _db.query('players', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _player(rows.first);
  }

  Future<Player?> playerByName(String name) async {
    final rows = await _db.query(
      'players',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name.trim()],
    );
    return rows.isEmpty ? null : _player(rows.first);
  }

  /// The active player, or null on first launch.
  Future<Player?> currentPlayer() async {
    final id = int.tryParse(await _setting('current_player') ?? '');
    return id == null ? null : playerById(id);
  }

  /// Creates a player (or reuses one with the same name) and selects them.
  Future<Player> createPlayer(String name) async {
    final clean = name.trim();
    var player = await playerByName(clean);
    if (player == null) {
      final id = await _db.insert('players', {
        'name': clean,
        'hints': startingHints,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      player = (await playerById(id))!;
    }
    await selectPlayer(player.id);
    return player;
  }

  Future<void> selectPlayer(int id) => _setSetting('current_player', '$id');

  Future<void> setHints(int playerId, int hints) => _db.update(
    'players',
    {'hints': hints},
    where: 'id = ?',
    whereArgs: [playerId],
  );

  // ---- progress ----

  Future<Map<int, LevelResult>> results(int playerId) async {
    final rows = await _db.query(
      'level_results',
      where: 'player_id = ?',
      whereArgs: [playerId],
    );
    return {
      for (final r in rows)
        r['level'] as int: LevelResult(
          level: r['level'] as int,
          stars: r['stars'] as int,
          score: r['best_score'] as int,
          timeMs: r['best_time_ms'] as int,
        ),
    };
  }

  /// The furthest level the player may play: one past their best clear.
  Future<int> unlockedLevel(int playerId) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(level) AS m FROM level_results WHERE player_id = ?',
      [playerId],
    );
    return ((rows.first['m'] as int?) ?? 0) + 1;
  }

  /// Records a clear, keeping the best stars, score and time.
  /// Returns true when this is the first time the level was completed.
  Future<bool> saveResult({
    required int playerId,
    required int level,
    required int stars,
    required int score,
    required int timeMs,
  }) {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'level_results',
        where: 'player_id = ? AND level = ?',
        whereArgs: [playerId, level],
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      if (rows.isEmpty) {
        await txn.insert('level_results', {
          'player_id': playerId,
          'level': level,
          'stars': stars,
          'best_score': score,
          'best_time_ms': timeMs,
          'completed_at': now,
        });
        return true;
      }
      final old = rows.first;
      await txn.update(
        'level_results',
        {
          'stars': stars > (old['stars'] as int) ? stars : old['stars'],
          'best_score': score > (old['best_score'] as int)
              ? score
              : old['best_score'],
          'best_time_ms': timeMs < (old['best_time_ms'] as int)
              ? timeMs
              : old['best_time_ms'],
          'completed_at': now,
        },
        where: 'player_id = ? AND level = ?',
        whereArgs: [playerId, level],
      );
      return false;
    });
  }

  Future<List<LeaderboardEntry>> leaderboard({int limit = 50}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT p.id, p.name,
             COALESCE(SUM(r.best_score), 0) AS total,
             COUNT(r.level) AS levels,
             COALESCE(SUM(r.stars), 0) AS stars
      FROM players p
      LEFT JOIN level_results r ON r.player_id = p.id
      GROUP BY p.id
      ORDER BY total DESC, levels DESC, p.name COLLATE NOCASE
      LIMIT ?''',
      [limit],
    );
    return rows
        .map(
          (r) => LeaderboardEntry(
            playerId: r['id'] as int,
            name: r['name'] as String,
            totalScore: r['total'] as int,
            levels: r['levels'] as int,
            stars: r['stars'] as int,
          ),
        )
        .toList();
  }
}
