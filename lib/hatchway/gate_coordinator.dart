import 'dart:async';
import 'dart:io';

import 'config/frenzy_gate_config.dart';
import 'core/gate_models.dart';
import 'infra/cold_route_reader.dart';
import 'infra/flock_probe.dart';
import 'infra/frenzy_safe.dart';
import 'infra/gate_exchange.dart';
import 'infra/perch_signals.dart';
import 'infra/plume_agent.dart';
import 'infra/wing_attribution.dart';

/// Central routing brain. Given the persisted route + a fresh
/// reachability probe + attribution signals, decides which surface the
/// user sees.
class FrenzyGateCoordinator {
  FrenzyGateCoordinator({
    required this.safe,
    required this.probe,
    required this.attribution,
    required this.exchange,
    required this.signals,
    required this.agent,
    required this.runtimeEnabled,
  });

  final FrenzySafe safe;
  final FlockNetProbe probe;
  final WingAttribution attribution;
  final GateExchange exchange;
  final PerchSignalHub signals;
  final PlumeAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && FrenzyGateConfig.grayCredentialsReady;

  Future<GateDestination>? _decideFuture;

  /// De-duplicates only *concurrent* calls (splash may build twice at
  /// startup → avoids double attribution / config POST). The cache is
  /// cleared once the pipeline finishes so a later call — e.g. Retry
  /// from the offline screen after Wi-Fi returns — runs the full
  /// pipeline again instead of replaying the cached OfflineSurface
  /// forever.
  Future<GateDestination> decide({
    required void Function(double value) onProgress,
  }) {
    return _decideFuture ??=
        _drive(onProgress).whenComplete(() => _decideFuture = null);
  }

  Future<GateDestination> _drive(void Function(double) progress) async {
    if (!enabled) {
      ffrTrace(
        () => '[FFR.GATE] disabled '
            'runtime=$runtimeEnabled '
            'creds=${FrenzyGateConfig.grayCredentialsReady}',
      );
      progress(1);
      return const GameSurface();
    }
    ffrTrace(() => '[FFR.GATE] decide start route=${safe.route}');

    signals.onTokenChanged = _refreshForToken;

    // Cold-start push route wins over every persisted state.
    final coldRoute = await ColdRouteReader.consume();
    if (coldRoute != null) {
      await safe.saveRoute(GateRoute.web);
      await safe.consumePushUrl();
      unawaited(_backgroundDispatch());
      progress(1);
      return WebSurface(coldRoute, coldLaunch: true);
    }

    progress(0.12);
    return switch (safe.route) {
      GateRoute.unset => _firstRun(progress),
      GateRoute.web => _returningWeb(progress),
      GateRoute.game => _returningGame(progress),
    };
  }

  Future<GateDestination> _firstRun(void Function(double) progress) async {
    final reach = await _confirmReachability(progress, gate: 0.28);
    if (!reach) {
      ffrTrace(() => '[FFR.GATE] first: unreachable -> offline');
      return const OfflineSurface(returnToGame: false);
    }
    progress(0.48);
    await attribution.awaitSignals();
    progress(0.72);
    final reply = await _requestConfig();
    progress(1);
    ffrTrace(
      () => '[FFR.GATE] first: dest=${reply.hasDestination} url=${reply.url}',
    );
    if (reply.hasDestination) {
      await safe.saveRoute(GateRoute.web);
      return WebSurface(reply.url!);
    }
    await safe.saveRoute(GateRoute.game);
    return const GameSurface();
  }

  Future<GateDestination> _returningWeb(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineSurface(returnToGame: false);
    }

    // Pending push URL wins over the cached one — it is fresher.
    final pending = (await safe.consumePushUrl())?.trim();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return WebSurface(pending);
    }

    final cached = await safe.savedUrl();
    if (cached != null && !safe.cachedUrlExpired) {
      progress(1);
      return WebSurface(cached);
    }

    // Parallel warmup while we're already going to hit the network.
    await Future.wait<void>(<Future<void>>[
      signals.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      return const OfflineSurface(returnToGame: false);
    }
    progress(0.62);
    await attribution.awaitSignals(installTimeout: const Duration(seconds: 5));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return WebSurface(reply.url!);
    if (cached != null) return WebSurface(cached);
    return const OfflineSurface(returnToGame: false);
  }

  Future<GateDestination> _returningGame(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      progress(1);
      return const GameSurface();
    }
    await Future.wait<void>(<Future<void>>[
      signals.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      progress(1);
      return const GameSurface();
    }
    progress(0.55);
    await attribution.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const GameSurface();
    await safe.saveRoute(GateRoute.web);
    return WebSurface(reply.url!);
  }

  /// First-run reachability: interface + boot signals + DNS probe.
  /// Reports [gate] once the interface check passes so the splash bar
  /// keeps moving while the probe is in flight.
  Future<bool> _confirmReachability(
    void Function(double) progress, {
    required double gate,
  }) async {
    if (!await probe.hasInterface()) return false;
    progress(gate);
    try {
      await signals.boot();
    } catch (_) {
      // A messaging boot failure must never break routing — the config
      // POST proceeds without a push token, the gate re-runs later.
    }
    return probe.canReachNetwork();
  }

  Future<GateReply> _requestConfig({String? token}) async {
    final body = await attribution.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? signals.token,
    );
    return exchange.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        signals.boot(),
        attribution.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
