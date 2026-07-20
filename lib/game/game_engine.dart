import 'dart:math';
import 'dart:ui';

enum PlatformKind { normal, cracks, moves, spikes }

enum ItemKind { none, spring, rocket }

enum GameState { ready, playing, dying, dead }

/// A single platform in the world. Coordinates are in screen space where the
/// origin is the top-left and y grows downward.
class Platform {
  double cx; // center x
  double top; // top edge y
  double width;
  double height;
  PlatformKind kind;
  ItemKind item;

  /// 0 = none, 1 = crow, 2 = boar. A monster stands on the platform and is
  /// deadly on contact (but the platform can still be landed on at its edges).
  int monster;

  // Moving platform patrol velocity (px/s).
  double vx;

  // Cracks platform state.
  bool breaking = false;
  double breakTimer = 0;
  bool removed = false;

  Platform({
    required this.cx,
    required this.top,
    required this.width,
    required this.height,
    required this.kind,
    this.item = ItemKind.none,
    this.monster = 0,
    this.vx = 0,
  });

  double get bottom => top + height;
  double get left => cx - width / 2;
  double get right => cx + width / 2;
}

/// A rare "black hole" hazard floating in open space. Falling into it ends the
/// run. Coordinates are the centre of the hole.
class BlackHole {
  double cx;
  double cy;
  double size; // drawn diameter
  bool removed = false;
  BlackHole(this.cx, this.cy, this.size);
}

/// A stomped monster tumbling off the screen (visual only).
class FallingMonster {
  double cx;
  double cy;
  double size;
  int type;
  double vy;
  double rot = 0;
  double rotVel;
  bool removed = false;
  FallingMonster(this.cx, this.cy, this.size, this.type, this.vy, this.rotVel);
}

/// Pure game-logic engine. The widget layer feeds it `update(dt)` and input,
/// then reads its public state to render each frame.
class GameEngine {
  final Random _rng = Random();

  // Screen size.
  double w = 0;
  double h = 0;

  // Chicken (center coordinates).
  double cx = 0;
  double cy = 0;
  double vx = 0;
  double vy = 0;
  double chickenW = 0;
  double chickenH = 0;
  bool facingRight = true;

  // Black-hole suck animation.
  double chickenScale = 1.0;
  bool beingSucked = false;
  double suckProgress = 0; // 0..1
  BlackHole? _suckHole;
  double _suckStartX = 0;
  double _suckStartY = 0;

  // Rocket power-up.
  bool rocketActive = false;
  double rocketTimer = 0;

  final List<Platform> platforms = [];
  final List<BlackHole> holes = [];
  final List<FallingMonster> fallingMonsters = [];
  double _lastHoleY = double.infinity;

  GameState state = GameState.ready;
  int score = 0;
  double _totalScroll = 0;
  double _lastDt = 1 / 60;

  // Run statistics.
  int jumps = 0;
  int platformsBounced = 0;
  int rocketsUsed = 0;
  int springsUsed = 0;

  // Input: desired horizontal control in range [-1, 1].
  double controlX = 0;

  // Event callbacks (haptics / effects).
  void Function()? onBounce;
  void Function()? onSpring;
  void Function()? onRocket;
  void Function()? onDeath;

  // Tunables (scaled by screen height in [configure]).
  late double gravity;
  late double jumpV;
  late double springV;
  late double rocketV;
  late double maxMoveSpeed;
  late double baseGap;

  // Art aspect ratios (height / width) so hitboxes match the drawn sprites.
  Map<PlatformKind, double> platformAspect = {
    PlatformKind.normal: 0.34,
    PlatformKind.cracks: 0.30,
    PlatformKind.moves: 0.30,
    PlatformKind.spikes: 0.55,
  };
  double birdAspect = 1.0;

  void configure(
    Size size, {
    Map<PlatformKind, double>? aspects,
    double birdAspect = 1.0,
  }) {
    w = size.width;
    h = size.height;
    final s = h / 800.0;

    gravity = 2300 * s;
    jumpV = -1180 * s;
    springV = -2050 * s;
    rocketV = -1550 * s;
    maxMoveSpeed = 560 * s;
    baseGap = h * 0.135;

    if (aspects != null) platformAspect = aspects;
    this.birdAspect = birdAspect;

    chickenW = w * 0.16;
    chickenH = chickenW * birdAspect;

    reset();
  }

