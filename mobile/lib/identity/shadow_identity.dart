import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;

import 'shadow_kdf.dart';
import 'handle_shaper.dart';
import 'password_policy.dart';
import 'password_shaper.dart';
import 'registrable_domain.dart';
import 'site_identity.dart';

/// Derives a distinct, unlinkable identity for every site from one recovery
/// phrase.
///
/// The wallet does not become the user's account on a site. It becomes the
/// seed that generates an ordinary account — an email address, a password and
/// a username — which the site accepts exactly as it would any other signup,
/// and which nothing links back to the user or to their other accounts.
///
/// ## Why the per-site step is not memory-hard
///
/// A memory-hard KDF exists to make guessing a *low-entropy* input expensive.
/// The input here is [_branchKey]: 256 bits derived from a BIP-39 phrase
/// carrying 128–256 bits of its own entropy. There is nothing to guess, so
/// Argon2id per site would buy no security while costing seconds of phone
/// battery on every derivation. The stretching that does matter happens once,
/// at the phrase-and-passphrase boundary, which BIP-39 already performs.
///
/// ## Why the branch is separated
///
/// [passphrase] should not be empty in production. It puts the identity root
/// on a different branch from any trading key derived from the same phrase,
/// so a seed exposed while signing a transaction does not also surrender
/// every account the user owns. There is no revocation primitive here: a
/// leaked root is total and permanent identity loss, and separation is the
/// only mitigation available.
class ShadowIdentity {
  ShadowIdentity._(this._branchKey);

  /// Bumping this re-derives every credential for every site, so it changes
  /// only if the construction below is found to be unsound.
  static const String schemeVersion = 'cred/v1';

  static const String _rootSalt = 'shadow.identity.v1';
  static const String _branchInfo = 'credential-branch';

  final Uint8List _branchKey;

  /// Builds an engine from a BIP-39 recovery phrase.
  ///
  /// Throws [FormatException] if the phrase fails its checksum, which catches
  /// the overwhelmingly common failure of a mistyped or misremembered word
  /// before it silently produces a wrong, unrecoverable identity.
  factory ShadowIdentity.fromMnemonic(String mnemonic, {String passphrase = ''}) {
    final normalized = mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (!bip39.validateMnemonic(normalized)) {
      throw const FormatException(
        'Recovery phrase is not valid. Check for a mistyped or missing word.',
      );
    }
    final seed = bip39.mnemonicToSeed(normalized, passphrase: passphrase);
    final branchKey = ShadowKdf.derive(
      inputKeyMaterial: seed,
      salt: _rootSalt,
      info: _branchInfo,
      length: 32,
    );
    return ShadowIdentity._(branchKey);
  }

  /// Generates a fresh 12-word recovery phrase (128 bits of entropy).
  static String generateMnemonic({int strength = 128}) =>
      bip39.generateMnemonic(strength: strength);

  static bool isValidMnemonic(String mnemonic) => bip39.validateMnemonic(
        mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
      );

  /// Derives the identity for [host].
  ///
  /// [host] may be a bare domain, a host with a port or a full URL; it is
  /// normalised to a registrable domain first so every route to the same site
  /// yields the same credentials.
  ///
  /// [aliasDomain] must be a domain the user controls with catch-all mail
  /// enabled, or an aliasing provider that accepts arbitrary local-parts.
  /// Apple's Hide My Email cannot be used: Apple mints those addresses, so
  /// they cannot be derived.
  SiteIdentity forSite(
    String host, {
    required String aliasDomain,
    int accountIndex = 0,
    int version = 1,
    PasswordPolicy policy = PasswordPolicy.standard,
    String handleSeparator = '',
  }) {
    if (accountIndex < 0) {
      throw ArgumentError.value(accountIndex, 'accountIndex', 'must not be negative');
    }
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'must be at least 1');
    }
    final cleanAliasDomain = aliasDomain.trim().toLowerCase().replaceAll(RegExp(r'^@'), '');
    if (cleanAliasDomain.isEmpty || !cleanAliasDomain.contains('.')) {
      throw ArgumentError.value(
        aliasDomain,
        'aliasDomain',
        'must be a domain that accepts catch-all mail, such as mail.example.com',
      );
    }

    final domain = RegistrableDomain.of(host);

    // One derivation, split three ways, so the password cannot be recovered
    // from the alias or the handle even if either is public.
    final material = ShadowKdf.derive(
      inputKeyMaterial: _branchKey,
      salt: domain,
      info: '$schemeVersion|$domain|$accountIndex|$version',
      length: 96,
    );

    final passwordEntropy = material.sublist(0, 32);
    final aliasEntropy = material.sublist(32, 64);
    final handleEntropy = material.sublist(64, 96);

    // 12 base32 characters is 60 bits — far past any collision concern
    // within one catch-all domain, and still short enough to read out loud.
    final localPart = base32Encode(aliasEntropy).substring(0, 12);

    return SiteIdentity(
      registrableDomain: domain,
      email: '$localPart@$cleanAliasDomain',
      password: PasswordShaper.shape(entropy: passwordEntropy, policy: policy),
      handle: HandleShaper.shape(entropy: handleEntropy, separator: handleSeparator),
      accountIndex: accountIndex,
      version: version,
    );
  }

  /// Clears the branch key from memory. Call on lock.
  ///
  /// Dart offers no guarantee the value has not already been copied by the
  /// garbage collector, so treat this as reducing exposure rather than
  /// eliminating it.
  void wipe() {
    for (var i = 0; i < _branchKey.length; i++) {
      _branchKey[i] = 0;
    }
  }
}
