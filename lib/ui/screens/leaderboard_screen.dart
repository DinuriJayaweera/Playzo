import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../data/game_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/mascot.dart';

/// Players on this device ranked by total best score, read from SQLite.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final Future<List<LeaderboardEntry>> _entries = AppScope.read(context)
      .repo
      .leaderboard();

  @override
  Widget build(BuildContext context) {
    final me = AppScope.of(context).player?.id;
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Leaderboard'),
              Expanded(
                child: FutureBuilder(
                  future: _entries,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    final list = snap.data!;
                    if (list.isEmpty) {
                      return const Center(
                        child: MascotSays(
                          text: 'No scores yet.\nGo play!',
                          pose: MascotPose.point,
                          size: 120,
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _Podium(entries: list.take(3).toList()),
                        const SizedBox(height: 16),
                        for (var i = 0; i < list.length; i++)
                          if (list[i].playerId == me)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: MascotSays(
                                text: i == 0
                                    ? "You're number one!"
                                    : 'You are #${i + 1}. Keep climbing!',
                                pose: i == 0
                                    ? MascotPose.cheer
                                    : MascotPose.thumbsUp,
                                size: 80,
                                bubbleColor: context.palette.surface,
                                textColor: context.palette.ink,
                              ),
                            ),
                        for (var i = 0; i < list.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _Row(
                              rank: i + 1,
                              entry: list[i],
                              isMe: list[i].playerId == me,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _medals = [Color(0xFFFFC94A), Color(0xFFD7DCE5), Color(0xFFE59A5B)];

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Shown as 2nd, 1st, 3rd so the winner stands in the middle.
    final order = [1, 0, 2].where((i) => i < entries.length).toList();
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final i in order)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: i == 0 ? 30 : 24,
                    backgroundColor: _medals[i],
                    child: Text(
                      entries[i].name.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: i == 0 ? 26 : 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entries[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: [90.0, 66.0, 50.0][i],
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _medals[i],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.entry, required this.isMe});
  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: isMe ? Colors.white.withValues(alpha: 0.28) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rank <= 3
                  ? _medals[rank - 1]
                  : Colors.white.withValues(alpha: 0.2),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank <= 3 ? AppColors.ink : Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${entry.name} (you)' : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${entry.levels} levels  ·  ${entry.stars} ',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.gold,
                      size: 15,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${entry.totalScore}',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
