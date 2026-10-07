import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../data/game_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Settings'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          _Toggle(
                            icon: Icons.music_note_rounded,
                            label: 'Music',
                            value: app.musicOn,
                            onChanged: app.setMusic,
                          ),
                          _Toggle(
                            icon: Icons.volume_up_rounded,
                            label: 'Sound effects',
                            value: app.sfxOn,
                            onChanged: app.setSfx,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PLAYER',
                              style: TextStyle(
                                  color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_rounded, color: Colors.white),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(app.player?.name ?? '-',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: GameButton(
                                  label: 'SWITCH',
                                  icon: Icons.swap_horiz_rounded,
                                  color: const Color(0xFF3A86FF),
                                  expand: true,
                                  onTap: () => _switchPlayer(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GameButton(
                                  label: 'NEW',
                                  icon: Icons.person_add_rounded,
                                  color: const Color(0xFF8338EC),
                                  expand: true,
                                  onTap: () async {
                                    final name = await askPlayerName(context);
                                    if (name != null) await app.createPlayer(name);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const GlassCard(
                      child: Text(
                        'Progress, scores and settings are saved on this device in a local SQLite database. Every player on this device appears on the leaderboard.',
                        style: TextStyle(color: Colors.white70, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchPlayer(BuildContext context) async {
    final app = AppScope.read(context);
    final players = await app.repo.players();
    if (!context.mounted) return;
    final picked = await showDialog<Player>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Choose player', style: TextStyle(color: AppColors.ink)),
        children: [
          for (final p in players)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, p),
              child: Row(
                children: [
                  Icon(p.id == app.player?.id ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: AppColors.bgMid),
                  const SizedBox(width: 10),
                  Text(p.name, style: const TextStyle(color: AppColors.ink, fontSize: 16)),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) await app.selectPlayer(picked);
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.value, required this.onChanged});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.play,
      onChanged: onChanged,
    );
  }
}

/// Asks for a player name. Returns null if cancelled (when [cancellable]).
Future<String?> askPlayerName(BuildContext context, {bool cancellable = true}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: cancellable,
    builder: (c) => PopScope(
      canPop: cancellable,
      child: AlertDialog(
        title: const Text("What's your name?",
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: AppColors.ink, fontSize: 18),
          decoration: const InputDecoration(hintText: 'Player name'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(c, v.trim());
          },
        ),
        actions: [
          if (cancellable)
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(c, v);
            },
            child: const Text("LET'S GO"),
          ),
        ],
      ),
    ),
  );
}
