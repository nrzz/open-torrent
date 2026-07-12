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
import '../util/magnet_validator.dart';

bool get forceMockEngine =>
    const bool.fromEnvironment('OPENTORRENT_MOCK', defaultValue: false);

class TorrentController extends ChangeNotifier {
  TorrentController();

  SessionSettings settings = SessionSettings();
  SchedulerWindow scheduler = SchedulerWindow();
  final List<RssRule> rssRules = [];
  List<TorrentItem> torrents = [];
  String? lastError;
  bool ready = false;
  bool usingMock = true;
  String engineVersion = 'mock';

  OpenTorrentNative? _native;
  ffi.Pointer<ffi.Void>? _session;
  MockTorrentEngine? _mock;
  Timer? _poll;
  Timer? _resumeTimer;
  Timer? _schedulerTimer;
  String _resumeDir = '';
  String _metaPath = '';

  Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    _resumeDir = p.join(support.path, 'resume');
    _metaPath = p.join(support.path, 'session_meta.json');
    await Directory(_resumeDir).create(recursive: true);

    await _loadMeta();
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
      final resumePtr = _resumeDir.toNativeUtf8();
      _native!.loadResumeDir(_session!, resumePtr.cast());
      malloc.free(resumePtr);
    } else {
      usingMock = true;
      _mock = MockTorrentEngine(settings)..start();
      engineVersion = 'OpenTorrent/0.2.1 mock';
      await _loadMockResume();
    }

    ready = true;
    _refresh();
    _poll = Timer.periodic(const Duration(milliseconds: 800), (_) => _refresh());
    _resumeTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => saveResume());
    _schedulerTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _applyScheduler());
    notifyListeners();
  }

  Future<void> disposeController() async {
    await saveResume();
    _poll?.cancel();
    _resumeTimer?.cancel();
    _schedulerTimer?.cancel();
    _mock?.dispose();
    if (_session != null && _native != null) {
      _native!.sessionDestroy(_session!);
      _session = null;
    }
  }

  Future<String> addMagnet(String uri, {String? savePath}) async {
    lastError = null;
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
      lastError = 'Failed to add magnet (code $code)';
      notifyListeners();
      throw StateError(lastError!);
    }
    _refresh();
    return hash;
  }

  Future<String> addTorrentFile(String filePath, {String? savePath}) async {
    lastError = null;
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
      lastError = 'Failed to add torrent file (code $code)';
      notifyListeners();
      throw StateError(lastError!);
    }
    _refresh();
    return hash;
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
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      lastError = 'URL must be http(s) or magnet';
      notifyListeners();
      throw ArgumentError(lastError);
    }
    final client = HttpClient();
    try {
      final req = await client.getUrl(parsed);
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode >= 400) {
        throw StateError('HTTP ${res.statusCode}');
      }
      final bytes = await consolidateHttpClientResponseBytes(res)
          .timeout(const Duration(seconds: 60));
      if (bytes.isEmpty) {
        throw StateError('Empty torrent response');
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
    } finally {
      client.close(force: true);
    }
  }

  void pause(String hash) {
    if (usingMock) {
      _mock!.pause(hash);
    } else {
      final ptr = hash.toNativeUtf8();
      _native!.pause(_session!, ptr.cast());
      malloc.free(ptr);
    }
    _refresh();
  }

  void resume(String hash) {
    if (usingMock) {
      _mock!.resume(hash);
    } else {
      final ptr = hash.toNativeUtf8();
      _native!.resume(_session!, ptr.cast());
      malloc.free(ptr);
    }
    _refresh();
  }

  void remove(String hash, {bool deleteFiles = false}) {
    if (usingMock) {
      _mock!.remove(hash, deleteFiles: deleteFiles);
    } else {
      final ptr = hash.toNativeUtf8();
      _native!.remove(_session!, ptr.cast(), deleteFiles ? 1 : 0);
      malloc.free(ptr);
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
      _native!.setFilePriority(
          _session!, ptr.cast(), index, priority.nativeValue);
      malloc.free(ptr);
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
    if (usingMock) {
      _mock!.settings = next;
    } else if (_session != null) {
      final ptr = calloc<OtSessionSettings>();
      _writeSettings(ptr.ref);
      _native!.applySettings(_session!, ptr);
      calloc.free(ptr);
    }
    await _saveMeta();
    notifyListeners();
  }

  Future<void> saveResume() async {
    if (usingMock) {
      final file = File(p.join(_resumeDir, 'mock_resume.json'));
      await file.writeAsString(_mock!.dumpResumeJson());
    } else if (_session != null) {
      _native!.saveResume(_session!);
      // Drain alerts so resume files are written.
      _pollNativeAlerts();
    }
    await _saveMeta();
  }

  void addRssRule(RssRule rule) {
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
    for (final rule in rssRules.where((r) => r.enabled)) {
      try {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse(rule.feedUrl));
        final res = await req.close();
        final body = await res.transform(utf8.decoder).join();
        client.close(force: true);
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
    if (usingMock) {
      torrents = _mock!.list();
      notifyListeners();
      return;
    }
    _pollNativeAlerts();
    final count = _native!.torrentCount(_session!);
    final next = <TorrentItem>[];
    for (var i = 0; i < count; i++) {
      final st = calloc<OtTorrentStatus>();
      final code = _native!.statusAt(_session!, i, st);
      if (code == 0) {
        final hash = _readArray(st.ref.infoHash, 64);
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
          files: files,
        ));
      }
      calloc.free(st);
    }
    // Preserve category/tags from previous list
    for (var i = 0; i < next.length; i++) {
      final prev = torrents.where((t) => t.infoHash == next[i].infoHash);
      if (prev.isNotEmpty) {
        next[i] = next[i].copyWith(
          category: prev.first.category,
          tags: prev.first.tags,
        );
      }
    }
    torrents = next;
    notifyListeners();
  }

  void _pollNativeAlerts() {
    if (_native == null || _session == null) return;
    final buf = calloc<OtAlert>(32);
    _native!.pollAlerts(_session!, buf, 32);
    calloc.free(buf);
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
