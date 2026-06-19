import 'dart:ui';

import 'package:flutter/material.dart';

class ControlButton extends StatefulWidget {
  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onDown,
    required this.onUp,
    this.accent = const Color(0xFF1DE9B6),
    this.danger = false,
    this.compact = false,
    this.width,
    this.height,
    this.iconSize,
    this.labelSize,
    this.circular = false,
    this.showLabel = true,
    this.opacity = 0.78,
  });

  final IconData icon;
  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final Color accent;
  final bool danger;
  final bool compact;
  final double? width;
  final double? height;
  final double? iconSize;
  final double? labelSize;
  final bool circular;
  final bool showLabel;
  final double opacity;

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  double get _opacity => widget.opacity.clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final bg = widget.danger
        ? const Color(0xFF8C1D2D).withValues(alpha: 0.18 + (0.58 * _opacity))
        : _pressed
            ? widget.accent.withValues(alpha: 0.10 + (0.22 * _opacity))
            : const Color(0xFF0C1522).withValues(alpha: 0.12 + (0.58 * _opacity));
    final border = _pressed
        ? widget.accent.withValues(alpha: 0.44 + (0.52 * _opacity))
        : widget.accent.withValues(alpha: 0.18 + (0.32 * _opacity));
    final radius = BorderRadius.circular(widget.circular ? 999 : 24);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        _setPressed(true);
        widget.onDown();
      },
      onPointerUp: (_) {
        _setPressed(false);
        widget.onUp();
      },
      onPointerCancel: (_) {
        _setPressed(false);
        widget.onUp();
      },
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            width: widget.width ?? (widget.compact ? 72 : 100),
            height: widget.height ?? (widget.compact ? 72 : 100),
            transformAlignment: Alignment.center,
            transform: Matrix4.identity()..scale(_pressed ? 0.94 : 1.0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: Border.all(color: border, width: 1.2),
              gradient: widget.circular
                  ? RadialGradient(
                      colors: [
                        widget.danger
                            ? const Color(0xFFE22C45).withValues(alpha: 0.20 + (0.28 * _opacity))
                            : widget.accent.withValues(alpha: _pressed ? 0.32 : 0.18),
                        bg,
                        const Color(0x33000000),
                      ],
                      stops: const [0.0, 0.62, 1.0],
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: (_pressed ? 0.24 : 0.10) * _opacity),
                  blurRadius: _pressed ? 24 : 16,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: CustomPaint(
              foregroundPainter: widget.circular
                  ? _ControlButtonRingPainter(
                      color: widget.danger ? const Color(0xFFFF5267) : widget.accent,
                      pressed: _pressed,
                      opacity: _opacity,
                    )
                  : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: widget.iconSize ?? (widget.compact ? 28 : 36),
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: (widget.danger ? const Color(0xFFFF5267) : widget.accent)
                            .withValues(alpha: 0.30 + (0.40 * _opacity)),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  if (widget.showLabel) ...[
                    SizedBox(height: widget.compact ? 4 : 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: widget.labelSize ?? (widget.compact ? 10 : 12),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButtonRingPainter extends CustomPainter {
  const _ControlButtonRingPainter({
    required this.color,
    required this.pressed,
    required this.opacity,
  });

  final Color color;
  final bool pressed;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = pressed ? 7 : 5
      ..color = color.withValues(alpha: (pressed ? 0.34 : 0.22) * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: (pressed ? 0.90 : 0.62) * opacity);
    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: (pressed ? 0.88 : 0.58) * opacity);

    canvas.drawCircle(center, radius - 5, glow);
    canvas.drawCircle(center, radius - 5, ring);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      -1.65,
      1.12,
      false,
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _ControlButtonRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.pressed != pressed ||
        oldDelegate.opacity != opacity;
  }
}
