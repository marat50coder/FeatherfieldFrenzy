import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/gate_models.dart';

/// Persistent storage for gate state. Key prefix is unique to
/// Fietherfield Frenzy — never share a prefix with sibling apps
/// (`gray_part_mixing_review` §1: SharedPrefs/SecureStorage keys are a
/// grep-able cluster signal).
class FrenzySafe {
  FrenzySafe({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  // Namespaces are grouped under `fzy.aviary` so a strings dump on the
  // release binary doesn't line up 1:1 with the `ced.roost.*` /
  // `era.hatch.*` prefixes used by sibling apps.
  static const String _ns = 'fzy.aviary';
  static const String _routeKey = '$_ns.route';
  static const String _expiryKey = '$_ns.portal.expiresAt';
  static const String _inviteAfterKey = '$_ns.push.inviteAfter';
  static const String _pushAllowedKey = '$_ns.push.allowed';
  static const String _pushOsDeniedKey = '$_ns.push.osDenied';
  static const String _savedUrlKey = '$_ns.portal.address';
  static const String _pendingUrlKey = '$_ns.portal.pending';

  final FlutterSecureStorage _secure;
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  GateRoute get route => GateRoute.parse(_preferences.getString(_routeKey));

  Future<void> saveRoute(GateRoute route) =>
      _preferences.setString(_routeKey, route.storageValue);

  Future<String?> savedUrl() => _safeRead(_savedUrlKey);

  Future<void> cacheUrl(String url, int? expiresAt) async {
    await _safeWrite(_savedUrlKey, url);
    if (expiresAt != null) {
      await _preferences.setInt(_expiryKey, expiresAt);
    }
  }

  bool get cachedUrlExpired {
    final expiry = _preferences.getInt(_expiryKey);
    if (expiry == null) return true;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds >= expiry;
  }

  Future<void> stashPushUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    await _safeWrite(_pendingUrlKey, trimmed);
  }

  Future<String?> consumePushUrl() async {
    final value = await _safeRead(_pendingUrlKey);
    if (value != null) {
      // Fire-and-forget; a failed delete is not worse than a duplicate
      // consume (the gate is idempotent on the URL string).
      try {
        await _secure.delete(key: _pendingUrlKey);
      } catch (_) {}
    }
    return value;
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
    if (after == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= after;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_inviteAfterKey, epochSeconds);

  Future<String?> _safeRead(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } catch (_) {}
  }
}
