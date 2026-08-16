import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/mail/code_extraction.dart';
import 'package:shadow_mobile/mail/mime_lite.dart';

/// Builds a plain message with the given subject and body.
MimeMessage plain(String subject, String body, {String from = 'x@sendgrid.net'}) {
  return MimeLite.parse(
    'From: $from\r\nSubject: $subject\r\n'
    'Content-Type: text/plain; charset=utf-8\r\n\r\n$body',
  );
}

String? codeIn(MimeMessage message, {String? alias}) =>
    CodeExtraction.bestCode(message, aliasLocalPart: alias)?.value;

void main() {
  group('MIME reading', () {
    test('splits headers from body and unfolds continuations', () {
      final message = MimeLite.parse(
        'From: Twitter <verify@twitter.com>\r\n'
        'Subject: A subject that\r\n'
        ' wrapped across lines\r\n'
        '\r\n'
        'Body here.',
      );

      expect(message.subject, 'A subject that wrapped across lines');
      expect(message.from, 'Twitter <verify@twitter.com>');
      expect(message.fromDomain, 'twitter.com');
      expect(message.text.trim(), 'Body here.');
    });

    test('decodes base64 bodies', () {
      final message = MimeLite.parse(
        'Content-Type: text/plain\r\n'
        'Content-Transfer-Encoding: base64\r\n\r\n'
        '${base64Encode(utf8.encode('Your code is 483920.'))}',
      );
      expect(message.text, contains('483920'));
    });

    test('decodes quoted-printable, including soft breaks', () {
      final message = MimeLite.parse(
        'Content-Type: text/plain\r\n'
        'Content-Transfer-Encoding: quoted-printable\r\n\r\n'
        'Your code is 4839=\n20 and costs =C2=A35.',
      );
      expect(message.text, contains('483920'));
      expect(message.text, contains('£5'));
    });

    test('decodes RFC 2047 subjects, which is where codes often live', () {
      final b64 = base64Encode(utf8.encode('483920 is your code'));
      final message = MimeLite.parse('Subject: =?utf-8?B?$b64?=\r\n\r\nbody');
      expect(message.subject, '483920 is your code');
    });

    test('prefers text/plain over html in a multipart', () {
      final message = MimeLite.parse(
        'Content-Type: multipart/alternative; boundary="b1"\r\n\r\n'
        '--b1\r\n'
        'Content-Type: text/plain\r\n\r\n'
        'plain wins\r\n'
        '--b1\r\n'
        'Content-Type: text/html\r\n\r\n'
        '<p>html loses</p>\r\n'
        '--b1--',
      );
      expect(message.text, contains('plain wins'));
      expect(message.text, isNot(contains('html loses')));
    });

    test('falls back to html with tags and styles stripped', () {
      final message = MimeLite.parse(
        'Content-Type: text/html\r\n\r\n'
        '<style>.a{color:#ffffff}</style><p>Code: <b>483920</b></p>',
      );
      expect(message.text, contains('483920'));
      expect(message.text, isNot(contains('#ffffff')));
      expect(message.text, isNot(contains('<b>')));
    });

    test('refuses a message that is too large rather than parsing it', () {
      final message = MimeLite.parse('x' * (MimeLite.maxBytes + 1));
      expect(message.degraded, isTrue);
      expect(message.text, isEmpty);
    });

    test('survives deep nesting without a stack overflow', () {
      // Forty nested boundaries, sent by anyone who knows the address.
      var body = 'Your code is 483920.';
      for (var i = 0; i < 40; i++) {
        body = 'Content-Type: multipart/mixed; boundary="b$i"\r\n\r\n'
            '--b$i\r\n$body\r\n--b$i--';
      }
      final message = MimeLite.parse(body);
      expect(message.degraded, isTrue);
    });

    test('an unknown charset degrades rather than throwing', () {
      final message = MimeLite.parse(
        'Content-Type: text/plain; charset=shift_jis\r\n\r\nCode 483920',
      );
      expect(message.degraded, isTrue);
      expect(message.text, contains('483920'));
    });

    test('a first From wins over a second', () {
      final message = MimeLite.parse(
        'From: real@twitter.com\r\nFrom: spoof@evil.test\r\n\r\nbody',
      );
      expect(message.fromDomain, 'twitter.com');
    });

    test('garbage never throws', () {
      for (final input in <String>[
        '',
        '\r\n\r\n',
        'no headers at all',
        'Content-Type: multipart/mixed\r\n\r\nno boundary declared',
        'Content-Transfer-Encoding: base64\r\n\r\n!!!not base64!!!',
        ':::::',
      ]) {
        expect(() => MimeLite.parse(input), returnsNormally, reason: input);
      }
    });
  });

  group('codes that should be found', () {
    test('the declared header wins outright', () {
      final message = MimeLite.parse(
        'One-Time-Code: code=246810; origin=twitter.com\r\n'
        'Subject: 483920 is your code\r\n\r\n'
        'Your code is 111111.',
      );
      expect(codeIn(message), '246810');
    });

    test('from a subject line', () {
      expect(codeIn(plain('483920 is your Twitter code', 'Hello.')), '483920');
      expect(codeIn(plain('Your code: 92831', 'Hello.')), '92831');
    });

    test('from a body next to a trigger word', () {
      expect(codeIn(plain('Hi', 'Your verification code is 483920.')), '483920');
      expect(codeIn(plain('Hi', 'Enter 4821 to confirm your email.')), '4821');
      expect(codeIn(plain('Hi', 'OTP: 918273')), '918273');
    });

    test('alphanumeric codes', () {
      expect(codeIn(plain('Hi', 'Your code is A1B2C3.')), 'A1B2C3');
    });

    test('grouped digits', () {
      expect(codeIn(plain('Hi', 'Verification code: 483 920')), '483920');
    });

    test('inside HTML with markup between the words and the number', () {
      final message = MimeLite.parse(
        'Content-Type: text/html\r\n\r\n'
        '<div style="width:600px;color:#1a1a1a">'
        '<p>Your verification code is</p><h1>483920</h1></div>',
      );
      expect(codeIn(message), '483920');
    });
  });

  group('the negatives, which are the whole point', () {
    test('a bare number with no trigger word is not a code', () {
      expect(codeIn(plain('Hi', 'We have 12345 users now.')), isNull);
    });

    test('an order number is not a code', () {
      expect(
        codeIn(plain('Your order', 'Order number 483920 has shipped.')),
        isNull,
      );
      expect(
        codeIn(plain('Hi', 'Invoice 774411. Confirm your address below.')),
        isNull,
      );
    });

    test('a hex colour is not a code', () {
      final message = MimeLite.parse(
        'Content-Type: text/html\r\n\r\n'
        '<p style="color:#483920">Please confirm your account.</p>',
      );
      expect(codeIn(message), isNull);
    });

    test('a table width is not a code', () {
      final message = MimeLite.parse(
        'Content-Type: text/html\r\n\r\n'
        '<table width="600"><tr><td>Confirm your email</td></tr></table>',
      );
      expect(codeIn(message), isNull);
    });

    test('a pixel size is not a code', () {
      expect(
        codeIn(plain('Hi', 'Confirm below. Image is 640px wide.')),
        isNull,
      );
    });

    test('a copyright year is not a code', () {
      expect(
        codeIn(plain('Hi', 'Please confirm. © 2026 Example Inc.')),
        isNull,
      );
    });

    test('a price is not a code', () {
      expect(
        codeIn(plain('Hi', 'Confirm your order of \$1,234.00 today.')),
        isNull,
      );
    });

    test('a phone number is not a code', () {
      expect(
        codeIn(plain('Hi', 'To confirm, call +44 20 7946 0958.')),
        isNull,
      );
    });

    test('a date is not a code', () {
      expect(
        codeIn(plain('Hi', 'Confirm before 12/08/2026 please.')),
        isNull,
      );
    });

    test('a token inside a URL is not a code', () {
      // It is a magic-link token. Typing it into a box does nothing.
      expect(
        codeIn(plain(
          'Hi',
          'Verify here: https://twitter.com/verify?token=483920',
        )),
        isNull,
      );
    });

    test('numbers below the unsubscribe line are ignored', () {
      expect(
        codeIn(plain(
          'Hi',
          'Welcome aboard.\n\nUnsubscribe or manage preferences.\n'
              'Your confirmation code 999999 mailing id.',
        )),
        isNull,
      );
    });

    test('the user\'s own address is never offered back as a code', () {
      // The local part is base32, so uppercased it matches the alphanumeric
      // shape exactly. Offering a slice of somebody's own email address as
      // their verification code would be a confident, useless lie.
      const alias = 'exkhu6wfl3lx2pexvcgx';
      final message = plain(
        'Hi',
        'Your code is EXKHU6WF. Sent to $alias@mail.shadow.test',
      );
      expect(codeIn(message, alias: alias), isNull);
    });
  });

  group('ambiguity is surfaced, not guessed away', () {
    test('a message with a code and a link yields both', () {
      final message = plain(
        'Hi',
        'Your verification code is 483920, or click '
            'https://twitter.com/auth/confirm?token=abc123 instead.',
      );
      final results = CodeExtraction.extract(message);

      expect(results.whereType<OneTimeCode>().first.value, '483920');
      expect(results.whereType<MagicLink>().first.host, 'twitter.com');
    });

    test('several plausible codes are all returned, ranked', () {
      final message = plain(
        'Your code is 483920',
        'Your verification code is 918273. Confirm code 5544 also works.',
      );
      final codes = CodeExtraction.extract(message).whereType<OneTimeCode>();

      expect(codes.length, greaterThan(1));
      // The subject outranks the body.
      expect(codes.first.value, '483920');
      for (var i = 1; i < codes.length; i++) {
        expect(
          codes.elementAt(i).confidence,
          lessThanOrEqualTo(codes.elementAt(i - 1).confidence),
        );
      }
    });

    test('a candidate carries the words around it', () {
      final code = CodeExtraction.bestCode(
        plain('Hi', 'Your verification code is 483920 and expires soon.'),
      );
      expect(code!.context, contains('verification code'));
    });
  });

  group('magic links', () {
    test('only auth-shaped links are offered', () {
      final message = plain(
        'Hi',
        'Confirm: https://twitter.com/verify?t=1 '
            'Our blog: https://twitter.com/blog/post',
      );
      final links = CodeExtraction.extract(message).whereType<MagicLink>();

      expect(links, hasLength(1));
      expect(links.first.url.path, '/verify');
    });

    test('http links are never offered at all', () {
      final message = plain('Hi', 'Confirm: http://twitter.com/verify?t=1');
      expect(CodeExtraction.extract(message).whereType<MagicLink>(), isEmpty);
    });

    test('trailing punctuation is not part of the URL', () {
      final message = plain('Hi', 'Go to https://x.test/verify?t=1.');
      final link = CodeExtraction.extract(message).whereType<MagicLink>().first;
      expect(link.url.toString(), 'https://x.test/verify?t=1');
    });
  });
}
