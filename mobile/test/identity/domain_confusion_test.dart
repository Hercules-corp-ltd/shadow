import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/identity/identity.dart';

void main() {
  group('a path cannot name a different site', () {
    test('an @ in the path is not a userinfo section', () {
      // The bug this file exists for. Credentials were stripped before the
      // path, so the last @ anywhere in the URL was treated as the end of a
      // userinfo section. Every site controls its own paths, so serving one
      // page at /@bank.com was enough to make Shadow derive bank.com's
      // password, username and alias — and offer them to the page asking.
      expect(RegistrableDomain.of('https://evil.test/@bank.com'), 'evil.test');
      expect(
        RegistrableDomain.of('https://evil.test/login/@paypal.com'),
        'evil.test',
      );
      expect(
        RegistrableDomain.of('https://evil.test/a/b/c@d.example/e'),
        'evil.test',
      );
    });

    test('an @ in the query string is not one either', () {
      // Reachable without any malice on the site's part: an open redirect
      // parameter carrying an address is enough.
      expect(
        RegistrableDomain.of('https://evil.test/?next=@bank.com'),
        'evil.test',
      );
      expect(
        RegistrableDomain.of('https://shop.example.com/?ref=a@b.test'),
        'example.com',
      );
    });

    test('an @ in the fragment is not one either', () {
      expect(
        RegistrableDomain.of('https://evil.test/#/profile/@bank.com'),
        'evil.test',
      );
    });
  });

  group('real credentials are still stripped', () {
    test('the host after an authority @ wins', () {
      // The other half of the same trick, and the one the original code got
      // right: what precedes the @ inside the authority is a username, not a
      // site.
      expect(RegistrableDomain.of('https://bank.com@evil.test/'), 'evil.test');
      expect(
        RegistrableDomain.of('https://user:pass@shop.example.com/cart'),
        'example.com',
      );
    });
  });

  group('ordinary addresses are unchanged', () {
    test('the shapes a browser actually reports', () {
      // The fix must not move any legitimate host, or every account derived
      // before it would silently get different credentials.
      const cases = <String, String>{
        'twitter.com': 'twitter.com',
        'https://twitter.com': 'twitter.com',
        'https://www.twitter.com/login': 'twitter.com',
        'accounts.google.com': 'google.com',
        'news.bbc.co.uk': 'bbc.co.uk',
        'bbc.co.uk': 'bbc.co.uk',
        'https://shop.example.com:8443/x': 'example.com',
        'EXAMPLE.com.': 'example.com',
      };
      cases.forEach((input, expected) {
        expect(RegistrableDomain.of(input), expected, reason: input);
      });
    });
  });
}
