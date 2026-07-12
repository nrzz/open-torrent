enum TorrentState {
  unknown,
  checkingFiles,
  downloadingMetadata,
  downloading,
  finished,
  seeding,
  checkingResume,
  paused,
  queued,
  error,
}

TorrentState torrentStateFromInt(int v) {
  if (v < 0 || v >= TorrentState.values.length) return TorrentState.unknown;
  return TorrentState.values[v];
}

enum FilePriority { skip, low, normal, high }

extension FilePriorityX on FilePriority {
  int get nativeValue => switch (this) {
        FilePriority.skip => 0,
        FilePriority.low => 1,
        FilePriority.normal => 4,
        FilePriority.high => 7,
      };

  static FilePriority fromNative(int v) {
    return switch (v) {
      0 => FilePriority.skip,
      1 => FilePriority.low,
      7 => FilePriority.high,
      _ => FilePriority.normal,
    };
  }
}

class FileEntry {
  FileEntry({
    required this.path,
    required this.size,
    required this.priority,
    required this.progress,
  });

  final String path;
  final int size;
  final FilePriority priority;
  final double progress;

  FileEntry copyWith({FilePriority? priority, double? progress}) => FileEntry(
        path: path,
        size: size,
        priority: priority ?? this.priority,
        progress: progress ?? this.progress,
      );
}

class TorrentItem {
  TorrentItem({
    required this.infoHash,
    required this.name,
    required this.savePath,
    this.errorMessage = '',
    this.state = TorrentState.unknown,
    this.progress = 0,
    this.totalWanted = 0,
    this.totalWantedDone = 0,
    this.totalDownload = 0,
    this.totalUpload = 0,
    this.downloadRate = 0,
    this.uploadRate = 0,
    this.numPeers = 0,
    this.numSeeds = 0,
    this.queuePosition = 0,
    this.sequential = false,
    this.paused = false,
    this.finished = false,
    this.etaSeconds = -1,
    this.files = const [],
    this.category = '',
    this.tags = const [],
  });

  final String infoHash;
  final String name;
  final String savePath;
  final String errorMessage;
  final TorrentState state;
  final double progress;
  final int totalWanted;
  final int totalWantedDone;
  final int totalDownload;
  final int totalUpload;
  final int downloadRate;
  final int uploadRate;
  final int numPeers;
  final int numSeeds;
  final int queuePosition;
  final bool sequential;
  final bool paused;
  final bool finished;
  final int etaSeconds;
  final List<FileEntry> files;
  final String category;
  final List<String> tags;

  TorrentItem copyWith({
    String? name,
    String? savePath,
    String? errorMessage,
    TorrentState? state,
    double? progress,
    int? totalWanted,
    int? totalWantedDone,
    int? totalDownload,
    int? totalUpload,
    int? downloadRate,
    int? uploadRate,
    int? numPeers,
    int? numSeeds,
    int? queuePosition,
    bool? sequential,
    bool? paused,
    bool? finished,
    int? etaSeconds,
    List<FileEntry>? files,
    String? category,
    List<String>? tags,
  }) {
    return TorrentItem(
      infoHash: infoHash,
      name: name ?? this.name,
      savePath: savePath ?? this.savePath,
      errorMessage: errorMessage ?? this.errorMessage,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      totalWanted: totalWanted ?? this.totalWanted,
      totalWantedDone: totalWantedDone ?? this.totalWantedDone,
      totalDownload: totalDownload ?? this.totalDownload,
      totalUpload: totalUpload ?? this.totalUpload,
      downloadRate: downloadRate ?? this.downloadRate,
      uploadRate: uploadRate ?? this.uploadRate,
      numPeers: numPeers ?? this.numPeers,
      numSeeds: numSeeds ?? this.numSeeds,
      queuePosition: queuePosition ?? this.queuePosition,
      sequential: sequential ?? this.sequential,
      paused: paused ?? this.paused,
      finished: finished ?? this.finished,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      files: files ?? this.files,
      category: category ?? this.category,
      tags: tags ?? this.tags,
    );
  }
}

class SessionSettings {
  SessionSettings({
    this.savePath = '',
    this.listenPort = 6881,
    this.downloadRateLimit = 0,
    this.uploadRateLimit = 0,
    this.maxConnections = 200,
    this.maxUploads = 8,
    this.enableDht = true,
    this.enableLsd = true,
    this.enablePex = true,
    this.encryptionMode = 1,
    this.sequentialDefault = false,
    this.proxyHost = '',
    this.proxyPort = 0,
    this.proxyUsername = '',
    this.proxyPassword = '',
    this.blocklistPath = '',
    this.wifiOnly = false,
    this.themeMode = 'system',
    this.locale = 'en',
    this.debugLogging = false,
  });

