import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class HudSettingsController extends ChangeNotifier {
  bool _singleJoystickMode = false;
  double _buttonScale = 1.0;
  double _buttonOpacity = 0.78;
  double _edgeInset = 0.0;
  double _bottomOffset = 0.0;
  Timer? _saveDebounce;
  bool _loaded = false;

  bool get singleJoystickMode => _singleJoystickMode;
  double get buttonScale => _buttonScale;
  double get buttonOpacity => _buttonOpacity;
  double get edgeInset => _edgeInset;
  double get bottomOffset => _bottomOffset;
  bool get loaded => _loaded;

  HudSettingsController() {
    unawaited(_load());
  }

  void setSingleJoystickMode(bool value) {
    if (_singleJoystickMode == value) return;
    _singleJoystickMode = value;
    notifyListeners();
    _scheduleSave();
  }

  void setButtonScale(double value) {
    final next = value.clamp(0.75, 1.35).toDouble();
    if (_buttonScale == next) return;
    _buttonScale = next;
    notifyListeners();
    _scheduleSave();
  }

  void setButtonOpacity(double value) {
    final next = value.clamp(0.35, 1.0).toDouble();
    if (_buttonOpacity == next) return;
    _buttonOpacity = next;
    notifyListeners();
    _scheduleSave();
  }

  void setEdgeInset(double value) {
    final next = value.clamp(0.0, 48.0).toDouble();
    if (_edgeInset == next) return;
    _edgeInset = next;
    notifyListeners();
    _scheduleSave();
  }

  void setBottomOffset(double value) {
    final next = value.clamp(-36.0, 86.0).toDouble();
    if (_bottomOffset == next) return;
    _bottomOffset = next;
    notifyListeners();
    _scheduleSave();
  }

  Future<void> _load() async {
    try {
      final file = _settingsFile();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _singleJoystickMode = data['singleJoystickMode'] == true;
        _buttonScale = _asDouble(data['buttonScale'], 1.0).clamp(0.75, 1.35).toDouble();
        _buttonOpacity = _asDouble(data['buttonOpacity'], 0.78).clamp(0.35, 1.0).toDouble();
        _edgeInset = _asDouble(data['edgeInset'], 0.0).clamp(0.0, 48.0).toDouble();
        _bottomOffset = _asDouble(data['bottomOffset'], 0.0).clamp(-36.0, 86.0).toDouble();
      }
    } catch (_) {
      // Settings are a convenience. Bad local data should not block driving.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_save());
    });
  }

  Future<void> _save() async {
    try {
      final file = _settingsFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(<String, Object>{
        'singleJoystickMode': _singleJoystickMode,
        'buttonScale': _buttonScale,
        'buttonOpacity': _buttonOpacity,
        'edgeInset': _edgeInset,
        'bottomOffset': _bottomOffset,
      }));
    } catch (_) {
      // Fall back to in-memory settings if the platform path is unavailable.
    }
  }

  File _settingsFile() {
    final env = Platform.environment;
    final base = env['APPDATA'] ??
        env['LOCALAPPDATA'] ??
        env['HOME'] ??
        env['USERPROFILE'] ??
        Directory.current.path;
    return File('$base${Platform.pathSeparator}OptiRide${Platform.pathSeparator}hud_settings.json');
  }

  double _asDouble(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }
}
