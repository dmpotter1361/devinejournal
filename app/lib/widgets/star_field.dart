import 'dart:math';
import 'package:flutter/material.dart';

class StarField extends StatelessWidget {
  final Widget child;
  final Color starColor;
  final int count;

  const StarField({
    super.key,
    required this.child,
    this.starColor = Colors.white,
    this.count = 160,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _StarPainter(starColor, count)),
        child,
      ],
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color color;
  final int count;
  _StarPainter(this.color, this.count);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(0xC0FFEE);
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.4 + 0.2;
      final a = rng.nextDouble() * 0.7 + 0.2;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = color.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}
