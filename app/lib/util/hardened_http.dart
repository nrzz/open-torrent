import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Hardened HTTP fetch with size caps, timeouts, and HTTPS-downgrade rejection.
class HardenedHttp {
  HardenedHttp({
    this.maxBytes = 10 * 1024 * 1024,
    this.connectTimeout = const Duration(seconds: 15),
    this.totalTimeout = const Duration(seconds: 60),
    this.maxRedirects = 5,
    this.allowHttp = false,
  });

  final int maxBytes;
  final Duration connectTimeout;
  final Duration totalTimeout;
  final int maxRedirects;
  final bool allowHttp;

  /// Returns response body bytes. Throws [StateError] on policy violations.
  Future<Uint8List> getBytes(Uri uri, {Map<String, String>? headers}) async {
    _assertScheme(uri);
    final client = HttpClient()
      ..connectionTimeout = connectTimeout
      ..idleTimeout = connectTimeout
      ..autoUncompress = true;
    try {
      return await _getFollow(client, uri, headers: headers, hops: 0)
          .timeout(totalTimeout);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> getString(Uri uri, {Map<String, String>? headers}) async {
    final bytes = await getBytes(uri, headers: headers);
    return String.fromCharCodes(bytes);
  }

  void _assertScheme(Uri uri) {
    if (uri.scheme == 'https') return;
    if (uri.scheme == 'http' && allowHttp) return;
    throw StateError(
      allowHttp
          ? 'URL must be http(s)'
          : 'Only HTTPS URLs are allowed (enable allowHttpTorrents in settings for HTTP)',
    );
  }

  Future<Uint8List> _getFollow(
    HttpClient client,
    Uri uri, {
    Map<String, String>? headers,
    required int hops,
  }) async {
    if (hops > maxRedirects) {
      throw StateError('Too many redirects');
    }
    _assertScheme(uri);
    final req = await client.getUrl(uri);
    req.followRedirects = false;
    headers?.forEach(req.headers.set);
    final res = await req.close();
    if (res.statusCode >= 300 && res.statusCode < 400) {
      final loc = res.headers.value(HttpHeaders.locationHeader);
      await res.drain<void>();
      if (loc == null || loc.isEmpty) {
        throw StateError('Redirect without Location');
      }
      final next = uri.resolve(loc);
      if (uri.scheme == 'https' && next.scheme == 'http') {
        throw StateError('HTTPS to HTTP redirect rejected');
      }
      return _getFollow(client, next, headers: headers, hops: hops + 1);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      await res.drain<void>();
      throw StateError('HTTP ${res.statusCode}');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res) {
      if (builder.length + chunk.length > maxBytes) {
        throw StateError('Response exceeds $maxBytes bytes');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// True if bytes look like a bencoded torrent dictionary.
  static bool looksLikeTorrent(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    return bytes[0] == 0x64; // 'd'
  }
}
