import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/frenzy_gate_config.dart';

/// Mobile-Safari User-Agent HTTP client. The UA MUST match the WebView UA
/// (partner backends cross-check). See `.cursor/rules/gray_user_agent`
/// for the full contract.
///
// GAME THEME CATEGORY: crash (no appid/appname suffix).
// Fietherfield Frenzy is a Doodle-Jump-style casual arcade — neither a
// slot/reel/roulette game nor a rising-multiplier "crash" game. Per
// gray_user_agent.mdc §2, defaulting to the *no-suffix* variant is the
// safe choice for non-slot categories: a suffix on a wrong category
// corrupts the partner's tracking and flags the install. If the partner
// brief later confirms this must ship as slot, add the suffix here.
class PlumeAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _userAgent;

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _userAgent = _fallback();
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      final version = _normalizedIos(info.systemVersion);
      _userAgent = _mobileSafari(version);
    } catch (_) {
      _userAgent = _fallback();
    }
  }

  String get userAgent => _userAgent ?? _fallback();

  String _normalizedIos(String raw) {
    final parts = raw
        .split('.')
        .map((piece) => int.tryParse(piece))
        .whereType<int>()
        .take(3)
        .toList();
    if (parts.isEmpty || parts.first < 18) return '18.6';
    return parts.join('.');
  }

  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS $cpu like Mac OS X) '
        'AppleWebKit/${FrenzyGateConfig.webKitVersion} (KHTML, like Gecko) '
        'Version/${FrenzyGateConfig.safariVersion} Mobile/15E148 '
        'Safari/${FrenzyGateConfig.safariTail}';
  }

  String _fallback() => _mobileSafari('18.6');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
