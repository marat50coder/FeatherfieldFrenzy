import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../game/game_screen.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'level_select_screen.dart';
import 'skins_screen.dart';
import 'settings_screen.dart';
import 'quests_screen.dart';
import 'stats_screen.dart';
import 'achievements_screen.dart';
import 'leaderboard_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final store = GameStorage.instance;

  Future<void> _go(Widget screen) async {
    await Navigator.of(context).push(appRoute(screen));
    if (mounted) setState(() {});
  }

  void _play() {
    final theme = kThemes[store.selectedTheme.clamp(0, kThemes.length - 1)];
    _go(GameScreen(theme: theme));
  }

  @override
  Widget build(BuildContext context) {
    final selected = kThemes[store.selectedTheme.clamp(0, kThemes.length - 1)];
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(A.menuBg, fit: BoxFit.cover),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const CoinPill(),
                      const Spacer(),
                      RoundIconButton(
                        icon: Icons.settings_rounded,
                        onTap: () => _go(const SettingsScreen()),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Current world label.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('World: ${selected.name}',
                      style: AppTheme.body(16)),
                ),
                const SizedBox(height: 16),
                CandyButton(
                  label: 'PLAY',
                  icon: Icons.play_arrow_rounded,
                  width: 260,
                  height: 72,
                  fontSize: 28,
                  color: AppTheme.green,
                  shadowColor: AppTheme.greenDark,
                  onTap: _play,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CandyButton(
                      label: 'WORLDS',
                      icon: Icons.public_rounded,
                      width: 150,
                      height: 56,
                      fontSize: 18,
                      onTap: () => _go(const LevelSelectScreen()),
                    ),
                    const SizedBox(width: 12),
                    CandyButton(
                      label: 'SKINS',
                      icon: Icons.checkroom_rounded,
                      width: 150,
                      height: 56,
                      fontSize: 18,
                      color: AppTheme.sky,
                      shadowColor: const Color(0xFF2E86C1),
                      onTap: () => _go(const SkinsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MiniButton(
                      icon: Icons.assignment_turned_in_rounded,
                      label: 'Quests',
                      onTap: () => _go(const QuestsScreen()),
                    ),
                    _MiniButton(
                      icon: Icons.leaderboard_rounded,
                      label: 'Ranks',
                      onTap: () => _go(const LeaderboardScreen()),
                    ),
                    _MiniButton(
                      icon: Icons.emoji_events_rounded,
                      label: 'Awards',
                      onTap: () => _go(const AchievementsScreen()),
                    ),
                    _MiniButton(
                      icon: Icons.bar_chart_rounded,
                      label: 'Stats',
                      onTap: () => _go(const StatsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MiniButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          RoundIconButton(icon: icon, onTap: onTap, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.body(13)),
        ],
      ),
    );
  }
}

/// Reusable coin counter pill. Reacts to a global notifier so the balance is
/// always live wherever it is shown.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded,
              color: Color(0xFFFFD54F), size: 22),
          const SizedBox(width: 6),
          ValueListenableBuilder<int>(
            valueListenable: GameStorage.instance.coinsListenable,
            builder: (_, v, __) => Text('$v', style: AppTheme.title(18)),
          ),
        ],
      ),
    );
  }
}
