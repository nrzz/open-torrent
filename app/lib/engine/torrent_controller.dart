import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'mock_engine.dart';
import 'models.dart';
import 'opentorrent_bindings.dart';
import '../util/file_logger.dart';
import '../util/hardened_http.dart';
import '../util/magnet_validator.dart';
import '../util/secure_credentials.dart';
import '../util/ssrf_guard.dart';

bool get forceMockEngine =>
    const bool.fromEnvironment('OPENTORRENT_MOCK', defaultValue: false);

class TorrentController extends ChangeNotifier {
  TorrentController({SecureCredentials? credentials})
      : _creds = credentials ?? SecureCredentials();

  final SecureCredentials _creds;

  SessionSettings settings = SessionSettings();
  SchedulerWindow scheduler = SchedulerWindow();
  final List<RssRule> rssRules = [];
  List<TorrentItem> torrents = [];
  String? lastError;
  bool ready = false;
  bool busy = false;
  bool usingMock = true;
  String engineVersion = 'mock';

  OpenTorrentNative? _native;
  ffi.Pointer<ffi.Void>? _session;
  MockTorrentEngine? _mock;
  Timer? _poll;
  Timer? _alertTimer;
  Timer? _resumeTimer;
  Timer? _schedulerTimer;
  String _resumeDir = '';
  String _metaPath = '';
  String _supportDir = '';
  bool _refreshing = false;

  Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    _supportDir = support.path;
    _resumeDir = p.join(support.path, 'resume');
    _metaPath = p.join(support.path, 'session_meta.json');
    await Directory(_resumeDir).create(recursive: true);

    await _loadMeta();
    await _migrateAndLoadCredentials();
    await FileLogger.instance.configure(
      support.path,
      enabled: settings.debugLogging,
    );
    if (settings.savePath.isEmpty) {
      final downloads = await getDownloadsDirectory();
      settings.savePath =
          downloads?.path ?? p.join(support.path, 'downloads');
      await Directory(settings.savePath).create(recursive: true);
    }

    if (!forceMockEngine) {
      _native = OpenTorrentNative.tryLoad();
    }

    if (_native != null) {
      usingMock = false;
      final settingsPtr = calloc<OtSessionSettings>();
      _writeSettings(settingsPtr.ref);
      _session = _native!.sessionCreate(settingsPtr);
      calloc.free(settingsPtr);
      engineVersion = _native!.version().cast<Utf8>().toDartString();
      _native!.setLogEnabled(_session!, settings.debugLogging ? 1 : 0);
      final resumePtr = _resumeDir.toNativeUtf8();
      _native!.loadResumeDir(_session!, resumePtr.cast());
      malloc.free(resumePtr);
      await FileLogger.instance.log('session started: $engineVersion');
    } else {
      usingMock = true;
      _mock = MockTorrentEngine(settings)..start();
      engineVersion = 'OpenTorrent/0.3.0 mock';
      await _loadMockResume();
      await FileLogger.instance.log('session started: mock');
    }

