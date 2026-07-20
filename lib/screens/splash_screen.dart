import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'menu_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final start = DateTime.now();

    // Creep the bar up to ~0.9 while real work happens; it must only reach
    // 1.0 at the very last moment before launching.
    _tickTo(0.9, const Duration(milliseconds: 1600));

    await preloadEverything(context);

    // Guarantee a minimum splash time so the animation reads well.
    final elapsed = DateTime.now().difference(start);
    const minDuration = Duration(milliseconds: 1900);
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }

    // Fill completely right before entering the game.
    _progress.value = 1.0;
    await Future.delayed(const Duration(milliseconds: 380));

    await lockPortrait();
    if (!mounted) return;
    _launching = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const MenuScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _tickTo(double target, Duration duration) {
    const steps = 30;
    final stepDur = duration ~/ steps;
    int i = 0;
    void step() {
      if (!mounted || _launching) return;
      i++;
      final v = (i / steps) * target;
      if (v > _progress.value) _progress.value = v;
      if (i < steps) Future.delayed(stepDur, step);
    }

    step();
  }

  @override
  void dispose() {
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
                    builder: (_, v, __) => Text(
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, __) => Align(
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
