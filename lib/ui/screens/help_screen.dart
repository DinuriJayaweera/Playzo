import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/mascot.dart';

class _Tip {
  const _Tip(this.icon, this.color, this.title, this.text);
  final IconData icon;
  final Color color;
  final String title;
  final String text;
}

const _tips = [
  _Tip(
    Icons.flag_rounded,
    Color(0xFF06D6A0),
    'Goal',
    'Clear the board! Tap arrows to slide them off the dotted canvas until none are left.',
  ),
  _Tip(
    Icons.open_with_rounded,
    Color(0xFF3A86FF),
    'How arrows move',
    'Each arrow points up, down, left or right, and only moves that way. Its body follows the head like a snake.',
  ),
  _Tip(
    Icons.block_rounded,
    Color(0xFFFF9F1C),
    'Clear path',
    'An arrow can only leave if nothing is in front of it. Free the arrows on the outside first.',
  ),
  _Tip(
    Icons.favorite_rounded,
    AppColors.heart,
    '3 hearts',
    'Tapping a blocked arrow bumps it and costs a heart. Lose all 3 and you retry the level.',
  ),
  _Tip(
    Icons.lightbulb_rounded,
    AppColors.gold,
    'Hints',
    'Stuck? A hint makes a free arrow glow. Every new level you clear earns one more hint.',
  ),
  _Tip(
    Icons.star_rounded,
    Color(0xFFFFC300),
    'Stars & score',
    'No mistakes gives 3 stars. Bigger levels, more stars and faster clears all score more points for the leaderboard.',
  ),
  _Tip(
    Icons.route_rounded,
    Color(0xFF8338EC),
    'Endless road',
    'Levels never end and get harder as you go, with bigger boards, longer twisting arrows and new shapes. Clear a level to unlock the next, and replay any cleared level from the road.',
  ),
  _Tip(
    Icons.zoom_in_rounded,
    Color(0xFF2EC4B6),
    'Zoom',
    'Big boards can be pinched to zoom in for precise taps.',
  ),
];

class _HelpList extends StatelessWidget {
  const _HelpList({this.controller});
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _tips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final t = _tips[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: t.color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: t.color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(t.icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: TextStyle(
                      color: context.palette.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.text,
                    style: TextStyle(
                      color: context.palette.ink.withValues(alpha: 0.75),
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shows how-to-play as a bottom sheet over the current screen.
Future<void> showHelpSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, controller) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Mascot(pose: MascotPose.thumbsUp, size: 76),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOW TO PLAY',
                      style: TextStyle(
                        color: context.palette.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      "Hi, I'm Arrowy! Let's escape!",
                      style: TextStyle(
                        color: context.palette.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _HelpList(controller: controller)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.play,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'GOT IT!',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
