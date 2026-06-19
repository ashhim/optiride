import 'dart:ui';

import 'package:flutter/material.dart';

class SettingsIconButton extends StatelessWidget {
  const SettingsIconButton({
    super.key,
    required this.onPressed,
    this.opacity = 0.65,
  });

  final VoidCallback onPressed;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final alpha = opacity.clamp(0.05, 1.0).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.10 + (0.18 * alpha)),
              border: Border.all(
                color: const Color(0xFF1DE9B6).withValues(alpha: 0.22 + (0.28 * alpha)),
                width: 1.2,
              ),
            ),
            child: Icon(
              Icons.settings_rounded,
              size: 22,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }
}