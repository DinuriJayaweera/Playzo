import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum Sfx { tap, whoosh, wrong, win, lose, hint }

/// Background music and sound effects. Errors are swallowed, so a device
/// without audio, or a test run, never breaks the game.
class AudioService {
  AudioPlayer? _music;
  final Map<Sfx, AudioPlayer> _sfx = {};
  bool musicOn = true;
  bool sfxOn = true;
  bool _paused = false;

  Future<void> init({required bool music, required bool sfx}) async {
    musicOn = music;
    sfxOn = sfx;
    try {
      _music = AudioPlayer();
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(0.35);
      if (musicOn) await _music!.play(AssetSource('audio/music.mp3'));
    } catch (e) {
      debugPrint('Music unavailable: $e');
      _music = null;
    }
  }

  Future<void> setMusic(bool on) async {
    musicOn = on;
    try {
      if (on && !_paused) {
        await _music?.play(AssetSource('audio/music.mp3'));
      } else {
        await _music?.pause();
      }
    } catch (_) {}
  }

  void setSfx(bool on) => sfxOn = on;

  /// Called when the app goes to the background or comes back.
  Future<void> setPaused(bool paused) async {
    _paused = paused;
    try {
      if (paused) {
        await _music?.pause();
      } else if (musicOn) {
        await _music?.resume();
      }
    } catch (_) {}
  }

  Future<void> play(Sfx sfx) async {
    if (!sfxOn) return;
    try {
      final player = _sfx.putIfAbsent(sfx, AudioPlayer.new);
      await player.stop();
      await player.play(AssetSource('audio/${sfx.name}.mp3'), volume: 0.9);
    } catch (_) {}
  }
}
