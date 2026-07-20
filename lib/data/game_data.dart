import 'package:flutter/material.dart';

/// All asset paths in one place. The trailing folder is `assets/`.
class A {
  static const String logo = 'assets/logo.webp';
  static const String menuBg = 'assets/menubg.jpg';
  static const String loadingVert = 'assets/loading_vert.webp';
  static const String loadingHor = 'assets/loading_hor.webp';

  // Shared items (used on every level).
  static const String rocket = 'assets/rocket.webp';
  static const String spring = 'assets/spring.webp';
  static const String cracksBlock = 'assets/cracksblock.webp';
  static const String movesBlock = 'assets/movesblock.webp';

  // Hazards shared across every level.
  static const String monster1 = 'assets/monster1.png'; // grumpy crow
  static const String monster2 = 'assets/monster2.png'; // spiky boar
  static const String blackHole = 'assets/blackhole.png';
}

/// A level / skin theme. Each level uses identical mechanics but different art.
class LevelTheme {
  final int index;
  final String name;
  final String background;
  final String platform;
  final String spikes;
  final String bird;
  final String birdRocket;
  final Color accent;
  final Color accentDark;
  final int unlockCost; // coins needed to unlock (0 => free)

  const LevelTheme({
    required this.index,
    required this.name,
    required this.background,
    required this.platform,
    required this.spikes,
    required this.bird,
    required this.birdRocket,
    required this.accent,
    required this.accentDark,
    required this.unlockCost,
  });
}

const List<LevelTheme> kThemes = [
  LevelTheme(
    index: 0,
    name: 'Sunny Meadow',
    background: 'assets/level1.webp',
    platform: 'assets/blocklawn.webp',
    spikes: 'assets/grassspikes.webp',
    bird: 'assets/bird.webp',
    birdRocket: 'assets/birdrocket.webp',
    accent: Color(0xFF7CB342),
    accentDark: Color(0xFF558B2F),
    unlockCost: 0,
  ),
  LevelTheme(
    index: 1,
    name: 'Starry Night',
    background: 'assets/levelnight.webp',
    platform: 'assets/nightlawn.webp',
    spikes: 'assets/nightspikes.webp',
    bird: 'assets/nightbird.webp',
    birdRocket: 'assets/nightrocket.webp',
    accent: Color(0xFF5C6BC0),
    accentDark: Color(0xFF3949AB),
    unlockCost: 300,
  ),
  LevelTheme(
    index: 2,
    name: 'Golden Sunset',
    background: 'assets/level3.webp',
    platform: 'assets/orangelawn.webp',
    spikes: 'assets/orangespikes.webp',
    bird: 'assets/orangebird.webp',
    birdRocket: 'assets/orangerocket.webp',
    accent: Color(0xFFF57C00),
    accentDark: Color(0xFFE65100),
    unlockCost: 700,
  ),
  LevelTheme(
    index: 3,
    name: 'Frosty Winter',
    background: 'assets/levelwinter.webp',
    platform: 'assets/winterlawn.webp',
    spikes: 'assets/spikeswinter.webp',
    bird: 'assets/coldbird.webp',
    birdRocket: 'assets/coldrocket.webp',
    accent: Color(0xFF4FC3F7),
    accentDark: Color(0xFF0288D1),
    unlockCost: 1200,
  ),
];

/// Definition of a daily quest.
class QuestDef {
  final String id;
  final String title;
  final IconData icon;
  final int target;
  final int reward;
  const QuestDef(this.id, this.title, this.icon, this.target, this.reward);
}

const List<QuestDef> kDailyQuests = [
  QuestDef('q_games', 'Play 4 games', Icons.sports_esports_rounded, 4, 40),
  QuestDef('q_platforms', 'Bounce on 120 platforms', Icons.grid_view_rounded, 120, 50),
  QuestDef('q_rocket', 'Use the rocket 3 times', Icons.rocket_launch_rounded, 3, 45),
  QuestDef('q_spring', 'Hit 8 springs', Icons.vertical_align_top_rounded, 8, 35),
  QuestDef('q_score', 'Score 1500 in one run', Icons.emoji_events_rounded, 1500, 60),
];

/// Weekly quests share the same metric ids as the daily ones but have larger
/// targets and rewards, and reset once per week.
const List<QuestDef> kWeeklyQuests = [
  QuestDef('q_games', 'Play 25 games', Icons.sports_esports_rounded, 25, 200),
  QuestDef('q_platforms', 'Bounce on 800 platforms', Icons.grid_view_rounded, 800, 240),
  QuestDef('q_rocket', 'Use the rocket 15 times', Icons.rocket_launch_rounded, 15, 220),
  QuestDef('q_spring', 'Hit 50 springs', Icons.vertical_align_top_rounded, 50, 180),
  QuestDef('q_score', 'Score 4000 in one run', Icons.emoji_events_rounded, 4000, 320),
];

/// Definition of a permanent achievement. [target] is used to show progress
/// and [reward] is granted (once) when the player claims it.
class AchievementDef {
  final String id;
  final String title;
  final String desc;
  final IconData icon;
  final int target;
  final int reward;
  const AchievementDef(
      this.id, this.title, this.desc, this.icon, this.target, this.reward);
}

const List<AchievementDef> kAchievements = [
  AchievementDef('a_score500', 'First Flight', 'Score 500 in a run', Icons.flight_takeoff_rounded, 500, 50),
  AchievementDef('a_score2000', 'Sky Climber', 'Score 2000 in a run', Icons.terrain_rounded, 2000, 100),
  AchievementDef('a_score5000', 'Stratosphere', 'Score 5000 in a run', Icons.rocket_rounded, 5000, 200),
  AchievementDef('a_coins500', 'Coin Collector', 'Earn 500 coins total', Icons.savings_rounded, 500, 80),
  AchievementDef('a_games25', 'Dedicated', 'Play 25 games', Icons.calendar_month_rounded, 25, 100),
  AchievementDef('a_rockets20', 'Rocketeer', 'Use the rocket 20 times', Icons.local_fire_department_rounded, 20, 120),
  AchievementDef('a_platforms1000', 'Bounce Master', 'Bounce on 1000 platforms', Icons.stacked_bar_chart_rounded, 1000, 150),
  AchievementDef('a_allthemes', 'Globetrotter', 'Unlock every world', Icons.public_rounded, 4, 250),
];
