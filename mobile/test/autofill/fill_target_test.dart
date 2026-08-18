import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/autofill/fill_target.dart';

AutofillRequest request({
  String packageName = 'com.android.chrome',
  bool browserTrusted = true,
  List<String> webDomains = const <String>['example.com'],
  bool wantsPassword = true,
  bool wantsUsername = false,
  bool wantsEmail = false,
}) =>
    AutofillRequest(
      packageName: packageName,
      browserTrusted: browserTrusted,
      webDomains: webDomains,
      wantsPassword: wantsPassword,
      wantsUsername: wantsUsername,
      wantsEmail: wantsEmail,
    );

String? filledDomain(FillDecision decision) =>
    decision is FillFor ? decision.domain : null;

FillRefusal? refusal(FillDecision decision) =>
    decision is FillRefused ? decision.reason : null;

void main() {
  group('a recognised browser on a normal page', () {
    test('fills for the page it reports', () {
      expect(filledDomain(FillTarget.decide(request())), 'example.com');
    });

    test('a subdomain keys on the registrable domain', () {
      // Otherwise accounts.google.com and mail.google.com would derive two
      // different identities for one account.
      final decision = FillTarget.decide(
        request(webDomains: <String>['accounts.google.com']),
      );
      expect(filledDomain(decision), 'google.com');
    });

    test('the same site written several ways is still one site', () {
      final decision = FillTarget.decide(
        request(webDomains: <String>[
          'https://twitter.com/login',
          'www.twitter.com',
          'mobile.twitter.com',
        ]),
      );
      expect(filledDomain(decision), 'twitter.com');
    });

    test('a multi-part suffix is not mistaken for a domain', () {
      expect(
        filledDomain(FillTarget.decide(request(webDomains: <String>['bbc.co.uk']))),
        'bbc.co.uk',
      );
      expect(
        filledDomain(
          FillTarget.decide(request(webDomains: <String>['news.bbc.co.uk'])),
        ),
        'bbc.co.uk',
      );
    });
  });

  group('what it refuses to fill', () {
    test('an app that is not a recognised browser', () {
      // The important refusal. Filling into an app needs a trustworthy answer
      // to "which website is this?", and a package name is evidence about who
      // wrote something, not about who owns it.
      expect(
        refusal(FillTarget.decide(
          request(packageName: 'com.twitter.android', browserTrusted: false),
        )),
        FillRefusal.notABrowser,
      );
    });

    test('a browser package name with the wrong signature', () {
      // The platform reports browserTrusted false when the certificate does
      // not match, and a name alone must never be enough.
      expect(
        refusal(FillTarget.decide(
          request(packageName: 'com.android.chrome', browserTrusted: false),
        )),
        FillRefusal.notABrowser,
      );
    });

    test('two different sites in one structure', () {
      // A page with a login form and an embedded third-party frame. There is
      // no way to tell from here which one the focused field belongs to, and
      // choosing wrong types one site's password into another's form.
      expect(
        refusal(FillTarget.decide(
          request(webDomains: <String>['bank.example', 'ads.tracker.test']),
        )),
        FillRefusal.ambiguousDomain,
      );
    });

    test('a page with no domain reported', () {
      expect(
        refusal(FillTarget.decide(request(webDomains: <String>[]))),
        FillRefusal.noDomain,
      );
    });

    test('an address with no registrable domain', () {
      for (final raw in <String>['localhost', '127.0.0.1', 'com', '']) {
        expect(
          refusal(FillTarget.decide(request(webDomains: <String>[raw]))),
          FillRefusal.underivableDomain,
          reason: raw,
        );
      }
    });

    test('one usable domain beside one unusable one is still refused', () {
      // Answering for the half that parsed answers a question nobody asked.
      expect(
        refusal(FillTarget.decide(
          request(webDomains: <String>['bank.example', 'localhost']),
        )),
        FillRefusal.underivableDomain,
      );
    });

    test('a form with nothing Shadow fills', () {
      expect(
        refusal(FillTarget.decide(request(
          wantsPassword: false,
          wantsUsername: false,
          wantsEmail: false,
        ))),
        FillRefusal.nothingToFill,
      );
    });
  });

  group('hostile domain strings', () {
    test('a userinfo section cannot smuggle another domain in', () {
      // https://evil.test/@bank.com and https://bank.com@evil.test are the
      // classic pair. Both are evil.test, and a parser that splits on '/' or
      // takes the text after '@' gets one of them wrong.
      expect(
        filledDomain(
          FillTarget.decide(request(webDomains: <String>['https://evil.test/@bank.com'])),
        ),
        'evil.test',
      );
      expect(
        filledDomain(
          FillTarget.decide(request(webDomains: <String>['https://bank.com@evil.test/'])),
        ),
        'evil.test',
      );
    });

    test('a port and a path are not part of the domain', () {
      expect(
        filledDomain(FillTarget.decide(
          request(webDomains: <String>['https://shop.example.com:8443/login?a=b']),
        )),
        'example.com',
      );
    });

    test('case and whitespace do not create a second site', () {
      expect(
        filledDomain(FillTarget.decide(
          request(webDomains: <String>['  Example.COM  ', 'example.com']),
        )),
        'example.com',
      );
    });
  });

  group('what the user is told', () {
    test('every refusal has copy that says what to do instead', () {
      for (final reason in FillRefusal.values) {
        final text = FillTarget.explain(reason);
        expect(text, isNotEmpty, reason: reason.name);
        expect(text.length, greaterThan(20), reason: reason.name);
      }
    });
  });
}
