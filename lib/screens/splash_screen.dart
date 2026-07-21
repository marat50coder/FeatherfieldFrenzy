import 'dart:async';

import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../hatchway/core/gate_models.dart';
import '../hatchway/gate_coordinator.dart';
import '../hatchway/pages/no_connection_page.dart';
import '../hatchway/pages/push_invitation_page.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'menu_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.coordinator});

  final FrenzyGateCoordinator? coordinator;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  bool _launching = false;
  bool _assetsDone = false;
  GateDestination? _destination;
  Timer? _hardDeadline;

  static const Duration _minSplash = Duration(milliseconds: 1900);

  @override
  void initState() {
    super.initState();
    // Safety net: never let the pipeline hang forever.
    //
    // Must be strictly LARGER than the sum of the coordinator's own timeouts
    // (attribution.awaitSignals installTimeout=20s + config POST 15s = 35s
    // worst case) — otherwise this deadline fires FIRST and force-routes to
    // GameSurface while a valid Non-organic verdict is still in flight,
    // killing the whole gray pipeline for the first-run user.
    _hardDeadline = Timer(const Duration(seconds: 40), () {
      if (!mounted || _launching) return;
      _destination ??= const GameSurface();
      _tryLaunch();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final start = DateTime.now();
    _tickTo(0.35, const Duration(milliseconds: 900));

    await Future.wait<void>(<Future<void>>[
      _preloadAssets(),
      _resolveGate(),
    ]);

    _progress.value = 1.0;

    final elapsed = DateTime.now().difference(start);
    if (elapsed < _minSplash) {
      await Future.delayed(_minSplash - elapsed);
    }
    if (!mounted) return;
    _tryLaunch();
  }

  Future<void> _preloadAssets() async {
    try {
      await preloadEverything(context);
    } catch (_) {}
    _assetsDone = true;
    _bumpTo(0.55);
  }

  Future<void> _resolveGate() async {
    final coordinator = widget.coordinator;
    if (coordinator == null) {
      _destination = const GameSurface();
      _bumpTo(1.0);
      return;
    }
    try {
      _destination = await coordinator.decide(
        onProgress: (value) {
          // Gate progress feeds the top 45% of the bar so the animation
          // reads as "assets loaded, connecting…".
          final scaled = 0.55 + value.clamp(0.0, 1.0) * 0.45;
          if (scaled > _progress.value) _progress.value = scaled;
        },
      );
    } catch (_) {
      _destination = const GameSurface();
    }
    _bumpTo(1.0);
  }

  void _bumpTo(double v) {
    if (v > _progress.value) _progress.value = v.clamp(0.0, 1.0);
  }

  void _tickTo(double target, Duration duration) {
    const steps = 30;
    final stepDur = duration ~/ steps;
    var i = 0;
    void step() {
      if (!mounted || _launching) return;
      i++;
      final v = (i / steps) * target;
      if (v > _progress.value) _progress.value = v;
      if (i < steps) Future.delayed(stepDur, step);
    }

    step();
  }

  Future<void> _tryLaunch() async {
    if (_launching) return;
    if (!_assetsDone || _destination == null) return;
    _launching = true;
    _hardDeadline?.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;
    await _openDestination(_destination!);
  }

  Future<void> _openDestination(GateDestination destination) async {
    final coordinator = widget.coordinator;

    // Organic / gate disabled / offline-with-return-to-game → white game.
    if (destination is GameSurface || coordinator == null) {
      await lockPortrait();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, _, _) => const MenuScreen(),
          transitionsBuilder: (_, a, _, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
      return;
    }

    if (destination is OfflineSurface) {
      // Offline path: rebuild the whole splash on retry so a fresh probe
      // + attribution + config POST runs from scratch.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NoConnectionPage(
            probe: coordinator.probe,
            retryBuilder: (_) => SplashScreen(coordinator: coordinator),
          ),
        ),
      );
      return;
    }

    if (destination is WebSurface) {
      Widget portalBuilder(BuildContext _) => portalShellBuilder(
        coordinator: coordinator,
        url: destination.url,
        coldLaunch: destination.coldLaunch,
      );

      final showInvite =
          coordinator.safe.shouldShowPushInvite &&
          await coordinator.signals.canOfferPermission();
      if (!mounted) return;

      if (showInvite) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PushInvitationPage(
              safe: coordinator.safe,
              signals: coordinator.signals,
              nextBuilder: portalBuilder,
            ),
          ),
        );
      } else {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute<void>(builder: portalBuilder));
      }
    }
  }

  @override
  void dispose() {
    _hardDeadline?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bg = isLandscape ? A.loadingHor : A.loadingVert;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bg, fit: BoxFit.cover),
          Align(
            alignment: const Alignment(0, 0.86),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LoadingBar(progress: _progress),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<double>(
                    valueListenable: _progress,
                    builder: (_, v, _) => Text(
                      v >= 1.0 ? 'Let\'s go!' : 'Loading ${(v * 100).round()}%',
                      style: AppTheme.body(15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal progress bar that fills left → right.
class _LoadingBar extends StatelessWidget {
  final ValueNotifier<double> progress;
  const _LoadingBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 2.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v.clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, Color(0xFFFFD54F)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
