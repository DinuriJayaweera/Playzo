import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/mascot.dart';
import 'game_screen.dart';
import 'help_screen.dart';
import 'leaderboard_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onboard());
  }

  /// First launch: ask for a name, then show how to play.
  Future<void> _onboard() async {
    final app = AppScope.read(context);
    if (app.player == null) {
      final name = await askPlayerName(context, cancellable: false);
      if (name == null) return;
      await app.createPlayer(name);
    }
    if (!app.seenHelp && mounted) {
      await app.markHelpSeen();
      if (mounted) await showHelpSheet(context);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              app.player?.name ?? '...',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _Stat(
                      icon: Icons.star_rounded,
                      color: AppColors.gold,
                      value: '${app.totalStars}',
                    ),
                    const SizedBox(width: 8),
                    _Stat(
                      icon: Icons.lightbulb_rounded,
                      color: AppColors.gold,
                      value: '${app.hints}',
                    ),
                    const SizedBox(width: 8),
                    RoundButton(
                      icon: Theme.of(context).brightness == Brightness.dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 40,
                      tooltip: 'Light / dark',
                      onTap: () => app.setThemeMode(
                        Theme.of(context).brightness == Brightness.dark
                            ? ThemeMode.light
                            : ThemeMode.dark,
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _bob,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                      0,
                      -8 * Curves.easeInOut.transform(_bob.value),
                    ),
                    child: child,
                  ),
                  child: const _Logo(),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap. Slide. Escape!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                MascotSays(
                  text: app.player == null
                      ? 'Hi there!'
                      : 'Hi ${app.player!.name}!\nReady for level ${app.unlocked}?',
                  pose: MascotPose.wave,
                  size: 112,
                  bubbleColor: context.palette.surface,
                  textColor: context.palette.ink,
                ),
                const Spacer(),
                GameButton(
                  label: 'PLAY  ·  LEVEL ${app.unlocked}',
                  icon: Icons.play_arrow_rounded,
                  big: true,
                  onTap: app.player == null
                      ? null
                      : () =>
                            Navigator.of(context)
                                .push(GameScreen.route(app.unlocked)),
                ),
                const SizedBox(height: 16),
                GameButton(
                  label: 'LEVEL ROAD',
                  icon: Icons.route_rounded,
                  color: const Color(0xFFFF9F1C),
                  onTap: app.player == null
                      ? null
                      : () => _open(const MapScreen()),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MenuIcon(
                      icon: Icons.emoji_events_rounded,
                      label: 'Ranks',
                      color: const Color(0xFFFFC300),
                      onTap: () => _open(const LeaderboardScreen()),
                    ),
                    _MenuIcon(
                      icon: Icons.help_rounded,
                      label: 'Help',
                      color: const Color(0xFF06D6A0),
                      onTap: () => showHelpSheet(context),
                    ),
                    _MenuIcon(
                      icon: app.musicOn
                          ? Icons.music_note_rounded
                          : Icons.music_off_rounded,
                      label: 'Music',
                      color: const Color(0xFFFF4D6D),
                      onTap: () => app.setMusic(!app.musicOn),
                    ),
                    _MenuIcon(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      color: const Color(0xFF3A86FF),
                      onTap: () => _open(const SettingsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        GradientText(
          'ARROW\nESCAPE',
          style: TextStyle(
            fontSize: 58,
            fontWeight: FontWeight.w900,
            height: 0.95,
            letterSpacing: 3,
            shadows: [
              Shadow(
                color: Colors.black45,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value});
  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  const _MenuIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RoundButton(
          icon: icon,
          color: color,
          iconColor: Colors.white,
          size: 58,
          onTap: onTap,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
