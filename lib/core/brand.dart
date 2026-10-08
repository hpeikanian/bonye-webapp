import 'package:flutter/material.dart';

/// Vector rendering of the logo supplied by the brand owner.
class BonyeLogo extends StatelessWidget {
  final double size;
  const BonyeLogo({super.key, this.size = 36});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'bonYe!',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _LogoPainter()),
        ),
      );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 373, size.height / 363);
    final green = Paint()..color = const Color(0xFF6B826F);
    final cream = Paint()..color = const Color(0xFFE8D8C7);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 373, 363), green);
    for (final x in [98.0, 262.0]) {
      for (final y in [95.0, 257.0]) {
        canvas.drawCircle(Offset(x, y), 75, cream);
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y),
              width: y == 95 ? 46 : 72,
              height: y == 95 ? 136 : 72),
          green,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => false;
}

/// The original logotype artwork can replace this typographic lockup without
/// changing layouts. The brand symbol remains vector-based.
class BrandLockup extends StatelessWidget {
  final bool light;
  final double symbolSize;
  const BrandLockup({super.key, this.light = false, this.symbolSize = 76});
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BonyeLogo(size: symbolSize),
          const SizedBox(height: 12),
          Text('bonYe!',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontFamily: 'Cormorant',
                  fontSize: symbolSize * .62,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                  color: light
                      ? const Color(0xFFE8D8C7)
                      : const Color(0xFF3F5544))),
          const SizedBox(height: 8),
          Text('P E T   F O O D',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: light
                      ? const Color(0xFFE8D8C7)
                      : const Color(0xFF627365))),
        ],
      );
}
