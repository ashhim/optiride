import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'motion_controller.dart';

class JoystickController extends ChangeNotifier {
  MotionController? _motion;
  Offset _normalized = Offset.zero;
  DriveDirection _drive = DriveDirection.neutral;
  SteerDirection _steer = SteerDirection.neutral;

  Offset get normalized => _normalized;
  DriveDirection get drive => _drive;
  SteerDirection get steer => _steer;

  void bind(MotionController motion) {
    _motion = motion;
  }

  Future<void> updateNormalized(Offset normalized) async {
    final next = Offset(
      normalized.dx.clamp(-1.0, 1.0).toDouble(),
      normalized.dy.clamp(-1.0, 1.0).toDouble(),
    );

    if (next == _normalized) return;

    _normalized = next;
    notifyListeners();

    final nextDrive = _driveFromY(_normalized.dy);
    final nextSteer = _steerFromX(_normalized.dx);

    if (nextDrive != _drive) {
      _drive = nextDrive;
      final motion = _motion;
      if (motion != null) {
        await motion.setDrive(nextDrive);
      }
    }

    if (nextSteer != _steer) {
      _steer = nextSteer;
      final motion = _motion;
      if (motion != null) {
        await motion.setSteer(nextSteer);
      }
    }

    notifyListeners();
  }

  Future<void> release() async {
    _normalized = Offset.zero;
    _drive = DriveDirection.neutral;
    _steer = SteerDirection.neutral;
    notifyListeners();

    final motion = _motion;
    if (motion != null) {
      await motion.stopDrive();
      await motion.stopSteer();
    }
  }

  DriveDirection _driveFromY(double y) {
    const threshold = 0.18;
    if (y.abs() < threshold) return DriveDirection.neutral;
    return y > 0 ? DriveDirection.forward : DriveDirection.backward;
  }

  SteerDirection _steerFromX(double x) {
    const threshold = 0.18;
    if (x.abs() < threshold) return SteerDirection.neutral;
    return x < 0 ? SteerDirection.left : SteerDirection.right;
  }
}
