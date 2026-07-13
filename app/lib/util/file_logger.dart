import 'dart:io';

import 'package:path/path.dart' as p;

/// Opt-in rotating file logger for bug reports.
class FileLogger {
  FileLogger._();
  static final instance = FileLogger._();

  static const _maxBytes = 5 * 1024 * 1024;
  File? _file;
  bool enabled = false;

  Future<void> configure(String supportDir, {required bool enabled}) async {
    this.enabled = enabled;
    _file = File(p.join(supportDir, 'opentorrent_debug.log'));
    if (enabled) {
      await _file!.parent.create(recursive: true);
      await log('--- debug logging enabled ${DateTime.now().toIso8601String()} ---');
    }
  }

  Future<void> log(String message) async {
    if (!enabled || _file == null) return;
    try {
      if (await _file!.exists() && await _file!.length() > _maxBytes) {
        final bak = File('${_file!.path}.1');
        if (await bak.exists()) await bak.delete();
        await _file!.rename(bak.path);
      }
      await _file!.writeAsString(
        '${DateTime.now().toIso8601String()} $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  String? get path => _file?.path;

  Future<String?> readTail({int maxChars = 20000}) async {
    if (_file == null || !await _file!.exists()) return null;
    final text = await _file!.readAsString();
    if (text.length <= maxChars) return text;
    return text.substring(text.length - maxChars);
  }
}
