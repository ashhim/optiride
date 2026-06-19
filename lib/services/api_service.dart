import 'dart:io';

class ApiService {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2)
    ..idleTimeout = const Duration(seconds: 3);

  Uri? _baseUri;

  Uri? get baseUri => _baseUri;

  void setBaseUri(Uri? uri) {
    _baseUri = uri;
  }

  Uri? _resolve(String path) {
    final base = _baseUri;
    if (base == null) return null;
    return Uri.parse('${base.toString()}$path');
  }

  Future<bool> ping() => _get('/ping');

  Future<bool> command(String path) => _get(path);

  Future<bool> _get(String path) async {
    final uri = _resolve(path);
    if (uri == null) return false;

    try {
      final request = await _client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.headers.set(HttpHeaders.connectionHeader, 'close');
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
