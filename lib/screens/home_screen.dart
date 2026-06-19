import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/connection_controller.dart';
import '../controllers/gyro_controller.dart';
import '../controllers/light_controller.dart';
import '../controllers/motion_controller.dart';
import '../services/stream_service.dart';
import '../widgets/camera_view.dart';
import '../widgets/connection_badge.dart';
import '../widgets/control_button.dart';
import '../widgets/settings_icon_button.dart';
import '../widgets/settings_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _ipController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _keysDown = <LogicalKeyboardKey>{};
  bool _listening = false;

  late ConnectionController _connection;
  late MotionController _motion;
  late LightController _light;
  late GyroController _gyro;
  late StreamService _streamService;

  bool _driveForwardHeld = false;
  bool _driveBackwardHeld = false;
  bool _steerLeftHeld = false;
  bool _steerRightHeld = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _connection = context.read<ConnectionController>();
    _motion = context.read<MotionController>();
    _light = context.read<LightController>();
    _gyro = context.read<GyroController>();
    _streamService = context.read<StreamService>();
    if (!_listening) {
      _connection.addListener(_handleConnectionChanged);
      _listening = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_listening) {
      _connection.removeListener(_handleConnectionChanged);
    }
    _ipController.dispose();
    _focusNode.dispose();
    unawaited(_motion.stopAll());
    unawaited(_gyro.setEnabled(false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_motion.stopAll());
    }
  }

  void _handleConnectionChanged() {
    if (_connection.connected && _connection.baseUri != null) {
      _streamService.setBaseUri(_connection.baseUri);
    }
    if (!_connection.connected) {
      unawaited(_motion.stopAll());
    }
    if (_ipController.text != _connection.input) {
      _ipController.text = _connection.input;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _connect() async {
    _connection.setInput(_ipController.text);
    final ok = await _connection.connect();
    if (ok) {
      _streamService.setBaseUri(_connection.baseUri);
    } else {
      setState(() {});
    }
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettingsPanel(
        ipController: _ipController,
        connected: _connection.connected,
        statusText: _connection.statusText,
        onConnect: _connect,
        gyroEnabled: _gyro.enabled,
        onGyroChanged: (value) {
          unawaited(_gyro.setEnabled(value));
          if (value) {
            unawaited(_motion.stopAll());
          }
          if (mounted) setState(() {});
        },
        gyroSensitivity: _gyro.sensitivity,
        onSensitivityChanged: (value) {
          _gyro.setSensitivity(value);
          if (mounted) setState(() {});
        },
        gyroDeadZone: _gyro.deadZone,
        onDeadZoneChanged: (value) {
          _gyro.setDeadZone(value);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _toggleLight() => _light.toggle();

  Future<void> _stopAll() async {
    _driveForwardHeld = false;
    _driveBackwardHeld = false;
    _steerLeftHeld = false;
    _steerRightHeld = false;
    _keysDown.clear();
    await _motion.stopAll();
  }

  Future<void> _applyMotionState() async {
    final forward = _keysDown.contains(LogicalKeyboardKey.arrowUp) ||
        _keysDown.contains(LogicalKeyboardKey.keyW) ||
        _driveForwardHeld;
    final backward = _keysDown.contains(LogicalKeyboardKey.arrowDown) ||
        _keysDown.contains(LogicalKeyboardKey.keyS) ||
        _driveBackwardHeld;
    final left = _keysDown.contains(LogicalKeyboardKey.arrowLeft) ||
        _keysDown.contains(LogicalKeyboardKey.keyA) ||
        _steerLeftHeld;
    final right = _keysDown.contains(LogicalKeyboardKey.arrowRight) ||
        _keysDown.contains(LogicalKeyboardKey.keyD) ||
        _steerRightHeld;

    if (forward && !backward) {
      await _motion.setDrive(DriveDirection.forward);
    } else if (backward && !forward) {
      await _motion.setDrive(DriveDirection.backward);
    } else {
      await _motion.stopDrive();
    }

    if (left && !right) {
      await _motion.setSteer(SteerDirection.left);
    } else if (right && !left) {
      await _motion.setSteer(SteerDirection.right);
    } else {
      await _motion.stopSteer();
    }
  }

  Future<void> _pressDriveForward() async {
    _driveForwardHeld = true;
    await _applyMotionState();
  }

  Future<void> _releaseDriveForward() async {
    _driveForwardHeld = false;
    await _applyMotionState();
  }

  Future<void> _pressDriveBackward() async {
    _driveBackwardHeld = true;
    await _applyMotionState();
  }

  Future<void> _releaseDriveBackward() async {
    _driveBackwardHeld = false;
    await _applyMotionState();
  }

  Future<void> _pressSteerLeft() async {
    _steerLeftHeld = true;
    await _applyMotionState();
  }

  Future<void> _releaseSteerLeft() async {
    _steerLeftHeld = false;
    await _applyMotionState();
  }

  Future<void> _pressSteerRight() async {
    _steerRightHeld = true;
    await _applyMotionState();
  }

  Future<void> _releaseSteerRight() async {
    _steerRightHeld = false;
    await _applyMotionState();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;
    if (!isDown && !isUp) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.space && isDown) {
      unawaited(_stopAll());
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyL && isDown && event is! KeyRepeatEvent) {
      unawaited(_toggleLight());
      return KeyEventResult.handled;
    }

    final controlKeys = <LogicalKeyboardKey>{
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.keyD,
    };

    if (!controlKeys.contains(key)) return KeyEventResult.ignored;

    if (isDown) {
      _keysDown.add(key);
    } else {
      _keysDown.remove(key);
    }
    unawaited(_applyMotionState());
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      body: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            const Positioned.fill(child: CameraView()),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF05070C).withValues(alpha: 0.18),
                        Colors.transparent,
                        const Color(0xFF05070C).withValues(alpha: 0.62),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xCC09111D),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x2236E6C5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'OPTIRIDE',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ConnectionBadge(
                                connected: _connection.connected,
                                checking: _connection.checking,
                                statusText: _connection.statusText,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        SettingsIconButton(onPressed: _openSettings),
                      ],
                    ),
                    const Spacer(),
                    if (compact)
                      _CompactControls(
                        onDriveForwardDown: _pressDriveForward,
                        onDriveForwardUp: _releaseDriveForward,
                        onDriveBackwardDown: _pressDriveBackward,
                        onDriveBackwardUp: _releaseDriveBackward,
                        onSteerLeftDown: _pressSteerLeft,
                        onSteerLeftUp: _releaseSteerLeft,
                        onSteerRightDown: _pressSteerRight,
                        onSteerRightUp: _releaseSteerRight,
                      )
                    else
                      _LandscapeControls(
                        onDriveForwardDown: _pressDriveForward,
                        onDriveForwardUp: _releaseDriveForward,
                        onDriveBackwardDown: _pressDriveBackward,
                        onDriveBackwardUp: _releaseDriveBackward,
                        onSteerLeftDown: _pressSteerLeft,
                        onSteerLeftUp: _releaseSteerLeft,
                        onSteerRightDown: _pressSteerRight,
                        onSteerRightUp: _releaseSteerRight,
                      ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ControlButton(
                          icon: Icons.power_settings_new,
                          label: 'STOP',
                          onDown: _stopAll,
                          onUp: () {},
                          danger: true,
                          compact: true,
                        ),
                        const SizedBox(width: 12),
                        ControlButton(
                          icon: Icons.lightbulb_outline,
                          label: 'LIGHT',
                          onDown: _toggleLight,
                          onUp: () {},
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactControls extends StatelessWidget {
  const _CompactControls({
    required this.onDriveForwardDown,
    required this.onDriveForwardUp,
    required this.onDriveBackwardDown,
    required this.onDriveBackwardUp,
    required this.onSteerLeftDown,
    required this.onSteerLeftUp,
    required this.onSteerRightDown,
    required this.onSteerRightUp,
  });

  final VoidCallback onDriveForwardDown;
  final VoidCallback onDriveForwardUp;
  final VoidCallback onDriveBackwardDown;
  final VoidCallback onDriveBackwardUp;
  final VoidCallback onSteerLeftDown;
  final VoidCallback onSteerLeftUp;
  final VoidCallback onSteerRightDown;
  final VoidCallback onSteerRightUp;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ControlButton(
              icon: Icons.arrow_upward,
              label: 'UP',
              onDown: onDriveForwardDown,
              onUp: onDriveForwardUp,
            ),
            const SizedBox(height: 12),
            ControlButton(
              icon: Icons.arrow_downward,
              label: 'DOWN',
              onDown: onDriveBackwardDown,
              onUp: onDriveBackwardUp,
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ControlButton(
              icon: Icons.arrow_back,
              label: 'LEFT',
              onDown: onSteerLeftDown,
              onUp: onSteerLeftUp,
            ),
            const SizedBox(height: 12),
            ControlButton(
              icon: Icons.arrow_forward,
              label: 'RIGHT',
              onDown: onSteerRightDown,
              onUp: onSteerRightUp,
            ),
          ],
        ),
      ],
    );
  }
}

