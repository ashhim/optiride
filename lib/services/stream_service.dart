import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'api_service.dart';

class StreamService extends ChangeNotifier {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2)
    ..idleTimeout = const Duration(seconds: 2);

  ApiService? _api;
  Uri? _baseUri;
  Uint8List? _frame;
  String _status = 'idle';
  bool _running = false;
  bool _disposed = false;
  int _session = 0;
  List<int> _buffer = <int>[];
  StreamSubscription<List<int>>? _subscription;
  Timer? _watchdog;

  Uint8List? get frame => _frame;
  String get status => _status;
  bool get hasFrame => _frame != null;

  void bind(ApiService api) {
    if (identical(_api, api) && _baseUri == api.baseUri) {
      return;
    }
    _api = api;
    setBaseUri(api.baseUri);
  }

  void setBaseUri(Uri? uri) {
    if (_baseUri == uri) return;
    _baseUri = uri;
    _session++;
    _subscription?.cancel();
    _watchdog?.cancel();
    _subscription = null;
    _watchdog = null;
    _buffer = <int>[];
    _status = uri == null ? 'idle' : 'connecting';
    notifyListeners();
    _ensureLoop();
  }

  Future<void> _ensureLoop() async {
    if (_running || _disposed) return;
    _running = true;
    final mySession = _session;

    while (!_disposed && mySession == _session) {
      final uri = _baseUri;
      if (uri == null) {
        _status = 'idle';
        notifyListeners();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        continue;
      }

      try {
        _status = 'connecting';
        notifyListeners();

        final streamUri = uri.replace(port: 81, path: '/stream');
        final request = await _client.getUrl(streamUri);
        request.followRedirects = false;
        request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        request.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

        final response = await request.close().timeout(const Duration(seconds: 4));
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('Stream returned ${response.statusCode}');
        }

        _status = 'live';
        notifyListeners();
        await _consume(response, mySession);
      } catch (_) {
        if (_disposed || mySession != _session) break;
        _status = 'retrying';
        notifyListeners();
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    _running = false;
    if (!_disposed && mySession != _session && _baseUri != null) {
      _ensureLoop();
    }
  }

  Future<void> _consume(HttpClientResponse response, int session) async {
    final done = Completer<void>();
    var lastFrameAt = DateTime.now();

    late StreamSubscription<List<int>> subscription;
    subscription = response.listen(
      (chunk) {
        if (_disposed || session != _session) {
          return;
        }
        lastFrameAt = DateTime.now();
        _buffer.addAll(chunk);
        _extractFrames();
      },
      onError: (_) {
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );

    _subscription = subscription;
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || session != _session) {
        subscription.cancel();
        if (!done.isCompleted) done.complete();
        return;
      }

      if (DateTime.now().difference(lastFrameAt) > const Duration(seconds: 3)) {
        subscription.cancel();
        if (!done.isCompleted) done.complete();
      }
    });

    await done.future;
    await subscription.cancel();
    _watchdog?.cancel();
    _watchdog = null;
    _subscription = null;
    _buffer = <int>[];
  }

  void _extractFrames() {
    while (true) {
      final start = _indexOf(_buffer, const [0xFF, 0xD8], 0);
      if (start < 0) {
        if (_buffer.length > 1024 * 1024) {
          _buffer = <int>[];
        }
        return;
      }

      final end = _indexOf(_buffer, const [0xFF, 0xD9], start + 2);
      if (end < 0) {
        if (start > 0) {
          _buffer = _buffer.sublist(start);
        }
        return;
      }

      final frame = Uint8List.fromList(_buffer.sublist(start, end + 2));
      _frame = frame;
      notifyListeners();
      _buffer = _buffer.sublist(end + 2);
    }
  }

  int _indexOf(List<int> source, List<int> needle, int start) {
    if (needle.isEmpty || source.length < needle.length) return -1;
    for (var i = start; i <= source.length - needle.length; i++) {
      var matched = true;
      for (var j = 0; j < needle.length; j++) {
        if (source[i + j] != needle[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return i;
    }
    return -1;
  }

  @override
  void dispose() {
    _disposed = true;
    _session++;
    _subscription?.cancel();
    _watchdog?.cancel();
    _client.close(force: true);
    super.dispose();
  }
}
