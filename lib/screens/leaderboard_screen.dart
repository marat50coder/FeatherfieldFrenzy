import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = GameStorage.instance;
    // Build a ranking from the player's best score per world.
    final entries = kThemes
        .map((t) => MapEntry(t, store.bestScore(t.index)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ScreenHeader(
                  title: 'Leaderboard',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                WoodPanel(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your best overall',
                          style: AppTheme.body(16, color: AppTheme.brown)),
                      Text('${store.bestOverall}',
                          style: AppTheme.title(24, color: AppTheme.ink)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Top worlds', style: AppTheme.title(20)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      return WoodPanel(
                        child: Row(
                          children: [
                            _rankBadge(i + 1),
                            const SizedBox(width: 12),
                            Image.asset(e.key.bird, width: 44, height: 44),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(e.key.name,
                                  style:
                                      AppTheme.body(17, color: AppTheme.ink)),
                            ),
                            Text('${e.value}',
                                style: AppTheme.title(20, color: AppTheme.ink)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rankBadge(int rank) {
    final colors = {
      1: const Color(0xFFFFD54F),
      2: const Color(0xFFB0BEC5),
      3: const Color(0xFFD7A56A),
    };
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors[rank] ?? AppTheme.sky,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text('$rank', style: AppTheme.title(16)),
    );
  }
}
