import 'dart:async';
import 'dart:ui';

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
      builder: (context) => Consumer2<GyroController, HudSettingsController>(
        builder: (context, gyro, hudSettings, _) => SettingsPanel(
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
        final shortest = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final controlSize = (portrait
            ? (shortest * 0.18).clamp(60.0, 74.0).toDouble()
            : (shortest * 0.13).clamp(54.0, 66.0).toDouble()) *
            hudSettings.buttonScale;
        final actionSize = (portrait
            ? (shortest * 0.16).clamp(56.0, 66.0).toDouble()
            : (shortest * 0.11).clamp(50.0, 60.0).toDouble()) *
            hudSettings.buttonScale;
        final horizontalInset = (portrait ? 16.0 : 28.0) + hudSettings.edgeInset;
        final controlBottom = ((portrait ? 94.0 : 22.0) + hudSettings.bottomOffset)
            .clamp(12.0, constraints.maxHeight * 0.46)
            .toDouble();
        final controlSpacing = portrait ? 12.0 : 18.0;
        final joystickSize = (portrait
                ? (shortest * 0.34).clamp(118.0, 156.0).toDouble()
                : (shortest * 0.26).clamp(116.0, 144.0).toDouble()) *
            hudSettings.buttonScale;

        return Scaffold(
          body: Focus(
            autofocus: true,
            focusNode: _focusNode,
            onKeyEvent: _handleKeyEvent,
            child: Stack(
              children: [
                const Positioned.fill(child: _AppBackground()),
                const Positioned.fill(child: _FullScreenCamera()),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        _HudHeader(
                          connected: _connection.connected,
                          checking: _connection.checking,
                          statusText: _connection.statusText,
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
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x0F000000),
                            Colors.transparent,
                            Color(0x24000000),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
                if (hudSettings.singleJoystickMode)
                  Positioned(
                    left: horizontalInset,
                    bottom: controlBottom,
                    child: Consumer<JoystickController>(
                      builder: (context, joystick, _) => _JoystickPad(
                        size: joystickSize,
                        joystick: joystick,
                        opacity: hudSettings.buttonOpacity,
                      ),
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
                  bottom: portrait ? 18 : 18,
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
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x121DE9B6)),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF1DE9B6).withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudHeader extends StatelessWidget {
  const _HudHeader({
    required this.connected,
    required this.checking,
    required this.statusText,
  });

  final bool connected;
  final bool checking;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0x5609111D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x1836E6C5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OPTIRIDE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Controller',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      letterSpacing: 1.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              ConnectionBadge(
                connected: connected,
                checking: checking,
                statusText: statusText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoystickPad extends StatelessWidget {
  const _JoystickPad({
    required this.size,
    required this.joystick,
    required this.opacity,
  });

  final double size;
  final JoystickController joystick;
  final double opacity;

  void _updateFromLocal(Offset localPosition) {
    final radius = size / 2;
    final center = Offset(radius, radius);
    final raw = localPosition - center;
    final limited = raw.distance > radius ? Offset.fromDirection(raw.direction, radius) : raw;
    joystick.updateNormalized(Offset(limited.dx / radius, -limited.dy / radius));
  }

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final knobSize = size * 0.34;
    final knobOffset = Offset(
      radius + joystick.normalized.dx * radius * 0.64 - knobSize / 2,
      radius - joystick.normalized.dy * radius * 0.64 - knobSize / 2,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => _updateFromLocal(details.localPosition),
      onPanUpdate: (details) => _updateFromLocal(details.localPosition),
      onPanEnd: (_) => unawaited(joystick.release()),
      onPanCancel: () => unawaited(joystick.release()),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _JoystickPainter(
                  active: joystick.normalized.distance > 0.05,
                  opacity: opacity,
                ),
              ),
            ),
            Positioned(
              left: knobOffset.dx,
              top: knobOffset.dy,
              child: Container(
                width: knobSize,
                height: knobSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF9EFFF2).withValues(alpha: 0.55),
                      const Color(0xFF1DE9B6).withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.18),
                    ],
                  ),
                  border: Border.all(color: const Color(0xCC6DFFF0), width: 1.4),
                  boxShadow: const [
                    BoxShadow(color: Color(0xAA1DE9B6), blurRadius: 22),
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

class _JoystickPainter extends CustomPainter {
  const _JoystickPainter({
    required this.active,
    required this.opacity,
  });

  final bool active;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final normalizedOpacity = opacity.clamp(0.0, 1.0).toDouble();
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 9 : 6
      ..color = const Color(0x6637F5DF).withValues(alpha: 0.16 + (0.28 * normalizedOpacity))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xAA37F5DF).withValues(alpha: 0.28 + (0.52 * normalizedOpacity));
    final axis = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.10 + (0.18 * normalizedOpacity));

    canvas.drawCircle(center, radius - 5, glow);
    canvas.drawCircle(center, radius - 5, ring);
    canvas.drawCircle(center, radius * 0.36, axis);
    canvas.drawLine(Offset(center.dx, 8), Offset(center.dx, size.height - 8), axis);
    canvas.drawLine(Offset(8, center.dy), Offset(size.width - 8, center.dy), axis);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return oldDelegate.active != active || oldDelegate.opacity != opacity;
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
          onUp: () {},
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
          onUp: () {},
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
        children: [
          first,
          SizedBox(height: spacing),
          second,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        first,
        SizedBox(width: spacing),
        second,
      ],
    );
  }
}

class _FullScreenCamera extends StatelessWidget {
  const _FullScreenCamera();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CameraView(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.22),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.18),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
