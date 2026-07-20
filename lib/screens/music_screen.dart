import 'package:flutter/material.dart';

import '../services/audio.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Dedicated screen for controlling background music: on/off and volume.
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  final store = GameStorage.instance;
  late double _volume = store.musicVolume;

  @override
  Widget build(BuildContext context) {
    final musicOn = store.soundOn;
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ScreenHeader(
                  title: 'Music & Sound',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      WoodPanel(
                        child: Column(
                          children: [
                            _bigIcon(musicOn),
                            const SizedBox(height: 6),
                            Text(
                              musicOn ? 'Music is on' : 'Music is off',
                              style: AppTheme.title(20, color: AppTheme.ink),
                            ),
                            const SizedBox(height: 16),
                            _musicToggle(musicOn),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      WoodPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.volume_up_rounded,
                                    color: AppTheme.brown),
                                const SizedBox(width: 12),
                                Text('Volume',
                                    style:
                                        AppTheme.body(18, color: AppTheme.ink)),
                                const Spacer(),
                                Text('${(_volume * 100).round()}%',
                                    style: AppTheme.title(16,
                                        color: AppTheme.brown)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.volume_mute_rounded,
                                    color: AppTheme.brown, size: 20),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppTheme.green,
                                      thumbColor: AppTheme.green,
                                      overlayColor:
                                          AppTheme.green.withValues(alpha: 0.2),
                                    ),
                                    child: Slider(
                                      value: _volume,
                                      min: 0,
                                      max: 1,
                                      onChanged: musicOn
                                          ? (v) {
                                              setState(() => _volume = v);
                                              Audio.instance.setMusicVolume(v);
                                            }
                                          : null,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.volume_up_rounded,
                                    color: AppTheme.brown, size: 20),
                              ],
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

  Widget _bigIcon(bool on) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (on ? AppTheme.green : AppTheme.brown).withValues(alpha: 0.15),
        border: Border.all(
            color: on ? AppTheme.green : AppTheme.brown, width: 3),
      ),
      child: Icon(
        on ? Icons.music_note_rounded : Icons.music_off_rounded,
        size: 44,
        color: on ? AppTheme.green : AppTheme.brown,
      ),
    );
  }

  Widget _musicToggle(bool on) {
    return Row(
      children: [
        Icon(Icons.music_note_rounded, color: AppTheme.brown),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Play music', style: AppTheme.body(18, color: AppTheme.ink)),
        ),
        Switch(
          value: on,
          activeThumbColor: AppTheme.green,
          onChanged: (v) {
            Audio.instance.setMusicEnabled(v);
            setState(() {});
          },
        ),
      ],
    );
  }
}
