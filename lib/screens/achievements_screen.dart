import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../services/audio.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'menu_screen.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final store = GameStorage.instance;

  @override
  Widget build(BuildContext context) {
    final unlockedCount =
        kAchievements.where((a) => store.isAchievementUnlocked(a.id)).length;
    final overall = unlockedCount / kAchievements.length;

    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ScreenHeader(
                  title: 'Achievements',
                  onBack: () => Navigator.pop(context),
                  actions: const [CoinPill()],
                ),
                const SizedBox(height: 12),
                // Overall progress tracker.
                WoodPanel(
                  child: Row(
                    children: [
                      _TrophyRing(progress: overall),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Collection',
                                style:
                                    AppTheme.title(20, color: AppTheme.ink)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: overall,
                                minHeight: 12,
                                backgroundColor: Colors.black12,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('$unlockedCount of ${kAchievements.length} unlocked',
                                style:
                                    AppTheme.body(13, color: AppTheme.brown)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: kAchievements.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _card(kAchievements[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(AchievementDef a) {
    final unlocked = store.isAchievementUnlocked(a.id);
    final claimed = store.isAchievementClaimed(a.id);
    final current = store.achievementProgress(a.id).clamp(0, a.target);
    final ratio = (current / a.target).clamp(0.0, 1.0);

    return WoodPanel(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: unlocked
                  ? const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFFFFD54F)])
                  : null,
              color: unlocked ? null : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(unlocked ? a.icon : Icons.lock_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: AppTheme.body(17, color: AppTheme.ink)),
                Text(a.desc,
                    style: AppTheme.body(12,
                        color: AppTheme.brown, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: Colors.black12,
                    color: unlocked ? AppTheme.green : AppTheme.sky,
                  ),
                ),
                const SizedBox(height: 3),
                Text('$current / ${a.target}',
                    style: AppTheme.body(11, color: AppTheme.brown)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _reward(a, unlocked, claimed),
        ],
      ),
    );
  }

  Widget _reward(AchievementDef a, bool unlocked, bool claimed) {
    if (claimed) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 28),
          Text('Claimed', style: TextStyle(fontSize: 10, color: AppTheme.brown)),
        ],
      );
    }
    final canClaim = unlocked;
    return GestureDetector(
      onTap: canClaim
          ? () {
              store.claimAchievement(a.id, a.reward);
              Audio.instance.reward();
              setState(() {});
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: canClaim ? AppTheme.primary : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on_rounded,
                color: Color(0xFFFFF3C4), size: 18),
            Text('+${a.reward}', style: AppTheme.body(13)),
          ],
        ),
      ),
    );
  }
}

/// Circular badge showing overall completion.
class _TrophyRing extends StatelessWidget {
  final double progress;
  const _TrophyRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: Colors.black12,
              color: AppTheme.primary,
            ),
          ),
          const Icon(Icons.emoji_events_rounded,
              color: AppTheme.primaryDark, size: 30),
        ],
      ),
    );
  }
}
