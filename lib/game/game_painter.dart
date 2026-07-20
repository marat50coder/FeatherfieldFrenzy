import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../data/game_data.dart';
import '../services/image_assets.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;
  final LevelTheme theme;
  final ImageAssets assets;

  GamePainter({
    required this.engine,
    required this.theme,
    required this.assets,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    for (final hole in engine.holes) {
      _drawBlackHole(canvas, hole);
    }
    for (final p in engine.platforms) {
      _drawPlatform(canvas, p);
    }
    for (final m in engine.fallingMonsters) {
      _drawFallingMonster(canvas, m);
    }
    _drawChicken(canvas);
    // While being sucked in, redraw the swirl on top so the chicken appears to
    // sink beneath the vortex.
    if (engine.beingSucked) {
      final hole = engine.suckHole;
      if (hole != null) _drawBlackHole(canvas, hole);
    }
  }

  void _drawFallingMonster(Canvas canvas, FallingMonster m) {
    final path = m.type == 1 ? A.monster1 : A.monster2;
    final img = assets[path];
    if (img == null) return;
    final content = assets.contentRect(path);
    final mw = m.size;
    final mh = mw * (content.height / content.width);
    final dst = Rect.fromCenter(
      center: Offset(m.cx, m.cy),
      width: mw,
      height: mh,
    );
    // Flip upside-down while tumbling so it clearly reads as "defeated".
    _drawSprite(canvas, img, content, dst, rotation: m.rot, flip: true);
  }

  void _drawBlackHole(Canvas canvas, BlackHole hole) {
    final img = assets[A.blackHole];
    if (img == null) return;
    final content = assets.contentRect(A.blackHole);
    // Slow continuous swirl driven by total scroll for a living vortex feel.
    final rotation = (engine.scroll * 0.004) % (2 * 3.14159);
    final dst = Rect.fromCenter(
      center: Offset(hole.cx, hole.cy),
      width: hole.size,
      height: hole.size,
    );
    _drawSprite(canvas, img, content, dst, rotation: rotation);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final img = assets[theme.background];
    if (img == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = theme.accent);
      return;
    }
    final imgW = img.width.toDouble();
    final imgH = img.height.toDouble();
    final tileH = size.width * (imgH / imgW);
    final scrollOffset = engine.scroll * 0.5;
    final baseIndex = (scrollOffset / tileH).floor();
    final offset = scrollOffset - baseIndex * tileH;
    final src = Rect.fromLTWH(0, 0, imgW, imgH);
    final paint = Paint()..filterQuality = FilterQuality.low;

    double yy = offset - tileH;
    int tileIndex = baseIndex - 1;
    while (yy < size.height) {
      final dst = Rect.fromLTWH(0, yy, size.width, tileH);
      // Mirror every other tile vertically so edges always match → no seam.
      final flip = tileIndex.isOdd;
      if (flip) {
        canvas.save();
        canvas.translate(0, dst.center.dy);
        canvas.scale(1, -1);
        canvas.translate(0, -dst.center.dy);
        canvas.drawImageRect(img, src, dst, paint);
        canvas.restore();
      } else {
        canvas.drawImageRect(img, src, dst, paint);
      }
      yy += tileH;
      tileIndex++;
    }
  }

  void _drawPlatform(Canvas canvas, Platform p) {
    String path;
    switch (p.kind) {
      case PlatformKind.normal:
        path = theme.platform;
        break;
      case PlatformKind.cracks:
        path = A.cracksBlock;
        break;
      case PlatformKind.moves:
        path = A.movesBlock;
        break;
      case PlatformKind.spikes:
        path = theme.spikes;
        break;
    }
    final img = assets[path];
    if (img == null) return;
    final content = assets.contentRect(path);

    double opacity = 1;
    if (p.breaking) {
      opacity = (1 - p.breakTimer / 0.5).clamp(0.0, 1.0);
    }

    // Spikes art includes tall spikes above the ground band, so anchor the
    // drawing by its bottom to keep the ground line at the platform top+height.
    final dst = Rect.fromLTWH(p.left, p.top, p.width, p.height);
    _drawSprite(canvas, img, content, dst, opacity: opacity);

    if (p.item == ItemKind.spring || p.item == ItemKind.rocket) {
      final itemPath = p.item == ItemKind.spring ? A.spring : A.rocket;
      final itemImg = assets[itemPath];
      if (itemImg != null) {
        final ic = assets.contentRect(itemPath);
        final iw = p.width * 0.52;
        final ih = iw * (ic.height / ic.width);
        final rect = Rect.fromCenter(
          center: Offset(p.cx, p.top - ih * 0.35),
          width: iw,
          height: ih,
        );
        _drawSprite(canvas, itemImg, ic, rect);
      }
    }

    if (p.monster != 0) {
      _drawMonster(canvas, p);
    }
  }

  void _drawMonster(Canvas canvas, Platform p) {
    final path = p.monster == 1 ? A.monster1 : A.monster2;
    final img = assets[path];
    if (img == null) return;
    final content = assets.contentRect(path);
    // Neatly sized to the block; feet resting on the grass line.
    final mw = p.width * 0.82;
    final mh = mw * (content.height / content.width);
    final bottom = p.top + p.height * 0.42;
    final rect = Rect.fromCenter(
      center: Offset(p.cx, bottom - mh / 2),
      width: mw,
      height: mh,
    );
    _drawSprite(canvas, img, content, rect);
  }

  void _drawChicken(Canvas canvas) {
    final scale = engine.chickenScale;
    if (scale <= 0.001) return; // fully swallowed by the hole
    final path = engine.rocketActive ? theme.birdRocket : theme.bird;
    final img = assets[path];
    if (img == null) return;
    final content = assets.contentRect(path);
    final baseW = engine.chickenW * (engine.rocketActive ? 1.32 : 1.12) * scale;
    final h = baseW * (content.height / content.width);
    final center = Offset(engine.cx, engine.cy);
    double rotation = (engine.vx / (engine.maxMoveSpeed)).clamp(-1.0, 1.0) * 0.16;
    if (engine.beingSucked) {
      rotation += engine.suckProgress * math.pi * 5; // spin into the vortex
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    if (!engine.facingRight) canvas.scale(-1, 1);
    final dst = Rect.fromCenter(center: Offset.zero, width: baseW, height: h);
    canvas.drawImageRect(img, content, dst,
        Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
  }

  void _drawSprite(
    Canvas canvas,
    ui.Image img,
    Rect content,
    Rect dst, {
    bool flip = false,
    double rotation = 0,
    double opacity = 1,
  }) {
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(dst.center.dx, dst.center.dy);
    if (rotation != 0) canvas.rotate(rotation);
    if (flip) canvas.scale(-1, 1);
    final d =
        Rect.fromCenter(center: Offset.zero, width: dst.width, height: dst.height);
    canvas.drawImageRect(img, content, d, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => false;
}
