/// Pure validation helpers shared by UI and controller.
class MagnetValidator {
  static bool isValid(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    final looksLikeMagnet = trimmed.startsWith('magnet:') &&
        (trimmed.contains('xt=urn:btih:') || trimmed.contains('xt=urn:btmh:'));
    final looksLikeHash = RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(trimmed) ||
        RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(trimmed);
    return looksLikeMagnet || looksLikeHash;
  }

  static String normalize(String input) {
    final trimmed = input.trim();
    if (RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(trimmed) ||
        RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(trimmed)) {
      return 'magnet:?xt=urn:btih:${trimmed.toLowerCase()}';
    }
    return trimmed;
  }
}
