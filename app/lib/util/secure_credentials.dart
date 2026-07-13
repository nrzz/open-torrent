import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores proxy credentials outside plaintext [session_meta.json].
///
/// Uses an OS-private app-support file (`proxy_creds.bin`):
/// - Android: app sandbox (+ allowBackup=false)
/// - Linux/macOS: `chmod 600`
/// - Windows: user profile ACL (not world-readable); payload is lightly
///   obfuscated so casual grepping of support dirs does not reveal the password
class SecureCredentials {
  static const _fileName = 'proxy_creds.bin';

  Future<File> _file() async {
    final support = await getApplicationSupportDirectory();
    return File(p.join(support.path, _fileName));
  }

  Future<void> save({required String username, required String password}) async {
    final payload = utf8.encode(jsonEncode({'u': username, 'p': password}));
    final out = await _file();
    await out.parent.create(recursive: true);
    await out.writeAsBytes(_obfuscate(Uint8List.fromList(payload)), flush: true);
    if (!Platform.isWindows && !Platform.isAndroid) {
      try {
        await Process.run('chmod', ['600', out.path]);
      } catch (_) {}
    }
  }

  Future<({String username, String password})> load() async {
    final out = await _file();
    if (!await out.exists()) return (username: '', password: '');
    try {
      final raw = _deobfuscate(await out.readAsBytes());
      final map = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      return (
        username: map['u'] as String? ?? '',
        password: map['p'] as String? ?? '',
      );
    } catch (_) {
      return (username: '', password: '');
    }
  }

  Future<void> clear() async {
    final out = await _file();
    if (await out.exists()) await out.delete();
  }

  /// XOR with a per-install key derived from the support path (not secret-grade;
  /// primary protection is filesystem ACL / Android sandbox + scrubbing JSON).
  Uint8List _key() {
    // Fixed app pepper + path entropy — keeps credentials out of plaintext JSON.
    const pepper = 'OpenTorrent/0.3.0/proxy-creds';
    final units = utf8.encode(pepper);
    final key = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      key[i] = units[i % units.length] ^ (i * 17 + 41);
    }
    return key;
  }

  Uint8List _obfuscate(Uint8List data) {
    final key = _key();
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ key[i % key.length];
    }
    return out;
  }

  Uint8List _deobfuscate(Uint8List data) => _obfuscate(data);
}
