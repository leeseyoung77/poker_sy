import 'dart:io';

import 'package:image/image.dart' as img;

/// Extracts the foreground character from each source PNG by flood-filling
/// near-white background from the edges, then trims to content.
///
/// Source → destination mapping:
///   sy.png  → assets/images/avatar_jiyoung.png   (세롱)
///   yy.png  → assets/images/avatar_minsu.png     (용이)
///   ch.png  → assets/images/avatar_hyunwoo.png   (창호)
Future<void> main() async {
  const jobs = {
    'sy2.png': 'assets/images/avatar_jiyoung.png',
    'yy2.png': 'assets/images/avatar_minsu.png',
  };

  for (final e in jobs.entries) {
    final src = File(e.key);
    if (!src.existsSync()) {
      stderr.writeln('✗ missing ${e.key}');
      continue;
    }
    final decoded = img.decodeImage(src.readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('✗ decode failed ${e.key}');
      continue;
    }
    final rgba = decoded.convert(numChannels: 4);
    _floodFillTransparent(rgba);
    final trimmed = _cropToContent(rgba);
    File(e.value).writeAsBytesSync(img.encodePng(trimmed));
    stdout.writeln(
        '✓ ${e.key} (${decoded.width}×${decoded.height}) → ${e.value} (${trimmed.width}×${trimmed.height})');
  }
}

/// Flood-fill from every edge pixel; any near-white connected region becomes
/// transparent.
void _floodFillTransparent(img.Image image) {
  final w = image.width;
  final h = image.height;
  final visited = List.generate(h, (_) => List.filled(w, false));
  final stack = <int>[];

  void push(int x, int y) {
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    if (visited[y][x]) return;
    stack.add(y * w + x);
  }

  for (var x = 0; x < w; x++) {
    push(x, 0);
    push(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    push(0, y);
    push(w - 1, y);
  }

  while (stack.isNotEmpty) {
    final code = stack.removeLast();
    final x = code % w;
    final y = code ~/ w;
    if (visited[y][x]) continue;
    visited[y][x] = true;

    final px = image.getPixel(x, y);
    final r = px.r.toInt();
    final g = px.g.toInt();
    final b = px.b.toInt();
    final a = px.a.toInt();

    final isNearWhite = r >= 232 && g >= 232 && b >= 232;
    if (a == 0 || isNearWhite) {
      image.setPixelRgba(x, y, r, g, b, 0);
      push(x + 1, y);
      push(x - 1, y);
      push(x, y + 1);
      push(x, y - 1);
    }
  }
}

/// Trim fully-transparent borders so the subject fills the frame.
img.Image _cropToContent(img.Image image) {
  final w = image.width;
  final h = image.height;
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (image.getPixel(x, y).a.toInt() > 8) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return image;
  const pad = 4;
  final x = (minX - pad).clamp(0, w - 1);
  final y = (minY - pad).clamp(0, h - 1);
  final width = (maxX - minX + pad * 2).clamp(1, w - x);
  final height = (maxY - minY + pad * 2).clamp(1, h - y);
  return img.copyCrop(image, x: x, y: y, width: width, height: height);
}
