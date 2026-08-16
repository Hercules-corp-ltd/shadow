import 'package:shadow_mobile/identity/identity.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fixed phrase so every expectation below is reproducible. This is a test
/// vector, never a wallet — do not fund it.
const String testPhrase =
    'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

const String aliasDomain = 'mail.shadow.test';

void main() {
  group('RegistrableDomain', () {
    test('collapses every route to a site onto one key', () {
      const expected = 'twitter.com';
      for (final input in <String>[
        'twitter.com',
        'www.twitter.com',
        'TWITTER.COM',
        'https://twitter.com',
        'https://www.twitter.com/settings/account',
        'http://mobile.twitter.com:8080/home?x=1#frag',
        'twitter.com.',
      ]) {
        expect(RegistrableDomain.of(input), expected, reason: 'input: $input');
      }
    });

    test('separates tenants on multi-tenant hosts', () {
      // The reason the full Public Suffix List ships. Under the old curated
      // subset these collapsed to one registrable domain, so two unrelated
      // shops shared one derived identity — and, once addresses are real,
      // one mailbox. Whoever ran shop A could reset the user's password at
      // shop B and read the code.
      expect(RegistrableDomain.of('alice.myshopify.com'),
          'alice.myshopify.com');
      expect(RegistrableDomain.of('bob.myshopify.com'), 'bob.myshopify.com');
      expect(
        RegistrableDomain.of('alice.myshopify.com'),
        isNot(RegistrableDomain.of('bob.myshopify.com')),
      );

      for (final host in <String>[
        'someone.blogspot.com',
        'someone.notion.site',
        'someone.wixsite.com',
        'someone.github.io',
        'someone.pages.dev',
      ]) {
        expect(RegistrableDomain.of(host), host, reason: host);
      }
    });

    test('separates tenants the PSL itself does not list', () {
      // The PSL's private section is opt-in, and these operators never
      // submitted. Without the supplement in tool/build_psl.mjs they would
      // still collapse, so this test is what stops the supplement being
      // dropped as redundant.
      expect(RegistrableDomain.of('alice.wordpress.com'),
          'alice.wordpress.com');
      expect(RegistrableDomain.of('someones.substack.com'),
          'someones.substack.com');
      expect(RegistrableDomain.of('acme.atlassian.net'), 'acme.atlassian.net');
    });

    test('a company keeps one identity across its own subdomains', () {
      // The opposite failure. Over-splitting would give the user different
      // credentials for the login page and the account page of one site.
      expect(RegistrableDomain.of('accounts.google.com'), 'google.com');
      expect(RegistrableDomain.of('mail.google.com'), 'google.com');
      expect(RegistrableDomain.of('shop.example.co.uk'), 'example.co.uk');
    });

    test('handles wildcard and exception rules', () {
      // `*.ck` makes any label under ck a public suffix...
      expect(RegistrableDomain.of('anything.ck'), 'anything.ck');
      expect(RegistrableDomain.of('shop.anything.ck'), 'shop.anything.ck');
      // ...except www.ck, which `!www.ck` hands back as registrable.
      expect(RegistrableDomain.of('www.ck'), 'www.ck');
      expect(RegistrableDomain.of('city.kobe.jp'), 'city.kobe.jp');
    });

    test('keeps the registrable label for multi-part public suffixes', () {
      expect(RegistrableDomain.of('www.bbc.co.uk'), 'bbc.co.uk');
      expect(RegistrableDomain.of('shop.example.com.au'), 'example.com.au');
      expect(RegistrableDomain.of('someone.github.io'), 'someone.github.io');
    });

    test('treats IP literals and single-label hosts as their own key', () {
      expect(RegistrableDomain.of('127.0.0.1'), '127.0.0.1');
      expect(RegistrableDomain.of('localhost'), 'localhost');
      expect(RegistrableDomain.of('http://192.168.1.4:3000/x'), '192.168.1.4');
    });

    test('rejects empty input rather than deriving from nothing', () {
      expect(() => RegistrableDomain.of('   '), throwsFormatException);
      expect(RegistrableDomain.tryOf(''), isNull);
    });
  });

  group('ShadowIdentity derivation', () {
    final engine = ShadowIdentity.fromMnemonic(testPhrase, passphrase: 'unit-test');

    test('is deterministic — the same phrase rebuilds the same account', () {
      final rebuilt = ShadowIdentity.fromMnemonic(testPhrase, passphrase: 'unit-test');
      final a = engine.forSite('twitter.com', aliasDomain: aliasDomain);
      final b = rebuilt.forSite('twitter.com', aliasDomain: aliasDomain);

      expect(a.email, b.email);
      expect(a.password, b.password);
      expect(a.handle, b.handle);
    });

    test('gives every site a different, unlinkable identity', () {
      final twitter = engine.forSite('twitter.com', aliasDomain: aliasDomain);
      final reddit = engine.forSite('reddit.com', aliasDomain: aliasDomain);

      expect(twitter.email, isNot(reddit.email));
      expect(twitter.password, isNot(reddit.password));
      expect(twitter.handle, isNot(reddit.handle));
    });

    test('separates identities by passphrase, so a leaked branch is contained', () {
      final other = ShadowIdentity.fromMnemonic(testPhrase, passphrase: 'different');
      final a = engine.forSite('twitter.com', aliasDomain: aliasDomain);
      final b = other.forSite('twitter.com', aliasDomain: aliasDomain);

      expect(a.password, isNot(b.password));
      expect(a.email, isNot(b.email));
    });

    test('supports multiple accounts on one site', () {
      final first = engine.forSite('twitter.com', aliasDomain: aliasDomain);
      final second =
          engine.forSite('twitter.com', aliasDomain: aliasDomain, accountIndex: 1);

      expect(first.email, isNot(second.email));
      expect(first.password, isNot(second.password));
      expect(second.accountIndex, 1);
    });

    test('rotating the password leaves the mailbox where it was', () {
      // The bug this pair of counters exists to prevent. One number for both
      // meant that changing a password after a breach also changed the
      // address the site had on file — so the reset mail went to a mailbox
      // that no longer existed, and the account was gone.
      final original = engine.forSite('twitter.com', aliasDomain: aliasDomain);
      final rotated = engine.forSite('twitter.com',
          aliasDomain: aliasDomain, passwordEpoch: 2);

      expect(rotated.password, isNot(original.password));
      expect(rotated.email, original.email);
      expect(rotated.isRotated, isTrue);
      expect(original.isRotated, isFalse);
    });

    test('burning the address leaves the password where it was', () {
      // And the converse: replacing a leaked address must not lock the user
      // out of the account it belongs to.
      final original = engine.forSite('twitter.com', aliasDomain: aliasDomain);
      final burned = engine.forSite('twitter.com',
          aliasDomain: aliasDomain, aliasEpoch: 2);

      expect(burned.email, isNot(original.email));
      expect(burned.password, original.password);
      expect(burned.handle, original.handle);
      expect(burned.isRotated, isTrue);
    });

    test('the two counters are genuinely independent', () {
      final both = engine.forSite('twitter.com',
          aliasDomain: aliasDomain, passwordEpoch: 3, aliasEpoch: 2);
      final passwordOnly = engine.forSite('twitter.com',
          aliasDomain: aliasDomain, passwordEpoch: 3);
      final aliasOnly = engine.forSite('twitter.com',
          aliasDomain: aliasDomain, aliasEpoch: 2);

      expect(both.password, passwordOnly.password);
      expect(both.email, aliasOnly.email);
    });

    test('builds a usable alias on the configured catch-all domain', () {
      final identity = engine.forSite('twitter.com', aliasDomain: aliasDomain);
      final parts = identity.email.split('@');

      expect(parts, hasLength(2));
      expect(parts[1], aliasDomain);
      expect(parts[0], hasLength(SiteMailboxKeys.localPartLength));
      expect(parts[0], matches(RegExp(r'^[a-z2-7]+$')));
      // The address is the mailbox, not a separate string that happens to
      // look like one.
      expect(parts[0], engine.mailboxKeysFor('twitter.com').localPart);
    });

    test('rejects a mistyped recovery phrase instead of deriving nonsense', () {
      expect(
        () => ShadowIdentity.fromMnemonic('abandon abandon abandon'),
        throwsFormatException,
      );
      expect(ShadowIdentity.isValidMnemonic(testPhrase), isTrue);
      expect(ShadowIdentity.isValidMnemonic('not a real phrase at all'), isFalse);
    });

    test('generated phrases are valid and distinct', () {
      final first = ShadowIdentity.generateMnemonic();
      final second = ShadowIdentity.generateMnemonic();

      expect(first.split(' '), hasLength(12));
      expect(ShadowIdentity.isValidMnemonic(first), isTrue);
      expect(first, isNot(second));
    });

    test('requires a catch-all alias domain', () {
      expect(
        () => engine.forSite('twitter.com', aliasDomain: 'nonsense'),
        throwsArgumentError,
      );
      expect(
        () => engine.forSite('twitter.com', aliasDomain: ''),
        throwsArgumentError,
      );
    });

    test('rejects an out-of-range account index or version', () {
      expect(
        () => engine.forSite('a.com', aliasDomain: aliasDomain, accountIndex: -1),
        throwsArgumentError,
      );
      expect(
        () => engine.forSite('a.com', aliasDomain: aliasDomain, passwordEpoch: 0),
        throwsArgumentError,
      );
    });

    test('does not leak the password through toString', () {
      final identity = engine.forSite('twitter.com', aliasDomain: aliasDomain);
      expect(identity.toString(), isNot(contains(identity.password)));
    });

    test('a different passphrase is visibly a different identity', () {
      // The failure this exists to catch: BIP-39 checksums the words, not the
      // passphrase, so `Shadow` for `shadow` unlocks perfectly into an empty
      // universe of accounts and says nothing.
      final a = ShadowIdentity.fromMnemonic(testPhrase, passphrase: 'shadow');
      final b = ShadowIdentity.fromMnemonic(testPhrase, passphrase: 'Shadow');

      expect(a.passphraseVerifier, isNot(b.passphraseVerifier));
      expect(a.fingerprint, isNot(b.fingerprint));
    });

    test('the same passphrase always gives the same verifier and label', () {
      final a = ShadowIdentity.fromMnemonic(testPhrase, passphrase: 'shadow');
      final b = ShadowIdentity.fromMnemonic(testPhrase, passphrase: 'shadow');

      expect(a.passphraseVerifier, b.passphraseVerifier);
      expect(a.fingerprint, b.fingerprint);
    });

    test('the fingerprint is four readable words, not a credential', () {
      final identity = engine.forSite('twitter.com', aliasDomain: aliasDomain);
      final fingerprint = engine.fingerprint;

      expect(fingerprint.split(RegExp(r'[ ·]+')).length, 4);
      expect(fingerprint, matches(RegExp(r'^[a-z]+ [a-z]+ · [a-z]+ [a-z]+$')));
      // It names the identity; it must never carry anything derived for a
      // site, because it is shown on screen and meant to be spoken about.
      expect(fingerprint, isNot(contains(identity.password)));
      expect(fingerprint, isNot(contains(identity.handle)));
    });

    test('the verifier does not expose the branch or any credential', () {
      final identity = engine.forSite('twitter.com', aliasDomain: aliasDomain);
      expect(engine.passphraseVerifier, isNot(contains(identity.password)));
      expect(engine.passphraseVerifier.length, greaterThanOrEqualTo(12));
      expect(engine.passphraseVerifier, matches(RegExp(r'^[a-z2-7]+$')));
    });

    test('fingerprint and verifier are refused after wipe', () {
      final wiped = ShadowIdentity.fromMnemonic(testPhrase)..wipe();
      expect(() => wiped.fingerprint, throwsStateError);
      expect(() => wiped.passphraseVerifier, throwsStateError);
    });

    test('refuses to derive after wipe instead of deriving from zeros', () {
      final wiped = ShadowIdentity.fromMnemonic(testPhrase);
      wiped.wipe();
      expect(
        () => wiped.forSite('twitter.com', aliasDomain: aliasDomain),
        throwsStateError,
      );
    });

    test('a wiped engine cannot produce the same identity as another', () {
      // The failure this guards against is not "wrong credentials" but
      // "everyone's credentials are identical", because a zeroed branch key
      // is the same zeroed branch key on every device. Two engines built
      // from different phrases must not converge after wiping.
      final a = ShadowIdentity.fromMnemonic(testPhrase)..wipe();
      final b = ShadowIdentity.fromMnemonic(
        'legal winner thank year wave sausage worth useful legal '
        'winner thank yellow',
      )..wipe();

      expect(() => a.forSite('x.com', aliasDomain: aliasDomain),
          throwsStateError);
      expect(() => b.forSite('x.com', aliasDomain: aliasDomain),
          throwsStateError);
    });
  });

  group('PasswordShaper', () {
    final entropy = List<int>.generate(32, (i) => (i * 7 + 11) % 256);

    test('satisfies every required class', () {
      final password = PasswordShaper.shape(entropy: entropy);

      expect(password, matches(RegExp(r'[a-z]')));
      expect(password, matches(RegExp(r'[A-Z]')));
      expect(password, matches(RegExp(r'[2-9]')));
      expect(password.split('').any((c) => PasswordPolicy.defaultSymbols.contains(c)), isTrue);
      expect(password, hasLength(PasswordPolicy.standard.targetLength));
    });

    test('honours a site that forbids symbols', () {
      final password = PasswordShaper.shape(
        entropy: entropy,
        policy: PasswordPolicy.alphanumericOnly,
      );
      expect(password, matches(RegExp(r'^[a-zA-Z2-9]+$')));
    });

    test('honours a short legacy maximum', () {
      final password =
          PasswordShaper.shape(entropy: entropy, policy: PasswordPolicy.legacyShort);
      expect(password.length, lessThanOrEqualTo(12));
      expect(password.length, greaterThanOrEqualTo(8));
    });

    test('omits characters the site bans', () {
      const banned = r'!#$%&';
      const policy = PasswordPolicy(bannedCharacters: banned);
      for (var i = 0; i < 25; i++) {
        final password = PasswordShaper.shape(
          entropy: List<int>.generate(32, (j) => (i * 41 + j * 7) % 256),
          policy: policy,
        );
        for (final character in banned.split('')) {
          expect(password, isNot(contains(character)));
        }
      }
    });

    test('refuses to satisfy a rule the site makes impossible', () {
      // Requiring a symbol while banning every symbol is an adapter bug, and
      // failing loudly beats silently shipping a password the site rejects.
      const contradictory = PasswordPolicy(bannedCharacters: PasswordPolicy.defaultSymbols);
      expect(
        () => PasswordShaper.shape(entropy: entropy, policy: contradictory),
        throwsStateError,
      );
    });

    test('never emits characters that break shells, JSON or SQL escaping', () {
      for (var i = 0; i < 50; i++) {
        final password = PasswordShaper.shape(
          entropy: List<int>.generate(32, (j) => (i * 37 + j * 11) % 256),
        );
        for (final hazard in <String>['\\', '"', "'", '`', '<', '>', ';', ' ']) {
          expect(password, isNot(contains(hazard)),
              reason: 'password must not contain $hazard');
        }
      }
    });

    test('never emits visually ambiguous characters', () {
      for (var i = 0; i < 50; i++) {
        final password = PasswordShaper.shape(
          entropy: List<int>.generate(32, (j) => (i * 31 + j * 17) % 256),
        );
        for (final ambiguous in <String>['l', 'I', 'O', '0', '1']) {
          expect(password, isNot(contains(ambiguous)));
        }
      }
    });

    test('does not park required classes in a predictable order', () {
      // If shuffling were skipped every password would start lower, upper,
      // digit, symbol. Across many seeds that pattern must not hold.
      var alwaysClassOrder = true;
      for (var i = 0; i < 40; i++) {
        final password = PasswordShaper.shape(
          entropy: List<int>.generate(32, (j) => (i * 13 + j * 29) % 256),
        );
        final looksOrdered = RegExp(r'^[a-z][A-Z][2-9]').hasMatch(password);
        if (!looksOrdered) {
          alwaysClassOrder = false;
          break;
        }
      }
      expect(alwaysClassOrder, isFalse);
    });

    test('refuses a policy that cannot be satisfied', () {
      const impossible = PasswordPolicy(
        minLength: 4,
        maxLength: 4,
        preferredLength: 4,
        bannedCharacters: PasswordPolicy.lowercaseAlphabet,
      );
      expect(() => PasswordShaper.shape(entropy: entropy, policy: impossible),
          throwsStateError);
    });
  });

  group('DeterministicBytes', () {
    test('nextInt stays in range and is reproducible', () {
      const seed = <int>[1, 2, 3, 4, 5];
      final a = DeterministicBytes(seed);
      final b = DeterministicBytes(seed);

      for (var i = 0; i < 200; i++) {
        final value = a.nextInt(7);
        expect(value, inInclusiveRange(0, 6));
        expect(value, b.nextInt(7));
      }
    });

    test('is not measurably biased across a non-power-of-two range', () {
      // Modulo folding over 100 would skew low values; rejection sampling
      // should keep every bucket near the 1/100 expectation.
      final counts = List<int>.filled(100, 0);
      final stream = DeterministicBytes(const <int>[9, 9, 9]);
      const draws = 20000;
      for (var i = 0; i < draws; i++) {
        counts[stream.nextInt(100)]++;
      }
      const expectedPerBucket = draws / 100;
      for (final count in counts) {
        expect(count, greaterThan(expectedPerBucket * 0.6));
        expect(count, lessThan(expectedPerBucket * 1.4));
      }
    });

    test('different domain separators diverge from the same seed', () {
      final a = DeterministicBytes(const <int>[1, 2, 3], domainSeparator: 'password');
      final b = DeterministicBytes(const <int>[1, 2, 3], domainSeparator: 'handle');
      final fromA = List<int>.generate(16, (_) => a.nextByte());
      final fromB = List<int>.generate(16, (_) => b.nextByte());
      expect(fromA, isNot(fromB));
    });
  });

  group('HandleShaper', () {
    test('produces a pronounceable, site-safe handle', () {
      final handle = HandleShaper.shape(
        entropy: List<int>.generate(32, (i) => i * 3 % 256),
      );
      expect(handle, matches(RegExp(r'^[a-z]+\d{4}$')));
    });

    test('honours a separator for sites that allow one', () {
      final handle = HandleShaper.shape(
        entropy: List<int>.generate(32, (i) => i),
        separator: '_',
      );
      expect(handle, matches(RegExp(r'^[a-z]+_[a-z]+_\d{4}$')));
    });

    test('reports its own collision space honestly', () {
      expect(HandleShaper.combinations(), greaterThan(100000000));
    });
  });

  group('ShadowKdf', () {
    test('matches RFC 5869 structure: same inputs, same output', () {
      final a = ShadowKdf.derive(
        inputKeyMaterial: const <int>[1, 2, 3],
        salt: 'salt',
        info: 'info',
        length: 64,
      );
      final b = ShadowKdf.derive(
        inputKeyMaterial: const <int>[1, 2, 3],
        salt: 'salt',
        info: 'info',
        length: 64,
      );
      expect(a, b);
      expect(a, hasLength(64));
    });

    test('info string separates outputs', () {
      final a = ShadowKdf.derive(
        inputKeyMaterial: const <int>[1, 2, 3],
        salt: 'salt',
        info: 'one',
        length: 32,
      );
      final b = ShadowKdf.derive(
        inputKeyMaterial: const <int>[1, 2, 3],
        salt: 'salt',
        info: 'two',
        length: 32,
      );
      expect(a, isNot(b));
    });

    test('expands past one hash block correctly', () {
      final long = ShadowKdf.derive(
        inputKeyMaterial: const <int>[7],
        salt: 's',
        info: 'i',
        length: 200,
      );
      expect(long, hasLength(200));
      // A repeated block would mean the counter is not being mixed in.
      expect(long.sublist(0, 64), isNot(long.sublist(64, 128)));
    });

    test('base32 output is lowercase and unpadded', () {
      expect(base32Encode(const <int>[0, 1, 2, 3, 4]), matches(RegExp(r'^[a-z2-7]+$')));
      expect(base32Encode(const <int>[255, 255]), isNot(contains('=')));
    });
  });
}
