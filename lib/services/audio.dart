import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'storage.dart';

/// Handles background music (via audioplayers) and haptic feedback. The
/// "Music" setting maps to [GameStorage.soundOn]; "Vibration" maps to
/// [GameStorage.hapticsOn].
class Audio {
  Audio._();
  static final Audio instance = Audio._();

  AudioPlayer? _music;
  bool _musicStarted = false;

  Future<void> init() async {
    try {
      _music = AudioPlayer();
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(GameStorage.instance.musicVolume);
    } catch (_) {
      _music = null;
    }
  }

  double get musicVolume => GameStorage.instance.musicVolume;

  /// Applies (and persists) music volume live while playing.
  Future<void> setMusicVolume(double v) async {
    final vol = v.clamp(0.0, 1.0);
    GameStorage.instance.musicVolume = vol;
    try {
      await _music?.setVolume(vol);
    } catch (_) {}
  }

  bool get _hapticsEnabled => GameStorage.instance.hapticsOn;
  bool get musicEnabled => GameStorage.instance.soundOn;

  Future<void> startMusic() async {
    if (!musicEnabled || _music == null) return;
    try {
      if (_musicStarted) {
        await _music!.resume();
      } else {
        await _music!.play(AssetSource('music.wav'));
        _musicStarted = true;
      }
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _music?.pause();
    } catch (_) {}
  }

  Future<void> setMusicEnabled(bool enabled) async {
    GameStorage.instance.soundOn = enabled;
    if (enabled) {
      await startMusic();
    } else {
      await stopMusic();
    }
  }

  // ---- Haptics ----
  void tap() {
    if (_hapticsEnabled) HapticFeedback.selectionClick();
  }

  void bounce() {
    if (_hapticsEnabled) HapticFeedback.lightImpact();
  }

  void spring() {
    if (_hapticsEnabled) HapticFeedback.mediumImpact();
  }

  void rocket() {
    if (_hapticsEnabled) HapticFeedback.heavyImpact();
  }

  void death() {
    if (_hapticsEnabled) HapticFeedback.heavyImpact();
  }

  void reward() {
    if (_hapticsEnabled) HapticFeedback.mediumImpact();
  }
}
