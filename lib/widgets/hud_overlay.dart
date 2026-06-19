import 'package:flutter/material.dart';

import '../controllers/connection_controller.dart';
import '../controllers/gyro_controller.dart';
import '../controllers/light_controller.dart';
import 'connection_badge.dart';

class HudOverlay extends StatelessWidget {
  const HudOverlay({
    super.key,
    required this.connection,
    required this.lightController,
    required this.gyroController,
    required this.ipController,
    required this.onConnect,
    required this.onStop,
    required this.onGyroToggle,
    required this.onLightToggle,
    required this.onCalibrateGyro,
    required this.onSensitivityChanged,
  });

  final ConnectionController connection;
  final LightController lightController;
  final GyroController gyroController;
  final TextEditingController ipController;
  final VoidCallback onConnect;
  final VoidCallback onStop;
  final VoidCallback onGyroToggle;
  final VoidCallback onLightToggle;
  final VoidCallback onCalibrateGyro;
  final ValueChanged<double> onSensitivityChanged;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;
    final listenable = Listenable.merge([connection, lightController, gyroController]);

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        return IgnorePointer(
          ignoring: false,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopRow(
                    connection: connection,
                    ipController: ipController,
                    onConnect: onConnect,
                  ),
                  const Spacer(),
                  Align(
                    alignment: isCompact ? Alignment.bottomCenter : Alignment.bottomRight,
                    child: _ActionTray(
                      lightController: lightController,
                      gyroController: gyroController,
                      onStop: onStop,
                      onGyroToggle: onGyroToggle,
                      onLightToggle: onLightToggle,
                      onCalibrateGyro: onCalibrateGyro,
                      onSensitivityChanged: onSensitivityChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.connection,
    required this.ipController,
    required this.onConnect,
  });

  final ConnectionController connection;
  final TextEditingController ipController;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 760;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xCC09111D),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x2236E6C5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: ipController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onConnect(),
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'ESP32 IP address',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ConnectionBadge(
                      connected: connection.connected,
                      checking: connection.checking,
                      statusText: connection.statusText,
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: onConnect,
                      child: const Text('CONNECT'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const _Brand(),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xCC09111D),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x2236E6C5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ipController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onConnect(),
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'ESP32 IP address',
                      isDense: true,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ConnectionBadge(
                  connected: connection.connected,
                  checking: connection.checking,
                  statusText: connection.statusText,
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: onConnect,
                  child: const Text('CONNECT'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E1524), Color(0xFF07101B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x2236E6C5)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1DE9B6).withValues(alpha: 0.12), blurRadius: 24),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPTIRIDE',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Controller',
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTray extends StatelessWidget {
  const _ActionTray({
    required this.lightController,
    required this.gyroController,
    required this.onStop,
    required this.onGyroToggle,
    required this.onLightToggle,
    required this.onCalibrateGyro,
    required this.onSensitivityChanged,
  });

  final LightController lightController;
  final GyroController gyroController;
  final VoidCallback onStop;
  final VoidCallback onGyroToggle;
  final VoidCallback onLightToggle;
  final VoidCallback onCalibrateGyro;
  final ValueChanged<double> onSensitivityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width < 900 ? double.infinity : 430,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC09111D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x2236E6C5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _ToggleChip(
                label: gyroController.enabled ? 'GYRO ON' : 'GYRO OFF',
                active: gyroController.enabled,
                onTap: onGyroToggle,
              ),
              _ToggleChip(
                label: lightController.lightOn ? 'LIGHT ON' : 'LIGHT OFF',
                active: lightController.lightOn,
                onTap: onLightToggle,
              ),
              _DangerChip(label: 'EMERGENCY STOP', onTap: onStop),
              _ToggleChip(
                label: 'CALIBRATE',
                active: false,
                onTap: onCalibrateGyro,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Gyro sensitivity', style: TextStyle(color: Colors.white70)),
              const Spacer(),
              Text(
                gyroController.sensitivity.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: gyroController.sensitivity,
            min: 0.7,
            max: 2.0,
            onChanged: onSensitivityChanged,
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = active ? const Color(0xFF1DE9B6) : const Color(0xFF203042);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: accent.withValues(alpha: 0.7)),
        backgroundColor: active ? const Color(0x221DE9B6) : const Color(0xFF0E1623),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Text(label),
    );
  }
}

class _DangerChip extends StatelessWidget {
  const _DangerChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFB81E33),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(label),
    );
  }
}
