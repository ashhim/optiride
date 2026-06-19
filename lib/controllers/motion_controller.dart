import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

enum DriveDirection { neutral, forward, backward }
enum SteerDirection { neutral, left, right }

class MotionController extends ChangeNotifier {
  ApiService? _api;
  DriveDirection _drive = DriveDirection.neutral;
  SteerDirection _steer = SteerDirection.neutral;

  DriveDirection get drive => _drive;
  SteerDirection get steer => _steer;

  void bind(ApiService api) {
    _api = api;
  }

  Future<void> setDrive(DriveDirection next) async {
    if (_drive == next) return;
    _drive = next;
    notifyListeners();

    final api = _api;
    if (api == null) return;

    switch (next) {
      case DriveDirection.forward:
        await api.command('/forward');
        break;
      case DriveDirection.backward:
        await api.command('/backward');
        break;
      case DriveDirection.neutral:
        await api.command('/stopdrive');
        break;
    }
  }

  Future<void> setSteer(SteerDirection next) async {
    if (_steer == next) return;
    _steer = next;
    notifyListeners();

    final api = _api;
    if (api == null) return;

    switch (next) {
      case SteerDirection.left:
        await api.command('/steerleft');
        break;
      case SteerDirection.right:
        await api.command('/steerright');
        break;
      case SteerDirection.neutral:
        await api.command('/stopsteer');
        break;
    }
  }

  Future<void> stopDrive() => setDrive(DriveDirection.neutral);

  Future<void> stopSteer() => setSteer(SteerDirection.neutral);

  Future<void> stopAll() async {
    _drive = DriveDirection.neutral;
    _steer = SteerDirection.neutral;
    notifyListeners();
    await _api?.command('/stopall');
  }
}
