import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../services/audio.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../widgets/unlock_dialog.dart';
import 'menu_screen.dart';

class SkinsScreen extends StatefulWidget {
  const SkinsScreen({super.key});

  @override
  State<SkinsScreen> createState() => _SkinsScreenState();
}

class _SkinsScreenState extends State<SkinsScreen> {
  final store = GameStorage.instance;

  void _select(LevelTheme t) {
    Audio.instance.tap();
    if (store.isThemeUnlocked(t.index)) {
      store.selectedTheme = t.index;
      setState(() {});
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
              children: [
                ScreenHeader(
                  title: 'Skins',
                  onBack: () => Navigator.pop(context),
                  actions: const [CoinPill()],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.82,
                    children: kThemes.map(_card).toList(),
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
    return GestureDetector(
      onTap: () => _select(t),
      child: WoodPanel(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(t.bird, fit: BoxFit.contain),
                  if (!unlocked)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock_rounded,
                            color: Colors.white, size: 40),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(t.name,
                textAlign: TextAlign.center,
                style: AppTheme.body(14, color: AppTheme.ink)),
            const SizedBox(height: 6),
            if (!unlocked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      color: Color(0xFFE0A200), size: 18),
                  const SizedBox(width: 4),
                  Text('${t.unlockCost}',
                      style: AppTheme.title(16, color: AppTheme.ink)),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.green : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(selected ? 'SELECTED' : 'SELECT',
                    style: AppTheme.body(13)),
              ),
          ],
        ),
      ),
    );
  }
}
