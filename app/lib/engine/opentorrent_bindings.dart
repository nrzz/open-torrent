/// Hand-written FFI bindings matching core/include/opentorrent.h
/// (ffigen can regenerate: dart run ffigen)
library;

import 'dart:ffi' as ffi;
import 'dart:io';

final class OtSessionSettings extends ffi.Struct {
  @ffi.Array.multi([1024])
  external ffi.Array<ffi.Char> savePath;
  @ffi.Int()
  external int listenPort;
  @ffi.Int()
  external int downloadRateLimit;
  @ffi.Int()
  external int uploadRateLimit;
  @ffi.Int()
  external int maxConnections;
  @ffi.Int()
  external int maxUploads;
  @ffi.Int()
  external int enableDht;
  @ffi.Int()
  external int enableLsd;
  @ffi.Int()
  external int enablePex;
  @ffi.Int()
  external int encryptionMode;
  @ffi.Int()
  external int sequentialDownloadDefault;
  @ffi.Array.multi([256])
  external ffi.Array<ffi.Char> proxyHost;
  @ffi.Int()
  external int proxyPort;
  @ffi.Array.multi([128])
  external ffi.Array<ffi.Char> proxyUsername;
  @ffi.Array.multi([128])
  external ffi.Array<ffi.Char> proxyPassword;
  @ffi.Array.multi([1024])
  external ffi.Array<ffi.Char> blocklistPath;
  @ffi.Int()
  external int wifiOnly;
}

final class OtTorrentStatus extends ffi.Struct {
  @ffi.Array.multi([64])
  external ffi.Array<ffi.Char> infoHash;
  @ffi.Array.multi([512])
  external ffi.Array<ffi.Char> name;
  @ffi.Array.multi([1024])
  external ffi.Array<ffi.Char> savePath;
  @ffi.Array.multi([512])
  external ffi.Array<ffi.Char> errorMessage;
  @ffi.Int32()
  external int state;
  @ffi.Double()
  external double progress;
  @ffi.Int64()
  external int totalWanted;
  @ffi.Int64()
  external int totalWantedDone;
  @ffi.Int64()
  external int totalDownload;
  @ffi.Int64()
  external int totalUpload;
  @ffi.Int()
  external int downloadRate;
  @ffi.Int()
  external int uploadRate;
  @ffi.Int()
  external int numPeers;
  @ffi.Int()
  external int numSeeds;
  @ffi.Int()
  external int queuePosition;
  @ffi.Int()
  external int sequential;
  @ffi.Int()
  external int paused;
  @ffi.Int()
  external int finished;
  @ffi.Int64()
  external int etaSeconds;
}

final class OtFileEntry extends ffi.Struct {
  @ffi.Array.multi([1024])
  external ffi.Array<ffi.Char> path;
  @ffi.Int64()
  external int size;
  @ffi.Int32()
  external int priority;
  @ffi.Double()
  external double progress;
}

final class OtAlert extends ffi.Struct {
  @ffi.Int32()
  external int type;
  @ffi.Array.multi([64])
  external ffi.Array<ffi.Char> infoHash;
  @ffi.Array.multi([1024])
  external ffi.Array<ffi.Char> message;
  external OtTorrentStatus status;
}

typedef _SessionCreateNative = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<OtSessionSettings>);
typedef SessionCreate = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<OtSessionSettings>);

typedef _SessionDestroyNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef SessionDestroy = void Function(ffi.Pointer<ffi.Void>);

typedef _AddMagnetNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Size,
);
typedef AddMagnet = int Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<ffi.Char>,
  int,
);

typedef _IntSessionNative = ffi.Int32 Function(ffi.Pointer<ffi.Void>);
typedef IntSession = int Function(ffi.Pointer<ffi.Void>);

typedef _StatusAtNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Int32,
  ffi.Pointer<OtTorrentStatus>,
);
typedef StatusAt = int Function(
  ffi.Pointer<ffi.Void>,
  int,
  ffi.Pointer<OtTorrentStatus>,
);

typedef _HashOpNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
);
typedef HashOp = int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>);

typedef _RemoveNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
);
typedef Remove = int Function(
    ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>, int);

typedef _PollNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<OtAlert>,
  ffi.Int32,
);
typedef Poll = int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<OtAlert>, int);

typedef _VersionNative = ffi.Pointer<ffi.Char> Function();
typedef VersionFn = ffi.Pointer<ffi.Char> Function();

typedef _FileCountNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
);
typedef FileCount = int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>);

