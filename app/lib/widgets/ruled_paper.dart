import 'package:flutter/material.dart';

enum PaperStyle { plain, lined, dotted, grid }

class RuledPaper extends StatelessWidget {
  final Widget child;
  final Color lineColor;
  final double spacing;
  final PaperStyle style;

  const RuledPaper({
    super.key,
    required this.child,
    required this.lineColor,
    this.spacing = 30.0,
    this.style = PaperStyle.lined,
  });

  @override
  Widget build(BuildContext context) {
    if (style == PaperStyle.plain) return child;

    // Stack(expand) gives TIGHT constraints to both children:
    // - CustomPaint (no child) fills the full viewport and paints lines across it
    // - child (SingleChildScrollView) also fills the full viewport and scrolls on top
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _PaperPainter(
                style: style, color: lineColor, spacing: spacing),
          ),
        ),
        child,
      ],
    );
  }
}

class _PaperPainter extends CustomPainter {
  final PaperStyle style;
  final Color color;
  final double spacing;

  const _PaperPainter(
      {required this.style, required this.color, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;

    switch (style) {
      case PaperStyle.lined:
        for (var y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case PaperStyle.dotted:
        final dot = Paint()..color = color;
        for (var y = spacing; y < size.height; y += spacing) {
          for (var x = spacing; x < size.width; x += spacing) {
            canvas.drawCircle(Offset(x, y), 1.3, dot);
          }
        }
      case PaperStyle.grid:
        for (var y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        for (var x = spacing; x < size.width; x += spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
      case PaperStyle.plain:
        break;
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.style != style || old.color != color || old.spacing != spacing;
}
