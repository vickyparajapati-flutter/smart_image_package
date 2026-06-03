import 'package:flutter_test/flutter_test.dart';
import 'package:smart_image_x/src/utils/domain_guard.dart';

void main() {
  group('DomainGuard.isAllowed', () {
    Uri uri(String host) => Uri.parse('https://$host/image.png');

    test('permits everything when the whitelist is null or empty', () {
      expect(DomainGuard.isAllowed(uri('any.com'), null), isTrue);
      expect(DomainGuard.isAllowed(uri('any.com'), const []), isTrue);
    });

    test('permits exact host matches', () {
      expect(
        DomainGuard.isAllowed(uri('cdn.example.com'), ['cdn.example.com']),
        isTrue,
      );
    });

    test('permits sub-domains of a listed apex domain', () {
      expect(
        DomainGuard.isAllowed(uri('cdn.example.com'), ['example.com']),
        isTrue,
      );
      expect(
        DomainGuard.isAllowed(uri('example.com'), ['example.com']),
        isTrue,
      );
    });

    test('rejects hosts not on the list', () {
      expect(
        DomainGuard.isAllowed(uri('evil.com'), ['example.com']),
        isFalse,
      );
    });

    test('does not allow a partial suffix that is not a sub-domain', () {
      // "notexample.com" must NOT match "example.com".
      expect(
        DomainGuard.isAllowed(uri('notexample.com'), ['example.com']),
        isFalse,
      );
    });

    test('matching is case-insensitive', () {
      expect(
        DomainGuard.isAllowed(uri('CDN.Example.COM'), ['example.com']),
        isTrue,
      );
    });
  });
}
