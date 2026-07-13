import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_torrent/engine/mock_engine.dart';
import 'package:open_torrent/engine/models.dart';
import 'package:open_torrent/util/file_logger.dart';
import 'package:open_torrent/util/format.dart';
import 'package:path/path.dart' as p;

void main() {
  test('ETA formatting for unknown and large values', () {
    expect(formatEta(-1), isNot(contains('null')));
    expect(formatEta(0), isNotEmpty);
    expect(formatEta(3661), contains('h'));
  });

  test('mock resume survives pause and remove dump', () {
    final engine = MockTorrentEngine(SessionSettings(savePath: '.'))..start();
    final hash = engine.addMagnet(
      'magnet:?xt=urn:btih:fedcba9876543210fedcba9876543210fedcba98&dn=Resume',
      '.',
    );
    engine.pause(hash);
    final dump = engine.exportResume();
    final list = dump['torrents'] as List;
    expect(list, hasLength(1));
    expect((list.first as Map)['paused'], isTrue);
    engine.remove(hash);
    expect(engine.list(), isEmpty);
    engine.importResume(dump);
    expect(engine.list(), hasLength(1));
    expect(engine.list().first.paused, isTrue);
    engine.dispose();
  });

  test('file logger writes when enabled', () async {
    final dir = await Directory.systemTemp.createTemp('ot_log_');
    try {
      await FileLogger.instance.configure(dir.path, enabled: true);
      await FileLogger.instance.log('hello reliability');
      final path = FileLogger.instance.path!;
      expect(File(path).existsSync(), isTrue);
      final text = await File(path).readAsString();
      expect(text, contains('hello reliability'));
      final tail = await FileLogger.instance.readTail();
      expect(tail, contains('hello reliability'));
      expect(p.basename(path), 'opentorrent_debug.log');
    } finally {
      await FileLogger.instance.configure(dir.path, enabled: false);
      await dir.delete(recursive: true);
    }
  });

  test('debugLogging roundtrips in settings', () {
    final s = SessionSettings(savePath: '/tmp', debugLogging: true);
    final copy = SessionSettings.fromJson(s.toJson());
    expect(copy.debugLogging, isTrue);
  });
}
