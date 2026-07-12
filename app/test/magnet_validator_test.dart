import 'package:flutter_test/flutter_test.dart';
import 'package:open_torrent/util/magnet_validator.dart';

void main() {
  test('magnet validator covers edge cases', () {
    expect(MagnetValidator.isValid(''), isFalse);
    expect(MagnetValidator.isValid('   '), isFalse);
    expect(MagnetValidator.isValid('magnet:'), isFalse);
    expect(MagnetValidator.isValid('http://example.com'), isFalse);
    expect(
      MagnetValidator.isValid(
        'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
      ),
      isTrue,
    );
    expect(
      MagnetValidator.isValid('0123456789abcdef0123456789abcdef01234567'),
      isTrue,
    );
    expect(
      MagnetValidator.normalize('ABCDEF0123456789ABCDEF0123456789ABCDEF01'),
      startsWith('magnet:?xt=urn:btih:'),
    );
  });
}
