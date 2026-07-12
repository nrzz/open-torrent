import 'dart:io';

import 'package:http/http.dart' as http;
import 'dart:convert';

/// Checks GitHub Releases for a newer version (desktop / optional Android).
class UpdateChecker {
  UpdateChecker({
    required this.owner,
    required this.repo,
    required this.currentVersion,
  });

  final String owner;
  final String repo;
  final String currentVersion;

  Future<String?> latestTag() async {
    if (owner == 'OWNER') return null;
    final uri = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/releases/latest',
    );
    final res = await http.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'OpenTorrent/$currentVersion',
    });
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['tag_name'] as String?;
  }

  Future<bool> isUpdateAvailable() async {
    final tag = await latestTag();
    if (tag == null) return false;
    final remote = tag.replaceFirst(RegExp(r'^v'), '');
    return remote != currentVersion && remote.compareTo(currentVersion) > 0;
  }

  static bool get supported => !Platform.isLinux;
}
