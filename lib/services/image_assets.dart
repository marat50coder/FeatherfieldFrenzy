import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../data/game_data.dart';

/// Decodes and caches `ui.Image` objects so the game's [CustomPainter] can
/// draw them directly on the canvas (much faster than widgets per sprite).
class ImageAssets {
  ImageAssets._();
  static final ImageAssets instance = ImageAssets._();

  final Map<String, ui.Image> _cache = {};
  final Map<String, Rect> _content = {};
  bool _loaded = false;

  ui.Image? operator [](String path) => _cache[path];

  ui.Image get(String path) => _cache[path]!;

  /// The tight opaque bounding box of a sprite in image pixels. Falls back to
  /// the full image when it wasn't analysed (e.g. backgrounds).
  Rect contentRect(String path) {
    final img = _cache[path];
    return _content[path] ??
        Rect.fromLTWH(
            0, 0, (img?.width ?? 1).toDouble(), (img?.height ?? 1).toDouble());
  }

  Future<Rect> _computeContentRect(ui.Image img) async {
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final wpx = img.width;
    final hpx = img.height;
    if (byteData == null) {
      return Rect.fromLTWH(0, 0, wpx.toDouble(), hpx.toDouble());
    }
    final bytes = byteData.buffer.asUint8List();
    const alphaThreshold = 16;
    const step = 2;
    int minX = wpx, minY = hpx, maxX = -1, maxY = -1;
    for (int y = 0; y < hpx; y += step) {
      final rowOffset = y * wpx * 4;
      for (int x = 0; x < wpx; x += step) {
        final a = bytes[rowOffset + x * 4 + 3];
        if (a > alphaThreshold) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return Rect.fromLTWH(0, 0, wpx.toDouble(), hpx.toDouble());
    return Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    );
  }

  Future<ui.Image> _decode(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  List<String> get _allPaths {
    final paths = <String>{
      A.rocket,
      A.spring,
      A.cracksBlock,
      A.movesBlock,
      A.monster1,
      A.monster2,
      A.blackHole,
      A.logo,
    };
    for (final t in kThemes) {
      paths.addAll([
        t.background,
        t.platform,
        t.spikes,
        t.bird,
        t.birdRocket,
      ]);
    }
    return paths.toList();
  }

  Set<String> get _spritePaths {
    final backgrounds = kThemes.map((t) => t.background).toSet()
      ..addAll([A.logo]);
    return _allPaths.toSet().difference(backgrounds);
  }

  /// Loads every game sprite. Also warms the widget image cache for the big
  /// menu / loading backgrounds. Safe to call multiple times.
  Future<void> preloadAll(BuildContext context) async {
    if (_loaded) return;
    final sprites = _spritePaths;
    for (final path in _allPaths) {
      final img = await _decode(path);
      _cache[path] = img;
      if (sprites.contains(path)) {
        _content[path] = await _computeContentRect(img);
      }
    }
    // Warm widget-level image cache for full-screen backgrounds.
    if (context.mounted) {
      for (final p in [A.menuBg, A.loadingHor, A.loadingVert, A.logo]) {
        await precacheImage(AssetImage(p), context);
      }
    }
    _loaded = true;
  }
}
