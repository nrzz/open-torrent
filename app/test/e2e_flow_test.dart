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
}
