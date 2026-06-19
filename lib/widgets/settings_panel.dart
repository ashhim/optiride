import 'package:flutter/material.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.ipController,
    required this.connected,
    required this.statusText,
    required this.onConnect,
    required this.gyroEnabled,
    required this.onGyroChanged,
    required this.gyroSensitivity,
    required this.onSensitivityChanged,
    required this.gyroDeadZone,
    required this.onDeadZoneChanged,
  });

  final TextEditingController ipController;
  final bool connected;
  final String statusText;
  final VoidCallback onConnect;
  final bool gyroEnabled;
  final ValueChanged<bool> onGyroChanged;
  final double gyroSensitivity;
  final ValueChanged<double> onSensitivityChanged;
  final double gyroDeadZone;
  final ValueChanged<double> onDeadZoneChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xF0121725),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x2236E6C5)),
          boxShadow: const [
            BoxShadow(color: Color(0x80000000), blurRadius: 28, offset: Offset(0, -8)),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'SETTINGS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: connected ? const Color(0x223DFFB6) : const Color(0x22FF5267),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ipController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ESP32 IP address',
                  hintText: '192.168.1.120',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('CONNECT'),
              ),
              const SizedBox(height: 18),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: gyroEnabled,
                onChanged: onGyroChanged,
                title: const Text('Gyro control'),
                subtitle: const Text('Tilt to drive and steer'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Sensitivity')),
                  Text(gyroSensitivity.toStringAsFixed(2)),
                ],
              ),
              Slider(
                value: gyroSensitivity,
                min: 0.7,
                max: 2.0,
                onChanged: onSensitivityChanged,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Dead zone')),
                  Text(gyroDeadZone.toStringAsFixed(2)),
                ],
              ),
              Slider(
                value: gyroDeadZone,
                min: 0.05,
                max: 0.35,
                onChanged: onDeadZoneChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
