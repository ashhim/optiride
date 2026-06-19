import 'dart:ui';

import 'package:flutter/material.dart';

class ControlButton extends StatefulWidget {
  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onDown,
    required this.onUp,
    this.width = 68,
    this.height = 68,
    this.iconSize = 32,
    this.circular = true,
    this.showLabel = false,
    this.danger = false,
    this.compact = false,
    this.opacity = 0.55,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onDown;
  final Future<void> Function() onUp;
  final double width;
  final double height;
  final double iconSize;
  final bool circular;
  final bool showLabel;
  final bool danger;
  final bool compact;
  final double opacity;

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  bool _pressed = false;

  Future<void> _handleDown() async {
    if (_pressed) return;
    setState(() => _pressed = true);
    await widget.onDown();
  }

  Future<void> _handleUp() async {
    if (!_pressed) return;
    setState(() => _pressed = false);
    await widget.onUp();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.danger ? const Color(0xFFDA4453) : const Color(0xFF1DE9B6);

    final alpha = widget.opacity.clamp(0.05, 1.0).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _handleDown(),
      onTapUp: (_) => _handleUp(),
      onTapCancel: _handleUp,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.circular ? 999 : 18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget.circular ? null : BorderRadius.circular(18),
              color: Colors.black.withValues(alpha: 0.10 + (0.18 * alpha)),
              border: Border.all(
                color: baseColor.withValues(alpha: 0.24 + (0.40 * alpha)),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: _pressed ? 0.40 : 0.18),
                  blurRadius: _pressed ? 20 : 14,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape:
                          widget.circular
                              ? BoxShape.circle
                              : BoxShape.rectangle,
                      borderRadius:
                          widget.circular ? null : BorderRadius.circular(18),
                      gradient: RadialGradient(
                        colors: [
                          baseColor.withValues(alpha: _pressed ? 0.34 : 0.18),
                          Colors.transparent,
                        ],
                        stops: const [0, 1],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    widget.icon,
                    size: widget.iconSize,
                    color: Colors.white.withValues(alpha: 0.96),
                  ),
                ),
                if (widget.showLabel)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
