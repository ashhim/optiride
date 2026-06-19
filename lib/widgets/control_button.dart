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
  });

  final IconData icon;
  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final Color accent;
  final bool danger;
  final bool compact;

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.danger
        ? const Color(0xFF8C1D2D)
        : _pressed
            ? widget.accent.withValues(alpha: 0.22)
            : const Color(0xFF0C1522);
    final border = _pressed
        ? widget.accent.withValues(alpha: 0.95)
        : widget.accent.withValues(alpha: 0.35);

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        width: widget.compact ? 82 : 104,
        height: widget.compact ? 82 : 104,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: _pressed ? 0.24 : 0.10),
              blurRadius: _pressed ? 24 : 16,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: widget.compact ? 32 : 38, color: Colors.white),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: widget.compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
