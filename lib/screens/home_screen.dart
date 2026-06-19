import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

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
        final screenWidth = constraints.maxWidth;
        final shortest = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final controlSize = portrait
            ? (shortest * 0.18).clamp(60.0, 74.0)
            : (shortest * 0.13).clamp(54.0, 66.0);
        final actionSize = portrait
            ? (shortest * 0.16).clamp(56.0, 66.0)
            : (shortest * 0.11).clamp(50.0, 60.0);
        final horizontalInset = portrait ? 16.0 : 28.0;
        final controlBottom = portrait ? 94.0 : 22.0;
        final controlSpacing = portrait ? 12.0 : 18.0;
        final speedGaugeSize = portrait
            ? (shortest * 0.30).clamp(104.0, 132.0)
            : (shortest * 0.34).clamp(118.0, 168.0);
        final miniMapSize = portrait
            ? (shortest * 0.15).clamp(48.0, 60.0)
            : (shortest * 0.16).clamp(62.0, 82.0);

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
                        if (!portrait || screenWidth > 560) const _RaceTimer(),
                        if (!portrait || screenWidth > 560) const Spacer(),
                        if (!portrait || screenWidth > 560) ...[
                          _MiniMapHud(size: miniMapSize),
                          const SizedBox(width: 10),
                        ],
                        SettingsIconButton(onPressed: _openSettings),
                      ],
                    ),
                  ),
                ),
                if (portrait && screenWidth > 520)
                  const Positioned(
                    top: 18,
                    left: 0,
                    right: 0,
                    child: SafeArea(child: Center(child: _RaceTimer())),
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
                Positioned(
                  left: portrait ? 18 : 28,
                  top: portrait ? 112 : 96,
                  child: _SpeedGauge(size: speedGaugeSize),
                ),
                if (!portrait)
                  Positioned(
                    right: 32,
                    bottom: 94,
                    child: _PedalMeter(size: speedGaugeSize * 0.64),
                  ),
                Positioned(
                  left: horizontalInset,
                  bottom: controlBottom,
                  child: _RaceControlPair(
                    vertical: portrait,
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
                    ),
                  ),
                ),
                Positioned(
                  right: horizontalInset,
                  bottom: controlBottom,
                  child: _RaceControlPair(
                    vertical: portrait,
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
                    ),
                  ),
                ),
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
            color: const Color(0x7A09111D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x2236E6C5)),
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

class _RaceTimer extends StatelessWidget {
  const _RaceTimer();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x2236E6C5)),
          ),
          child: const Text(
            '00:00:00',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              shadows: [
                Shadow(color: Color(0xFF06110F), blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapHud extends StatelessWidget {
  const _MiniMapHud({
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.15),
            border: Border.all(color: const Color(0xAA37F5DF), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x6637F5DF), blurRadius: 18),
            ],
          ),
          child: CustomPaint(painter: _MiniMapPainter()),
        ),
      ),
    );
  }
}

class _SpeedGauge extends StatelessWidget {
  const _SpeedGauge({
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final dialSize = size * 0.58;
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size * 1.28,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _SpeedGaugePainter())),
            Positioned(
              left: size * 0.23,
              top: size * 0.45,
              child: Container(
                width: dialSize,
                height: dialSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x55071D22),
                  border: Border.all(color: const Color(0xAA37F5DF), width: 1.1),
                  boxShadow: const [
                    BoxShadow(color: Color(0x7737F5DF), blurRadius: 18),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '207',
                      style: TextStyle(
                        color: Color(0xFF6DFFF0),
                        fontSize: 25,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w800,
                        height: 0.95,
                      ),
                    ),
                    Text(
                      'km/h',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: size * 0.03,
              child: _TinyTelemetry(label: '0543', sublabel: 'HP'),
            ),
            Positioned(
              left: size * 0.46,
              bottom: 0,
              child: Container(
                width: size * 0.20,
                height: size * 0.20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x661B1308),
                  border: Border.all(color: const Color(0xFFFF9440), width: 1.1),
                  boxShadow: const [BoxShadow(color: Color(0x66FF9440), blurRadius: 12)],
                ),
                child: const Text(
                  '3',
                  style: TextStyle(
                    color: Color(0xFFFFB15E),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
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

class _TinyTelemetry extends StatelessWidget {
  const _TinyTelemetry({
    required this.label,
    required this.sublabel,
  });

  final String label;
  final String sublabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x55071D22),
        border: Border.all(color: const Color(0xAA37F5DF), width: 1),
        boxShadow: const [BoxShadow(color: Color(0x5537F5DF), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6DFFF0),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            sublabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 7,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PedalMeter extends StatelessWidget {
  const _PedalMeter({
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _PedalMeterPainter()),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final cyan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xAA37F5DF);
    final dim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.24);

    canvas.drawCircle(center, radius * 0.74, dim);
    canvas.drawLine(Offset(center.dx, radius * 0.18), Offset(center.dx, radius * 1.55), dim);
    canvas.drawLine(Offset(radius * 0.25, center.dy), Offset(radius * 1.55, center.dy), dim);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      -math.pi * 0.70,
      math.pi * 1.25,
      false,
      cyan,
    );

    final route = Path()
      ..moveTo(radius * 0.58, radius * 0.18)
      ..quadraticBezierTo(radius * 1.03, radius * 0.62, radius * 0.87, radius * 1.06)
      ..quadraticBezierTo(radius * 0.78, radius * 1.34, radius * 1.18, radius * 1.65);
    canvas.drawPath(
      route,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.62),
    );

    final arrow = Path()
      ..moveTo(center.dx, center.dy - radius * 0.20)
      ..lineTo(center.dx - radius * 0.14, center.dy + radius * 0.18)
      ..lineTo(center.dx + radius * 0.14, center.dy + radius * 0.18)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()
        ..color = const Color(0xFFFFE84B)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpeedGaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.53;
    final center = Offset(size.width * 0.57, size.height * 0.57);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = math.pi * 0.82;
    const sweep = math.pi * 1.18;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0x5537F5DF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(rect, start, sweep * 0.68, false, glowPaint);

    for (var i = 0; i < 23; i++) {
      final segmentStart = start + (sweep / 24) * i;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i > 17 ? 8 : 5
        ..strokeCap = StrokeCap.butt
        ..color = i > 17
            ? const Color(0xFFFF2E48)
            : i % 5 == 0
                ? Colors.black.withValues(alpha: 0.78)
                : const Color(0xFF39F7DE);
      canvas.drawArc(rect, segmentStart, sweep / 38, false, paint);
    }

    final needleAngle = start + sweep * 0.62;
    final needleEnd = Offset(
      center.dx + math.cos(needleAngle) * radius * 0.72,
      center.dy + math.sin(needleAngle) * radius * 0.72,
    );
    canvas.drawLine(
      center,
      needleEnd,
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF2E48),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PedalMeterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x9937F5DF);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = const Color(0x4437F5DF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);

    canvas.drawCircle(center, radius * 0.82, glow);
    canvas.drawCircle(center, radius * 0.82, ring);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.96),
      -math.pi * 0.68,
      math.pi * 0.62,
      false,
      ring..strokeWidth = 5,
    );

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.48);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 3; col++) {
        canvas.drawCircle(
          Offset(center.dx - radius * 0.22 + col * radius * 0.22, center.dy - radius * 0.28 + row * radius * 0.18),
          radius * 0.035,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
