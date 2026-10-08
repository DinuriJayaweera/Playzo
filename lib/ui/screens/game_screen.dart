import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../app_state.dart';
import '../../game/game_state.dart';
import '../../game/level_generator.dart';
import '../../game/shapes.dart';
import '../../services/audio_service.dart';
import '../theme.dart';
import '../widgets/board_painter.dart';
import '../widgets/common.dart';
import '../widgets/mascot.dart';
import '../widgets/shape_icon.dart';
import 'help_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.levelNumber});
  final int levelNumber;

  static Route<void> route(int level) => PageRouteBuilder(
    pageBuilder: (_, _, _) => GameScreen(levelNumber: level),
    transitionsBuilder: (_, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(anim),
        child: child,
      ),
    ),
  );

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final level = generateLevel(widget.levelNumber);
  late GameState game;
  late Map<int, ArrowTrack> tracks;
  final Map<int, ArrowMotion> motions = {};
  final ValueNotifier<double> clock = ValueNotifier(0);
  late final Ticker _ticker = createTicker(_onTick);
  final Stopwatch _watch = Stopwatch();
  Timer? _secondTimer;
  int? hintId;
  double hintStart = 0;
  Set<int> flashIds = {};
  double flashStart = 0;
  bool _ended = false;

  /// What the mascot is saying right now, if anything.
  String? _buddyText;
  MascotPose _buddyPose = MascotPose.wave;
  Timer? _buddyTimer;
  bool _cheeredHalfway = false;

  void _say(String text, MascotPose pose, {int ms = 2200}) {
    _buddyTimer?.cancel();
    setState(() {
      _buddyText = text;
      _buddyPose = pose;
    });
    _buddyTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _buddyText = null);
    });
  }

  AppState get app => AppScope.read(context);
  double get _now => _watch.elapsedMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    _reset();
    _watch.start();
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !game.over) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _greet();
    });
  }

  void _greet() => _say(
    level.number == 1
        ? 'Tap an arrow with a clear path!'
        : 'Level ${level.number}. You got this!',
    MascotPose.wave,
  );

  void _reset() {
    game = GameState(level);
    tracks = {for (final a in level.arrows) a.id: ArrowTrack(a)};
    motions.clear();
    hintId = null;
    flashIds = {};
    _ended = false;
    _cheeredHalfway = false;
    _playTime.reset();
    _playTime.start();
  }

  /// Time spent on the current attempt (restarts on retry).
  final Stopwatch _playTime = Stopwatch();

  void _onTick(Duration _) {
    final now = _now;
    motions.removeWhere((id, m) {
      if (!m.done(now)) return false;
      if (m.kind == MotionKind.escape) tracks.remove(id);
      return true;
    });
    if (hintId != null && now - hintStart > 4) hintId = null;
    clock.value = now;
    // Only run while something is moving or glowing, to save battery.
    final active =
        motions.isNotEmpty || hintId != null || now - flashStart < 0.7;
    if (!active) _ticker.stop();
  }

  void _animate() {
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _secondTimer?.cancel();
    _buddyTimer?.cancel();
    clock.dispose();
    super.dispose();
  }

  void _onTap(Offset local, Size size) {
    if (game.over) return;
    final cell = cellAt(local, size, level);
    if (cell == null) return;
    final arrow = game.arrowAt(cell);
    // An arrow still bouncing back from a bump can't be tapped again yet.
    if (arrow == null || motions.containsKey(arrow.id)) return;

    final result = game.tap(cell);
    switch (result) {
      case TapMissed():
        return;
      case TapEscaped(:final arrow, :final travel):
        app.audio.play(Sfx.whoosh);
        HapticFeedback.lightImpact();
        if (hintId == arrow.id) hintId = null;
        final track = tracks[arrow.id]!;
        motions[arrow.id] = ArrowMotion(
          track: track,
          kind: MotionKind.escape,
          start: _now,
          distance: travel + track.length + 1.5,
        );
        _animate();
        setState(() {});
        if (game.won) {
          _buddyTimer?.cancel();
          _buddyText = null;
          _finish(won: true);
        } else if (!_cheeredHalfway &&
            game.cleared * 2 >= game.total &&
            game.total >= 6) {
          _cheeredHalfway = true;
          _say(
            game.mistakes == 0
                ? 'Halfway there, no mistakes!'
                : 'Halfway there!',
            MascotPose.thumbsUp,
          );
        }
      case TapBlocked(:final arrow, :final blocker, :final distance):
        app.audio.play(Sfx.wrong);
        HapticFeedback.heavyImpact();
        motions[arrow.id] = ArrowMotion(
          track: tracks[arrow.id]!,
          kind: MotionKind.bump,
          start: _now,
          distance: distance + 0.3,
        );
        flashIds = {arrow.id, blocker.id};
        flashStart = _now;
        _animate();
        setState(() {});
        if (game.lost) {
          _buddyTimer?.cancel();
          _buddyText = null;
          _finish(won: false);
        } else if (game.hearts == 1) {
          _say('Careful, last heart!', MascotPose.sad);
        } else {
          _say('Oops! Something is in the way.', MascotPose.sad);
        }
    }
  }

  Future<void> _finish({required bool won}) async {
    if (_ended) return;
    _ended = true;
    _playTime.stop();
    final time = _playTime.elapsed;
    final score = game.score(time);
    var firstClear = false;
    if (won) {
      firstClear = await app.completeLevel(
        level: level.number,
        stars: game.stars,
        score: score,
        time: time,
      );
    }
    await Future.delayed(Duration(milliseconds: won ? 700 : 600));
    if (!mounted) return;
    app.audio.play(won ? Sfx.win : Sfx.lose);
    final choice = await showGeneralDialog<_EndChoice>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 450),
      transitionBuilder: (_, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: child,
      ),
      pageBuilder: (_, _, _) => won
          ? _WinDialog(
              level: level.number,
              stars: game.stars,
              score: score,
              time: time,
              bonusHint: firstClear,
            )
          : _LoseDialog(level: level.number),
    );
    if (!mounted) return;
    switch (choice) {
      case _EndChoice.next:
        Navigator.of(context)
            .pushReplacement(GameScreen.route(level.number + 1));
      case _EndChoice.retry:
        setState(_reset);
      case _EndChoice.map:
      case null:
        Navigator.of(context).pop();
    }
  }

  Future<void> _useHint() async {
    if (game.over) return;
    final target = game.hint();
    if (target == null) return;
    if (hintId == target.id) return; // already showing
    if (!await app.useHint()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hints left. Clear a new level to earn one!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    app.audio.play(Sfx.hint);
    setState(() {
      hintId = target.id;
      hintStart = _now;
    });
    _say('Tap the glowing arrow!', MascotPose.point, ms: 3000);
    _animate();
  }

  Future<void> _confirmRestart() async {
    if (game.cleared == 0 && game.hearts == game.maxHearts) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restart level?'),
        content: const Text('Your progress on this level will be reset.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(_reset);
      _greet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final shape = shapeByName(level.shape);
    final secs = _playTime.elapsed.inSeconds;
    final timeText = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      body: GradientBackground(
        drift: false,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        RoundButton(
                          icon: Icons.arrow_back_rounded,
                          size: 44,
                          tooltip: 'Back to road',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LEVEL ${level.number}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Row(
                                children: [
                                  ShapeIcon(
                                    shape: shape,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      shape.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    timeText,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        HeartsRow(hearts: game.hearts, max: game.maxHearts),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LevelStrip(current: level.number, unlocked: state.unlocked),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ProgressBar(
                      cleared: game.cleared,
                      total: game.total,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.palette.board,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: InteractiveViewer(
                            maxScale: 3,
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final size = box.biggest;
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (d) => _onTap(d.localPosition, size),
                                  child: CustomPaint(
                                    size: size,
                                    painter: BoardPainter(
                                      BoardScene(
                                        level: level,
                                        arrows: tracks.values,
                                        motions: motions,
                                        clock: clock,
                                        hintId: hintId,
                                        hintStart: hintStart,
                                        flashIds: flashIds,
                                        flashStart: flashStart,
                                        dotColor: context.palette.dot,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        RoundButton(
                          icon: Icons.help_outline_rounded,
                          tooltip: 'How to play',
                          size: 54,
                          onTap: () => showHelpSheet(context),
                        ),
                        RoundButton(
                          icon: Icons.lightbulb_rounded,
                          tooltip: 'Hint',
                          size: 66,
                          color: AppColors.gold,
                          iconColor: Colors.white,
                          badge: '${state.hints}',
                          onTap: _useHint,
                        ),
                        RoundButton(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Restart',
                          size: 54,
                          onTap: _confirmRestart,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // The mascot pops up to cheer, warn and give hints.
              Positioned(
                left: 6,
                right: 40,
                bottom: 82,
                child: IgnorePointer(
                  child: AnimatedSlide(
                    offset: _buddyText == null
                        ? const Offset(-1.2, 0)
                        : Offset.zero,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity: _buddyText == null ? 0 : 1,
                      duration: const Duration(milliseconds: 250),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: MascotSays(
                          text: _buddyText ?? '',
                          pose: _buddyPose,
                          size: 84,
                          bubbleColor: context.palette.surface,
                          textColor: context.palette.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.cleared, required this.total});
  final int cleared;
  final int total;

  @override
  Widget build(BuildContext context) {
    final f = total == 0 ? 0.0 : cleared / total;
    return Row(
      children: [
        const Icon(Icons.north_east_rounded, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 300),
                  widthFactor: f,
                  child: Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF06D6A0),
                          Color(0xFFFFC300),
                          Color(0xFFFF4D6D),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$cleared / $total',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// A mini road showing the levels around the current one.
class _LevelStrip extends StatelessWidget {
  const _LevelStrip({required this.current, required this.unlocked});
  final int current;
  final int unlocked;

  @override
  Widget build(BuildContext context) {
    final first = (current - 2).clamp(1, 1 << 30);
    final levels = List.generate(5, (i) => first + i);
    return SizedBox(
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < levels.length; i++) ...[
            if (i > 0)
              Container(
                width: 22,
                height: 4,
                decoration: BoxDecoration(
                  color: levels[i] <= unlocked
                      ? AppColors.gold
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            _StripNode(level: levels[i], current: current, unlocked: unlocked),
          ],
        ],
      ),
    );
  }
}

class _StripNode extends StatelessWidget {
  const _StripNode({
    required this.level,
    required this.current,
    required this.unlocked,
  });
  final int level;
  final int current;
  final int unlocked;

  @override
  Widget build(BuildContext context) {
    final isCurrent = level == current;
    final done = level < unlocked && !isCurrent;
    final locked = level > unlocked;
    final size = isCurrent ? 34.0 : 26.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrent
            ? AppColors.heart
            : done
            ? AppColors.gold
            : Colors.white.withValues(alpha: locked ? 0.15 : 0.35),
        border: Border.all(color: Colors.white, width: isCurrent ? 3 : 1.5),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : locked
          ? const Icon(Icons.lock_rounded, size: 13, color: Colors.white70)
          : Text(
              '$level',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: isCurrent ? 13 : 11,
              ),
            ),
    );
  }
}

enum _EndChoice { next, retry, map }

class _WinDialog extends StatelessWidget {
  const _WinDialog({
    required this.level,
    required this.stars,
    required this.score,
    required this.time,
    required this.bonusHint,
  });

  final int level;
  final int stars;
  final int score;
  final Duration time;
  final bool bonusHint;

  @override
  Widget build(BuildContext context) {
    final secs = time.inSeconds;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7C3AED), Color(0xFF0E7490)],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Mascot(pose: MascotPose.cheer, size: 104),
              const SizedBox(height: 6),
              const GradientText(
                'LEVEL\nCOMPLETE!',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 500 + i * 250),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i == 1 ? 14 : 0),
                      child: Icon(
                        i < stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: i == 1 ? 72 : 56,
                        color: i < stars ? AppColors.gold : Colors.white38,
                        shadows: const [
                          Shadow(color: Colors.black38, blurRadius: 8),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                'Score  $score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Time ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              if (bonusHint) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        color: AppColors.gold,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '+1 hint earned',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              GameButton(
                label: 'NEXT LEVEL',
                icon: Icons.play_arrow_rounded,
                big: true,
                onTap: () => Navigator.pop(context, _EndChoice.next),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RoundButton(
                    icon: Icons.map_rounded,
                    tooltip: 'Road map',
                    onTap: () => Navigator.pop(context, _EndChoice.map),
                  ),
                  const SizedBox(width: 20),
                  RoundButton(
                    icon: Icons.replay_rounded,
                    tooltip: 'Play again',
                    onTap: () => Navigator.pop(context, _EndChoice.retry),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoseDialog extends StatelessWidget {
  const _LoseDialog({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 310,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFBE123C), Color(0xFF581C87)],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Mascot(pose: MascotPose.sad, size: 104),
              const SizedBox(height: 8),
              const Text(
                'OUT OF HEARTS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Level $level needs a clear path.\nCheck where each arrow points!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 22),
              GameButton(
                label: 'TRY AGAIN',
                icon: Icons.replay_rounded,
                big: true,
                color: const Color(0xFFFF9F1C),
                onTap: () => Navigator.pop(context, _EndChoice.retry),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, _EndChoice.map),
                icon: const Icon(Icons.map_rounded, color: Colors.white),
                label: const Text(
                  'Back to road',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
