import 'dart:io';

import '../engine/torrent_controller.dart';

/// Opens magnet / .torrent / http(s) URLs from desktop CLI argv (Linux/Windows).
class DesktopDeepLinks {
  static Future<void> handleArgs(
    TorrentController controller,
    List<String> args,
  ) async {
    for (final raw in args) {
      final arg = raw.trim();
      if (arg.isEmpty || arg.startsWith('-')) continue;
      try {
        if (arg.startsWith('magnet:') || arg.contains('xt=urn:btih:')) {
          await controller.addMagnet(arg);
        } else if (arg.startsWith('http://') || arg.startsWith('https://')) {
          await controller.addTorrentUrl(arg);
        } else if (arg.startsWith('file:')) {
          final path = Uri.parse(arg).toFilePath();
          await controller.addTorrentFile(path);
        } else if (arg.endsWith('.torrent') || await File(arg).exists()) {
          await controller.addTorrentFile(arg);
        }
      } catch (e) {
        controller.reportError('Failed to open "$arg": $e');
      }
    }
  }
}
