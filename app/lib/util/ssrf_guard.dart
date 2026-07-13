import 'dart:io';

/// Blocks private / loopback / link-local / metadata IPs (SSRF guard).
class SsrfGuard {
  static final _privateV4 = [
    RegExp(r'^127\.'),
    RegExp(r'^10\.'),
    RegExp(r'^192\.168\.'),
    RegExp(r'^169\.254\.'),
    RegExp(r'^0\.'),
    RegExp(r'^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.'), // CGNAT 100.64/10
  ];

  static bool isPrivateHost(String host) {
    final h = host.toLowerCase().trim();
    if (h.isEmpty || h == 'localhost' || h == '::1' || h == '[::1]') {
      return true;
    }
    if (h.endsWith('.local') || h.endsWith('.internal')) return true;
    // IPv6 ULA / link-local / loopback prefixes
    if (h.startsWith('fe80:') ||
        h.startsWith('fc') ||
        h.startsWith('fd') ||
        h == '::' ||
        h.startsWith('::ffff:127.')) {
      return true;
    }
    for (final re in _privateV4) {
      if (re.hasMatch(h)) return true;
    }
    // 172.16.0.0 – 172.31.255.255
    final m = RegExp(r'^172\.(\d+)\.').firstMatch(h);
    if (m != null) {
      final second = int.tryParse(m.group(1)!) ?? -1;
      if (second >= 16 && second <= 31) return true;
    }
    return false;
  }

  /// Validates feed/download URL: scheme + host SSRF check.
  static void assertSafeUrl(Uri uri, {bool allowHttp = true}) {
    if (uri.scheme != 'https' && !(allowHttp && uri.scheme == 'http')) {
      throw ArgumentError('URL must be http(s)');
    }
    final host = uri.host;
    if (host.isEmpty) throw ArgumentError('URL host is empty');
    if (isPrivateHost(host)) {
      throw ArgumentError('URL host is not allowed (private/loopback)');
    }
  }

  /// Resolve host and reject if any address is private (best-effort).
  static Future<void> assertSafeResolved(Uri uri, {bool allowHttp = true}) async {
    assertSafeUrl(uri, allowHttp: allowHttp);
    try {
      final list = await InternetAddress.lookup(uri.host)
          .timeout(const Duration(seconds: 5));
      for (final addr in list) {
        if (isPrivateHost(addr.address)) {
          throw ArgumentError('Resolved address is private: ${addr.address}');
        }
      }
    } on ArgumentError {
      rethrow;
    } catch (_) {
      // DNS failure — leave to HTTP client.
    }
  }
}
