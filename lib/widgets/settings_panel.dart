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
    required this.onCalibrateGyro,
    required this.singleJoystickMode,
    required this.onSingleJoystickModeChanged,
    required this.buttonScale,
    required this.onButtonScaleChanged,
    required this.buttonOpacity,
    required this.onButtonOpacityChanged,
    required this.edgeInset,
    required this.onEdgeInsetChanged,
    required this.bottomOffset,
    required this.onBottomOffsetChanged,
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
  final VoidCallback onCalibrateGyro;
  final bool singleJoystickMode;
  final ValueChanged<bool> onSingleJoystickModeChanged;
  final double buttonScale;
  final ValueChanged<double> onButtonScaleChanged;
  final double buttonOpacity;
  final ValueChanged<double> onButtonOpacityChanged;
  final double edgeInset;
  final ValueChanged<double> onEdgeInsetChanged;
  final double bottomOffset;
  final ValueChanged<double> onBottomOffsetChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xEE09111D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x2236E6C5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 28,
              offset: Offset(0, -8),
            ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          connected
                              ? const Color(0x223DFFB6)
                              : const Color(0x22FF5267),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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
                subtitle: const Text('Steering only'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onCalibrateGyro,
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('CALIBRATE GYRO'),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: singleJoystickMode,
                onChanged: onSingleJoystickModeChanged,
                title: const Text('Single joystick mode'),
                subtitle: const Text('Hide separate directional buttons'),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Button scale')),
                  Text(buttonScale.toStringAsFixed(2)),
                ],
              ),
              Slider(
                value: buttonScale,
                min: 0.75,
                max: 1.35,
                onChanged: onButtonScaleChanged,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Button transparency')),
                  Text(buttonOpacity.toStringAsFixed(2)),
                ],
              ),
              Slider(
                value: buttonOpacity,
                min: 0.35,
                max: 1.0,
                onChanged: onButtonOpacityChanged,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Edge inset')),
                  Text(edgeInset.toStringAsFixed(0)),
                ],
              ),
              Slider(
                value: edgeInset,
                min: 0,
                max: 48,
                onChanged: onEdgeInsetChanged,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Vertical offset')),
                  Text(bottomOffset.toStringAsFixed(0)),
                ],
              ),
              Slider(
                value: bottomOffset,
                min: -36,
                max: 86,
                onChanged: onBottomOffsetChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
