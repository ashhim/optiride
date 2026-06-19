import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/connection_controller.dart';
import '../controllers/gyro_controller.dart';
import '../controllers/hud_settings_controller.dart';
import '../controllers/joystick_controller.dart';
import '../controllers/light_controller.dart';
import '../controllers/motion_controller.dart';
import '../services/stream_service.dart';
import '../widgets/camera_view.dart';
import '../widgets/control_button.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/connection_badge.dart';
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
  late JoystickController _joystick;
  late HudSettingsController _hudSettings;
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
    _joystick = context.read<JoystickController>();
    _hudSettings = context.read<HudSettingsController>();
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
    unawaited(_joystick.release());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_gyro.setEnabled(false));
      unawaited(_motion.stopAll());
    }
  }

  void _handleConnectionChanged() {
    if (_connection.connected && _connection.baseUri != null) {
      _streamService.setBaseUri(_connection.baseUri);
    }
    if (!_connection.connected) {
      _streamService.setBaseUri(null);
      _driveForwardHeld = false;
      _driveBackwardHeld = false;
      _steerLeftHeld = false;
      _steerRightHeld = false;
      _keysDown.clear();
      unawaited(_motion.stopAll());
      unawaited(_joystick.release());
      _gyro.setManualSteerOverride(false);
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

  Future<void> _setGyroEnabled(bool value) async {
    _steerLeftHeld = false;
    _steerRightHeld = false;
    _keysDown.remove(LogicalKeyboardKey.arrowLeft);
    _keysDown.remove(LogicalKeyboardKey.keyA);
    _keysDown.remove(LogicalKeyboardKey.arrowRight);
    _keysDown.remove(LogicalKeyboardKey.keyD);
    if (value) {
      _hudSettings.setSingleJoystickMode(false);
      await _joystick.release();
    }
    await _gyro.setEnabled(value);
    _gyro.setManualSteerOverride(false);
    if (mounted) setState(() {});
  }

  Future<void> _setSingleJoystickMode(bool value) async {
    _hudSettings.setSingleJoystickMode(value);
    _driveForwardHeld = false;
    _driveBackwardHeld = false;
    _steerLeftHeld = false;
    _steerRightHeld = false;
    _keysDown.clear();
    if (value) {
      await _setGyroEnabled(false);
    } else {
      await _joystick.release();
    }
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Consumer2<GyroController, HudSettingsController>(
            builder:
                (context, gyro, hudSettings, _) => SettingsPanel(
                  ipController: _ipController,
                  connected: _connection.connected,
                  statusText: _connection.statusText,
                  onConnect: _connect,
                  gyroEnabled: gyro.enabled,
                  onGyroChanged: (value) {
                    unawaited(_setGyroEnabled(value));
                  },
                  gyroSensitivity: gyro.sensitivity,
                  onSensitivityChanged: gyro.setSensitivity,
                  gyroDeadZone: gyro.deadZone,
                  onDeadZoneChanged: gyro.setDeadZone,
                  onCalibrateGyro: gyro.calibrate,
                  singleJoystickMode: hudSettings.singleJoystickMode,
                  onSingleJoystickModeChanged: (value) {
                    unawaited(_setSingleJoystickMode(value));
                  },
                  buttonScale: hudSettings.buttonScale,
                  onButtonScaleChanged: hudSettings.setButtonScale,
                  buttonOpacity: hudSettings.buttonOpacity,
                  onButtonOpacityChanged: hudSettings.setButtonOpacity,
                  edgeInset: hudSettings.edgeInset,
                  onEdgeInsetChanged: hudSettings.setEdgeInset,
                  bottomOffset: hudSettings.bottomOffset,
                  onBottomOffsetChanged: hudSettings.setBottomOffset,
                ),
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
    _gyro.setManualSteerOverride(false);
    await _joystick.release();
    await _motion.stopAll();
  }

  Future<void> _applyMotionState() async {
    final forward =
        _keysDown.contains(LogicalKeyboardKey.arrowUp) ||
        _keysDown.contains(LogicalKeyboardKey.keyW) ||
        _driveForwardHeld;
    final backward =
        _keysDown.contains(LogicalKeyboardKey.arrowDown) ||
        _keysDown.contains(LogicalKeyboardKey.keyS) ||
        _driveBackwardHeld;
    final left =
        _keysDown.contains(LogicalKeyboardKey.arrowLeft) ||
        _keysDown.contains(LogicalKeyboardKey.keyA) ||
        _steerLeftHeld;
    final right =
        _keysDown.contains(LogicalKeyboardKey.arrowRight) ||
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

    _gyro.setManualSteerOverride(_gyro.enabled && (left || right));
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
    final hudSettings = context.watch<HudSettingsController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final portrait = constraints.maxHeight >= constraints.maxWidth;
        _gyro.setOrientationLandscape(!portrait);

        final shortest =
            constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;

        final controlSize =
            (portrait
                ? (shortest * 0.18).clamp(60.0, 74.0).toDouble()
                : (shortest * 0.13).clamp(54.0, 66.0).toDouble()) *
            hudSettings.buttonScale;
        final actionSize =
            (portrait
                ? (shortest * 0.16).clamp(56.0, 66.0).toDouble()
                : (shortest * 0.11).clamp(50.0, 60.0).toDouble()) *
            hudSettings.buttonScale;
        final horizontalInset =
            (portrait ? 16.0 : 28.0) + hudSettings.edgeInset;
        final maxControlBottom = math.max(12.0, constraints.maxHeight * 0.46);
        final controlBottom =
            ((portrait ? 24.0 : 12.0) + hudSettings.bottomOffset)
                .clamp(12.0, maxControlBottom)
                .toDouble();
        final controlSpacing = portrait ? 12.0 : 18.0;
        final joystickSize =
            (portrait
                ? (shortest * 0.34).clamp(118.0, 156.0).toDouble()
                : (shortest * 0.26).clamp(116.0, 144.0).toDouble()) *
            hudSettings.buttonScale;

        return Scaffold(
          body: Focus(
            autofocus: true,
            focusNode: _focusNode,
            onKeyEvent: _handleKeyEvent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(child: _AppBackground()),
                const Positioned.fill(child: CameraView()),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.14),
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
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        ConnectionBadge(
                          connected: _connection.connected,
                          checking: _connection.checking,
                          statusText: _connection.statusText,
                          compact: true,
                        ),
                        const Spacer(),
                        SettingsIconButton(
                          onPressed: _openSettings,
                          opacity: hudSettings.buttonOpacity,
                        ),
                      ],
                    ),
                  ),
                ),
                if (hudSettings.singleJoystickMode)
                  Positioned(
                    left: horizontalInset,
                    bottom: controlBottom,
                    child: JoystickWidget(
                      size: joystickSize,
                      opacity: hudSettings.buttonOpacity,
                      onChanged: (offset) {
                        _joystick.updateNormalized(offset);
                      },
                      onReleased: () {
                        unawaited(_joystick.release());
                      },
                    ),
                  )
                else ...[
                  Positioned(
                    left: horizontalInset,
                    bottom: controlBottom,
                    child: _RaceControlPair(
                      vertical: true,
                      spacing: controlSpacing,
                      first: ControlButton(
                        icon: Icons.keyboard_arrow_up_rounded,
                        label: 'UP',
                        onDown: _pressDriveForward,
                        onUp: _releaseDriveForward,
                        width: controlSize,
                        height: controlSize,
                        iconSize: controlSize * 0.54,
                        circular: true,
                        showLabel: false,
                        opacity: hudSettings.buttonOpacity,
                      ),
                      second: ControlButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        label: 'DOWN',
                        onDown: _pressDriveBackward,
                        onUp: _releaseDriveBackward,
                        width: controlSize,
                        height: controlSize,
                        iconSize: controlSize * 0.54,
                        circular: true,
                        showLabel: false,
                        opacity: hudSettings.buttonOpacity,
                      ),
                    ),
                  ),
                  Positioned(
                    right: horizontalInset,
                    bottom: controlBottom,
                    child: _RaceControlPair(
                      vertical: true,
                      spacing: controlSpacing,
                      first: ControlButton(
                        icon: Icons.keyboard_arrow_left_rounded,
                        label: 'LEFT',
                        onDown: _pressSteerLeft,
                        onUp: _releaseSteerLeft,
                        width: controlSize,
                        height: controlSize,
                        iconSize: controlSize * 0.54,
                        circular: true,
                        showLabel: false,
                        opacity: hudSettings.buttonOpacity,
                      ),
                      second: ControlButton(
                        icon: Icons.keyboard_arrow_right_rounded,
                        label: 'RIGHT',
                        onDown: _pressSteerRight,
                        onUp: _releaseSteerRight,
                        width: controlSize,
                        height: controlSize,
                        iconSize: controlSize * 0.54,
                        circular: true,
                        showLabel: false,
                        opacity: hudSettings.buttonOpacity,
                      ),
                    ),
                  ),
                ],
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 4,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: _ActionDock(
                        buttonSize: actionSize,
                        onStop: _stopAll,
                        onLight: _toggleLight,
                        opacity: hudSettings.buttonOpacity,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppBackground extends StatelessWidget {
  const _AppBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF05070C), Color(0xFF08111C), Color(0xFF03060A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1DE9B6).withValues(alpha: 0.06),
                    Colors.transparent,
                    const Color(0xFF15B7FF).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionDock extends StatelessWidget {
  const _ActionDock({
    required this.buttonSize,
    required this.onStop,
    required this.onLight,
    required this.opacity,
  });

  final double buttonSize;
  final Future<void> Function() onStop;
  final Future<void> Function() onLight;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ControlButton(
          icon: Icons.power_settings_new,
          label: 'STOP',
          onDown: onStop,
          onUp: () async {},
          danger: true,
          compact: true,
          width: buttonSize,
          height: buttonSize,
          iconSize: buttonSize * 0.48,
          circular: true,
          showLabel: false,
          opacity: opacity,
        ),
        const SizedBox(width: 14),
        ControlButton(
          icon: Icons.lightbulb_outline,
          label: 'LIGHT',
          onDown: onLight,
          onUp: () async {},
          compact: true,
          width: buttonSize,
          height: buttonSize,
          iconSize: buttonSize * 0.46,
          circular: true,
          showLabel: false,
          opacity: opacity,
        ),
      ],
    );
  }
}

class _RaceControlPair extends StatelessWidget {
  const _RaceControlPair({
    required this.vertical,
    required this.spacing,
    required this.first,
    required this.second,
  });

  final bool vertical;
  final double spacing;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [first, SizedBox(height: spacing), second],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [first, SizedBox(width: spacing), second],
    );
  }
}
