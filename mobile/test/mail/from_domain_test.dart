import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/mail/mime_lite.dart';

MimeMessage parse(String from) =>
    MimeLite.parse('From: $from\r\nSubject: hi\r\n\r\nbody\r\n');

void main() {
  group('who a message says it is from', () {
    test('an ordinary sender', () {
      expect(parse('Twitter <verify@twitter.com>').fromDomain, 'twitter.com');
      expect(parse('verify@twitter.com').fromDomain, 'twitter.com');
    });

    test('a subdomain reduces to the registrable domain', () {
      // Otherwise `email.notifications.twitter.com` and `twitter.com` read as
      // two different senders, and every large sender looks like a stranger.
      expect(
        parse('<no-reply@email.notifications.twitter.com>').fromDomain,
        'twitter.com',
      );
      expect(parse('<x@post.bbc.co.uk>').fromDomain, 'bbc.co.uk');
    });

    test('a display name cannot impersonate an address', () {
      // The defect this exists for. Taking the first `@` in the header let
      // the sender choose what Shadow displayed: the name is free text, and
      // this value sits next to a verification code where it reads as
      // provenance.
      expect(
        parse('"billing@acme.com" <mallory@evil.test>').fromDomain,
        'evil.test',
      );
      expect(
        parse('Acme Support @acme.com <attacker@evil.test>').fromDomain,
        'evil.test',
      );
    });

    test('an encoded word in the name cannot reach the domain', () {
      // Decoding first was how the old version got here: the header is parsed
      // undecoded, so an encoded-word display name has nothing to contribute.
      expect(
        parse('=?utf-8?B?YmlsbGluZ0BhY21lLmNvbQ==?= <mallory@evil.test>')
            .fromDomain,
        'evil.test',
      );
    });

    test('more than one sender is refused rather than guessed', () {
      // A header carrying two addresses has no single honest answer, and
      // picking either one would be Shadow choosing which to show.
      expect(
          parse('a@one.test <b@two.test>, c@three.test <d@four.test>')
              .fromDomain,
          isNull);
      expect(parse('a@one.test, b@two.test').fromDomain, isNull);
    });

    test('nonsense yields null, never a throw', () {
      expect(parse('').fromDomain, isNull);
      expect(parse('not an address').fromDomain, isNull);
      expect(parse('<broken@').fromDomain, isNull);
      expect(parse('<@nothing.test>').fromDomain, 'nothing.test');
      expect(parse('<trailing@>').fromDomain, isNull);
    });

    test('the display name is available, and separately', () {
      final message = parse('"Acme Support" <billing@acme.com>');
      expect(message.displayName, 'Acme Support');
      expect(message.fromDomain, 'acme.com');
    });

    test('a second From header is not an update', () {
      final message = MimeLite.parse(
        'From: <real@acme.com>\r\nFrom: <spoof@evil.test>\r\n\r\nbody',
      );
      expect(message.fromDomain, 'acme.com');
    });
  });
}
