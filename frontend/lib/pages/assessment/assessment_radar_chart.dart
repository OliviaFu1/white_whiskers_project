import 'dart:math';
import 'package:flutter/material.dart';

class AssessmentRadarChart extends StatelessWidget {
  final List<double> scores; // length = 7
  final List<String> labels;
  final double size;
  final ImageProvider? centerImage;

  const AssessmentRadarChart({
    super.key,
    required this.scores,
    required this.labels,
    this.size = 260,
    this.centerImage,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          scores: scores,
          labels: labels,
          centerImage: centerImage,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> scores;
  final List<String> labels;
  final ImageProvider? centerImage;

  _RadarPainter({
    required this.scores,
    required this.labels,
    this.centerImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;
    final angleStep = 2 * pi / scores.length;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // rings
    ringPaint.color = const Color(0xFFE38B8B); // red (1–3)
    canvas.drawCircle(center, radius * 0.33, ringPaint);

    ringPaint.color = const Color(0xFFA67C52); // brown (4–6)
    canvas.drawCircle(center, radius * 0.66, ringPaint);

    ringPaint.color = const Color(0xFF7FB77E); // green (7–10)
    canvas.drawCircle(center, radius, ringPaint);

    // axis lines
    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    for (int i = 0; i < scores.length; i++) {
      final angle = -pi / 2 + i * angleStep;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    final path = Path();

    final pointPaint = Paint()..color = const Color(0xFF9C948C);
    final polygonPoints = <Offset>[];

    for (int i = 0; i < scores.length; i++) {
      final score = scores[i].clamp(1, 10).toDouble();
      final normalized = score / 10.0;
      final r = radius * normalized;

      final angle = -pi / 2 + i * angleStep;

      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);

      final point = Offset(x, y);
      polygonPoints.add(point);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(point, 3, pointPaint);
    }

    path.close();

    final polygonFill = Paint()
      ..color = const Color(0x269C948C)
      ..style = PaintingStyle.fill;

    final polygonStroke = Paint()
      ..color = const Color(0xFF9C948C)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, polygonFill);
    canvas.drawPath(path, polygonStroke);

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // labels
    for (int i = 0; i < labels.length; i++) {
      final angle = -pi / 2 + i * angleStep;
      final labelRadius = radius + 28;

      final x = center.dx + labelRadius * cos(angle);
      final y = center.dy + labelRadius * sin(angle);

      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x - textPainter.width / 2,
          y - textPainter.height / 2,
        ),
      );
    }

    // score numbers beside dots
    for (int i = 0; i < polygonPoints.length; i++) {
      final point = polygonPoints[i];
      final score = scores[i].clamp(1, 10);

      final angle = -pi / 2 + i * angleStep;

      const offsetDist = 14.0;
      final sx = point.dx + offsetDist * cos(angle);
      final sy = point.dy + offsetDist * sin(angle);

      textPainter.text = TextSpan(
        text: score.toInt().toString(),
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF8B6B4A),
          fontWeight: FontWeight.w700,
        ),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          sx - textPainter.width / 2,
          sy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}