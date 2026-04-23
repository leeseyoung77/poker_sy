import 'dart:io';

import 'package:image/image.dart' as img;

/// Crops `raw_avatars.png` into four individual avatar PNGs and removes the
/// white backdrop so only the character silhouette remains.
///
/// Output order (left → right): 지영 → 수진 → 현우 → 민수.
Future<void> main() async {
  const inputPath = 'raw_avatars.png';
  const outDir = 'assets/images';

  const outputs = <String>[
    'avatar_jiyoung.png', // 1st column
    'avatar_sujin.png',   // 2nd
    'avatar_hyunwoo.png', // 3rd
    'avatar_minsu.png',   // 4th
  ];

  final file = File(inputPath);
  if (!file.existsSync()) {
    stderr.writeln('✗ Input not found: $inputPath');
    exit(1);
  }

  final decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('✗ Failed to decode image.');
    exit(1);
  }

  stdout.writeln('Source: ${decoded.width} × ${decoded.height}');
  final colWidth = decoded.width ~/ 4;

  Directory(outDir).createSync(recursive: true);

  for (var i = 0; i < 4; i++) {
    final slice = img.copyCrop(
      decoded,
      x: i * colWidth,
      y: 0,
      width: colWidth,
      height: decoded.height,
    );
    // Convert to RGBA so we can punch out background to alpha 0.
    final rgba = slice.convert(numChannels: 4);
    _floodFillTransparent(rgba);
    final trimmed = _cropToContent(rgba);
    final outPath = '$outDir/${outputs[i]}';
    File(outPath).writeAsBytesSync(img.encodePng(trimmed));
    stdout.writeln('✓ $outPath — ${trimmed.width}×${trimmed.height}');
  }
  stdout.writeln('Done.');
}

/// Flood-fill starting from image edges; any pixel that is near-white and
/// reachable from the outside becomes fully transparent.
void _floodFillTransparent(img.Image image) {
  final w = image.width;
  final h = image.height;
  final visited = List.generate(h, (_) => List.filled(w, false));
  final stack = <int>[];

  // Encode (x, y) into a single int for a tighter hot loop.
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
  if (maxX < 0) return image; // entirely transparent, return as-is
  final pad = 4;
  final x = (minX - pad).clamp(0, w - 1);
  final y = (minY - pad).clamp(0, h - 1);
  final width = (maxX - minX + pad * 2).clamp(1, w - x);
  final height = (maxY - minY + pad * 2).clamp(1, h - y);
  return img.copyCrop(image, x: x, y: y, width: width, height: height);
}
