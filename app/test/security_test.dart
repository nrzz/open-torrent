import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_torrent/engine/models.dart';
import 'package:open_torrent/util/hardened_http.dart';
import 'package:open_torrent/util/ssrf_guard.dart';

void main() {
  group('SsrfGuard', () {
    test('blocks loopback and private hosts', () {
      expect(SsrfGuard.isPrivateHost('127.0.0.1'), isTrue);
      expect(SsrfGuard.isPrivateHost('localhost'), isTrue);
      expect(SsrfGuard.isPrivateHost('10.0.0.5'), isTrue);
      expect(SsrfGuard.isPrivateHost('192.168.1.1'), isTrue);
      expect(SsrfGuard.isPrivateHost('172.16.0.1'), isTrue);
      expect(SsrfGuard.isPrivateHost('169.254.1.1'), isTrue);
      expect(SsrfGuard.isPrivateHost('example.com'), isFalse);
      expect(SsrfGuard.isPrivateHost('8.8.8.8'), isFalse);
    });

    test('assertSafeUrl rejects bad schemes and private hosts', () {
      expect(
        () => SsrfGuard.assertSafeUrl(Uri.parse('ftp://example.com/a')),
        throwsArgumentError,
      );
      expect(
        () => SsrfGuard.assertSafeUrl(Uri.parse('http://127.0.0.1/x')),
        throwsArgumentError,
      );
      expect(
        () => SsrfGuard.assertSafeUrl(Uri.parse('https://example.com/feed')),
        returnsNormally,
      );
    });
  });

  group('HardenedHttp', () {
    test('looksLikeTorrent detects bencode dictionary', () {
      expect(HardenedHttp.looksLikeTorrent(Uint8List.fromList('d4:infod'.codeUnits)),
          isTrue);
      expect(HardenedHttp.looksLikeTorrent(Uint8List.fromList('<html>'.codeUnits)),
          isFalse);
      expect(HardenedHttp.looksLikeTorrent(Uint8List(0)), isFalse);
    });
  });

  group('SessionSettings secrets scrub', () {
    test('toJson omits proxy credentials', () {
      final s = SessionSettings(
        savePath: '/tmp',
        proxyUsername: 'user',
        proxyPassword: 'secret',
        allowHttpTorrents: true,
      );
      final json = s.toJson();
      expect(json.containsKey('proxyPassword'), isFalse);
      expect(json.containsKey('proxyUsername'), isFalse);
      expect(json['allowHttpTorrents'], isTrue);
      expect(json['proxyHost'], '');
    });

    test('copy preserves in-memory credentials', () {
      final s = SessionSettings(proxyUsername: 'u', proxyPassword: 'p');
      final c = s.copy();
      expect(c.proxyUsername, 'u');
      expect(c.proxyPassword, 'p');
      expect(c.toJson().containsKey('proxyPassword'), isFalse);
    });
  });
}
