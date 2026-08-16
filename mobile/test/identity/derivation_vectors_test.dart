import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/identity/identity.dart';

/// Frozen output of the derivation, as it actually shipped.
///
/// Every other test in this suite checks *relationships* — same phrase gives
/// the same account, different sites give different ones. All of them stay
/// green if someone edits an HKDF info string, because the relationships
/// still hold. What changes is every credential every user has.
///
/// These are the values themselves. A failure here is not "a test broke", it
/// is "everyone's password just changed and nobody can log in anywhere",
/// which is not a thing that can be fixed forward. The only legitimate way to
/// change one of these is a deliberate migration with a plan for the accounts
/// already created against the old value.
///
/// Test vector, never a wallet — do not fund it.
const String phrase = 'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

const String aliasDomain = 'mail.shadow.test';

class Vector {
  const Vector({
    required this.passphrase,
    required this.domain,
    required this.accountIndex,
    required this.email,
    required this.password,
    required this.handle,
  });

  final String passphrase;
  final String domain;
  final int accountIndex;
  final String email;
  final String password;
  final String handle;

  String get label => 'passphrase "$passphrase", $domain, account $accountIndex';
}

const List<Vector> vectors = <Vector>[
  Vector(
    passphrase: '',
    domain: 'twitter.com',
    accountIndex: 0,
    email: 'hbsq2dsr3ffksbwlsklb@mail.shadow.test',
    password: r's#2&$!-JvWkuCr@_f??_Z_Q2',
    handle: 'lonecreek6350',
  ),
  Vector(
    passphrase: '',
    domain: 'twitter.com',
    accountIndex: 1,
    email: 'dj5yayjsv7wlf2jzpabp@mail.shadow.test',
    password: 'jFmWPrxnQLZ6FL4kE59%+MK-',
    handle: 'steadystream1297',
  ),
  Vector(
    passphrase: '',
    domain: 'example.co.uk',
    accountIndex: 0,
    email: '32b5tf2elhm6x6rem255@mail.shadow.test',
    password: 'Y_AJExJaJAiucCD2Yzj6_y%L',
    handle: 'royalpebble4943',
  ),
  Vector(
    passphrase: 'unit-test',
    domain: 'twitter.com',
    accountIndex: 0,
    email: 'dnmf6rh5glisz7nhzctj@mail.shadow.test',
    password: r'7?8RG-dNkReMmNz@v#qV9&Zg',
    handle: 'arcticorchard7951',
  ),
  Vector(
    passphrase: 'unit-test',
    domain: 'example.co.uk',
    accountIndex: 1,
    email: '63m6lmymha6bueg3q65n@mail.shadow.test',
    password: r'oZ3#+CB7%orGZ5*zWRAgD&g9',
    handle: 'silentdune2337',
  ),
];

void main() {
  group('frozen derivation vectors', () {
    test('passwords have not moved', () {
      for (final v in vectors) {
        final engine =
            ShadowIdentity.fromMnemonic(phrase, passphrase: v.passphrase);
        final identity = engine.forSite(
          v.domain,
          aliasDomain: aliasDomain,
          accountIndex: v.accountIndex,
        );
        expect(identity.password, v.password, reason: v.label);
      }
    });

    test('handles have not moved', () {
      for (final v in vectors) {
        final engine =
            ShadowIdentity.fromMnemonic(phrase, passphrase: v.passphrase);
        final identity = engine.forSite(
          v.domain,
          aliasDomain: aliasDomain,
          accountIndex: v.accountIndex,
        );
        expect(identity.handle, v.handle, reason: v.label);
      }
    });

    test('addresses have not moved', () {
      // Separated from the password test on purpose. The address is derived
      // from a different branch and can be migrated on its own; the password
      // cannot, because a site will not accept a new one without the old.
      for (final v in vectors) {
        final engine =
            ShadowIdentity.fromMnemonic(phrase, passphrase: v.passphrase);
        final identity = engine.forSite(
          v.domain,
          aliasDomain: aliasDomain,
          accountIndex: v.accountIndex,
        );
        expect(identity.email, v.email, reason: v.label);
      }
    });

    test('the identity fingerprint and verifier have not moved', () {
      final plain = ShadowIdentity.fromMnemonic(phrase);
      expect(plain.fingerprint, 'rapid glacier · dawn brook');
      expect(plain.passphraseVerifier, 'qnwrkkla7od5c');

      final withPassphrase =
          ShadowIdentity.fromMnemonic(phrase, passphrase: 'unit-test');
      expect(withPassphrase.fingerprint, 'smooth fjord · rough forest');
      expect(withPassphrase.passphraseVerifier, 'g6gcwgbbvp2t6');
    });
  });

  group('HKDF-Expand is counter mode', () {
    test('asking for more bytes does not disturb the first 96', () {
      // This is what makes it safe to add key material to an existing
      // derivation at all. T(1) and T(2) depend on the PRK and the info
      // string, never on the requested length, so a longer request appends
      // rather than rewrites.
      const ikm = <int>[1, 2, 3, 4, 5];
      final short = ShadowKdf.derive(
        inputKeyMaterial: ikm,
        salt: 'salt',
        info: 'info',
        length: 96,
      );
      final long = ShadowKdf.derive(
        inputKeyMaterial: ikm,
        salt: 'salt',
        info: 'info',
        length: 192,
      );

      expect(long.sublist(0, 96), short);
    });
  });
}
