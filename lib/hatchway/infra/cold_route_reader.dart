import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads a URL stashed by the iOS SceneDelegate when the app was cold-
/// launched via a push. The native side (see `SceneDelegate.swift`) MUST
/// write it under the same UserDefaults key or the deep link is lost —
/// keep [_dartKey] and `SceneDelegate.coldRouteKey` in lock-step.
class ColdRouteReader {
  // The `flutter.` prefix is how the shared_preferences plugin
  // namespaces its entries on iOS; the suffix is app-specific to keep
  // this UserDefaults entry from clustering with sibling apps.
  static const String _dartKey = 'fzy_cold_launch_target';

  const ColdRouteReader._();

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    late final SharedPreferences preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
    final raw = preferences.getString(_dartKey)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    // Remove so a repeat cold-start (without a fresh push) can't replay
    // the stashed URL forever.
    try {
      await preferences.remove(_dartKey);
    } catch (_) {}
    return raw;
  }
}
