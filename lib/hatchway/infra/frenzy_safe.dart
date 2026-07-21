import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/gate_models.dart';

/// Persistent storage for gate state. Key prefix `ffr.gate.*` is unique
/// to Fietherfield Frenzy — never share a prefix with sibling apps.
class FrenzySafe {
  static const String _routeKey = 'ffr.gate.route';
  static const String _expiryKey = 'ffr.gate.web.expiry';
  static const String _inviteAfterKey = 'ffr.gate.push.invite.after';
  static const String _pushAllowedKey = 'ffr.gate.push.allowed';
  static const String _pushOsDeniedKey = 'ffr.gate.push.os.denied';
  static const String _savedUrlKey = 'ffr.gate.secure.web';
  static const String _pendingUrlKey = 'ffr.gate.secure.pending';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  GateRoute get route => GateRoute.parse(_preferences.getString(_routeKey));

  Future<void> saveRoute(GateRoute route) =>
      _preferences.setString(_routeKey, route.storageValue);

  Future<String?> savedUrl() async {
    try {
      return await _secure.read(key: _savedUrlKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _secure.write(key: _savedUrlKey, value: url);
      if (expiresAt != null) {
        await _preferences.setInt(_expiryKey, expiresAt);
      }
    } catch (_) {}
  }

  bool get cachedUrlExpired {
    final expiry = _preferences.getInt(_expiryKey);
    return expiry == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiry;
  }

  Future<void> stashPushUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      await _secure.write(key: _pendingUrlKey, value: url.trim());
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _secure.read(key: _pendingUrlKey);
      if (value != null) await _secure.delete(key: _pendingUrlKey);
      return value;
    } catch (_) {
      return null;
    }
  }

  bool get pushAllowed => _preferences.getBool(_pushAllowedKey) ?? false;
  bool get pushDeniedByOs => _preferences.getBool(_pushOsDeniedKey) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _preferences.setBool(_pushAllowedKey, value);

  Future<void> markPushDeniedByOs() =>
      _preferences.setBool(_pushOsDeniedKey, true);

  bool get shouldShowPushInvite {
    if (pushAllowed || pushDeniedByOs) return false;
    final after = _preferences.getInt(_inviteAfterKey);
    return after == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= after;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_inviteAfterKey, epochSeconds);
}
