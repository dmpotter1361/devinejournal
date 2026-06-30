import 'package:flutter/material.dart';

class RuledPaper extends StatelessWidget {
  final Widget child;
  final Color lineColor;
  final double spacing;

  const RuledPaper({
    super.key,
    required this.child,
    required this.lineColor,
    this.spacing = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LinePainter(lineColor, spacing),
      child: child,
    );
  }
}

class _LinePainter extends CustomPainter {
  final Color color;
  final double spacing;
  _LinePainter(this.color, this.spacing);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    var y = spacing;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += spacing;
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.color != color || old.spacing != spacing;
}
