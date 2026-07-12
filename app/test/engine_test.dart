import 'package:flutter_test/flutter_test.dart';
import 'package:open_torrent/engine/mock_engine.dart';
import 'package:open_torrent/engine/models.dart';
import 'package:open_torrent/util/format.dart';

void main() {
  test('formatBytes scales', () {
    expect(formatBytes(500), '500 B');
    expect(formatBytes(2048), contains('KB'));
    expect(formatBytes(5 * 1024 * 1024), contains('MB'));
  });

  test('mock engine add/pause/resume/remove', () {
    final engine = MockTorrentEngine(SessionSettings(savePath: '.'))..start();
    final hash = engine.addMagnet(
      'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=Demo',
      '.',
    );
    expect(engine.list(), hasLength(1));
    expect(engine.list().first.name, 'Demo');
    engine.pause(hash);
    expect(engine.list().first.paused, isTrue);
    engine.resume(hash);
    expect(engine.list().first.paused, isFalse);
    engine.setSequential(hash, true);
    expect(engine.list().first.sequential, isTrue);
    engine.setFilePriority(hash, 0, FilePriority.skip);
    expect(engine.list().first.files.first.priority, FilePriority.skip);
    final dump = engine.exportResume();
    engine.remove(hash);
    expect(engine.list(), isEmpty);
    engine.importResume(dump);
    expect(engine.list(), hasLength(1));
    engine.dispose();
  });

  test('session settings roundtrip', () {
    final s = SessionSettings(savePath: '/tmp', wifiOnly: true, locale: 'hi');
    final copy = SessionSettings.fromJson(s.toJson());
    expect(copy.savePath, '/tmp');
    expect(copy.wifiOnly, isTrue);
    expect(copy.locale, 'hi');
  });
}
