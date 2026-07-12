import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

import 'engine/torrent_controller.dart';
import 'platform/android_service.dart';
import 'ui/home_page.dart';

final torrentController = TorrentController();
final notifications = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    try {
      await windowManager.ensureInitialized();
      const opts = WindowOptions(
        size: Size(1100, 720),
        minimumSize: Size(800, 560),
        title: 'OpenTorrent',
      );
      await windowManager.waitUntilReadyToShow(opts, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e, st) {
      debugPrint('window_manager init failed: $e\n$st');
    }
  }

  try {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await notifications.initialize(initSettings);
  } catch (e) {
    debugPrint('notifications init failed: $e');
  }

  try {
    await torrentController.init();
  } catch (e, st) {
    debugPrint('engine init failed: $e\n$st');
    // Fall back to mock so UI still opens.
    if (!torrentController.ready) {
      torrentController.usingMock = true;
      torrentController.ready = true;
    }
  }

  if (Platform.isAndroid) {
    await AndroidDownloadService.ensureStarted(torrentController);
  }

  runApp(const OpenTorrentApp());
}

class OpenTorrentApp extends StatefulWidget {
  const OpenTorrentApp({super.key});

  @override
  State<OpenTorrentApp> createState() => _OpenTorrentAppState();
}

class _OpenTorrentAppState extends State<OpenTorrentApp>
    with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();
    torrentController.addListener(_onEngine);
    if (Platform.isWindows) {
      try {
        windowManager.addListener(this);
        trayManager.addListener(this);
        _initTray();
      } catch (e) {
        debugPrint('tray/window listeners failed: $e');
      }
    }
  }

  Future<void> _initTray() async {
    try {
      await trayManager.setToolTip('OpenTorrent');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: 'Show'),
        MenuItem(key: 'quit', label: 'Quit'),
      ]));
    } catch (_) {}
  }

  void _onEngine() {
    if (!mounted) return;
    setState(() {});
    _updateNotification();
  }

  Future<void> _updateNotification() async {
    if (!Platform.isAndroid) return;
    final active = torrentController.torrents
        .where((t) => !t.paused && !t.finished)
        .length;
    if (active == 0) return;
    try {
      const android = AndroidNotificationDetails(
        'downloads',
        'Downloads',
        channelDescription: 'Torrent download progress',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        showProgress: true,
        maxProgress: 100,
        progress: 0,
      );
      await notifications.show(
        1,
        'OpenTorrent',
        '$active active download(s)',
        const NotificationDetails(android: android),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    torrentController.removeListener(_onEngine);
    if (Platform.isWindows) {
      try {
        windowManager.removeListener(this);
        trayManager.removeListener(this);
      } catch (_) {}
    }
    torrentController.disposeController();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    try {
      await torrentController.saveResume();
      await windowManager.hide();
    } catch (_) {}
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayMenuItemClick(MenuItem item) async {
    if (item.key == 'show') await windowManager.show();
    if (item.key == 'quit') {
      await torrentController.saveResume();
      await windowManager.destroy();
    }
  }

  ThemeMode get _themeMode {
    return switch (torrentController.settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0B6E4F);
    return MaterialApp(
      title: 'OpenTorrent',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      locale: Locale(torrentController.settings.locale),
      home: torrentController.ready
          ? HomePage(controller: torrentController)
          : const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
    );
  }
}