  double get scroll => _totalScroll;
  BlackHole? get suckHole => _suckHole;

  void reset() {
    platforms.clear();
    holes.clear();
    fallingMonsters.clear();
    _lastHoleY = double.infinity;
    score = 0;
    _totalScroll = 0;
    jumps = 0;
    platformsBounced = 0;
    rocketsUsed = 0;
    springsUsed = 0;
    rocketActive = false;
    rocketTimer = 0;
    controlX = 0;
    facingRight = true;
    chickenScale = 1.0;
    beingSucked = false;
    suckProgress = 0;
    _suckHole = null;

    // Starting platform right under the chicken.
    final startPlat = Platform(
      cx: w / 2,
      top: h * 0.82,
      width: _platW,
      height: _platH(PlatformKind.normal),
      kind: PlatformKind.normal,
    );
    platforms.add(startPlat);

    cx = w / 2;
    cy = startPlat.top - chickenH / 2;
    vx = 0;
    vy = 0; // frozen until the player starts

    // Fill the screen with an initial ladder of platform rows.
    double y = startPlat.top - baseGap;
    while (y > -h) {
      _spawnRow(y);
      y -= _gap();
    }
    state = GameState.ready;
  }

  void start() {
    if (state == GameState.ready) {
      state = GameState.playing;
      vy = jumpV; // initial hop
    }
  }

  double get _platW => w * 0.28;
  double _platH(PlatformKind k) => _platW * (platformAspect[k] ?? 0.34);

  double _gap() {
    // Difficulty ramps with score; clamp so jumps stay reachable.
    final diff = (score / 1500).clamp(0.0, 1.0);
    final g = baseGap + diff * (h * 0.06);
    final jitter = _rng.nextDouble() * (h * 0.04);
    return (g + jitter).clamp(h * 0.10, h * 0.24);
  }

  /// Spawns a whole row of platforms at [top]. A row can hold several
  /// platforms side by side, and always contains at least one safe (non-spike)
  /// platform so a spike is never an unavoidable dead end.
  void _spawnRow(double top) {
    final diff = (score / 2200).clamp(0.0, 1.0);

    // How many platforms share this height. 3-in-a-row is intentionally rare;
    // mostly 1 or 2.
    int count;
    final r = _rng.nextDouble();
    if (r < 0.46) {
      count = 1;
    } else if (r < 0.88) {
      count = 2;
    } else {
      count = 3;
    }
    if (count == 3 && (diff > 0.5 || _rng.nextBool())) count = 2;

    final width = _platW;
    // Clamp count so platforms always fit with a real gap between them.
    count = _maxFittingCount(count, width);

    final slots = _pickSlots(count, width);

    if (count == 1) {
      // A lone platform is always fully safe (never spike/monster) so the row
      // can always be cleared. It may still crack or move.
      final kind = _pickSingleKind(diff);
      final p = Platform(
        cx: slots[0],
        top: top,
        width: width,
        height: _platH(kind),
        kind: kind,
        vx: kind == PlatformKind.moves
            ? (_rng.nextBool() ? 1 : -1) * (70 + _rng.nextDouble() * 60)
            : 0,
      );
      if (kind == PlatformKind.normal) _maybeItem(p);
      platforms.add(p);
    } else {
      // One slot is guaranteed a plain, monster-free platform: the safe path.
      final safeIdx = _rng.nextInt(count);
      bool itemPlaced = false;
      bool monsterPlaced = false; // at most one monster per row (never adjacent)
      for (int i = 0; i < count; i++) {
        PlatformKind kind = PlatformKind.normal;
        int monster = 0;
        if (i != safeIdx) {
          final rr = _rng.nextDouble();
          final spikeChance = 0.10 + diff * 0.10;
          final crackChance = 0.12 + diff * 0.06;
          final monsterChance = score > 350 ? (0.10 + diff * 0.10) : 0.0;
          if (rr < spikeChance) {
            kind = PlatformKind.spikes;
          } else if (rr < spikeChance + crackChance) {
            kind = PlatformKind.cracks;
          } else if (rr < spikeChance + crackChance + monsterChance) {
            if (!monsterPlaced) {
              monster = _rng.nextBool() ? 1 : 2;
              monsterPlaced = true;
            }
          }
        }
        final p = Platform(
          cx: slots[i],
          top: top,
          width: width,
          height: _platH(kind),
          kind: kind,
          monster: monster,
        );
        if (kind == PlatformKind.normal && monster == 0 && !itemPlaced) {
          _maybeItem(p);
          if (p.item != ItemKind.none) itemPlaced = true;
        }
        platforms.add(p);
      }
    }

    _maybeSpawnBlackHole(top, diff);
  }

