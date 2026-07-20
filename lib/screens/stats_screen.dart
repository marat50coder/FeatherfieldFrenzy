import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = GameStorage.instance;
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ScreenHeader(
                  title: 'Statistics',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      WoodPanel(
                        child: Column(
                          children: [
                            _row('Best score', '${store.bestOverall}',
                                Icons.emoji_events_rounded),
                            _row('Games played', '${store.statGames}',
                                Icons.sports_esports_rounded),
                            _row('Total jumps', '${store.statJumps}',
                                Icons.stairs_rounded),
                            _row('Platforms bounced', '${store.statPlatforms}',
                                Icons.grid_view_rounded),
                            _row('Rockets used', '${store.statRockets}',
                                Icons.rocket_launch_rounded),
                            _row('Springs hit', '${store.statSprings}',
                                Icons.vertical_align_top_rounded),
                            _row('Coins earned', '${store.statCoinsEarned}',
                                Icons.monetization_on_rounded),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Best per world', style: AppTheme.title(20)),
                      const SizedBox(height: 8),
                      WoodPanel(
                        child: Column(
                          children: kThemes
                              .map((t) => _row(t.name,
                                  '${store.bestScore(t.index)}', Icons.flag_rounded))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.brown, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTheme.body(16, color: AppTheme.ink)),
          ),
          Text(value, style: AppTheme.title(18, color: AppTheme.ink)),
        ],
      ),
    );
  }
}
