import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

import '../engine/torrent_controller.dart';

/// Android foreground-download bridge.
/// Native side: MainActivity + DownloadService (Kotlin).
class AndroidDownloadService {
  static const _channel = MethodChannel('org.opentorrent/service');

  static Future<void> ensureStarted(TorrentController controller) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startService');
    } catch (_) {
      // Service may be unavailable in debug without rebuilt APK — ignore.
    }
    Connectivity().onConnectivityChanged.listen((results) async {
      if (!controller.settings.wifiOnly) return;
      final wifi = results.contains(ConnectivityResult.wifi);
      if (!wifi) {
        for (final t in controller.torrents) {
          if (!t.paused) controller.pause(t.infoHash);
        }
      }
    });
  }
}