  static const double _rowEdge = 6;
  static const double _rowMinGap = 14;

  int _maxFittingCount(int desired, double width) {
    int c = desired;
    while (c > 1) {
      final free = w - 2 * _rowEdge - c * width;
      if (free / (c + 1) >= _rowMinGap) break;
      c--;
    }
    return c;
  }

  void _maybeItem(Platform p) {
    final ir = _rng.nextDouble();
    if (ir < 0.05) {
      p.item = ItemKind.rocket;
    } else if (ir < 0.17) {
      p.item = ItemKind.spring;
    }
  }

  PlatformKind _pickSingleKind(double diff) {
    final r = _rng.nextDouble();
    final crackChance = 0.10 + diff * 0.08;
    final moveChance = 0.12 + diff * 0.10;
    if (r < crackChance) return PlatformKind.cracks;
    if (r < crackChance + moveChance) return PlatformKind.moves;
    return PlatformKind.normal;
  }

  /// Occasionally drops a small black hole in the widest open gap of a row so
  /// it never sits above a platform and the row stays passable.
  void _maybeSpawnBlackHole(double rowTop, double diff) {
    if (score < 500) return;
    if (holes.length >= 2) return;
    // Keep a big vertical spacing so holes are rare and never stack up.
    if ((_lastHoleY - rowTop).abs() < h * 1.3) return;
    final chance = 0.05 + diff * 0.04;
    if (_rng.nextDouble() > chance) return;

    final size = w * 0.22;
    // Find the widest horizontal gap between platforms in this row.
    final rowPlats = platforms.where((p) => p.top == rowTop).toList()
      ..sort((a, b) => a.cx.compareTo(b.cx));
    double bestCenter = -1;
    double bestGap = 0;
    double cursor = 0;
    for (final p in rowPlats) {
      final gap = p.left - cursor;
      if (gap > bestGap) {
        bestGap = gap;
        bestCenter = cursor + gap / 2;
      }
      cursor = p.right;
    }
    final tailGap = w - cursor;
    if (tailGap > bestGap) {
      bestGap = tailGap;
      bestCenter = cursor + tailGap / 2;
    }
    // Only place it if there is genuine empty room for the hole.
    if (bestGap < size * 1.05 || bestCenter < 0) return;

    final cx = bestCenter.clamp(size / 2, w - size / 2);
    final cy = rowTop - size * 0.55;
    holes.add(BlackHole(cx, cy, size));
    _lastHoleY = rowTop;
  }

  /// Evenly spaces [count] platforms with equal gaps (never overlapping),
  /// plus a small random group shift for variety.
  List<double> _pickSlots(int count, double width) {
    if (count <= 1) {
      final margin = width / 2 + _rowEdge;
      return [margin + _rng.nextDouble() * (w - 2 * margin)];
    }
    final free = w - 2 * _rowEdge - count * width;
    final unit = free / (count + 1); // equal gap incl. edges
    final shift = (_rng.nextDouble() * 2 - 1) * (unit * 0.5);
    final slots = <double>[];
    for (int i = 0; i < count; i++) {
      final left = _rowEdge + unit * (i + 1) + width * i + shift;
      slots.add(left + width / 2);
    }
    return slots;
  }

  double get _highestTop {
    double m = double.infinity;
    for (final p in platforms) {
      if (p.top < m) m = p.top;
    }
    return m == double.infinity ? 0 : m;
  }

