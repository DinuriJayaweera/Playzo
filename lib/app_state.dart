import 'package:flutter/material.dart';

import 'data/game_repository.dart';
import 'services/audio_service.dart';

/// App-wide state: the active player, their progress and settings.
class AppState extends ChangeNotifier {
  AppState(this.repo, this.audio);

  final GameRepository repo;
  final AudioService audio;

  Player? player;
  Map<int, LevelResult> results = {};
  int unlocked = 1;
  bool musicOn = true;
  bool sfxOn = true;
  bool seenHelp = false;
  ThemeMode themeMode = ThemeMode.system;

  int get hints => player?.hints ?? 0;
  int get totalStars => results.values.fold(0, (s, r) => s + r.stars);
  int get totalScore => results.values.fold(0, (s, r) => s + r.score);

  Future<void> load() async {
    musicOn = await repo.musicOn();
    sfxOn = await repo.sfxOn();
    seenHelp = await repo.seenHelp();
    themeMode = ThemeMode.values.byName(await repo.themeMode());
    player = await repo.currentPlayer();
    await _loadProgress();
    await audio.init(music: musicOn, sfx: sfxOn);
  }

  Future<void> _loadProgress() async {
    final p = player;
    if (p == null) {
      results = {};
      unlocked = 1;
    } else {
      results = await repo.results(p.id);
      unlocked = await repo.unlockedLevel(p.id);
    }
    notifyListeners();
  }

  Future<void> createPlayer(String name) async {
    player = await repo.createPlayer(name);
    await _loadProgress();
  }

  Future<void> selectPlayer(Player p) async {
    await repo.selectPlayer(p.id);
    player = await repo.playerById(p.id);
    await _loadProgress();
  }

  /// Saves a cleared level. Every first-time clear earns a free hint.
  Future<bool> completeLevel({
    required int level,
    required int stars,
    required int score,
    required Duration time,
  }) async {
    final p = player;
    if (p == null) return false;
    final first = await repo.saveResult(
      playerId: p.id,
      level: level,
      stars: stars,
      score: score,
      timeMs: time.inMilliseconds,
    );
    if (first) await repo.setHints(p.id, p.hints + 1);
    player = await repo.playerById(p.id);
    await _loadProgress();
    return first;
  }

  Future<bool> useHint() async {
    final p = player;
    if (p == null || p.hints <= 0) return false;
    await repo.setHints(p.id, p.hints - 1);
    player = await repo.playerById(p.id);
    notifyListeners();
    return true;
  }

  Future<void> setMusic(bool on) async {
    musicOn = on;
    await repo.setMusic(on);
    await audio.setMusic(on);
    notifyListeners();
  }

  Future<void> setSfx(bool on) async {
    sfxOn = on;
    await repo.setSfx(on);
    audio.setSfx(on);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await repo.setThemeMode(mode.name);
    notifyListeners();
  }

  Future<void> markHelpSeen() async {
    seenHelp = true;
    await repo.markHelpSeen();
  }
}

/// Makes [AppState] available to the widget tree and rebuilds dependants
/// when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads the state without subscribing to rebuilds.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
