import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_torrent/engine/mock_engine.dart';
import 'package:open_torrent/engine/models.dart';
import 'package:open_torrent/engine/torrent_controller.dart';
import 'package:open_torrent/ui/home_page.dart';

void main() {
  testWidgets('home empty state renders', (tester) async {
    final c = TorrentController();
    c.ready = true;
    c.usingMock = true;
    c.engineVersion = 'test';
    c.settings = SessionSettings(savePath: '.');
    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: c)),
    );
    expect(find.text('No torrents yet'), findsOneWidget);
    expect(find.text('OpenTorrent'), findsOneWidget);
    expect(find.textContaining('Mock engine'), findsOneWidget);
  });

  test('mock list drives tile data', () {
    final engine = MockTorrentEngine(SessionSettings(savePath: '.'))..start();
    final hash = engine.addMagnet(
      'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=WidgetDemo',
      '.',
    );
    expect(hash, isNotEmpty);
    expect(engine.list().first.name, 'WidgetDemo');
    engine.dispose();
  });
}
