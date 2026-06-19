import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'motion_controller.dart';

class JoystickController extends ChangeNotifier {
  MotionController? _motion;
  Offset _normalized = Offset.zero;
  DriveDirection _drive = DriveDirection.neutral;
  SteerDirection _steer = SteerDirection.neutral;
  Timer? _debounce;

  Offset get normalized => _normalized;
  DriveDirection get drive => _drive;
  SteerDirection get steer => _steer;

  void bind(MotionController motion) {
    _motion = motion;
  }

  void updateNormalized(Offset normalized) {
    _normalized = Offset(
      normalized.dx.clamp(-1.0, 1.0),
      normalized.dy.clamp(-1.0, 1.0),
    );
    notifyListeners();

    final nextDrive = _driveFromY(_normalized.dy);
    final nextSteer = _steerFromX(_normalized.dx);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (nextDrive != _drive) {
        _drive = nextDrive;
        _motion?.setDrive(nextDrive);
      }
      if (nextSteer != _steer) {
        _steer = nextSteer;
        _motion?.setSteer(nextSteer);
      }
      notifyListeners();
    });
  }

  Future<void> release() async {
    _debounce?.cancel();
    _normalized = Offset.zero;
    _drive = DriveDirection.neutral;
    _steer = SteerDirection.neutral;
    notifyListeners();
    await _motion?.stopDrive();
    await _motion?.stopSteer();
  }

  DriveDirection _driveFromY(double y) {
    const threshold = 0.20;
    if (y.abs() < threshold) return DriveDirection.neutral;
    return y > 0 ? DriveDirection.forward : DriveDirection.backward;
  }

  SteerDirection _steerFromX(double x) {
    const threshold = 0.20;
    if (x.abs() < threshold) return SteerDirection.neutral;
    return x < 0 ? SteerDirection.left : SteerDirection.right;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
