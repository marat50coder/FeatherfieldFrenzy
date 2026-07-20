import 'package:flutter/material.dart';

import '../services/audio.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'music_screen.dart';
import 'webview_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final store = GameStorage.instance;

  static const String privacyUrl =
      'https://featherfieldfrenzy.com/privacy-policy.html';
  static const String supportUrl =
      'https://featherfieldfrenzy.com/support.html';
  static const String appId = '6792504341';

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
                  title: 'Settings',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      WoodPanel(
                        child: Column(
                          children: [
                            _toggle(
                              'Vibration',
                              Icons.vibration_rounded,
                              store.hapticsOn,
                              (v) {
                                setState(() => store.hapticsOn = v);
                                Audio.instance.tap();
                              },
                            ),
                            const Divider(),
                            _linkRow('Music & Sound', Icons.music_note_rounded,
                                () async {
                              await Navigator.of(context)
                                  .push(appRoute(const MusicScreen()));
                              if (mounted) setState(() {});
                            }),
                            const Divider(),
                            _controlSelector(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      WoodPanel(
                        child: Column(
                          children: [
                            _linkRow('Privacy Policy', Icons.privacy_tip_rounded,
                                () => _openWeb('Privacy Policy', privacyUrl)),
                            const Divider(),
                            _linkRow('Support', Icons.support_agent_rounded,
                                () => _openWeb('Support', supportUrl)),
                            const Divider(),
                            _linkRow(
                                'Rate on App Store', Icons.star_rounded,
                                () => _openWeb('App Store',
                                    'https://apps.apple.com/app/id$appId')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      WoodPanel(
                        child: Column(
                          children: [
                            _linkRow('Reset Progress', Icons.delete_forever_rounded,
                                _confirmReset,
                                color: AppTheme.danger),
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                'Feather Field Frenzy\nVersion 1.0.0  •  App ID $appId',
                                textAlign: TextAlign.center,
                                style: AppTheme.body(13, color: AppTheme.brown),
                              ),
                            ),
                          ],
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

  void _openWeb(String title, String url) {
    Navigator.of(context)
        .push(appRoute(WebViewScreen(title: title, url: url)));
  }

  Widget _toggle(
      String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.brown),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AppTheme.body(18, color: AppTheme.ink)),
        ),
        Switch(
          value: value,
          activeThumbColor: AppTheme.green,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _controlSelector() {
    final mode = store.controlMode;
    return Row(
      children: [
        const Icon(Icons.gamepad_rounded, color: AppTheme.brown),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Controls', style: AppTheme.body(18, color: AppTheme.ink)),
        ),
        ToggleButtons(
          isSelected: [mode == 'tilt', mode == 'touch'],
          borderRadius: BorderRadius.circular(12),
          selectedColor: Colors.white,
          fillColor: AppTheme.green,
          color: AppTheme.ink,
          constraints: const BoxConstraints(minHeight: 38, minWidth: 66),
          onPressed: (i) {
            setState(() => store.controlMode = i == 0 ? 'tilt' : 'touch');
            Audio.instance.tap();
          },
          children: const [Text('Tilt'), Text('Touch')],
        ),
      ],
    );
  }

  Widget _linkRow(String label, IconData icon, VoidCallback onTap,
      {Color color = AppTheme.ink}) {
    return InkWell(
      onTap: () {
        Audio.instance.tap();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color == AppTheme.ink ? AppTheme.brown : color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppTheme.body(18, color: color)),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.brown),
          ],
        ),
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset all progress?',
            style: AppTheme.title(20, color: AppTheme.ink)),
        content: Text(
          'This clears coins, scores, skins and achievements. This cannot be undone.',
          style: AppTheme.body(16, color: AppTheme.ink),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await store.resetAll();
              nav.pop();
              if (mounted) setState(() {});
            },
            child: const Text('Reset',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}