  void update(double dt) {
    if (state == GameState.dead) return;
    // Cap dt to avoid tunnelling through platforms on frame hitches.
    dt = dt.clamp(0.0, 1 / 30);
    _lastDt = dt <= 0 ? 1 / 60 : dt;

    if (state == GameState.ready) {
      // Frozen on the starting platform until the player begins; no gravity
      // so the chicken never falls through platforms while waiting.
      return;
    }

    if (beingSucked) {
      _updateSuck(dt);
      return;
    }

    if (rocketActive) {
      rocketTimer -= dt;
      vy = rocketV;
      if (rocketTimer <= 0) {
        rocketActive = false;
        vy = jumpV * 0.5;
      }
    }

    _integrate(dt, allowControl: state == GameState.playing);
    _updatePlatforms(dt);

    if (state == GameState.playing) {
      _handleCollisions();
    }

    _scroll();
    _recycle();
    _ensurePlatforms();
    _checkDeath();
  }

  void _integrate(double dt, {required bool allowControl}) {
    if (allowControl) {
      final target = controlX * maxMoveSpeed;
      // Smooth toward target for responsive but not twitchy movement.
      vx += (target - vx) * min(1.0, dt * 12);
      if (vx.abs() > 6) facingRight = vx > 0;
    } else if (state == GameState.dying) {
      vx *= 0.98;
    }

    vy += gravity * dt;
    cx += vx * dt;
    cy += vy * dt;

    // Horizontal screen wrap (classic Doodle Jump behaviour).
    if (cx < -chickenW / 2) cx = w + chickenW / 2;
    if (cx > w + chickenW / 2) cx = -chickenW / 2;
  }

  void _updatePlatforms(double dt) {
    for (final p in platforms) {
      if (p.kind == PlatformKind.moves && !p.breaking) {
        p.cx += p.vx * dt;
        if (p.left <= 0) {
          p.cx = p.width / 2;
          p.vx = p.vx.abs();
        } else if (p.right >= w) {
          p.cx = w - p.width / 2;
          p.vx = -p.vx.abs();
        }
      }
      if (p.breaking) {
        p.breakTimer += dt;
        p.top += 320 * dt; // fall away
        if (p.breakTimer > 0.5) p.removed = true;
      }
    }
    platforms.removeWhere((p) => p.removed);

    for (final m in fallingMonsters) {
      m.vy += gravity * dt;
      m.cy += m.vy * dt;
      m.rot += m.rotVel * dt;
    }
  }

  void _handleCollisions() {
    // Black holes and monsters are lethal on contact from any direction, but
    // the rocket makes the chicken invincible.
    if (!rocketActive) {
      for (final hole in holes) {
        final dx = cx - hole.cx;
        final dy = cy - hole.cy;
        final trigger = hole.size * 0.42;
        if (dx * dx + dy * dy < trigger * trigger) {
          _startSuck(hole);
          return;
        }
      }
    }

    final feet = cy + chickenH / 2;
    final prevFeet = feet - vy * _lastDt; // swept previous foot position

    for (final p in platforms) {
      if (p.breaking) continue;

      // A monster standing on the platform. The crow (type 1) can be stomped
      // from above (it dies and drops); the armoured boar (type 2) is deadly
      // from every direction, including its spiky back.
      if (p.monster != 0 && !rocketActive) {
        final mw = p.width * 0.5;
        final mh = p.width * 0.5;
        final mcx = p.cx;
        final mcy = p.top - mh * 0.5 + p.height * 0.2;
        final overlap = (cx - mcx).abs() < (mw + chickenW * 0.5) / 2 &&
            (cy - mcy).abs() < (mh + chickenH * 0.5) / 2;
        // Rising up into a monster from below (head graze while jumping past a
        // platform above) is harmless — you simply pass through.
        final comingFromBelow = vy < 0 && cy > mcy;
        if (overlap && !comingFromBelow) {
          final stomp = p.monster == 1 && vy > 0 && prevFeet <= mcy;
          if (stomp) {
            final s = h / 800.0;
            fallingMonsters.add(FallingMonster(
              mcx,
              mcy,
              p.width * 0.82,
              p.monster,
              -180 * s,
              (_rng.nextBool() ? 1 : -1) * 5,
            ));
            p.monster = 0;
            vy = jumpV; // bounce off its head
            jumps++;
            platformsBounced++;
            onBounce?.call();
            continue;
          }
          _die();
          return;
        }
      }

      // Rocket pickup can be grabbed from any direction on overlap.
      if (p.item == ItemKind.rocket) {
        final overlap = (cx - p.cx).abs() < p.width * 0.55 &&
            (cy - (p.top - p.height * 0.4)).abs() < p.height * 1.6 + chickenH * 0.5;
        if (overlap) {
          rocketActive = true;
          rocketTimer = 2.6;
          rocketsUsed++;
          onRocket?.call();
          p.item = ItemKind.none;
          continue;
        }
      }

      if (rocketActive) continue; // fly through everything while boosting
      if (vy <= 0) continue; // only interact while falling

      final horizOverlap = (cx - p.cx).abs() < (p.width / 2 + chickenW * 0.25);
      // Landing line sits near the top surface of the platform.
      final surface = p.top + p.height * 0.35;
      final crossed = prevFeet <= surface && feet >= p.top - 2;
      if (!(horizOverlap && crossed)) continue;

      if (p.kind == PlatformKind.spikes) {
        _die();
        return;
      }

      // Spring on this platform → super bounce.
      if (p.item == ItemKind.spring) {
        vy = springV;
        springsUsed++;
        jumps++;
        platformsBounced++;
        p.item = ItemKind.none;
        onSpring?.call();
        return;
      }

      // Normal bounce.
      vy = jumpV;
      jumps++;
      platformsBounced++;
      onBounce?.call();

      if (p.kind == PlatformKind.cracks) {
        p.breaking = true; // usable once, then falls away
      } else if (p.kind == PlatformKind.moves) {
        // Relocate to a new random spot on every bounce.
        p.cx = p.width / 2 + _rng.nextDouble() * (w - p.width);
        p.vx = (_rng.nextBool() ? 1 : -1) * p.vx.abs().clamp(70, 160);
      }
      return;
    }
  }

