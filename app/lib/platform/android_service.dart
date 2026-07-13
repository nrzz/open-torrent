import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../engine/torrent_controller.dart';

/// Android foreground-download bridge + deep-link intake.
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

    await _requestNotifications();
    await _consumeInitialUri(controller);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIncomingUri') {
        final uri = call.arguments?.toString();
        if (uri != null && uri.isNotEmpty) {
          await _addIncoming(controller, uri);
        }
      }
      return null;
    });

    Connectivity().onConnectivityChanged.listen((results) async {
      if (!controller.settings.wifiOnly) return;
      final wifi = results.contains(ConnectivityResult.wifi);
      if (!wifi) {
        for (final t in List.of(controller.torrents)) {
          if (!t.paused) await controller.pause(t.infoHash);
        }
        await controller.saveResume();
      } else {
        for (final t in List.of(controller.torrents)) {
          if (t.paused && !t.finished) await controller.resume(t.infoHash);
        }
      }
    });
  }

  static Future<void> _requestNotifications() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> _consumeInitialUri(TorrentController controller) async {
    try {
      final uri = await _channel.invokeMethod<String>('getInitialUri');
      if (uri != null && uri.isNotEmpty) {
        await _addIncoming(controller, uri);
      }
    } catch (_) {}
  }

  static Future<void> _addIncoming(
      TorrentController controller, String uri) async {
    try {
      final trimmed = uri.trim();
      if (trimmed.isEmpty || trimmed.length > 8192) {
        controller.reportError('Rejected incoming link (empty or too long)');
        return;
      }
      if (trimmed.startsWith('magnet:') || trimmed.contains('xt=urn:btih:')) {
        await controller.addMagnet(trimmed);
      } else if (trimmed.startsWith('http://') ||
          trimmed.startsWith('https://')) {
        await controller.addTorrentUrl(trimmed);
      } else if (trimmed.startsWith('content:') ||
          trimmed.startsWith('file:') ||
          trimmed.endsWith('.torrent')) {
        final path = trimmed.startsWith('file:')
            ? Uri.parse(trimmed).toFilePath()
            : trimmed;
        await controller.addTorrentFile(path);
      } else {
        controller.reportError('Rejected unsupported incoming URI scheme');
      }
    } catch (e) {
      controller.reportError('Failed to open incoming link: $e');
    }
  }
}