  String savePath;
  int listenPort;
  int downloadRateLimit;
  int uploadRateLimit;
  int maxConnections;
  int maxUploads;
  bool enableDht;
  bool enableLsd;
  bool enablePex;
  int encryptionMode;
  bool sequentialDefault;
  String proxyHost;
  int proxyPort;
  String proxyUsername;
  String proxyPassword;
  String blocklistPath;
  bool wifiOnly;
  String themeMode;
  String locale;
  bool debugLogging;

  Map<String, Object?> toJson() => {
        'savePath': savePath,
        'listenPort': listenPort,
        'downloadRateLimit': downloadRateLimit,
        'uploadRateLimit': uploadRateLimit,
        'maxConnections': maxConnections,
        'maxUploads': maxUploads,
        'enableDht': enableDht,
        'enableLsd': enableLsd,
        'enablePex': enablePex,
        'encryptionMode': encryptionMode,
        'sequentialDefault': sequentialDefault,
        'proxyHost': proxyHost,
        'proxyPort': proxyPort,
        'proxyUsername': proxyUsername,
        'proxyPassword': proxyPassword,
        'blocklistPath': blocklistPath,
        'wifiOnly': wifiOnly,
        'themeMode': themeMode,
        'locale': locale,
        'debugLogging': debugLogging,
      };

  factory SessionSettings.fromJson(Map<String, Object?> json) {
    final s = SessionSettings();
    s.savePath = json['savePath'] as String? ?? '';
    s.listenPort = json['listenPort'] as int? ?? 6881;
    s.downloadRateLimit = json['downloadRateLimit'] as int? ?? 0;
    s.uploadRateLimit = json['uploadRateLimit'] as int? ?? 0;
    s.maxConnections = json['maxConnections'] as int? ?? 200;
    s.maxUploads = json['maxUploads'] as int? ?? 8;
    s.enableDht = json['enableDht'] as bool? ?? true;
    s.enableLsd = json['enableLsd'] as bool? ?? true;
    s.enablePex = json['enablePex'] as bool? ?? true;
    s.encryptionMode = json['encryptionMode'] as int? ?? 1;
    s.sequentialDefault = json['sequentialDefault'] as bool? ?? false;
    s.proxyHost = json['proxyHost'] as String? ?? '';
    s.proxyPort = json['proxyPort'] as int? ?? 0;
    s.proxyUsername = json['proxyUsername'] as String? ?? '';
    s.proxyPassword = json['proxyPassword'] as String? ?? '';
    s.blocklistPath = json['blocklistPath'] as String? ?? '';
    s.wifiOnly = json['wifiOnly'] as bool? ?? false;
    s.themeMode = json['themeMode'] as String? ?? 'system';
    s.locale = json['locale'] as String? ?? 'en';
    s.debugLogging = json['debugLogging'] as bool? ?? false;
    return s;
  }

  SessionSettings copy() => SessionSettings.fromJson(toJson());
}

class RssRule {
  RssRule({
    required this.id,
    required this.name,
    required this.feedUrl,
    this.filter = '',
    this.enabled = true,
    this.lastMatch = '',
  });

  final String id;
  String name;
  String feedUrl;
  String filter;
  bool enabled;
  String lastMatch;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'feedUrl': feedUrl,
        'filter': filter,
        'enabled': enabled,
        'lastMatch': lastMatch,
      };

  factory RssRule.fromJson(Map<String, Object?> json) => RssRule(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        feedUrl: json['feedUrl'] as String? ?? '',
        filter: json['filter'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        lastMatch: json['lastMatch'] as String? ?? '',
      );
}

class SchedulerWindow {
  SchedulerWindow({
    this.enabled = false,
    this.startHour = 0,
    this.endHour = 8,
    this.limitedDownloadRate = 100 * 1024,
    this.limitedUploadRate = 50 * 1024,
  });

  bool enabled;
  int startHour;
  int endHour;
  int limitedDownloadRate;
  int limitedUploadRate;

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'startHour': startHour,
        'endHour': endHour,
        'limitedDownloadRate': limitedDownloadRate,
        'limitedUploadRate': limitedUploadRate,
      };

  factory SchedulerWindow.fromJson(Map<String, Object?> json) => SchedulerWindow(
        enabled: json['enabled'] as bool? ?? false,
        startHour: json['startHour'] as int? ?? 0,
        endHour: json['endHour'] as int? ?? 8,
        limitedDownloadRate: json['limitedDownloadRate'] as int? ?? 100 * 1024,
        limitedUploadRate: json['limitedUploadRate'] as int? ?? 50 * 1024,
      );
}
