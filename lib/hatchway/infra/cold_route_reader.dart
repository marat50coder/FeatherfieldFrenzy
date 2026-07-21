import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads a URL stashed by the iOS SceneDelegate when the app was cold-
/// launched via a push. The native side must write it under this exact
/// key or the deep link is lost.
class ColdRouteReader {
  static const String _dartKey = 'ffr_launch_route';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(_dartKey);
      return value;
    } catch (_) {
      return null;
    }
  }
}
