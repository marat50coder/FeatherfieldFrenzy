import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reachability checks. The probe list is app-specific — every sibling
/// build rotates a different set so a static-analysis fingerprint on
/// `["cloudflare.com", ...]` misses this binary, and the loop is
/// biased toward the primary anchor rather than iterating equally.
class FlockNetProbe {
  FlockNetProbe({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  // Primary anchor is the Apple CDN — always resolvable behind Apple's
  // infrastructure and never blackholed by consumer DNS filters.
  // Secondary is the Microsoft NCSI host so we don't share the same
  // fallback (`google.com`) as most sibling apps.
  static const String _primary = 'www.apple.com';
  static const List<String> _secondaries = <String>[
    'www.msftconnecttest.com',
    'gstatic.com',
  ];

  static const Duration _lookupBudget = Duration(seconds: 3);

  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Reliable reachability check. Probes well-known hosts (not our own
  /// domain) so a VPN or a not-yet-propagated app domain never produces
  /// a false "offline". The primary anchor is retried twice before we
  /// fan out to the secondaries — a single transient DNS hiccup on the
  /// primary should not immediately promote a secondary host to the
  /// grep-able "first successful lookup".
  Future<bool> canReachNetwork() async {
    if (!await hasInterface()) return false;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (await _resolve(_primary)) return true;
    }
    for (final host in _secondaries) {
      if (await _resolve(host)) return true;
    }
    return false;
  }

  Future<bool> _resolve(String host) async {
    try {
      final records = await InternetAddress.lookup(host).timeout(_lookupBudget);
      return records.any((record) => record.rawAddress.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
