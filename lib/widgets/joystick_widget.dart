import 'dart:math' as math;

import 'package:flutter/material.dart';

class JoystickWidget extends StatefulWidget {
  const JoystickWidget({
    super.key,
    required this.onChanged,
    required this.onReleased,
    this.size = 220,
  });

  final ValueChanged<Offset> onChanged;
  final VoidCallback onReleased;
  final double size;

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  Offset _normalized = Offset.zero;
  bool _dragging = false;

  void _update(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 18;
    final delta = localPosition - center;
    final clamped = Offset(
      delta.dx.clamp(-radius, radius).toDouble(),
      delta.dy.clamp(-radius, radius).toDouble(),
    );
    final normalized = Offset(clamped.dx / radius, -clamped.dy / radius);

    setState(() {
      _dragging = true;
      _normalized = normalized;
    });
    widget.onChanged(normalized);
  }

  void _release() {
    setState(() {
      _dragging = false;
      _normalized = Offset.zero;
    });
    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(widget.size, math.min(constraints.maxWidth, constraints.maxHeight));
        final knobRadius = side * 0.18;
        final radius = side / 2 - knobRadius - 14;
        final knobOffset = Offset(
          _normalized.dx * radius,
          -_normalized.dy * radius,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) => _update(details.localPosition, Size(side, side)),
          onPanUpdate: (details) => _update(details.localPosition, Size(side, side)),
          onPanEnd: (_) => _release(),
          onPanCancel: _release,
          child: SizedBox(
            width: side,
            height: side,
            child: CustomPaint(
              painter: _JoystickPainter(
                knobOffset: knobOffset,
                knobRadius: knobRadius,
                dragging: _dragging,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knobOffset,
    required this.knobRadius,
    required this.dragging,
  });

  final Offset knobOffset;
  final double knobRadius;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final basePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF112033), Color(0xFF081018)],
        stops: [0, 1],
      ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0x5536E6C5);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x2236E6C5);

    canvas.drawCircle(center, size.width / 2, basePaint);
    canvas.drawCircle(center, size.width / 2 - 2, ringPaint);
    canvas.drawLine(Offset(center.dx - size.width * 0.34, center.dy), Offset(center.dx + size.width * 0.34, center.dy), linePaint);
    canvas.drawLine(Offset(center.dx, center.dy - size.height * 0.34), Offset(center.dx, center.dy + size.height * 0.34), linePaint);

    final knobCenter = center + knobOffset;
    final glowPaint = Paint()
      ..color = const Color(0xFF1DE9B6).withValues(alpha: dragging ? 0.30 : 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(knobCenter, knobRadius * 1.45, glowPaint);

    final knobPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3DFFB6).withValues(alpha: 0.95),
          const Color(0xFF15B7FF).withValues(alpha: 0.85),
        ],
        stops: const [0, 1],
      ).createShader(Rect.fromCircle(center: knobCenter, radius: knobRadius));
    canvas.drawCircle(knobCenter, knobRadius, knobPaint);

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xBBFFFFFF);
    canvas.drawCircle(knobCenter, knobRadius * 0.72, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return oldDelegate.knobOffset != knobOffset ||
        oldDelegate.knobRadius != knobRadius ||
        oldDelegate.dragging != dragging;
  }
}
