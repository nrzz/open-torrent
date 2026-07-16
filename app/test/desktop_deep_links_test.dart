import 'package:flutter_test/flutter_test.dart';
import 'package:open_torrent/engine/models.dart';
import 'package:open_torrent/engine/torrent_controller.dart';
import 'package:open_torrent/platform/desktop_deep_links.dart';

void main() {
  test('DesktopDeepLinks skips empty args and flags', () async {
    final c = TorrentController();
    await DesktopDeepLinks.handleArgs(c, ['', '  ', '-v', '--help']);
    expect(c.lastError, isNull);
  });

  test('DesktopDeepLinks reports error when engine not ready', () async {
    final c = TorrentController()
      ..usingMock = true
      ..settings = SessionSettings(savePath: '.');
    await DesktopDeepLinks.handleArgs(c, [
      'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=DeepLink',
    ]);
    expect(c.lastError, isNotNull);
    expect(c.lastError!, contains('Failed to open'));
  });
}
