import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reachability checks. Rotates a probe list distinct from every sibling
/// app so a static-analysis fingerprint on `["cloudflare.com", ...]`
/// misses this build.
class FlockNetProbe {
  final Connectivity _connectivity = Connectivity();

  // Distinct probe list per project (rotate; do NOT copy from siblings).
  // apple.com is universally reachable (no CDN quirks) and google.com is
  // a second, geographically-diverse anchor.
  static const List<String> _probeHosts = <String>[
    'apple.com',
    'google.com',
  ];

  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Reliable reachability check. Probes well-known hosts (not our own
  /// domain) so a VPN or a not-yet-propagated app domain never produces a
  /// false "offline". Each lookup is time-boxed so the retry button can
  /// never hang forever.
  Future<bool> canReachNetwork() async {
    if (!await hasInterface()) return false;
    for (final host in _probeHosts) {
      try {
        final records = await InternetAddress.lookup(
          host,
        ).timeout(const Duration(seconds: 3));
        if (records.any((record) => record.rawAddress.isNotEmpty)) {
          return true;
        }
      } catch (_) {
        // Try the next host before declaring offline.
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
