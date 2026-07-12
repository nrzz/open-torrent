import 'package:flutter_test/flutter_test.dart';
import 'package:open_torrent/engine/mock_engine.dart';
import 'package:open_torrent/engine/models.dart';
import 'package:open_torrent/util/magnet_validator.dart';

void main() {
  test('end-to-end mock add → pause → resume → remove', () {
    final engine = MockTorrentEngine(SessionSettings(savePath: r'C:\Downloads'))
      ..start();
    expect(MagnetValidator.isValid('not a magnet'), isFalse);

    const magnet =
        'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=E2E';
    expect(MagnetValidator.isValid(magnet), isTrue);
    final hash =
        engine.addMagnet(MagnetValidator.normalize(magnet), r'C:\Downloads');
    expect(engine.list(), hasLength(1));
    expect(engine.list().first.name, 'E2E');
    expect(engine.list().first.savePath, r'C:\Downloads');

    engine.pause(hash);
    expect(engine.list().first.paused, isTrue);
    engine.resume(hash);
    expect(engine.list().first.paused, isFalse);

    final resume = engine.exportResume();
    engine.remove(hash);
    expect(engine.list(), isEmpty);
    engine.importResume(resume);
    expect(engine.list(), hasLength(1));
    engine.dispose();
  });

  test('multi-torrent filter metadata round-trip', () {
    final engine = MockTorrentEngine(SessionSettings(savePath: r'C:\Downloads'))
      ..start();
    final a = engine.addMagnet(
      'magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa&dn=Alpha',
      r'C:\Downloads',
    );
    final b = engine.addMagnet(
      'magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb&dn=Beta',
      r'C:\Downloads',
    );
    expect(a, isNot(equals(b)));
    expect(engine.list(), hasLength(2));

    engine.setCategory(a, 'movies');
    engine.setTags(b, ['linux', 'iso']);
    final listed = engine.list();
    expect(listed.firstWhere((t) => t.infoHash == a).category, 'movies');
    expect(listed.firstWhere((t) => t.infoHash == b).tags, ['linux', 'iso']);

    engine.setSequential(a, true);
    expect(engine.list().firstWhere((t) => t.infoHash == a).sequential, isTrue);

    engine.remove(a);
    engine.remove(b);
    expect(engine.list(), isEmpty);
    engine.dispose();
  });

  test('invalid magnets rejected by validator', () {
    expect(MagnetValidator.isValid(''), isFalse);
    expect(MagnetValidator.isValid('http://example.com/x.torrent'), isFalse);
    expect(MagnetValidator.isValid('magnet:?dn=nohash'), isFalse);
    expect(MagnetValidator.isValid('abcd'), isFalse);
    expect(
      MagnetValidator.normalize(
          '0123456789ABCDEF0123456789ABCDEF01234567'),
      startsWith('magnet:?xt=urn:btih:'),
    );
  });
}
