import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/browser/autofill.dart';
import 'package:shadow_mobile/browser/autofill_script.dart';
import 'package:shadow_mobile/identity/identity.dart';

SiteIdentity identityWith({
  String email = 'abc123@mail.shadow.test',
  String password = r'Aa1!bcdefghijklm',
  String handle = 'quietharbor4821',
  String domain = 'twitter.com',
}) {
  return SiteIdentity(
    registrableDomain: domain,
    email: email,
    password: password,
    handle: handle,
    accountIndex: 0,
    passwordEpoch: 1,
    aliasEpoch: 1,
  );
}

void main() {
  group('AutofillScript — the never-submit guarantee', () {
    final script = AutofillScript.build(identityWith());

    test('contains no way to submit the form', () {
      // If a future edit adds any of these, the tool stops being a credential
      // manager and becomes an agent creating accounts on its own.
      for (final forbidden in <String>[
        '.submit(',
        '.click(',
        'requestSubmit',
        'keyCode: 13',
        "key: 'Enter'",
        'form.submit',
      ]) {
        expect(script, isNot(contains(forbidden)),
            reason: 'autofill must never $forbidden');
      }
    });

    test('never touches a captcha or a one-time-code field', () {
      for (final forbidden in <String>['captcha', 'recaptcha', 'otp', 'g-recaptcha']) {
        expect(script.toLowerCase(), isNot(contains(forbidden)));
      }
    });
  });

  group('AutofillScript — payload escaping', () {
    test('a password with quotes and backslashes cannot become code', () {
      const nasty = r'''a"b'c\d</script>''';
      final script = AutofillScript.build(identityWith(password: nasty));

      // The raw sequence must not appear unescaped anywhere in the payload.
      expect(script, isNot(contains(r'"a"b')));
      // JSON encoding must have escaped the quote and the backslash.
      expect(script, contains(r'\"'));
      expect(script, contains(r'\\'));
    });

    test('a closing script tag in a value is escaped, not literal', () {
      final script = AutofillScript.build(identityWith(email: 'x</script>@y.z'));
      expect(script, isNot(contains('</script>@y.z')));
    });

    test('embeds all three credentials', () {
      final script = AutofillScript.build(
        identityWith(
          email: 'seed@mail.test',
          handle: 'somehandle1234',
          password: 'Passw0rd!xyz',
        ),
      );
      expect(script, contains('seed@mail.test'));
      expect(script, contains('somehandle1234'));
      expect(script, contains('Passw0rd!xyz'));
    });

    test('uses the native value setter so React fields register the change', () {
      final script = AutofillScript.build(identityWith());
      expect(script, contains('getOwnPropertyDescriptor'));
      expect(script, contains("dispatchEvent(new Event('input'"));
    });
  });

  group('AutofillResult messaging', () {
    test('refuses an unencrypted page and says why', () {
      const result = AutofillResult.refused(AutofillRefusal.insecurePage);
      expect(result.succeeded, isFalse);
      expect(result.message, contains('not encrypted'));
    });

    test('tells a locked user what to do', () {
      const result = AutofillResult.refused(AutofillRefusal.identityLocked);
      expect(result.message, contains('Unlock'));
    });

    test('reports finding no fields rather than claiming success', () {
      const result = AutofillResult.refused(AutofillRefusal.noFieldsFound);
      expect(result.succeeded, isFalse);
      expect(result.message, contains('No sign-up or login fields'));
    });
  });

  group('Autofill policy — checked before any script is built', () {
    test('refuses when no page is open', () {
      expect(
        Autofill.refusalFor(pageUrl: null, identityUnlocked: true),
        AutofillRefusal.noPage,
      );
      expect(
        Autofill.refusalFor(
            pageUrl: Uri.parse('about:blank'), identityUnlocked: true),
        AutofillRefusal.noPage,
      );
    });

    test('refuses http, so a password never goes out in cleartext', () {
      expect(
        Autofill.refusalFor(
          pageUrl: Uri.parse('http://twitter.com/signup'),
          identityUnlocked: true,
        ),
        AutofillRefusal.insecurePage,
      );
    });

    test('refuses when the identity is locked', () {
      expect(
        Autofill.refusalFor(
          pageUrl: Uri.parse('https://twitter.com/signup'),
          identityUnlocked: false,
        ),
        AutofillRefusal.identityLocked,
      );
    });

    test('allows an https page with an unlocked identity', () {
      expect(
        Autofill.refusalFor(
          pageUrl: Uri.parse('https://twitter.com/signup'),
          identityUnlocked: true,
        ),
        isNull,
      );
    });

    test('http is refused ahead of the lock, even when both are wrong', () {
      // Order matters beyond tidiness. The browser screen shows a preview
      // of the derived password once this returns null, so an http page has
      // to be turned away on the scheme alone — before anything about the
      // identity is consulted, derived or rendered.
      expect(
        Autofill.refusalFor(
          pageUrl: Uri.parse('http://twitter.com/signup'),
          identityUnlocked: false,
        ),
        AutofillRefusal.insecurePage,
      );
    });
  });

  group('derived identities are phishing-resistant by construction', () {
    test('a lookalike domain gets entirely different credentials', () {
      final engine = ShadowIdentity.fromMnemonic(
        ShadowIdentity.generateMnemonic(),
        passphrase: 'test',
      );
      final real = engine.forSite('twitter.com', aliasDomain: 'mail.test.dev');
      final fake =
          engine.forSite('twitter-login.example', aliasDomain: 'mail.test.dev');

      expect(fake.password, isNot(real.password));
      expect(fake.email, isNot(real.email));
      expect(fake.handle, isNot(real.handle));
    });
  });
}

