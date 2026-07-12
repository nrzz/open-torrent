import '../engine/models.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var i = -1;
  do {
    value /= 1024;
    i++;
  } while (value >= 1024 && i < units.length - 1);
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[i]}';
}

String formatRate(int bytesPerSec) => '${formatBytes(bytesPerSec)}/s';

String formatEta(int seconds) {
  if (seconds < 0) return '—';
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '${h}h ${m}m';
}

String stateLabel(TorrentState state) {
  return switch (state) {
    TorrentState.checkingFiles => 'Checking',
    TorrentState.downloadingMetadata => 'Metadata',
    TorrentState.downloading => 'Downloading',
    TorrentState.finished => 'Finished',
    TorrentState.seeding => 'Seeding',
    TorrentState.checkingResume => 'Checking resume',
    TorrentState.paused => 'Paused',
    TorrentState.queued => 'Queued',
    TorrentState.error => 'Error',
    TorrentState.unknown => 'Unknown',
  };
}
