import 'package:flutter/material.dart';

/// 极简迷你折线图，用于在标题旁展示速率趋势
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double width;
  final double height;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.width = 56,
    this.height = 18,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);

    final path = Path();
    final stepX = size.width / (values.length - 1);
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final norm = (values[i] - minV) / range;
      final y = size.height - norm * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()..color = color.withOpacity(0.12);
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
