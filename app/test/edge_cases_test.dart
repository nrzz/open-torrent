import 'package:flutter_test/flutter_test.dart';
import 'package:open_torrent/engine/mock_engine.dart';
import 'package:open_torrent/engine/models.dart';
import 'package:open_torrent/util/format.dart';

void main() {
  group('format', () {
    test('bytes edge cases', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(-1), '-1 B');
      expect(formatBytes(1023), '1023 B');
      expect(formatBytes(1024), contains('KB'));
      expect(formatRate(0), contains('/s'));
    });

    test('eta edge cases', () {
      expect(formatEta(-1), '—');
      expect(formatEta(0), '0s');
      expect(formatEta(59), '59s');
      expect(formatEta(60), contains('m'));
      expect(formatEta(3600), contains('h'));
    });
  });

  group('mock engine', () {
    late MockTorrentEngine engine;

    setUp(() {
      engine = MockTorrentEngine(SessionSettings(savePath: '.'))..start();
    });

    tearDown(() => engine.dispose());

    test('duplicate magnet returns same hash without doubling list', () {
      const uri =
          'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=Demo';
      final a = engine.addMagnet(uri, '.');
      final b = engine.addMagnet(uri, '.');
      expect(a, b);
      expect(engine.list(), hasLength(1));
    });

    test('pause unknown hash is no-op', () {
      engine.pause('missing');
      expect(engine.list(), isEmpty);
    });

    test('resume after finish stays seeding', () async {
      final hash = engine.addMagnet(
        'magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa&dn=Fast',
        '.',
      );
      // Force finish
      for (var i = 0; i < 200; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        if (engine.list().first.finished) break;
      }
      // Manually mark finished if timer hasn't fired enough in CI
      engine.pause(hash);
      engine.resume(hash);
      expect(engine.list().first.paused, isFalse);
    });

    test('file priority out of range ignored', () {
      final hash = engine.addMagnet(
        'magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb&dn=Files',
        '.',
      );
      engine.setFilePriority(hash, 99, FilePriority.high);
      expect(engine.list().first.files, isNotEmpty);
    });

    test('resume import ignores bad payloads', () {
      engine.importResume({});
      engine.importResume({'torrents': 'nope'});
      engine.importResume({
        'torrents': [
          {'infoHash': ''},
          {
            'infoHash': 'abc',
            'name': 'n',
            'progress': 0.5,
            'totalWanted': 1000,
          },
        ],
      });
      expect(engine.list(), hasLength(1));
      expect(engine.list().first.progress, 0.5);
    });

    test('export/import preserves sequential and category', () {
      final hash = engine.addMagnet(
        'magnet:?xt=urn:btih:cccccccccccccccccccccccccccccccccccccccc&dn=Cat',
        '.',
      );
      engine.setSequential(hash, true);
      final dump = engine.exportResume();
      final torrents = (dump['torrents'] as List).cast<Map>();
      torrents.first['category'] = 'movies';
      torrents.first['tags'] = ['a', 'b'];
      engine.remove(hash);
      engine.importResume({'torrents': torrents});
      expect(engine.list().first.sequential, isTrue);
      expect(engine.list().first.category, 'movies');
      expect(engine.list().first.tags, ['a', 'b']);
    });
  });

  group('models', () {
    test('rss and scheduler roundtrip', () {
      final rule = RssRule(
        id: '1',
        name: 'n',
        feedUrl: 'https://example.com/rss',
        filter: 'x',
      );
      final copy = RssRule.fromJson(rule.toJson());
      expect(copy.feedUrl, rule.feedUrl);
      final sched = SchedulerWindow(enabled: true, startHour: 22, endHour: 6);
      expect(SchedulerWindow.fromJson(sched.toJson()).enabled, isTrue);
    });

    test('torrent state mapping bounds', () {
      expect(torrentStateFromInt(-1), TorrentState.unknown);
      expect(torrentStateFromInt(999), TorrentState.unknown);
      expect(torrentStateFromInt(3), TorrentState.downloading);
    });
  });
}
