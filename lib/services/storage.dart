import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/game_data.dart';

/// Persistent game state backed by SharedPreferences.
class GameStorage {
  GameStorage._();
  static final GameStorage instance = GameStorage._();

  late SharedPreferences _prefs;

  /// Live coin balance so any [CoinPill] updates instantly everywhere.
  final ValueNotifier<int> coinsListenable = ValueNotifier<int>(0);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _ensureDailyReset();
    _ensureWeeklyReset();
    coinsListenable.value = coins;
  }

  // ---- Settings ----
  bool get soundOn => _prefs.getBool('soundOn') ?? true;
  set soundOn(bool v) => _prefs.setBool('soundOn', v);

  /// Music volume in range 0..1.
  double get musicVolume => _prefs.getDouble('musicVolume') ?? 0.05;
  set musicVolume(double v) =>
      _prefs.setDouble('musicVolume', v.clamp(0.0, 1.0));

  bool get hapticsOn => _prefs.getBool('hapticsOn') ?? true;
  set hapticsOn(bool v) => _prefs.setBool('hapticsOn', v);

  /// 'tilt' or 'touch'
  String get controlMode => _prefs.getString('controlMode') ?? 'tilt';
  set controlMode(String v) => _prefs.setString('controlMode', v);

  // ---- Economy / progression ----
  int get coins => _prefs.getInt('coins') ?? 0;
  set coins(int v) {
    final nv = v < 0 ? 0 : v;
    _prefs.setInt('coins', nv);
    coinsListenable.value = nv;
  }

  int get selectedTheme => _prefs.getInt('selectedTheme') ?? 0;
  set selectedTheme(int v) => _prefs.setInt('selectedTheme', v);

  List<int> get unlockedThemes {
    final raw = _prefs.getStringList('unlockedThemes');
    if (raw == null) return [0];
    final list = raw.map(int.parse).toList();
    if (!list.contains(0)) list.add(0);
    return list;
  }

  bool isThemeUnlocked(int i) => i == 0 || unlockedThemes.contains(i);

  void unlockTheme(int i) {
    final set = unlockedThemes.toSet()..add(i);
    _prefs.setStringList(
        'unlockedThemes', set.map((e) => e.toString()).toList());
  }

  // ---- Scores ----
  int bestScore(int theme) => _prefs.getInt('best_$theme') ?? 0;
  void setBestScore(int theme, int v) {
    if (v > bestScore(theme)) _prefs.setInt('best_$theme', v);
  }

  int get bestOverall {
    int best = 0;
    for (final t in kThemes) {
      final b = bestScore(t.index);
      if (b > best) best = b;
    }
    return best;
  }

  // ---- Lifetime statistics ----
  int get statGames => _prefs.getInt('stat_games') ?? 0;
  int get statJumps => _prefs.getInt('stat_jumps') ?? 0;
  int get statPlatforms => _prefs.getInt('stat_platforms') ?? 0;
  int get statRockets => _prefs.getInt('stat_rockets') ?? 0;
  int get statSprings => _prefs.getInt('stat_springs') ?? 0;
  int get statCoinsEarned => _prefs.getInt('stat_coins_earned') ?? 0;
  int get statBestHeight => _prefs.getInt('stat_best_height') ?? 0;

  // ---- Daily quests ----
  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  void _ensureDailyReset() {
    final last = _prefs.getString('quest_day');
    if (last != _today) {
      _prefs.setString('quest_day', _today);
      _prefs.setString('quest_progress', jsonEncode({}));
      _prefs.setStringList('quest_claimed', []);
    }
  }

  Map<String, int> get questProgress {
    final raw = _prefs.getString('quest_progress');
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  void _setQuestProgress(Map<String, int> m) {
    _prefs.setString('quest_progress', jsonEncode(m));
  }

  List<String> get questClaimed => _prefs.getStringList('quest_claimed') ?? [];

  bool isQuestClaimed(String id) => questClaimed.contains(id);

  void claimQuest(String id, int reward) {
    if (isQuestClaimed(id)) return;
    final list = questClaimed..add(id);
    _prefs.setStringList('quest_claimed', list);
    coins = coins + reward;
  }

  // ---- Weekly quests ----
  String get _weekKey {
    final n = DateTime.now();
    final firstDay = DateTime(n.year, 1, 1);
    final week = ((n.difference(firstDay).inDays + firstDay.weekday - 1) / 7)
        .floor();
    return '${n.year}-W$week';
  }

  void _ensureWeeklyReset() {
    final last = _prefs.getString('quest_week');
    if (last != _weekKey) {
      _prefs.setString('quest_week', _weekKey);
      _prefs.setString('weekly_progress', jsonEncode({}));
      _prefs.setStringList('weekly_claimed', []);
    }
  }

  Map<String, int> get weeklyProgress {
    final raw = _prefs.getString('weekly_progress');
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  void _setWeeklyProgress(Map<String, int> m) {
    _prefs.setString('weekly_progress', jsonEncode(m));
  }

  List<String> get weeklyClaimed => _prefs.getStringList('weekly_claimed') ?? [];

  bool isWeeklyClaimed(String id) => weeklyClaimed.contains(id);

  void claimWeekly(String id, int reward) {
    if (isWeeklyClaimed(id)) return;
    final list = weeklyClaimed..add(id);
    _prefs.setStringList('weekly_claimed', list);
    coins = coins + reward;
  }

  // ---- Achievements ----
  List<String> get achievementsUnlocked =>
      _prefs.getStringList('achievements') ?? [];

  bool isAchievementUnlocked(String id) => achievementsUnlocked.contains(id);

  bool unlockAchievement(String id) {
    if (isAchievementUnlocked(id)) return false;
    final list = achievementsUnlocked..add(id);
    _prefs.setStringList('achievements', list);
    return true;
  }

  /// Applies the outcome of a finished run. Returns the list of newly
  /// unlocked achievement ids so the UI can celebrate them.
  List<String> recordRun({
    required int theme,
    required int score,
    required int jumps,
    required int platforms,
    required int rockets,
    required int springs,
  }) {
    setBestScore(theme, score);
    _prefs.setInt('stat_games', statGames + 1);
    _prefs.setInt('stat_jumps', statJumps + jumps);
    _prefs.setInt('stat_platforms', statPlatforms + platforms);
    _prefs.setInt('stat_rockets', statRockets + rockets);
    _prefs.setInt('stat_springs', statSprings + springs);
    if (score > statBestHeight) _prefs.setInt('stat_best_height', score);

    final earned = (score / 8).floor();
    coins = coins + earned;
    _prefs.setInt('stat_coins_earned', statCoinsEarned + earned);

    _advanceQuests(
      games: 1,
      platforms: platforms,
      rockets: rockets,
      springs: springs,
      runScore: score,
    );

    return _checkAchievements();
  }

  int lastRunCoins(int score) => (score / 8).floor();

  void _advanceQuests({
    required int games,
    required int platforms,
    required int rockets,
    required int springs,
    required int runScore,
  }) {
    _ensureDailyReset();
    _ensureWeeklyReset();

    Map<String, int> bump(Map<String, int> p) {
      p['q_games'] = (p['q_games'] ?? 0) + games;
      p['q_platforms'] = (p['q_platforms'] ?? 0) + platforms;
      p['q_rocket'] = (p['q_rocket'] ?? 0) + rockets;
      p['q_spring'] = (p['q_spring'] ?? 0) + springs;
      // score quest tracks the best single-run score of the period.
      if (runScore > (p['q_score'] ?? 0)) p['q_score'] = runScore;
      return p;
    }

    _setQuestProgress(bump(questProgress));
    _setWeeklyProgress(bump(weeklyProgress));
  }

  /// Current progress value toward an achievement, for display.
  int achievementProgress(String id) {
    switch (id) {
      case 'a_score500':
      case 'a_score2000':
      case 'a_score5000':
        return bestOverall;
      case 'a_coins500':
        return statCoinsEarned;
      case 'a_games25':
        return statGames;
      case 'a_rockets20':
        return statRockets;
      case 'a_platforms1000':
        return statPlatforms;
      case 'a_allthemes':
        return unlockedThemes.toSet().length;
      default:
        return 0;
    }
  }

  List<String> get achievementsClaimed =>
      _prefs.getStringList('ach_claimed') ?? [];

  bool isAchievementClaimed(String id) => achievementsClaimed.contains(id);

  void claimAchievement(String id, int reward) {
    if (isAchievementClaimed(id) || !isAchievementUnlocked(id)) return;
    final list = achievementsClaimed..add(id);
    _prefs.setStringList('ach_claimed', list);
    coins = coins + reward;
  }

  List<String> _checkAchievements() {
    final newly = <String>[];
    void tryUnlock(String id, bool cond) {
      if (cond && unlockAchievement(id)) newly.add(id);
    }

    tryUnlock('a_score500', bestOverall >= 500);
    tryUnlock('a_score2000', bestOverall >= 2000);
    tryUnlock('a_score5000', bestOverall >= 5000);
    tryUnlock('a_coins500', statCoinsEarned >= 500);
    tryUnlock('a_games25', statGames >= 25);
    tryUnlock('a_rockets20', statRockets >= 20);
    tryUnlock('a_platforms1000', statPlatforms >= 1000);
    tryUnlock('a_allthemes', unlockedThemes.toSet().length >= kThemes.length);
    return newly;
  }

  Future<void> resetAll() async {
    await _prefs.clear();
    _ensureDailyReset();
    _ensureWeeklyReset();
    coinsListenable.value = coins;
  }
}