typedef _FileAtNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
  ffi.Pointer<OtFileEntry>,
);
typedef FileAt = int Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  int,
  ffi.Pointer<OtFileEntry>,
);

typedef _SetFilePrioNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
  ffi.Int32,
);
typedef SetFilePrio = int Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  int,
  int,
);

typedef _SetSequentialNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
);
typedef SetSequential = int Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
  int,
);

typedef _LoadResumeNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Char>,
);
typedef LoadResume = int Function(
    ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Char>);

typedef _SaveResumeNative = ffi.Int32 Function(ffi.Pointer<ffi.Void>);
typedef SaveResume = int Function(ffi.Pointer<ffi.Void>);

typedef _ApplySettingsNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<OtSessionSettings>,
);
typedef ApplySettings = int Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<OtSessionSettings>,
);

class OpenTorrentNative {
  OpenTorrentNative(ffi.DynamicLibrary lib)
      : sessionCreate = lib.lookupFunction<_SessionCreateNative, SessionCreate>(
            'ot_session_create'),
        sessionDestroy =
            lib.lookupFunction<_SessionDestroyNative, SessionDestroy>(
                'ot_session_destroy'),
        addMagnet =
            lib.lookupFunction<_AddMagnetNative, AddMagnet>('ot_add_magnet'),
        addTorrentFile = lib.lookupFunction<_AddMagnetNative, AddMagnet>(
            'ot_add_torrent_file'),
        torrentCount =
            lib.lookupFunction<_IntSessionNative, IntSession>('ot_torrent_count'),
        statusAt =
            lib.lookupFunction<_StatusAtNative, StatusAt>('ot_torrent_status_at'),
        pause = lib.lookupFunction<_HashOpNative, HashOp>('ot_pause_torrent'),
        resume = lib.lookupFunction<_HashOpNative, HashOp>('ot_resume_torrent'),
        remove =
            lib.lookupFunction<_RemoveNative, Remove>('ot_remove_torrent'),
        pollAlerts =
            lib.lookupFunction<_PollNative, Poll>('ot_poll_alerts'),
        version = lib.lookupFunction<_VersionNative, VersionFn>('ot_version'),
        fileCount =
            lib.lookupFunction<_FileCountNative, FileCount>('ot_file_count'),
        fileAt = lib.lookupFunction<_FileAtNative, FileAt>('ot_file_at'),
        setFilePriority = lib
            .lookupFunction<_SetFilePrioNative, SetFilePrio>('ot_set_file_priority'),
        setSequential = lib
            .lookupFunction<_SetSequentialNative, SetSequential>('ot_set_sequential'),
        loadResumeDir = lib
            .lookupFunction<_LoadResumeNative, LoadResume>('ot_session_load_resume_dir'),
        saveResume = lib
            .lookupFunction<_SaveResumeNative, SaveResume>('ot_session_save_resume'),
        applySettings = lib.lookupFunction<_ApplySettingsNative, ApplySettings>(
            'ot_session_apply_settings');

  final SessionCreate sessionCreate;
  final SessionDestroy sessionDestroy;
  final AddMagnet addMagnet;
  final AddMagnet addTorrentFile;
  final IntSession torrentCount;
  final StatusAt statusAt;
  final HashOp pause;
  final HashOp resume;
  final Remove remove;
  final Poll pollAlerts;
  final VersionFn version;
  final FileCount fileCount;
  final FileAt fileAt;
  final SetFilePrio setFilePriority;
  final SetSequential setSequential;
  final LoadResume loadResumeDir;
  final SaveResume saveResume;
  final ApplySettings applySettings;

  static OpenTorrentNative? tryLoad() {
    if (Platform.isAndroid) {
      // Packaged under jniLibs as libopentorrent_core.so — system loader resolves it.
      for (final name in const [
        'libopentorrent_core.so',
        'opentorrent_core.so',
      ]) {
        try {
          return OpenTorrentNative(ffi.DynamicLibrary.open(name));
        } catch (_) {}
      }
      return null;
    }

    final names = Platform.isWindows
        ? const ['opentorrent_core.dll']
        : const ['libopentorrent_core.so', 'opentorrent_core.so'];

    final candidates = <String>[];
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      for (final name in names) {
        candidates.add('$exeDir${Platform.pathSeparator}$name');
        candidates.add(
            '$exeDir${Platform.pathSeparator}native${Platform.pathSeparator}$name');
      }
    } catch (_) {}
    candidates.addAll(names);

    for (final path in candidates) {
      try {
        return OpenTorrentNative(ffi.DynamicLibrary.open(path));
      } catch (_) {
        // try next
      }
    }
    return null;
  }
}