    ready = true;
    _refresh();
    // Status poll (no file list) — keep UI smooth with many torrents.
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    // Alerts drained more often so resume/error events are not delayed.
    _alertTimer =
        Timer.periodic(const Duration(milliseconds: 400), (_) => _drainAlerts());
    _resumeTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => saveResume());
    _schedulerTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _applyScheduler());
    notifyListeners();
  }

  Future<void> disposeController() async {
    await saveResume();
    _poll?.cancel();
    _alertTimer?.cancel();
    _resumeTimer?.cancel();
    _schedulerTimer?.cancel();
    _mock?.dispose();
    if (_session != null && _native != null) {
      _native!.sessionDestroy(_session!);
      _session = null;
    }
  }

  void clearError() {
    if (lastError == null) return;
    lastError = null;
    notifyListeners();
  }

  void reportError(String message) {
    lastError = message;
    notifyListeners();
  }

  String? get debugLogPath => FileLogger.instance.path;

  Future<String> addMagnet(String uri, {String? savePath}) async {
    lastError = null;
    busy = true;
    notifyListeners();
    try {
      final trimmed = uri.trim();
      if (!MagnetValidator.isValid(trimmed)) {
        lastError = trimmed.isEmpty
            ? 'Magnet link is empty'
            : 'Invalid magnet link (expected magnet:?xt=urn:btih:...)';
        notifyListeners();
        throw ArgumentError(lastError);
      }
      final magnetUri = MagnetValidator.normalize(trimmed);
      final path = savePath ?? settings.savePath;
      if (path.trim().isEmpty) {
        lastError = 'Save path is not set';
        notifyListeners();
        throw StateError(lastError!);
      }
      if (usingMock) {
        final hash = _mock!.addMagnet(magnetUri, path);
        _refresh();
        return hash;
      }
      final uriPtr = magnetUri.toNativeUtf8();
      final pathPtr = path.toNativeUtf8();
      final out = calloc<ffi.Char>(64);
      final code = _native!.addMagnet(
          _session!, uriPtr.cast(), pathPtr.cast(), out, 64);
      final hash = out.cast<Utf8>().toDartString();
      malloc.free(uriPtr);
      malloc.free(pathPtr);
      calloc.free(out);
      if (code != 0) {
        lastError = _nativeError('Failed to add magnet (code $code)');
        await FileLogger.instance.log('addMagnet failed: $lastError');
        notifyListeners();
        throw StateError(lastError!);
      }
      _refresh();
      return hash;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String> addTorrentFile(String filePath, {String? savePath}) async {
    lastError = null;
    busy = true;
    notifyListeners();
    try {
      final trimmed = filePath.trim();
      if (trimmed.isEmpty) {
        lastError = 'Torrent path is empty';
        notifyListeners();
        throw ArgumentError(lastError);
      }
      if (!File(trimmed).existsSync()) {
        lastError = 'Torrent file not found: $trimmed';
        notifyListeners();
        throw ArgumentError(lastError);
      }
      final path = savePath ?? settings.savePath;
      if (usingMock) {
        final hash = _mock!.addTorrentPath(trimmed, path);
        _refresh();
        return hash;
      }
      final filePtr = trimmed.toNativeUtf8();
      final pathPtr = path.toNativeUtf8();
      final out = calloc<ffi.Char>(64);
      final code = _native!.addTorrentFile(
          _session!, filePtr.cast(), pathPtr.cast(), out, 64);
      final hash = out.cast<Utf8>().toDartString();
      malloc.free(filePtr);
      malloc.free(pathPtr);
      calloc.free(out);
      if (code != 0) {
        lastError = _nativeError('Failed to add torrent file (code $code)');
        await FileLogger.instance.log('addTorrentFile failed: $lastError');
        notifyListeners();
        throw StateError(lastError!);
      }
      _refresh();
      return hash;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String> addTorrentUrl(String url, {String? savePath}) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      lastError = 'URL is empty';
      notifyListeners();
      throw ArgumentError(lastError);
    }
    if (trimmed.startsWith('magnet:') || trimmed.contains('xt=urn:btih:')) {
      return addMagnet(trimmed, savePath: savePath);
    }
    Uri parsed;
    try {
      parsed = Uri.parse(trimmed);
    } catch (_) {
      lastError = 'Invalid URL';
      notifyListeners();
      throw ArgumentError(lastError);
    }
    try {
      await SsrfGuard.assertSafeResolved(
        parsed,
        allowHttp: settings.allowHttpTorrents,
      );
      final http = HardenedHttp(allowHttp: settings.allowHttpTorrents);
      final bytes = await http.getBytes(parsed);
      if (bytes.isEmpty) {
        throw StateError('Empty torrent response');
      }
      if (!HardenedHttp.looksLikeTorrent(bytes)) {
        throw StateError('Response is not a valid .torrent (bencode)');
      }
      final tmp = File(p.join(
          _resumeDir, 'url_${DateTime.now().millisecondsSinceEpoch}.torrent'));
      await tmp.writeAsBytes(bytes);
      return addTorrentFile(tmp.path, savePath: savePath);
    } on TimeoutException {
      lastError = 'Timed out downloading torrent URL';
      notifyListeners();
      rethrow;
    } catch (e) {
      lastError = 'Failed to add torrent URL: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pause(String hash) async {
    if (usingMock) {
      _mock!.pause(hash);
    } else {
      final ptr = hash.toNativeUtf8();
      final code = _native!.pause(_session!, ptr.cast());
      malloc.free(ptr);
      if (code != 0) {
        lastError = _nativeError('Failed to pause torrent (code $code)');
        notifyListeners();
        return;
      }
      await saveResume();
    }
    _refresh();
  }

  Future<void> resume(String hash) async {
    if (usingMock) {
      _mock!.resume(hash);
    } else {
      final ptr = hash.toNativeUtf8();
      final code = _native!.resume(_session!, ptr.cast());
      malloc.free(ptr);
      if (code != 0) {
        lastError = _nativeError('Failed to resume torrent (code $code)');
        notifyListeners();
        return;
      }
    }
    _refresh();
  }

  Future<void> remove(String hash, {bool deleteFiles = false}) async {
    if (usingMock) {
      _mock!.remove(hash, deleteFiles: deleteFiles);
    } else {
      await saveResume();
      final ptr = hash.toNativeUtf8();
      final code =
          _native!.remove(_session!, ptr.cast(), deleteFiles ? 1 : 0);
      malloc.free(ptr);
      if (code != 0) {
        lastError = _nativeError('Failed to remove torrent (code $code)');
        notifyListeners();
        return;
      }
      await saveResume();
    }
    _refresh();
  }

  void setSequential(String hash, bool enabled) {
    if (usingMock) {
      _mock!.setSequential(hash, enabled);
    } else {
      final ptr = hash.toNativeUtf8();
      _native!.setSequential(_session!, ptr.cast(), enabled ? 1 : 0);
      malloc.free(ptr);
    }
    _refresh();
  }

  void setFilePriority(String hash, int index, FilePriority priority) {
    if (usingMock) {
      _mock!.setFilePriority(hash, index, priority);
    } else {
      final ptr = hash.toNativeUtf8();
      final code = _native!.setFilePriority(
          _session!, ptr.cast(), index, priority.nativeValue);
      malloc.free(ptr);
      if (code != 0) {
        lastError = _nativeError('Failed to set file priority (code $code)');
        notifyListeners();
        return;
      }
      // Optimistic UI update until next refreshFiles.
      final i = torrents.indexWhere((t) => t.infoHash == hash);
      if (i >= 0 && index >= 0 && index < torrents[i].files.length) {
        final files = List<FileEntry>.from(torrents[i].files);
        files[index] = files[index].copyWith(priority: priority);
        torrents[i] = torrents[i].copyWith(files: files);
      }
    }
    _refresh();
  }

  void updateCategory(String hash, String category) {
    final i = torrents.indexWhere((t) => t.infoHash == hash);
    if (i < 0) return;
    torrents[i] = torrents[i].copyWith(category: category);
    notifyListeners();
  }

  void updateTags(String hash, List<String> tags) {
    final i = torrents.indexWhere((t) => t.infoHash == hash);
    if (i < 0) return;
    torrents[i] = torrents[i].copyWith(tags: tags);
    notifyListeners();
  }

  Future<void> applySettings(SessionSettings next) async {
    settings = next;
    await FileLogger.instance.configure(
      _supportDir.isEmpty ? settings.savePath : _supportDir,
      enabled: settings.debugLogging,
    );
    await _creds.save(
      username: settings.proxyUsername,
      password: settings.proxyPassword,
    );
    if (usingMock) {
      _mock!.settings = next;
    } else if (_session != null) {
      final ptr = calloc<OtSessionSettings>();
      _writeSettings(ptr.ref);
      final code = _native!.applySettings(_session!, ptr);
      calloc.free(ptr);
      _native!.setLogEnabled(_session!, settings.debugLogging ? 1 : 0);
      if (code != 0) {
        lastError = _nativeError('Failed to apply settings (code $code)');
      }
    }
    await _saveMeta();
    notifyListeners();
  }

  Future<void> saveResume() async {
    if (usingMock) {
      final file = File(p.join(_resumeDir, 'mock_resume.json'));
      await file.writeAsString(_mock!.dumpResumeJson());
    } else if (_session != null) {
      final code = _native!.saveResume(_session!);
      if (code != 0) {
        lastError = _nativeError('Failed to save resume data (code $code)');
        await FileLogger.instance.log('saveResume failed: $lastError');
      }
      for (var i = 0; i < 12; i++) {
        final n = _pollNativeAlerts();
        if (n == 0) break;
      }
    }
    await _saveMeta();
  }

  /// Fetch file list for one torrent (detail view). List view skips this.
  Future<void> refreshFiles(String hash) async {
    if (usingMock || _session == null || _native == null) return;
    final i = torrents.indexWhere((t) => t.infoHash == hash);
    if (i < 0) return;
    final files = _readFiles(hash);
    torrents[i] = torrents[i].copyWith(files: files);
    notifyListeners();
  }

  void addRssRule(RssRule rule) {
    final trimmed = rule.feedUrl.trim();
    try {
      final uri = Uri.parse(trimmed);
      SsrfGuard.assertSafeUrl(uri, allowHttp: true);
    } catch (e) {
      lastError = 'Invalid RSS feed URL: $e';
      notifyListeners();
      return;
    }
    rssRules.add(rule);
    _saveMeta();
    notifyListeners();
  }

  void removeRssRule(String id) {
    rssRules.removeWhere((r) => r.id == id);
    _saveMeta();
    notifyListeners();
  }

  Future<void> pollRssFeeds() async {
    final http = HardenedHttp(
      allowHttp: settings.allowHttpTorrents,
      maxBytes: 2 * 1024 * 1024,
    );
    for (final rule in rssRules.where((r) => r.enabled)) {
      try {
        final uri = Uri.parse(rule.feedUrl);
        await SsrfGuard.assertSafeResolved(
          uri,
          allowHttp: settings.allowHttpTorrents,
        );
        final body = await http.getString(uri);
        final magnets = RegExp(r'magnet:\?[^\s"<>]+')
            .allMatches(body)
            .map((m) => m.group(0)!)
            .toList();
        final filter = rule.filter.trim().toLowerCase();
        for (final magnet in magnets) {
          final name = magnet.toLowerCase();
          if (filter.isNotEmpty && !name.contains(filter)) continue;
          if (rule.lastMatch == magnet) continue;
          await addMagnet(magnet);
          rule.lastMatch = magnet;
          break;
        }
      } catch (e) {
        lastError = 'RSS ${rule.name}: $e';
      }
    }
    await _saveMeta();
    notifyListeners();
  }

  void _refresh() {
    if (_refreshing) return;
    _refreshing = true;
    try {
      if (usingMock) {
        torrents = _mock!.list();
        notifyListeners();
        return;
      }
      _drainAlerts();
      final count = _native!.torrentCount(_session!);
      final prevByHash = {for (final t in torrents) t.infoHash: t};
      final next = <TorrentItem>[];
      for (var i = 0; i < count; i++) {
        final st = calloc<OtTorrentStatus>();
        final code = _native!.statusAt(_session!, i, st);
        if (code == 0) {
          final hash = _readArray(st.ref.infoHash, 64);
          final prev = prevByHash[hash];
          next.add(TorrentItem(
            infoHash: hash,
            name: _readArray(st.ref.name, 512),
            savePath: _readArray(st.ref.savePath, 1024),
            errorMessage: _readArray(st.ref.errorMessage, 512),
            state: torrentStateFromInt(st.ref.state),
            progress: st.ref.progress,
            totalWanted: st.ref.totalWanted,
            totalWantedDone: st.ref.totalWantedDone,
            totalDownload: st.ref.totalDownload,
            totalUpload: st.ref.totalUpload,
            downloadRate: st.ref.downloadRate,
            uploadRate: st.ref.uploadRate,
            numPeers: st.ref.numPeers,
            numSeeds: st.ref.numSeeds,
            queuePosition: st.ref.queuePosition,
            sequential: st.ref.sequential != 0,
            paused: st.ref.paused != 0,
            finished: st.ref.finished != 0,
            etaSeconds: st.ref.etaSeconds,
            files: prev?.files ?? const [],
            category: prev?.category ?? '',
            tags: prev?.tags ?? const [],
          ));
        }
        calloc.free(st);
      }
      torrents = next;
      notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  void _drainAlerts() {
    if (_native == null || _session == null) return;
    for (var i = 0; i < 4; i++) {
      if (_pollNativeAlerts() == 0) break;
    }
  }

  List<FileEntry> _readFiles(String hash) {
    final files = <FileEntry>[];
    final hashPtr = hash.toNativeUtf8();
    final fc = _native!.fileCount(_session!, hashPtr.cast());
    for (var f = 0; f < fc; f++) {
      final fe = calloc<OtFileEntry>();
      if (_native!.fileAt(_session!, hashPtr.cast(), f, fe) == 0) {
        files.add(FileEntry(
          path: _readArray(fe.ref.path, 1024),
          size: fe.ref.size,
          priority: FilePriorityX.fromNative(fe.ref.priority),
          progress: fe.ref.progress,
        ));
      }
      calloc.free(fe);
    }
    malloc.free(hashPtr);
    return files;
  }

  /// Returns number of alerts drained.
  int _pollNativeAlerts() {
    if (_native == null || _session == null) return 0;
    final buf = calloc<OtAlert>(32);
    final n = _native!.pollAlerts(_session!, buf, 32);
    for (var i = 0; i < n; i++) {
      final alert = buf[i];
      final msg = _readArray(alert.message, 1024);
      if (alert.type == 7 /* OT_ALERT_ERROR */ && msg.isNotEmpty) {
        lastError = msg;
        FileLogger.instance.log('engine error: $msg');
      }
    }
    calloc.free(buf);
    return n;
  }

  String _nativeError(String fallback) {
    if (_native == null || _session == null) return fallback;
    try {
      final ptr = _native!.lastError(_session!);
      final msg = ptr.cast<Utf8>().toDartString();
      if (msg.isNotEmpty) return msg;
    } catch (_) {}
    return fallback;
  }

  void _writeSettings(OtSessionSettings ref) {
    _writeArray(ref.savePath, 1024, settings.savePath);
    ref.listenPort = settings.listenPort;
    ref.downloadRateLimit = settings.downloadRateLimit;
    ref.uploadRateLimit = settings.uploadRateLimit;
    ref.maxConnections = settings.maxConnections;
    ref.maxUploads = settings.maxUploads;
    ref.enableDht = settings.enableDht ? 1 : 0;
    ref.enableLsd = settings.enableLsd ? 1 : 0;
    ref.enablePex = settings.enablePex ? 1 : 0;
    ref.encryptionMode = settings.encryptionMode;
    ref.sequentialDownloadDefault = settings.sequentialDefault ? 1 : 0;
    _writeArray(ref.proxyHost, 256, settings.proxyHost);
    ref.proxyPort = settings.proxyPort;
    _writeArray(ref.proxyUsername, 128, settings.proxyUsername);
    _writeArray(ref.proxyPassword, 128, settings.proxyPassword);
    _writeArray(ref.blocklistPath, 1024, settings.blocklistPath);
    ref.wifiOnly = settings.wifiOnly ? 1 : 0;
  }

  void _writeArray(ffi.Array<ffi.Char> arr, int len, String value) {
    final units = value.codeUnits;
    for (var i = 0; i < len; i++) {
      arr[i] = i < units.length ? units[i] : 0;
    }
    if (len > 0) arr[len - 1] = 0;
  }

  String _readArray(ffi.Array<ffi.Char> arr, int len) {
    final codes = <int>[];
    for (var i = 0; i < len; i++) {
      final c = arr[i];
      if (c == 0) break;
      codes.add(c);
    }
    return String.fromCharCodes(codes);
  }

  Future<void> _loadMeta() async {
    final file = File(_metaPath);
    if (!await file.exists()) return;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      settings = SessionSettings.fromJson(
          Map<String, Object?>.from(json['settings'] as Map? ?? {}));
      scheduler = SchedulerWindow.fromJson(
          Map<String, Object?>.from(json['scheduler'] as Map? ?? {}));
      final rules = json['rss'] as List? ?? [];
      rssRules
        ..clear()
        ..addAll(rules.map((e) => RssRule.fromJson(Map<String, Object?>.from(e as Map))));
    } catch (e) {
      lastError = 'Failed to load session meta: $e';
    }
  }

  /// Migrate legacy plaintext proxy credentials into secure storage, then scrub disk.
  Future<void> _migrateAndLoadCredentials() async {
    try {
      final legacyUser = settings.proxyUsername;
      final legacyPass = settings.proxyPassword;
      if (legacyUser.isNotEmpty || legacyPass.isNotEmpty) {
        await _creds.save(username: legacyUser, password: legacyPass);
        settings.proxyUsername = '';
        settings.proxyPassword = '';
        await _saveMeta(); // scrub plaintext from disk
      }
      final loaded = await _creds.load();
      settings.proxyUsername = loaded.username;
      settings.proxyPassword = loaded.password;
    } catch (e) {
      await FileLogger.instance.log('credential migration failed: $e');
    }
  }

  Future<void> _saveMeta() async {
    final file = File(_metaPath);
    await file.writeAsString(jsonEncode({
      'settings': settings.toJson(),
      'scheduler': scheduler.toJson(),
      'rss': rssRules.map((r) => r.toJson()).toList(),
    }));
  }

  Future<void> _loadMockResume() async {
    final file = File(p.join(_resumeDir, 'mock_resume.json'));
    if (!await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _mock!.importResume(Map<String, Object?>.from(data));
    } catch (_) {}
  }

  void _applyScheduler() {
    if (!scheduler.enabled) return;
    final hour = DateTime.now().hour;
    final inWindow = scheduler.startHour <= scheduler.endHour
        ? hour >= scheduler.startHour && hour < scheduler.endHour
        : hour >= scheduler.startHour || hour < scheduler.endHour;
    final next = settings.copy();
    if (inWindow) {
      next.downloadRateLimit = scheduler.limitedDownloadRate;
      next.uploadRateLimit = scheduler.limitedUploadRate;
    }
    applySettings(next);
  }
}
