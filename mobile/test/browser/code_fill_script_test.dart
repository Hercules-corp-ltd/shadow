import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/browser/autofill_script.dart';
import 'package:shadow_mobile/browser/code_fill_script.dart';
import 'package:shadow_mobile/identity/identity.dart';

void main() {
  group('the code script never submits either', () {
    final script = CodeFillScript.build(
      code: '483920',
      expectedDomain: 'twitter.com',
    );

    test('contains no way to submit the form', () {
      for (final forbidden in <String>[
        '.submit(',
        '.click(',
        'requestSubmit',
        'keyCode: 13',
        "key: 'Enter'",
        'form.submit',
      ]) {
        expect(script, isNot(contains(forbidden)),
            reason: 'code fill must never $forbidden');
      }
    });

    test('never touches a captcha', () {
      for (final forbidden in <String>['captcha', 'recaptcha', 'g-recaptcha']) {
        expect(script.toLowerCase(), isNot(contains(forbidden)));
      }
    });

    test('uses the native setter so controlled inputs register', () {
      expect(script, contains('getOwnPropertyDescriptor'));
      expect(script, contains("dispatchEvent(new Event('input'"));
    });

    test('carries the code and the domain it is bound to', () {
      expect(script, contains('483920'));
      expect(script, contains('twitter.com'));
    });

    test('escapes a hostile code rather than embedding it as syntax', () {
      final nasty = CodeFillScript.build(
        code: r'''a"b'c\d</script>''',
        expectedDomain: 'twitter.com',
      );
      expect(nasty, isNot(contains('</script>')));
      expect(nasty, contains(r'\"'));
    });
  });

  group('the credential script keeps its own guarantee', () {
    test('still contains no reference to otp', () {
      // The reason code fill is a separate file. This assertion predates it
      // and must keep passing untouched — it defends the boundary that the
      // thing filling a signup form never goes near a challenge field.
      final credentials = AutofillScript.build(
        const SiteIdentity(
          registrableDomain: 'twitter.com',
          email: 'abc@mail.test',
          password: 'Aa1!bcdefghijklm',
          handle: 'quietharbor4821',
          accountIndex: 0,
          passwordEpoch: 1,
          aliasEpoch: 1,
        ),
      );

      for (final forbidden in <String>['otp', 'captcha', 'recaptcha']) {
        expect(credentials.toLowerCase(), isNot(contains(forbidden)));
      }
    });
  });

  group('a code may only be filled into the site it belongs to', () {
    bool may(String? url, String domain) => CodeFillScript.mayOffer(
          pageUrl: url == null ? null : Uri.parse(url),
          mailboxDomain: domain,
        );

    test('allows the owning site and its subdomains', () {
      expect(may('https://twitter.com/verify', 'twitter.com'), isTrue);
      expect(may('https://www.twitter.com/verify', 'twitter.com'), isTrue);
      expect(may('https://account.twitter.com/x', 'twitter.com'), isTrue);
    });

    test('refuses a different site, however convincing the mail', () {
      // The entire cross-site code-phishing class. A message can say
      // anything it likes; the code still cannot leave the site whose
      // mailbox it arrived in.
      expect(may('https://evil.test/verify', 'twitter.com'), isFalse);
      expect(may('https://twitter.com.evil.test/', 'twitter.com'), isFalse);
      expect(may('https://nottwitter.com/', 'twitter.com'), isFalse);
    });

    test('refuses http, matching the credential path', () {
      expect(may('http://twitter.com/verify', 'twitter.com'), isFalse);
    });

    test('refuses with no page or no mailbox', () {
      expect(may(null, 'twitter.com'), isFalse);
      expect(may('https://twitter.com/', ''), isFalse);
      expect(may('about:blank', 'twitter.com'), isFalse);
    });
  });
}