  void _scroll() {
    final threshold = h * 0.42;
    if (cy < threshold) {
      final delta = threshold - cy;
      cy = threshold;
      for (final p in platforms) {
        p.top += delta;
      }
      for (final hole in holes) {
        hole.cy += delta;
      }
      for (final m in fallingMonsters) {
        m.cy += delta;
      }
      if (_lastHoleY != double.infinity) _lastHoleY += delta;
      _totalScroll += delta;
      final newScore = (_totalScroll / 4).round();
      if (newScore > score) score = newScore;
    }
  }

  void _recycle() {
    platforms.removeWhere((p) => p.top > h + 60);
    holes.removeWhere((hole) => hole.cy - hole.size > h + 60);
    fallingMonsters.removeWhere((m) => m.cy - m.size > h + 80);
  }

  void _ensurePlatforms() {
    double highest = _highestTop;
    while (highest > -h * 0.2) {
      final newTop = highest - _gap();
      _spawnRow(newTop);
      highest = newTop;
    }
  }

  void _die() {
    if (state == GameState.dying || state == GameState.dead) return;
    state = GameState.dying;
    rocketActive = false;
    vy = jumpV * 0.5; // little hop then fall
    onDeath?.call();
  }

  void _startSuck(BlackHole hole) {
    if (beingSucked || state == GameState.dead) return;
    beingSucked = true;
    _suckHole = hole;
    suckProgress = 0;
    _suckStartX = cx;
    _suckStartY = cy;
    vx = 0;
    vy = 0;
    rocketActive = false;
    state = GameState.dying;
    onDeath?.call();
  }

  /// Pulls the chicken into the hole's centre while spiralling and shrinking.
  void _updateSuck(double dt) {
    final hole = _suckHole;
    if (hole == null) {
      state = GameState.dead;
      beingSucked = false;
      return;
    }
    suckProgress += dt / 0.85; // ~0.85s animation
    final t = suckProgress.clamp(0.0, 1.0);
    final e = t * t; // accelerate toward the centre
    final baseX = _suckStartX + (hole.cx - _suckStartX) * e;
    final baseY = _suckStartY + (hole.cy - _suckStartY) * e;
    final spiralR = (1 - t) * hole.size * 0.22;
    final ang = t * pi * 5; // ~2.5 rotations
    cx = baseX + cos(ang) * spiralR;
    cy = baseY + sin(ang) * spiralR;
    chickenScale = (1 - t) * 0.98 + 0.02;
    if (t >= 1.0) {
      chickenScale = 0;
      state = GameState.dead;
      beingSucked = false;
    }
  }

  void _checkDeath() {
    if (state == GameState.playing && cy - chickenH / 2 > h) {
      _die();
    }
    if (state == GameState.dying && cy - chickenH / 2 > h + 40) {
      state = GameState.dead;
    }
  }
}
