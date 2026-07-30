import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/frenzy_gate_config.dart';

/// Mobile-Safari User-Agent HTTP client. The UA MUST match the WebView
/// UA (partner backends cross-check). See `.cursor/rules/gray_user_agent`
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
  PlumeAgent({http.Client? transport}) : _transport = transport ?? http.Client();

  final http.Client _transport;

  // Cached User-Agent — built once in `prepare()` off the real device
  // info, then reused for every HTTP request AND the WebView setUserAgent
  // call (partner backends cross-check the two).
  String? _cached;

  // Minimum iOS major we're willing to advertise. Anything below this
  // (real device or a stub value from a simulator plist) falls through
  // to the current fallback below, so we never ship a UA claiming iOS 15
  // in 2026.
  static const int _minAdvertisedMajor = 18;
  static const String _fallbackVersion = '18.7.1';

  Future<void> prepare() async {
    _cached = await _buildUserAgent();
  }

  Future<String> _buildUserAgent() async {
    if (!Platform.isIOS) return _fromVersion(_fallbackVersion);
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      return _fromVersion(_normalizeIos(info.systemVersion));
    } catch (_) {
      return _fromVersion(_fallbackVersion);
    }
  }

  String get userAgent => _cached ??= _fromVersion(_fallbackVersion);

  String _normalizeIos(String raw) {
    final numeric = raw
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .toList(growable: false);
    if (numeric.isEmpty || numeric.first < _minAdvertisedMajor) {
      return _fallbackVersion;
    }
    return numeric.take(3).join('.');
  }

  String _fromVersion(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    final buffer = StringBuffer('Mozilla/5.0 (iPhone; CPU iPhone OS ')
      ..write(cpu)
      ..write(' like Mac OS X) AppleWebKit/')
      ..write(FrenzyGateConfig.webKitVersion)
      ..write(' (KHTML, like Gecko) Version/')
      ..write(FrenzyGateConfig.safariVersion)
      ..write(' Mobile/15E148 Safari/')
      ..write(FrenzyGateConfig.safariTail);
    return buffer.toString();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
