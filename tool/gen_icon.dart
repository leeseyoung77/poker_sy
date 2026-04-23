import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Generates an Android launcher icon: three fanned spade cards (10-J-Q) on
/// a dark gradient, inspired by a poker hand. Writes PNGs for every mipmap
/// density Android needs.
Future<void> main() async {
  const outBase = 'android/app/src/main/res';
  const sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  final master = _renderIcon(1024);
  stdout.writeln('Rendered master 1024×1024');

  for (final e in sizes.entries) {
    final resized = img.copyResize(
      master,
      width: e.value,
      height: e.value,
      interpolation: img.Interpolation.cubic,
    );
    final dir = Directory('$outBase/mipmap-${e.key}');
    dir.createSync(recursive: true);
    final file = File('${dir.path}/ic_launcher.png');
    file.writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('✓ ${file.path} — ${e.value}px');
  }
  stdout.writeln('Done.');
}

img.Image _renderIcon(int size) {
  final im = img.Image(width: size, height: size, numChannels: 4);
  _paintBackground(im, size);
  _paintGlow(im, size / 2, size * 0.38, size * 0.55, [80, 150, 255], 55);

  final cardW = (size * 0.42).toInt();
  final cardH = (cardW * 1.45).toInt();

  // Three cards fan out from a lower pivot.
  final cards = [
    _buildCard(cardW, cardH, 'Q'),
    _buildCard(cardW, cardH, 'J'),
    _buildCard(cardW, cardH, '10'),
  ];
  final angles = [-22.0, 0.0, 22.0];
  final centers = <List<double>>[
    [size * 0.33, size * 0.55],
    [size * 0.50, size * 0.48],
    [size * 0.67, size * 0.55],
  ];

  for (var i = 0; i < cards.length; i++) {
    _placeCard(im, cards[i], centers[i][0], centers[i][1], angles[i]);
  }

  _paintVignette(im, size);
  return im;
}

void _paintBackground(img.Image im, int size) {
  const top = [10, 14, 22];
  const mid = [6, 20, 34];
  const bot = [2, 4, 10];
  for (var y = 0; y < size; y++) {
    final t = y / (size - 1);
    List<int> c;
    if (t < 0.5) {
      c = _lerp(top, mid, t / 0.5);
    } else {
      c = _lerp(mid, bot, (t - 0.5) / 0.5);
    }
    for (var x = 0; x < size; x++) {
      im.setPixelRgba(x, y, c[0], c[1], c[2], 255);
    }
  }
}

void _paintGlow(
  img.Image im,
  double cx,
  double cy,
  double radius,
  List<int> color,
  int maxAlpha,
) {
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final r = math.sqrt(dx * dx + dy * dy);
      if (r < radius) {
        final a = ((1 - r / radius) * maxAlpha).toInt().clamp(0, 255);
        final px = im.getPixel(x, y);
        final nr = ((px.r * (255 - a) + color[0] * a) / 255).toInt();
        final ng = ((px.g * (255 - a) + color[1] * a) / 255).toInt();
        final nb = ((px.b * (255 - a) + color[2] * a) / 255).toInt();
        im.setPixelRgba(x, y, nr, ng, nb, 255);
      }
    }
  }
}

img.Image _buildCard(int w, int h, String rank) {
  final card = img.Image(width: w, height: h, numChannels: 4);
  // Rounded rectangle white surface with subtle bevel.
  _fillRoundedRect(
    card,
    0,
    0,
    w,
    h,
    (w * 0.10).round(),
    [246, 246, 242],
  );
  _strokeRoundedRect(
    card,
    0,
    0,
    w,
    h,
    (w * 0.10).round(),
    [190, 190, 180],
    2,
  );

  const black = [22, 22, 22];

  // Top-left rank + tiny spade.
  img.drawString(
    card,
    rank,
    font: img.arial48,
    x: (w * 0.07).round(),
    y: (h * 0.04).round(),
    color: img.ColorRgba8(black[0], black[1], black[2], 255),
  );
  _paintSpade(card, w * 0.13, h * 0.22, w * 0.08, black);

  // Bottom-right mirrored (flipped).
  _paintSpade(card, w - w * 0.13, h - h * 0.22, w * 0.08, black);

  // Large central spade.
  _paintSpade(card, w / 2, h / 2 + h * 0.05, w * 0.28, black);

  return card;
}

void _placeCard(
  img.Image dst,
  img.Image card,
  double centerX,
  double centerY,
  double angleDeg,
) {
  // Shadow layer: a dark-tinted silhouette of the card, slightly blurred.
  final shadow = img.Image.from(card);
  for (var y = 0; y < shadow.height; y++) {
    for (var x = 0; x < shadow.width; x++) {
      final p = shadow.getPixel(x, y);
      if (p.a > 0) {
        shadow.setPixelRgba(x, y, 0, 0, 0, (p.a * 0.55).toInt());
      }
    }
  }
  final shadowRot = img.copyRotate(
    shadow,
    angle: angleDeg,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    dst,
    shadowRot,
    dstX: (centerX - shadowRot.width / 2 + 6).round(),
    dstY: (centerY - shadowRot.height / 2 + 12).round(),
  );

  final rotated = img.copyRotate(
    card,
    angle: angleDeg,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    dst,
    rotated,
    dstX: (centerX - rotated.width / 2).round(),
    dstY: (centerY - rotated.height / 2).round(),
  );
}

