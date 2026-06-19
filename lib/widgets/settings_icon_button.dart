import 'package:flutter/material.dart';

class SettingsIconButton extends StatelessWidget {
  const SettingsIconButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF0D1624),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0x2236E6C5)),
      ),
    );
  }
}
