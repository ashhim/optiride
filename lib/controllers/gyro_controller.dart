import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'motion_controller.dart';

class GyroController extends ChangeNotifier {
  MotionController? _motion;
  StreamSubscription<AccelerometerEvent>? _subscription;
  bool _enabled = false;
  bool _landscape = false;
  double _sensitivity = 1.2;
  double _deadZone = 0.18;
  AccelerometerEvent? _baseline;
  double _tiltX = 0;
  double _tiltY = 0;
  DriveDirection _drive = DriveDirection.neutral;
  SteerDirection _steer = SteerDirection.neutral;
  Timer? _debounce;

  bool get enabled => _enabled;
  double get sensitivity => _sensitivity;
  double get deadZone => _deadZone;
  double get tiltX => _tiltX;
  double get tiltY => _tiltY;
  DriveDirection get drive => _drive;
  SteerDirection get steer => _steer;

  void bind(MotionController motion) {
    _motion = motion;
  }

  void setOrientationLandscape(bool landscape) {
    if (_landscape == landscape) return;
    _landscape = landscape;
  }

  void setSensitivity(double value) {
    _sensitivity = value.clamp(0.7, 2.0);
    notifyListeners();
  }

  void setDeadZone(double value) {
    _deadZone = value.clamp(0.05, 0.35);
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    _baseline = null;
    _debounce?.cancel();
    _debounce = null;
    _tiltX = 0;
    _tiltY = 0;
    _drive = DriveDirection.neutral;
    _steer = SteerDirection.neutral;
    notifyListeners();

    if (enabled) {
      await _motion?.stopAll();
      await _subscription?.cancel();
      _subscription = null;
      _subscription = accelerometerEventStream().listen(_handleAccelerometer);
      return;
    }

    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _motion?.stopAll();
  }

  void calibrate() {
    _baseline = null;
  }

  void _handleAccelerometer(AccelerometerEvent event) {
    if (!_enabled) return;
    final base = _baseline ?? event;
    _baseline ??= event;

    final driveSignalRaw = _landscape ? (base.x - event.x) : (base.y - event.y);
    final steerSignalRaw = _landscape ? (base.y - event.y) : (base.x - event.x);

    _tiltY = driveSignalRaw * _sensitivity;
    _tiltX = steerSignalRaw * _sensitivity;

    final nextDrive = _driveForSignal(_tiltY);
    final nextSteer = _steerForSignal(_tiltX);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (!_enabled) return;
      if (nextDrive != _drive) {
        _drive = nextDrive;
        final motion = _motion;
        if (motion != null) {
          unawaited(motion.setDrive(nextDrive));
        }
      }
      if (nextSteer != _steer) {
        _steer = nextSteer;
        final motion = _motion;
        if (motion != null) {
          unawaited(motion.setSteer(nextSteer));
        }
      }
      notifyListeners();
    });
  }

  DriveDirection _driveForSignal(double value) {
    if (value.abs() < _deadZone) return DriveDirection.neutral;
    return value > 0 ? DriveDirection.forward : DriveDirection.backward;
  }

  SteerDirection _steerForSignal(double value) {
    if (value.abs() < _deadZone) return SteerDirection.neutral;
    return value < 0 ? SteerDirection.left : SteerDirection.right;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
