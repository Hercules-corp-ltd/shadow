import 'package:shadow_mobile/browser/url_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UrlInput.resolve — destinations', () {
    test('upgrades a bare host to https rather than http', () {
      expect(UrlInput.resolve('twitter.com').toString(), 'https://twitter.com');
      expect(UrlInput.resolve('news.bbc.co.uk')!.scheme, 'https');
    });

    test('keeps an explicit scheme, including a deliberate http', () {
      expect(UrlInput.resolve('http://example.com')!.scheme, 'http');
      expect(UrlInput.resolve('https://example.com/a/b')!.path, '/a/b');
    });

    test('handles hosts with paths, ports and queries', () {
      expect(UrlInput.resolve('example.com/path')!.host, 'example.com');
      expect(UrlInput.resolve('localhost:3000')!.host, 'localhost');
      expect(UrlInput.resolve('192.168.1.4:8080')!.host, '192.168.1.4');
    });
  });

  group('UrlInput.resolve — search', () {
    test('sends prose to DuckDuckGo, not Google', () {
      final uri = UrlInput.resolve('how does hkdf work')!;
      expect(uri.host, 'duckduckgo.com');
      expect(uri.query, contains('how'));
    });

    test('treats anything containing a space as a search', () {
      expect(UrlInput.resolve('example.com and more')!.host, 'duckduckgo.com');
    });

    test('does not mistake a version number for a host', () {
      // "3.41" has a numeric last label, so it cannot be a TLD.
      expect(UrlInput.resolve('flutter 3.41')!.host, 'duckduckgo.com');
      expect(UrlInput.resolve('3.41')!.host, 'duckduckgo.com');
    });

    test('percent-encodes the query so it cannot break out of the URL', () {
      final uri = UrlInput.resolve('a&b=c d')!;
      expect(uri.host, 'duckduckgo.com');
      expect(uri.queryParameters['q'], 'a&b=c d');
    });
  });

  group('UrlInput.resolve — refused schemes', () {
    test('refuses javascript, data, file and app schemes', () {
      for (final hostile in <String>[
        'javascript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'file:///etc/passwd',
        'intent://scan/#Intent;scheme=zxing;end',
        'tel:+15551234',
      ]) {
        expect(UrlInput.resolve(hostile), isNull, reason: hostile);
      }
    });

    test('returns null for empty or whitespace input', () {
      expect(UrlInput.resolve(''), isNull);
      expect(UrlInput.resolve('   '), isNull);
    });
  });

  group('UrlInput display', () {
    test('shows the host, which is the part that matters for phishing', () {
      expect(
        UrlInput.displayLabel(Uri.parse('https://www.twitter.com/')),
        'twitter.com',
      );
      expect(
        UrlInput.displayLabel(Uri.parse('https://example.com/a/b')),
        'example.com/a/b',
      );
    });

    test('reports security from the actual scheme, not decoration', () {
      expect(UrlInput.isSecure(Uri.parse('https://example.com')), isTrue);
      expect(UrlInput.isSecure(Uri.parse('http://example.com')), isFalse);
      expect(UrlInput.isSecure(null), isFalse);
    });
  });

  group('UrlInput.hasDisallowedScheme — for saying which thing went wrong', () {
    test('true only for a scheme we refuse', () {
      for (final input in <String>[
        'javascript:alert(1)',
        'data:text/html,<b>x</b>',
        'file:///etc/passwd',
        'myapp://open',
      ]) {
        expect(UrlInput.hasDisallowedScheme(input), isTrue, reason: input);
      }
    });

    test('false for anything that simply is not an address', () {
      // The old copy blamed the scheme for these too, which told a confused
      // user nothing they could act on.
      for (final input in <String>[
        'bbc.co.uk',
        'https://bbc.co.uk',
        'how does hkdf work',
        'localhost:3000',
        'about:blank',
        '',
      ]) {
        expect(UrlInput.hasDisallowedScheme(input), isFalse, reason: input);
      }
    });
  });
}
