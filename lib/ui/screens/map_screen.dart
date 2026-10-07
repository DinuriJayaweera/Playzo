import 'dart:math';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../game/level_generator.dart';
import '../../game/shapes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/shape_icon.dart';
import 'game_screen.dart';

const _rowHeight = 118.0;

double _nodeX(int level, double width) =>
    width / 2 + sin(level * 0.85) * width * 0.27;

/// An endless winding road of levels, starting at the bottom. Cleared levels
/// light the road gold, and any of them can be replayed.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  ScrollController? _scroll;

  double _offsetFor(int level, double viewport) =>
      max(0.0, (level - 1) * _rowHeight - viewport * 0.35);

  void _play(int level) {
    final app = AppScope.read(context);
    if (level > app.unlocked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Clear level ${app.unlocked} first to unlock it.'),
        ));
      return;
    }
    Navigator.of(context).push(GameScreen.route(level));
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: 'Level Road',
                trailing: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text('${app.totalStars}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  _scroll ??= ScrollController(
                    initialScrollOffset: _offsetFor(app.unlocked, box.maxHeight),
                  );
                  return Stack(
                    children: [
                      ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        itemExtent: _rowHeight,
                        padding: const EdgeInsets.only(top: 40, bottom: 30),
                        // No itemCount: the road never ends.
                        itemBuilder: (context, i) => _RoadRow(
                          level: i + 1,
                          width: box.maxWidth,
                          unlocked: app.unlocked,
                          stars: app.results[i + 1]?.stars,
                          onTap: () => _play(i + 1),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: GameButton(
                          label: 'LEVEL ${app.unlocked}',
                          icon: Icons.play_arrow_rounded,
                          onTap: () => _play(app.unlocked),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 20,
                        child: RoundButton(
                          icon: Icons.my_location_rounded,
                          tooltip: 'Jump to current level',
                          onTap: () => _scroll?.animateTo(
                            _offsetFor(app.unlocked, box.maxHeight),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeInOutCubic,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadRow extends StatelessWidget {
  const _RoadRow({
    required this.level,
    required this.width,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final int level;
  final double width;
  final int unlocked;
  final int? stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final x = _nodeX(level, width);
    final shape = shapeForLevel(level);
    final rnd = Random(level * 31);
    const decorations = ['🌸', '🌴', '⭐', '🎈', '🍄', '💎', '🌈', '🍭', '🚀', '🎵'];
    final deco = decorations[rnd.nextInt(decorations.length)];
    final decoX = x < width / 2 ? width * 0.78 : width * 0.12;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RoadPainter(
              from: Offset(x, _rowHeight / 2),
              to: Offset(_nodeX(level + 1, width), -_rowHeight / 2),
              lit: level + 1 <= unlocked,
            ),
          ),
        ),
        if (level % 3 == 0)
          Positioned(
            left: decoX,
            top: _rowHeight / 2 - 18,
            child: Opacity(opacity: 0.8, child: Text(deco, style: const TextStyle(fontSize: 28))),
          ),
        Positioned(
          left: x - 40,
          top: _rowHeight / 2 - 40,
          child: _LevelNode(
            level: level,
            state: level < unlocked
                ? _NodeState.done
                : level == unlocked
                    ? _NodeState.current
                    : _NodeState.locked,
            stars: stars ?? 0,
            shape: shape,
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter({required this.from, required this.to, required this.lit});
  final Offset from;
  final Offset to;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = (from.dy + to.dy) / 2;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx, mid, to.dx, mid, to.dx, to.dy);
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke(Colors.black.withValues(alpha: 0.25), 30));
    canvas.drawPath(
        path, stroke(lit ? const Color(0xFFFF9F1C) : const Color(0xFF8B7FC7), 24));
    canvas.drawPath(
        path, stroke(lit ? AppColors.gold : const Color(0xFFB4A9E6), 16));
    // Dashed centre line.
    final dash = stroke(Colors.white.withValues(alpha: lit ? 0.9 : 0.45), 3);
    for (final metric in path.computeMetrics()) {
      for (var d = 6.0; d < metric.length; d += 16) {
        canvas.drawPath(metric.extractPath(d, min(d + 8, metric.length)), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) =>
      old.from != from || old.to != to || old.lit != lit;
}

enum _NodeState { done, current, locked }

class _LevelNode extends StatefulWidget {
  const _LevelNode({
    required this.level,
    required this.state,
    required this.stars,
    required this.shape,
    required this.onTap,
  });

  final int level;
  final _NodeState state;
  final int stars;
  final BoardShape shape;
  final VoidCallback onTap;

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.state == _NodeState.current) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_LevelNode old) {
    super.didUpdateWidget(old);
    if (widget.state == _NodeState.current && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (widget.state != _NodeState.current) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (List<Color> colors, Color rim) = switch (widget.state) {
      _NodeState.done => (const [Color(0xFFFFD25E), Color(0xFFFF9F1C)], const Color(0xFFB45309)),
      _NodeState.current => (const [Color(0xFFFF7A9A), Color(0xFFFF2E63)], const Color(0xFF9F1239)),
      _NodeState.locked => (const [Color(0xFFA79BD8), Color(0xFF7A6DB5)], const Color(0xFF4C3F8F)),
    };
    final current = widget.state == _NodeState.current;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Transform.scale(
          scale: current ? 1 + _pulse.value * 0.08 : 1,
          child: child,
        ),
        child: SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (current)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFF2E63).withValues(alpha: 0.6), blurRadius: 24),
                    ],
                  ),
                ),
              Container(
                width: current ? 70 : 60,
                height: current ? 70 : 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                  ),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [BoxShadow(color: rim, offset: const Offset(0, 5))],
                ),
                alignment: Alignment.center,
                child: widget.state == _NodeState.locked
                    ? const Icon(Icons.lock_rounded, color: Colors.white, size: 26)
                    : Text(
                        '${widget.level}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.level > 999 ? 16 : 22,
                          fontWeight: FontWeight.w900,
                          shadows: const [Shadow(blurRadius: 3, offset: Offset(0, 1))],
                        ),
                      ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: ShapeIcon(shape: widget.shape, size: 15, color: colors.last),
                ),
              ),
              if (widget.state == _NodeState.done)
                Positioned(bottom: -12, child: StarsRow(stars: widget.stars, size: 20)),
              if (current)
                Positioned(
                  bottom: -14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('PLAY',
                        style: TextStyle(
                            color: Color(0xFFFF2E63), fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
