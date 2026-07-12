import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'models.dart';

/// In-process engine used when the native libtorrent DLL is unavailable.
class MockTorrentEngine {
  MockTorrentEngine(this.settings);

  SessionSettings settings;
  final _torrents = <String, TorrentItem>{};
  final _order = <String>[];
  final _rng = Random();
  Timer? _tick;

  void start() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _advance());
  }

  void dispose() {
    _tick?.cancel();
  }

  List<TorrentItem> list() =>
      _order.map((h) => _torrents[h]!).toList(growable: false);

  String addMagnet(String uri, String savePath) {
    final hash = _hash(uri);
    if (_torrents.containsKey(hash)) return hash;
    final name = _nameFromMagnet(uri);
    final size = (50 + _rng.nextInt(200)) * 1024 * 1024;
    final item = TorrentItem(
      infoHash: hash,
      name: name,
      savePath: savePath.isEmpty ? settings.savePath : savePath,
      state: TorrentState.downloading,
      progress: 0.02,
      totalWanted: size,
      totalWantedDone: (size * 0.02).round(),
      downloadRate: 200 * 1024,
      numPeers: 2 + _rng.nextInt(8),
      numSeeds: 1 + _rng.nextInt(4),
      sequential: settings.sequentialDefault,
      files: [
        FileEntry(
          path: '$name/file1.bin',
          size: size ~/ 2,
          priority: FilePriority.normal,
          progress: 0.02,
        ),
        FileEntry(
          path: '$name/file2.bin',
          size: size - size ~/ 2,
          priority: FilePriority.normal,
          progress: 0.02,
        ),
      ],
    );
    _torrents[hash] = item;
    _order.add(hash);
    return hash;
  }

  String addTorrentPath(String path, String savePath) =>
      addMagnet(path, savePath);

  void pause(String hash) {
    final t = _torrents[hash];
    if (t == null) return;
    _torrents[hash] = t.copyWith(paused: true, state: TorrentState.paused);
  }

  void resume(String hash) {
    final t = _torrents[hash];
    if (t == null) return;
    _torrents[hash] = t.copyWith(
      paused: false,
      state: t.finished ? TorrentState.seeding : TorrentState.downloading,
    );
  }

  void remove(String hash, {bool deleteFiles = false}) {
    _torrents.remove(hash);
    _order.remove(hash);
    // deleteFiles ignored in mock
    assert(() {
      // ignore: avoid_print
      if (deleteFiles) print('mock remove with deleteFiles=$deleteFiles');
      return true;
    }());
  }

  void setSequential(String hash, bool enabled) {
    final t = _torrents[hash];
    if (t == null) return;
    _torrents[hash] = t.copyWith(sequential: enabled);
  }

  void setFilePriority(String hash, int index, FilePriority priority) {
    final t = _torrents[hash];
    if (t == null || index < 0 || index >= t.files.length) return;
    final files = [...t.files];
    files[index] = files[index].copyWith(priority: priority);
    _torrents[hash] = t.copyWith(files: files);
  }

  Map<String, Object?> exportResume() => {
        'torrents': _order
            .map((h) => {
                  'infoHash': h,
                  'name': _torrents[h]!.name,
                  'savePath': _torrents[h]!.savePath,
                  'progress': _torrents[h]!.progress,
                  'totalWanted': _torrents[h]!.totalWanted,
                  'paused': _torrents[h]!.paused,
                  'sequential': _torrents[h]!.sequential,
                  'category': _torrents[h]!.category,
                  'tags': _torrents[h]!.tags,
                })
            .toList(),
      };

  void importResume(Map<String, Object?> data) {
    final list = data['torrents'];
    if (list is! List) return;
    for (final raw in list) {
      if (raw is! Map) continue;
      final map = Map<String, Object?>.from(raw);
      final hash = map['infoHash'] as String? ?? '';
      if (hash.isEmpty || _torrents.containsKey(hash)) continue;
      final size = map['totalWanted'] as int? ?? 100 * 1024 * 1024;
      final progress = (map['progress'] as num?)?.toDouble() ?? 0;
      final paused = map['paused'] as bool? ?? false;
      final name = map['name'] as String? ?? hash;
      _torrents[hash] = TorrentItem(
        infoHash: hash,
        name: name,
        savePath: map['savePath'] as String? ?? settings.savePath,
        progress: progress,
        totalWanted: size,
        totalWantedDone: (size * progress).round(),
        paused: paused,
        state: paused
            ? TorrentState.paused
            : (progress >= 1 ? TorrentState.seeding : TorrentState.downloading),
        finished: progress >= 1,
        sequential: map['sequential'] as bool? ?? false,
        category: map['category'] as String? ?? '',
        tags: (map['tags'] as List?)?.cast<String>() ?? const [],
        files: [
          FileEntry(
            path: '$name/data.bin',
            size: size,
            priority: FilePriority.normal,
            progress: progress,
          ),
        ],
      );
      _order.add(hash);
    }
  }

  String dumpResumeJson() => jsonEncode(exportResume());

  void _advance() {
    for (final hash in [..._order]) {
      final t = _torrents[hash]!;
      if (t.paused || t.finished) continue;
      final next = (t.progress + 0.008 + _rng.nextDouble() * 0.004).clamp(0.0, 1.0);
      final rate = 150 * 1024 + _rng.nextInt(300 * 1024);
      final done = (t.totalWanted * next).round();
      final eta = rate > 0 && next < 1
          ? ((t.totalWanted - done) / rate).round()
          : -1;
      final finished = next >= 1.0;
      _torrents[hash] = t.copyWith(
        progress: next,
        totalWantedDone: done,
        downloadRate: finished ? 0 : rate,
        uploadRate: finished ? 32 * 1024 : 8 * 1024,
        numPeers: 2 + _rng.nextInt(12),
        numSeeds: 1 + _rng.nextInt(6),
        finished: finished,
        state: finished ? TorrentState.seeding : TorrentState.downloading,
        etaSeconds: eta,
        files: t.files
            .map((f) => f.copyWith(progress: next))
            .toList(growable: false),
      );
    }
  }

  String _hash(String seed) {
    var h = 0x811c9dc5;
    for (final c in seed.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0') * 5;
  }

  String _nameFromMagnet(String uri) {
    final dn = RegExp(r'[?&]dn=([^&]+)').firstMatch(uri);
    if (dn != null) {
      return Uri.decodeComponent(dn.group(1)!.replaceAll('+', ' '));
    }
    if (uri.length > 48) return uri.substring(0, 48);
    return uri;
  }
}
