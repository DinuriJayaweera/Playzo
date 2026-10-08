import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// The shared purple-to-teal backdrop, with softly drifting arrows behind it.
class GradientBackground extends StatefulWidget {
  const GradientBackground({super.key, required this.child, this.drift = true});
  final Widget child;
  final bool drift;

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );

  @override
  void initState() {
    super.initState();
    if (widget.drift) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.bgTop, palette.bgMid, palette.bgBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.drift)
            IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _DriftPainter(_c, palette.driftAlpha),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _DriftPainter extends CustomPainter {
  _DriftPainter(this.anim, this.alpha) : super(repaint: anim);
  final Animation<double> anim;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7);
    for (var i = 0; i < 16; i++) {
      final color = arrowColors[i % arrowColors.length].withValues(
        alpha: alpha,
      );
      final x = rnd.nextDouble() * size.width;
      final speed = 0.5 + rnd.nextDouble();
      final y =
          ((rnd.nextDouble() - anim.value * speed) % 1.0) *
              (size.height + 120) -
          60;
      final len = 26.0 + rnd.nextDouble() * 40;
      final up = i.isEven;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      final a = Offset(x, y + (up ? len : 0));
      final b = Offset(x, y + (up ? 0 : len));
      canvas.drawLine(a, b, paint);
      final dir = up ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(b.dx, b.dy + dir * 12)
        ..lineTo(b.dx - 10, b.dy - dir * 2)
        ..lineTo(b.dx + 10, b.dy - dir * 2)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_DriftPainter old) => old.alpha != alpha;
}

/// A chunky, glossy game button with a pressed-down effect.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = AppColors.play,
    this.big = false,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final bool big;
  final bool expand;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final depth = widget.big ? 6.0 : 4.0;
    final base = widget.color;
    final dark = Color.lerp(base, Colors.black, 0.35)!;
    final light = Color.lerp(base, Colors.white, 0.25)!;
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: Colors.white, size: widget.big ? 30 : 22),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: widget.big ? 24 : 16,
              letterSpacing: 1,
              shadows: const [Shadow(blurRadius: 2, offset: Offset(0, 1))],
            ),
          ),
        ),
      ],
    );
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: EdgeInsets.only(
          top: _down ? depth : 0,
          bottom: _down ? 0 : depth,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: widget.big ? 34 : 20,
          vertical: widget.big ? 16 : 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.big ? 28 : 18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.onTap == null
                ? [Colors.grey, Colors.grey]
                : [light, base],
          ),
          boxShadow: [
            BoxShadow(color: dark, offset: Offset(0, _down ? 0 : depth)),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: Offset(0, depth + 4),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}

/// A round icon button with an optional count badge.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.iconColor,
    this.badge,
    this.size = 48,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// Defaults to the theme's button colours.
  final Color? color;
  final Color? iconColor;
  final String? badge;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final button = GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color ?? palette.button,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor ?? palette.buttonIcon,
              size: size * 0.55,
            ),
          ),
          if (badge != null)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.heart,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Lives left this level. A lost heart pops and fades to grey.
class HeartsRow extends StatelessWidget {
  const HeartsRow({
    super.key,
    required this.hearts,
    this.max = 3,
    this.size = 26,
  });
  final int hearts;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final alive = i < hearts;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedScale(
            scale: alive ? 1 : 0.8,
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            child: Icon(
              alive ? Icons.favorite : Icons.heart_broken,
              size: size,
              color: alive
                  ? AppColors.heart
                  : Colors.white.withValues(alpha: 0.3),
              shadows: alive
                  ? const [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class StarsRow extends StatelessWidget {
  const StarsRow({
    super.key,
    required this.stars,
    this.size = 16,
    this.gap = 0,
  });
  final int stars;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: gap),
          child: Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < stars ? AppColors.gold : Colors.white54,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 3)],
          ),
        );
      }),
    );
  }
}

/// A frosted-glass panel used for headers and list rows.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.palette.glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

/// A gradient-filled title, for the logo and big headings.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style, this.colors});
  final String text;
  final TextStyle style;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => LinearGradient(
        colors:
            colors ??
            const [Color(0xFFFFE066), Color(0xFFFF6B9A), Color(0xFF7AE7FF)],
      ).createShader(r),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          RoundButton(
            icon: Icons.arrow_back_rounded,
            size: 44,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
