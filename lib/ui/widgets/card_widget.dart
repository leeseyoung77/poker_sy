import 'package:flutter/material.dart';

import '../../models/card.dart';
import '../theme.dart';

class CardWidget extends StatelessWidget {
  final PlayingCard? card;
  final bool faceDown;
  final double width;
  final bool highlighted;

  const CardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.width = 56,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 1.45;
    if (card == null || faceDown) {
      return _CardBack(width: width, height: height);
    }

    final c = card!;
    final color = c.suit.isRed ? AppColors.cardRed : AppColors.cardBlack;
    final rankFont = width * 0.34;
    final miniSuitFont = width * 0.28;
    final bigSuitFont = width * 0.62;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardSurface, AppColors.cardSurfaceEdge],
        ),
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(
          color: highlighted ? AppColors.highlight : const Color(0x22000000),
          width: highlighted ? 2.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          // Top-left: rank above a mini suit (same color).
          Positioned(
            top: height * 0.04,
            left: width * 0.08,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.rank.label,
                  style: TextStyle(
                    color: color,
                    fontSize: rankFont,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: height * 0.01),
                Text(
                  c.suit.symbol,
                  style: TextStyle(
                    color: color,
                    fontSize: miniSuitFont,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          // Bottom-right: large suit symbol.
          Positioned(
            bottom: height * 0.04,
            right: width * 0.08,
            child: Text(
              c.suit.symbol,
              style: TextStyle(
                color: color,
                fontSize: bigSuitFont,
                height: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final double width;
  final double height;
  const _CardBack({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(color: AppColors.borderStrong, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.12),
        child: CustomPaint(
          painter: _CardBackPainter(),
          size: Size(width, height),
        ),
      ),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.cardBackTop, AppColors.cardBackBottom],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Subtle dot grid
    final dot = Paint()..color = AppColors.accent.withAlpha(70);
    const step = 8.0;
    for (var y = 6.0; y < size.height; y += step) {
      for (var x = 6.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.9, dot);
      }
    }

    // Inner border
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.accent.withAlpha(160);
    final insetRect = Rect.fromLTRB(3, 3, size.width - 3, size.height - 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(insetRect, const Radius.circular(4)),
      inner,
    );
  }

  @override
  bool shouldRepaint(covariant _CardBackPainter oldDelegate) => false;
}
