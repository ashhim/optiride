import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ConnectionController extends ChangeNotifier {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2)
    ..idleTimeout = const Duration(seconds: 2);

  String _input = '';
  String? _host;
  Uri? _baseUri;
  bool _connected = false;
  bool _checking = false;
  String _statusText = 'disconnected';
  String? _errorText;
  Timer? _retryTimer;
  bool _disposed = false;

  String get input => _input;
  String? get host => _host;
  Uri? get baseUri => _baseUri;
  bool get connected => _connected;
  bool get checking => _checking;
  String get statusText => _statusText;
  String? get errorText => _errorText;

  void setInput(String value) {
    final previousHost = _host;
    _input = value.trim();
    final host = _sanitizeHost(_input);
    if (host == null) {
      _host = null;
      _baseUri = null;
      _connected = false;
      _checking = false;
      _statusText = 'enter ip';
      _errorText = 'Invalid IP address';
      _retryTimer?.cancel();
      notifyListeners();
      return;
    }

    _host = host;
    _baseUri = Uri.parse('http://$host');
    if (previousHost != host) {
      _connected = false;
      _retryTimer?.cancel();
      _retryTimer = null;
    }
    _errorText = null;
    _statusText = _connected ? 'connected' : 'ready';
    notifyListeners();
  }

  Future<bool> connect() async {
    final host = _host;
    if (host == null) return false;

    _retryTimer?.cancel();
    _retryTimer = null;
    _checking = true;
    _statusText = 'checking';
    notifyListeners();

    try {
      final request = await _client.getUrl(Uri.parse('http://$host/ping?t=${DateTime.now().millisecondsSinceEpoch}'));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.headers.set(HttpHeaders.connectionHeader, 'close');
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      _setConnectivity(ok);
      if (ok) {
        _retryTimer?.cancel();
        _retryTimer = null;
      } else {
        _scheduleRetry();
      }
      return ok;
    } catch (_) {
      _setConnectivity(false, error: 'Ping failed');
      _scheduleRetry();
      return false;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  Future<bool> pingOnce() async {
    final host = _host;
    if (host == null) return false;

    try {
      final request = await _client.getUrl(Uri.parse('http://$host/ping?t=${DateTime.now().millisecondsSinceEpoch}'));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.headers.set(HttpHeaders.connectionHeader, 'close');
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      _setConnectivity(ok);
      return ok;
    } catch (_) {
      _setConnectivity(false, error: 'Ping failed');
      return false;
    }
  }

  void _scheduleRetry() {
    if (_disposed || _host == null || _connected) return;
    if (_retryTimer?.isActive == true) return;

    _retryTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_disposed || _host == null) return;
      final ok = await pingOnce();
      if (ok) {
        _retryTimer?.cancel();
        _retryTimer = null;
      }
    });
  }

  void _setConnectivity(bool connected, {String? error}) {
    _connected = connected;
    _statusText = connected ? 'connected' : 'disconnected';
    _errorText = connected ? null : error ?? _errorText;
    notifyListeners();
  }

  String? _sanitizeHost(String input) {
    if (input.isEmpty) return null;

    var candidate = input;
    if (candidate.startsWith('http://')) candidate = candidate.substring(7);
    if (candidate.startsWith('https://')) candidate = candidate.substring(8);
    candidate = candidate.split('/').first;
    candidate = candidate.split(':').first;

    final ip = InternetAddress.tryParse(candidate);
    if (ip == null || ip.type != InternetAddressType.IPv4) return null;
    return ip.address;
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _client.close(force: true);
    super.dispose();
  }
}
