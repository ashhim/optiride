import 'package:flutter/material.dart';

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({
    super.key,
    required this.connected,
    required this.checking,
    required this.statusText,
  });

  final bool connected;
  final bool checking;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final color = connected
        ? const Color(0xFF3DFFB6)
        : checking
            ? const Color(0xFFFFD24A)
            : const Color(0xFFFF5267);

    final label = checking ? 'checking' : statusText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC0C1220),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.75), blurRadius: 12)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
