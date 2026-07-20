import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

import '../data/game_data.dart';
import '../services/image_assets.dart';
import '../services/storage.dart';
import '../services/audio.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'game_engine.dart';
import 'game_painter.dart';

class GameScreen extends StatefulWidget {
  final LevelTheme theme;
  const GameScreen({super.key, required this.theme});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final GameEngine _engine = GameEngine();
  final ImageAssets _assets = ImageAssets.instance;
  final _RepaintNotifier _repaint = _RepaintNotifier();
  final ValueNotifier<int> _score = ValueNotifier<int>(0);

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _configured = false;
  bool _paused = false;
  bool _resultShown = false;
  bool _started = false;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double? _pointerX;

  List<String> _newAchievements = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
    if (GameStorage.instance.controlMode == 'tilt') {
      _accelSub = accelerometerEventStream().listen(_onAccel);
    }
  }

  void _onAccel(AccelerometerEvent e) {
    if (GameStorage.instance.controlMode != 'tilt') return;
    // Tilting the device right moves the chicken right. Lower divisor = more
    // sensitive; a small dead-zone keeps it from drifting when held flat.
    final raw = -e.x / 3.2;
    _engine.controlX = raw.abs() < 0.04 ? 0.0 : raw.clamp(-1.0, 1.0);
  }

  void _onTick(Duration elapsed) {
    if (!_configured || _paused) {
      _last = elapsed;
      return;
    }
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;

    // Touch control (overrides tilt while a finger is down).
    if (_pointerX != null && _engine.state != GameState.dying) {
      final delta = (_pointerX! - _engine.cx) / (_engine.w * 0.22);
      _engine.controlX = delta.clamp(-1.0, 1.0);
    } else if (GameStorage.instance.controlMode == 'touch') {
      _engine.controlX = 0;
    }

    _engine.update(dt);
    _score.value = _engine.score;
    _repaint.tick();

    if (_engine.state == GameState.dead && !_resultShown) {
      _onGameOver();
    }
  }

  void _onGameOver() {
    _resultShown = true;
    _ticker.stop();
    Audio.instance.death();
    _newAchievements = GameStorage.instance.recordRun(
      theme: widget.theme.index,
      score: _engine.score,
      jumps: _engine.jumps,
      platforms: _engine.platformsBounced,
      rockets: _engine.rocketsUsed,
      springs: _engine.springsUsed,
    );
    setState(() {});
  }

  void _startIfNeeded() {
    if (!_started) {
      _started = true;
      _engine.start();
      setState(() {});
    }
  }

  void _restart() {
    setState(() {
      _engine.reset();
      _resultShown = false;
      _paused = false;
      // Auto-start on retry so the player doesn't need an extra tap.
      _started = true;
      _newAchievements = [];
      _score.value = 0;
      _last = Duration.zero;
    });
    if (!_ticker.isActive) _ticker.start();
    _engine.start();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _accelSub?.cancel();
    _repaint.dispose();
    _score.dispose();
    super.dispose();
  }

  void _bindEvents() {
    _engine.onBounce = Audio.instance.bounce;
    _engine.onSpring = Audio.instance.spring;
    _engine.onRocket = Audio.instance.rocket;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (!_configured) {
            _engine.configure(
              size,
              aspects: {
                PlatformKind.normal: _aspect(widget.theme.platform),
                PlatformKind.cracks: _aspect(A.cracksBlock),
                PlatformKind.moves: _aspect(A.movesBlock),
                PlatformKind.spikes: _aspect(widget.theme.spikes),
              },
              birdAspect: _aspect(widget.theme.bird),
            );
            _bindEvents();
            _configured = true;
          }
          return Listener(
            onPointerDown: (e) {
              _pointerX = e.localPosition.dx;
              _startIfNeeded();
            },
            onPointerMove: (e) => _pointerX = e.localPosition.dx,
            onPointerUp: (e) => _pointerX = null,
            onPointerCancel: (e) => _pointerX = null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: GamePainter(
                      engine: _engine,
                      theme: widget.theme,
                      assets: _assets,
                      repaint: _repaint,
                    ),
                  ),
                ),
                _buildHud(),
                if (!_started && _engine.state != GameState.dead) _buildReady(),
                if (_paused) _buildPause(),
                if (_engine.state == GameState.dead) _buildGameOver(),
              ],
            ),
          );
        },
      ),
    );
  }

  double _aspect(String path) {
    final c = _assets.contentRect(path);
    return c.height / c.width;
  }

  Widget _buildHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _score,
                    builder: (_, v, __) => Text('$v', style: AppTheme.title(26)),
                  ),
                ),
                const Spacer(),
                if (_engine.state != GameState.dead)
                  RoundIconButton(
                    icon: Icons.pause_rounded,
                    color: AppTheme.primary,
                    onTap: _togglePause,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _RocketBar(engine: _engine, repaint: _repaint),
          ],
        ),
      ),
    );
  }

  Widget _buildReady() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.25),
        alignment: Alignment.center,
        child: WoodPanel(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.theme.name, style: AppTheme.title(24, color: AppTheme.ink)),
              const SizedBox(height: 10),
              Icon(
                GameStorage.instance.controlMode == 'tilt'
                    ? Icons.screen_rotation_rounded
                    : Icons.swipe_rounded,
                size: 46,
                color: AppTheme.brown,
              ),
              const SizedBox(height: 8),
              Text(
                GameStorage.instance.controlMode == 'tilt'
                    ? 'Tilt your device to move.\nAvoid the spikes!'
                    : 'Swipe left / right to move.\nAvoid the spikes!',
                textAlign: TextAlign.center,
                style: AppTheme.body(16, color: AppTheme.ink),
              ),
              const SizedBox(height: 16),
              CandyButton(
                label: 'TAP TO START',
                width: 220,
                onTap: _startIfNeeded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPause() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: WoodPanel(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: AppTheme.title(28, color: AppTheme.ink)),
              const SizedBox(height: 18),
              CandyButton(label: 'RESUME', icon: Icons.play_arrow_rounded, onTap: _togglePause),
              const SizedBox(height: 12),
              CandyButton(
                label: 'RESTART',
                icon: Icons.refresh_rounded,
                color: AppTheme.green,
                shadowColor: AppTheme.greenDark,
                onTap: () {
                  _togglePause();
                  _restart();
                },
              ),
              const SizedBox(height: 12),
              CandyButton(
                label: 'HOME',
                icon: Icons.home_rounded,
                color: AppTheme.danger,
                shadowColor: const Color(0xFFB0362D),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final store = GameStorage.instance;
    final best = store.bestScore(widget.theme.index);
    final earned = store.lastRunCoins(_engine.score);
    final isNewBest = _engine.score >= best && _engine.score > 0;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: WoodPanel(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Game Over', style: AppTheme.title(28, color: AppTheme.ink)),
                const SizedBox(height: 14),
                _statLine('Score', '${_engine.score}'),
                _statLine('Best', '$best'),
                _statLine('Coins earned', '+$earned'),
                if (isNewBest) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('NEW BEST!', style: AppTheme.title(16)),
                  ),
                ],
                if (_newAchievements.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ..._newAchievements.map((id) {
                    final a = kAchievements.firstWhere((e) => e.id == id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(a.icon, color: AppTheme.primaryDark, size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text('Unlocked: ${a.title}',
                                style: AppTheme.body(14, color: AppTheme.ink)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 18),
                CandyButton(
                  label: 'PLAY AGAIN',
                  icon: Icons.refresh_rounded,
                  color: AppTheme.green,
                  shadowColor: AppTheme.greenDark,
                  onTap: _restart,
                ),
                const SizedBox(height: 12),
                CandyButton(
                  label: 'HOME',
                  icon: Icons.home_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.body(18, color: AppTheme.brown)),
          Text(value, style: AppTheme.title(20, color: AppTheme.ink)),
        ],
      ),
    );
  }
}

/// Drives the game [CustomPainter] repaints once per frame.
class _RepaintNotifier extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// Thin progress bar that appears while the rocket power-up is active.
class _RocketBar extends StatelessWidget {
  final GameEngine engine;
  final Listenable repaint;
  const _RocketBar({required this.engine, required this.repaint});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repaint,
      builder: (_, __) {
        if (!engine.rocketActive) return const SizedBox(height: 8);
        final t = (engine.rocketTimer / 2.6).clamp(0.0, 1.0);
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 140,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: t,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