void _fillRoundedRect(
  img.Image im,
  int x,
  int y,
  int w,
  int h,
  int r,
  List<int> color,
) {
  for (var py = 0; py < h; py++) {
    for (var px = 0; px < w; px++) {
      if (_insideRounded(px, py, w, h, r)) {
        im.setPixelRgba(x + px, y + py, color[0], color[1], color[2], 255);
      }
    }
  }
}

void _strokeRoundedRect(
  img.Image im,
  int x,
  int y,
  int w,
  int h,
  int r,
  List<int> color,
  int thickness,
) {
  for (var py = 0; py < h; py++) {
    for (var px = 0; px < w; px++) {
      final inside = _insideRounded(px, py, w, h, r);
      final insideInner =
          _insideRounded(px, py, w, h, r - thickness, inset: thickness);
      if (inside && !insideInner) {
        im.setPixelRgba(x + px, y + py, color[0], color[1], color[2], 255);
      }
    }
  }
}

bool _insideRounded(int px, int py, int w, int h, int r, {int inset = 0}) {
  if (r <= 0) {
    return px >= inset &&
        py >= inset &&
        px < w - inset &&
        py < h - inset;
  }
  final left = inset;
  final top = inset;
  final right = w - inset - 1;
  final bottom = h - inset - 1;
  if (px < left || px > right || py < top || py > bottom) return false;
  int cx, cy;
  if (px < left + r && py < top + r) {
    cx = left + r;
    cy = top + r;
  } else if (px > right - r && py < top + r) {
    cx = right - r;
    cy = top + r;
  } else if (px < left + r && py > bottom - r) {
    cx = left + r;
    cy = bottom - r;
  } else if (px > right - r && py > bottom - r) {
    cx = right - r;
    cy = bottom - r;
  } else {
    return true;
  }
  final dx = px - cx;
  final dy = py - cy;
  return dx * dx + dy * dy <= r * r;
}

void _paintSpade(img.Image im, double cx, double cy, double scale, List<int> color) {
  final bounds = (scale * 1.5).ceil();
  for (var py = -bounds; py <= (bounds * 1.3).ceil(); py++) {
    for (var px = -bounds; px <= bounds; px++) {
      var hits = 0;
      for (var sy = 0; sy < 3; sy++) {
        for (var sx = 0; sx < 3; sx++) {
          final nx = (px + (sx + 0.5) / 3 - 0.5) / scale;
          final ny = (py + (sy + 0.5) / 3 - 0.5) / scale;
          if (_inSpade(nx, ny)) hits++;
        }
      }
      if (hits == 0) continue;
      final x = (cx + px).round();
      final y = (cy + py).round();
      if (x < 0 || y < 0 || x >= im.width || y >= im.height) continue;
      final cover = hits / 9.0;
      final bg = im.getPixel(x, y);
      final a = (cover * 255).toInt();
      im.setPixelRgba(
        x,
        y,
        ((bg.r * (255 - a) + color[0] * a) / 255).toInt(),
        ((bg.g * (255 - a) + color[1] * a) / 255).toInt(),
        ((bg.b * (255 - a) + color[2] * a) / 255).toInt(),
        bg.a.toInt(),
      );
    }
  }
}

bool _inSpade(double x, double y) {
  const lobeR = 0.48;
  const lobeOffsetX = 0.42;
  const lobeOffsetY = -0.35;
  final dLeft = math.sqrt(
      math.pow(x + lobeOffsetX, 2) + math.pow(y - lobeOffsetY, 2));
  final dRight = math.sqrt(
      math.pow(x - lobeOffsetX, 2) + math.pow(y - lobeOffsetY, 2));
  if (dLeft < lobeR || dRight < lobeR) return true;

  if (y > lobeOffsetY && y < 0.85) {
    final t = (y - lobeOffsetY) / (0.85 - lobeOffsetY);
    final xLimit = (1 - t) * 0.88 + t * 0.02;
    if (x.abs() < xLimit) return true;
  }
  if (y >= 0.65 && y <= 1.05) {
    final t = (y - 0.65) / 0.4;
    final xLimit = 0.08 + t * 0.38;
    if (x.abs() < xLimit) return true;
  }
  return false;
}

void _paintVignette(img.Image im, int size) {
  final cx = size / 2;
  final cy = size / 2;
  final maxR = math.sqrt(cx * cx + cy * cy);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final r = math.sqrt(dx * dx + dy * dy);
      final t = (r / maxR).clamp(0.0, 1.0);
      final darken = (math.pow(t, 2.2) * 80).toInt().clamp(0, 255);
      final px = im.getPixel(x, y);
      im.setPixelRgba(
        x,
        y,
        (px.r * (255 - darken) / 255).toInt(),
        (px.g * (255 - darken) / 255).toInt(),
        (px.b * (255 - darken) / 255).toInt(),
        255,
      );
    }
  }
}

List<int> _lerp(List<int> a, List<int> b, double t) {
  return [
    (a[0] + (b[0] - a[0]) * t).round(),
    (a[1] + (b[1] - a[1]) * t).round(),
    (a[2] + (b[2] - a[2]) * t).round(),
  ];
}
