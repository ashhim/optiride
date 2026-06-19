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
        onCalibrateGyro: () {
          _gyro.calibrate();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final portrait = constraints.maxHeight >= constraints.maxWidth;
        final shortest = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final railButtonSize = portrait
            ? (shortest * 0.18).clamp(62.0, 78.0)
            : (shortest * 0.14).clamp(60.0, 74.0);
        final dockButtonSize = portrait
            ? (shortest * 0.17).clamp(60.0, 74.0)
            : (shortest * 0.12).clamp(58.0, 70.0);
        final cameraAspect = portrait ? 4 / 3 : 16 / 9;

        return Scaffold(
          body: Focus(
            autofocus: true,
            focusNode: _focusNode,
            onKeyEvent: _handleKeyEvent,
            child: Stack(
              children: [
                const Positioned.fill(child: _AppBackground()),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _HudHeader(
                            connected: _connection.connected,
                            checking: _connection.checking,
                            statusText: _connection.statusText,
                          ),
                        ),
                        const Spacer(),
                        SettingsIconButton(onPressed: _openSettings),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14, 76, 14, portrait ? 12 : 16),
                  child: portrait
                      ? _PortraitHud(
                          cameraAspect: cameraAspect,
                          railButtonSize: railButtonSize,
                          dockButtonSize: dockButtonSize,
                          onDriveForwardDown: _pressDriveForward,
                          onDriveForwardUp: _releaseDriveForward,
                          onDriveBackwardDown: _pressDriveBackward,
                          onDriveBackwardUp: _releaseDriveBackward,
                          onSteerLeftDown: _pressSteerLeft,
                          onSteerLeftUp: _releaseSteerLeft,
                          onSteerRightDown: _pressSteerRight,
                          onSteerRightUp: _releaseSteerRight,
                          onStop: _stopAll,
                          onLight: _toggleLight,
                        )
                      : _LandscapeHud(
                          cameraAspect: cameraAspect,
                          railButtonSize: railButtonSize,
                          dockButtonSize: dockButtonSize,
                          onDriveForwardDown: _pressDriveForward,
                          onDriveForwardUp: _releaseDriveForward,
                          onDriveBackwardDown: _pressDriveBackward,
                          onDriveBackwardUp: _releaseDriveBackward,
                          onSteerLeftDown: _pressSteerLeft,
                          onSteerLeftUp: _releaseSteerLeft,
                          onSteerRightDown: _pressSteerRight,
                          onSteerRightUp: _releaseSteerRight,
                          onStop: _stopAll,
                          onLight: _toggleLight,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC09111D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x2236E6C5)),
      ),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPTIRIDE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Controller',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: ConnectionBadge(
                connected: connected,
                checking: checking,
                statusText: statusText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitHud extends StatelessWidget {
  const _PortraitHud({
    required this.cameraAspect,
    required this.railButtonSize,
    required this.dockButtonSize,
    required this.onDriveForwardDown,
    required this.onDriveForwardUp,
    required this.onDriveBackwardDown,
    required this.onDriveBackwardUp,
    required this.onSteerLeftDown,
    required this.onSteerLeftUp,
    required this.onSteerRightDown,
    required this.onSteerRightUp,
    required this.onStop,
    required this.onLight,
  });

  final double cameraAspect;
  final double railButtonSize;
  final double dockButtonSize;
  final Future<void> Function() onDriveForwardDown;
  final Future<void> Function() onDriveForwardUp;
  final Future<void> Function() onDriveBackwardDown;
  final Future<void> Function() onDriveBackwardUp;
  final Future<void> Function() onSteerLeftDown;
  final Future<void> Function() onSteerLeftUp;
  final Future<void> Function() onSteerRightDown;
  final Future<void> Function() onSteerRightUp;
  final Future<void> Function() onStop;
  final Future<void> Function() onLight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: AspectRatio(
                      aspectRatio: cameraAspect,
                      child: const _CameraViewport(),
                    ),
                  ),
                ),
              ),
        const SizedBox(height: 12),
        SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _ControlCluster(
                    title: 'DRIVE',
                    primary: ControlButton(
                      icon: Icons.arrow_upward,
                      label: 'UP',
                      onDown: onDriveForwardDown,
                      onUp: onDriveForwardUp,
                      width: railButtonSize,
                      height: railButtonSize,
                      iconSize: railButtonSize * 0.42,
                      labelSize: 10,
                    ),
                    secondary: ControlButton(
                      icon: Icons.arrow_downward,
                      label: 'DOWN',
                      onDown: onDriveBackwardDown,
                      onUp: onDriveBackwardUp,
                      width: railButtonSize,
                      height: railButtonSize,
                      iconSize: railButtonSize * 0.42,
                      labelSize: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                fit: FlexFit.loose,
                child: _ActionDock(
                  buttonSize: dockButtonSize,
                  onStop: onStop,
                  onLight: onLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: _ControlCluster(
                    title: 'STEER',
                    primary: ControlButton(
                      icon: Icons.arrow_back,
                      label: 'LEFT',
                      onDown: onSteerLeftDown,
                      onUp: onSteerLeftUp,
                      width: railButtonSize,
                      height: railButtonSize,
                      iconSize: railButtonSize * 0.42,
                      labelSize: 10,
                    ),
                    secondary: ControlButton(
                      icon: Icons.arrow_forward,
                      label: 'RIGHT',
                      onDown: onSteerRightDown,
                      onUp: onSteerRightUp,
                      width: railButtonSize,
                      height: railButtonSize,
                      iconSize: railButtonSize * 0.42,
                      labelSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LandscapeHud extends StatelessWidget {
  const _LandscapeHud({
    required this.cameraAspect,
    required this.railButtonSize,
    required this.dockButtonSize,
    required this.onDriveForwardDown,
    required this.onDriveForwardUp,
    required this.onDriveBackwardDown,
    required this.onDriveBackwardUp,
    required this.onSteerLeftDown,
    required this.onSteerLeftUp,
    required this.onSteerRightDown,
    required this.onSteerRightUp,
    required this.onStop,
    required this.onLight,
  });

  final double cameraAspect;
  final double railButtonSize;
  final double dockButtonSize;
  final Future<void> Function() onDriveForwardDown;
  final Future<void> Function() onDriveForwardUp;
  final Future<void> Function() onDriveBackwardDown;
  final Future<void> Function() onDriveBackwardUp;
  final Future<void> Function() onSteerLeftDown;
  final Future<void> Function() onSteerLeftUp;
  final Future<void> Function() onSteerRightDown;
  final Future<void> Function() onSteerRightUp;
  final Future<void> Function() onStop;
  final Future<void> Function() onLight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.60,
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            child: AspectRatio(aspectRatio: cameraAspect, child: const _CameraViewport()),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _ControlCluster(
          title: 'DRIVE',
          primary: ControlButton(
              icon: Icons.arrow_upward,
              label: 'UP',
              onDown: onDriveForwardDown,
              onUp: onDriveForwardUp,
              width: railButtonSize,
              height: railButtonSize,
              iconSize: railButtonSize * 0.42,
              labelSize: 10,
            ),
            secondary: ControlButton(
              icon: Icons.arrow_downward,
              label: 'DOWN',
              onDown: onDriveBackwardDown,
              onUp: onDriveBackwardUp,
              width: railButtonSize,
              height: railButtonSize,
              iconSize: railButtonSize * 0.42,
              labelSize: 10,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _ControlCluster(
          title: 'STEER',
          primary: ControlButton(
              icon: Icons.arrow_back,
              label: 'LEFT',
              onDown: onSteerLeftDown,
              onUp: onSteerLeftUp,
              width: railButtonSize,
              height: railButtonSize,
              iconSize: railButtonSize * 0.42,
              labelSize: 10,
            ),
            secondary: ControlButton(
              icon: Icons.arrow_forward,
              label: 'RIGHT',
              onDown: onSteerRightDown,
              onUp: onSteerRightUp,
              width: railButtonSize,
              height: railButtonSize,
              iconSize: railButtonSize * 0.42,
              labelSize: 10,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: SafeArea(
              top: false,
              child: _ActionDock(
                buttonSize: dockButtonSize,
                onStop: onStop,
                onLight: onLight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraViewport extends StatelessWidget {
  const _CameraViewport();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x5536E6C5), width: 1.15),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 16)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CameraView(),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFF000000).withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlCluster extends StatelessWidget {
  const _ControlCluster({
    required this.title,
    required this.primary,
    required this.secondary,
  });

  final String title;
  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x90090F18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x2236E6C5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 2.2,
              color: Colors.white54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          primary,
          const SizedBox(height: 10),
          secondary,
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
  });

  final double buttonSize;
  final Future<void> Function() onStop;
  final Future<void> Function() onLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xC009111D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x2236E6C5)),
      ),
      child: Row(
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
            iconSize: buttonSize * 0.42,
            labelSize: 10,
          ),
          const SizedBox(width: 10),
          ControlButton(
            icon: Icons.lightbulb_outline,
            label: 'LIGHT',
            onDown: onLight,
            onUp: () {},
            compact: true,
            width: buttonSize,
            height: buttonSize,
            iconSize: buttonSize * 0.40,
            labelSize: 10,
          ),
        ],
      ),
    );
  }
}
