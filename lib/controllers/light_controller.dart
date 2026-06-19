import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

class LightController extends ChangeNotifier {
  ApiService? _api;
  bool _lightOn = false;

  bool get lightOn => _lightOn;

  void bind(ApiService api) {
    _api = api;
  }

  Future<void> setLight(bool on) async {
    if (_lightOn == on) return;
    _lightOn = on;
    notifyListeners();
    final api = _api;
    if (api == null) return;
    await api.command(on ? '/lighton' : '/lightoff');
  }

  Future<void> toggle() async {
    await setLight(!_lightOn);
  }
}
