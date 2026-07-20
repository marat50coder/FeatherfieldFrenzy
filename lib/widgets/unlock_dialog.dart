import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../services/audio.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// Shows a styled confirmation dialog to unlock a world/skin.
/// Returns `true` if the purchase was completed.
Future<bool> showUnlockDialog(BuildContext context, LevelTheme theme) async {
  final store = GameStorage.instance;
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'unlock',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final curved = Curves.easeOutBack.transform(anim.value.clamp(0.0, 1.0));
      return Transform.scale(
        scale: 0.85 + 0.15 * curved,
        child: Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: _UnlockContent(theme: theme, store: store),
        ),
      );
    },
  );
  return result ?? false;
}

class _UnlockContent extends StatelessWidget {
  final LevelTheme theme;
  final GameStorage store;
  const _UnlockContent({required this.theme, required this.store});

  @override
  Widget build(BuildContext context) {
    final canAfford = store.coins >= theme.unlockCost;
    return Material(
      type: MaterialType.transparency,
      child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: WoodPanel(
          width: 320,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bird preview in a themed circular badge.
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [theme.accent, theme.accentDark],
                  ),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x33000000),
                        offset: Offset(0, 4),
                        blurRadius: 10),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Image.asset(theme.bird, fit: BoxFit.contain),
              ),
              const SizedBox(height: 14),
              Text(theme.name,
                  style: AppTheme.title(24, color: AppTheme.ink)),
              const SizedBox(height: 4),
              Text('New world & chicken skin',
                  style: AppTheme.body(14, color: AppTheme.brown)),
              const SizedBox(height: 16),

              // Price tag.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: canAfford
                      ? AppTheme.primary.withValues(alpha: 0.16)
                      : AppTheme.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: canAfford ? AppTheme.primary : AppTheme.danger,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        color: Color(0xFFE0A200), size: 26),
                    const SizedBox(width: 8),
                    Text('${theme.unlockCost}',
                        style: AppTheme.title(24, color: AppTheme.ink)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    canAfford
                        ? Icons.account_balance_wallet_rounded
                        : Icons.error_outline_rounded,
                    size: 16,
                    color: canAfford ? AppTheme.brown : AppTheme.danger,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    canAfford
                        ? 'Balance: ${store.coins}'
                        : 'Not enough coins (${store.coins})',
                    style: AppTheme.body(14,
                        color: canAfford ? AppTheme.brown : AppTheme.danger),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (canAfford)
                Row(
                  children: [
                    Expanded(
                      child: CandyButton(
                        label: 'CANCEL',
                        width: double.infinity,
                        height: 54,
                        fontSize: 18,
                        color: Colors.grey.shade500,
                        shadowColor: Colors.grey.shade700,
                        onTap: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CandyButton(
                        label: 'UNLOCK',
                        icon: Icons.lock_open_rounded,
                        width: double.infinity,
                        height: 54,
                        fontSize: 18,
                        color: AppTheme.green,
                        shadowColor: AppTheme.greenDark,
                        onTap: () {
                          store.coins = store.coins - theme.unlockCost;
                          store.unlockTheme(theme.index);
                          store.selectedTheme = theme.index;
                          Audio.instance.reward();
                          Navigator.pop(context, true);
                        },
                      ),
                    ),
                  ],
                )
              else
                CandyButton(
                  label: 'EARN MORE COINS',
                  width: double.infinity,
                  height: 54,
                  fontSize: 17,
                  onTap: () => Navigator.pop(context, false),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
