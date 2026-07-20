import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../game/game_screen.dart';
import '../services/audio.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../widgets/unlock_dialog.dart';
import 'menu_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final store = GameStorage.instance;

  void _tap(LevelTheme t) {
    if (store.isThemeUnlocked(t.index)) {
      store.selectedTheme = t.index;
      setState(() {});
      Navigator.of(context)
          .push(appRoute(GameScreen(theme: t)))
          .then((_) => mounted ? setState(() {}) : null);
    } else {
      _confirmUnlock(t);
    }
  }

  Future<void> _confirmUnlock(LevelTheme t) async {
    final unlocked = await showUnlockDialog(context, t);
    if (unlocked && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  title: 'Worlds',
                  onBack: () => Navigator.pop(context),
                  actions: const [CoinPill()],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: kThemes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _card(kThemes[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(LevelTheme t) {
    final unlocked = store.isThemeUnlocked(t.index);
    final selected = store.selectedTheme == t.index;
    final best = store.bestScore(t.index);
    return GestureDetector(
      onTap: () {
        Audio.instance.tap();
        _tap(t);
      },
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.white.withValues(alpha: 0.8),
            width: selected ? 5 : 3,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), offset: Offset(0, 4), blurRadius: 8),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(t.background, fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.22)),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Image.asset(t.bird, width: 74, height: 74),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: AppTheme.title(20)),
                          const SizedBox(height: 4),
                          Text('Best: $best', style: AppTheme.body(14)),
                        ],
                      ),
                    ),
                    if (!unlocked)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded,
                              color: Colors.white, size: 26),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.monetization_on_rounded,
                                  color: Color(0xFFFFD54F), size: 16),
                              const SizedBox(width: 3),
                              Text('${t.unlockCost}',
                                  style: AppTheme.body(14)),
                            ],
                          ),
                        ],
                      )
                    else if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.primary, size: 30)
                    else
                      const Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
