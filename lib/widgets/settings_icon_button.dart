import 'package:flutter/material.dart';

class SettingsIconButton extends StatelessWidget {
  const SettingsIconButton({
    super.key,
    required this.onPressed,
    this.opacity = 0.78,
  });

  final VoidCallback onPressed;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final normalizedOpacity = opacity.clamp(0.0, 1.0).toDouble();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x7A0D1624).withValues(alpha: 0.12 + (0.66 * normalizedOpacity)),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x2236E6C5).withValues(alpha: 0.20 + (0.36 * normalizedOpacity))),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.settings_outlined),
        tooltip: 'Settings',
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