class _LandscapeControls extends StatelessWidget {
  const _LandscapeControls({
    required this.onDriveForwardDown,
    required this.onDriveForwardUp,
    required this.onDriveBackwardDown,
    required this.onDriveBackwardUp,
    required this.onSteerLeftDown,
    required this.onSteerLeftUp,
    required this.onSteerRightDown,
    required this.onSteerRightUp,
  });

  final VoidCallback onDriveForwardDown;
  final VoidCallback onDriveForwardUp;
  final VoidCallback onDriveBackwardDown;
  final VoidCallback onDriveBackwardUp;
  final VoidCallback onSteerLeftDown;
  final VoidCallback onSteerLeftUp;
  final VoidCallback onSteerRightDown;
  final VoidCallback onSteerRightUp;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ControlButton(
              icon: Icons.arrow_upward,
              label: 'UP',
              onDown: onDriveForwardDown,
              onUp: onDriveForwardUp,
              compact: false,
            ),
            const SizedBox(height: 12),
            ControlButton(
              icon: Icons.arrow_downward,
              label: 'DOWN',
              onDown: onDriveBackwardDown,
              onUp: onDriveBackwardUp,
              compact: false,
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ControlButton(
              icon: Icons.arrow_back,
              label: 'LEFT',
              onDown: onSteerLeftDown,
              onUp: onSteerLeftUp,
              compact: false,
            ),
            const SizedBox(height: 12),
            ControlButton(
              icon: Icons.arrow_forward,
              label: 'RIGHT',
              onDown: onSteerRightDown,
              onUp: onSteerRightUp,
              compact: false,
            ),
          ],
        ),
      ],
    );
  }
}
