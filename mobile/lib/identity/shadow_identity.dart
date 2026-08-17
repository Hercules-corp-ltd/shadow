import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;

import 'shadow_kdf.dart';
import 'handle_shaper.dart';
import 'password_policy.dart';
import 'password_shaper.dart';
import 'registrable_domain.dart';
import 'site_identity.dart';
import 'site_mailbox_keys.dart';

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
  ///
  /// Note for anyone adding a new kind of derived secret: give it its own
  /// scheme constant below rather than touching this one. This string feeds
  /// the password, so editing it to accommodate something unrelated changes
  /// every password ever issued.
  static const String schemeVersion = 'cred/v1';

  /// Independent of [schemeVersion] on purpose. Bumping this changes every
  /// address and orphans every mailbox; bumping that one changes every
  /// password. They must never be the same knob.
  static const String mailboxSchemeVersion = 'mail/v1';

  /// The one shareable address, which is not keyed on any site.
  static const String handleSchemeVersion = 'handle/v1';
  static const String _handleSalt = 'shadow.handle';

  static const String _rootSalt = 'shadow.identity.v1';
  static const String _branchInfo = 'credential-branch';
  static const String _fingerprintInfo = 'identity-fingerprint/v1';
  static const String _verifierInfo = 'identity-verifier/v1';
  static const String _backupInfo = 'adapter-backup/v1';

  /// A short, memorable label for *which* identity this is.
  ///
  /// BIP-39 checksums the words but not the passphrase, so `Shadow` instead
  /// of `shadow` unlocks successfully into a completely different, entirely
  /// empty universe of accounts with no error anywhere. Showing this on the
  /// unlock screen turns that silent divergence into something a person can
  /// notice in one glance.
  ///
  /// Safe to display; never send it anywhere. It is a stable identifier for
  /// one identity, so off the device it would be a correlation handle.
  String get fingerprint {
    _assertUsable();
    return HandleShaper.fingerprint(
      ShadowKdf.derive(
        inputKeyMaterial: _branchKey,
        salt: _rootSalt,
        info: _fingerprintInfo,
        length: 16,
      ),
    );
  }

  /// A value that proves a later unlock used the same passphrase.
  ///
  /// Stored once, on first unlock, and compared on every unlock afterwards.
  ///
  /// The honest trade: someone holding both the device's keystore and this
  /// value can test passphrase guesses offline. That costs one BIP-39 seed
  /// derivation per guess — which is exactly what it already costs them to
  /// test a guess by deriving a credential and trying it at a site they know
  /// the user uses. So this changes convenience rather than difficulty, and
  /// it buys the difference between a wrong passphrase failing loudly and a
  /// wrong passphrase silently orphaning every account the user owns.
  String get passphraseVerifier {
    _assertUsable();
    final bytes = ShadowKdf.derive(
      inputKeyMaterial: _branchKey,
      salt: _rootSalt,
      info: _verifierInfo,
      length: 8,
    );
    return base32Encode(bytes);
  }

  final Uint8List _branchKey;

  /// Set by [wipe], and checked before every derivation.
  ///
  /// [wipe] zeroes the branch key in place. Without this flag a derivation
  /// afterwards would not fail — it would succeed against 32 zero bytes and
  /// return a plausible-looking identity that is *the same for every user on
  /// earth*. A wrong password is the mild version of that. Once a derived
  /// address is a real mailbox, it is a local part every installation
  /// computes identically and then tries to claim.
  ///
  /// Today nothing reaches it, because `IdentityProvider.lock()` nulls the
  /// engine immediately after wiping. That is luck, not design, and it is one
  /// refactor away from not being true.
  bool _wiped = false;

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
    int passwordEpoch = 1,
    int aliasEpoch = 1,
    PasswordPolicy policy = PasswordPolicy.standard,
    String handleSeparator = '',
  }) {
    _assertUsable();
    if (accountIndex < 0) {
      throw ArgumentError.value(accountIndex, 'accountIndex', 'must not be negative');
    }
    if (passwordEpoch < 1) {
      throw ArgumentError.value(
          passwordEpoch, 'passwordEpoch', 'must be at least 1');
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
    //
    // Bytes 32..64 used to be the address. They are left as a hole rather
    // than reclaimed: the handle sits at 64..96 and moving it would change
    // every username already typed into a signup form. The address now comes
    // off the mail branch instead, so that it can be burned on its own
    // counter without touching the password.
    final material = ShadowKdf.derive(
      inputKeyMaterial: _branchKey,
      salt: domain,
      info: '$schemeVersion|$domain|$accountIndex|$passwordEpoch',
      length: 96,
    );

    final passwordEntropy = material.sublist(0, 32);
    final handleEntropy = material.sublist(64, 96);

    final mailbox = mailboxKeysFor(
      host,
      accountIndex: accountIndex,
      aliasEpoch: aliasEpoch,
    );

    return SiteIdentity(
      registrableDomain: domain,
      email: mailbox.addressAt(cleanAliasDomain),
      password: PasswordShaper.shape(entropy: passwordEntropy, policy: policy),
      handle: HandleShaper.shape(entropy: handleEntropy, separator: handleSeparator),
      accountIndex: accountIndex,
      passwordEpoch: passwordEpoch,
      aliasEpoch: aliasEpoch,
    );
  }

  /// Derives the mailbox keys for [host].
  ///
  /// A separate HKDF from [forSite] rather than more bytes on the same one,
  /// and the reason is the counter rather than tidiness. The info string is
  /// where the rotation counter lives, so sharing one string means sharing
  /// one counter — and rotating a password after a breach would then change
  /// the address the site mails, silently orphaning the mailbox. Separate
  /// counters require separate strings.
  ///
  /// [aliasEpoch] burns the address and nothing else. It is deliberately not
  /// the same number as the password's epoch.
  SiteMailboxKeys mailboxKeysFor(
    String host, {
    int accountIndex = 0,
    int aliasEpoch = 1,
  }) {
    _assertUsable();
    if (accountIndex < 0) {
      throw ArgumentError.value(
          accountIndex, 'accountIndex', 'must not be negative');
    }
    if (aliasEpoch < 1) {
      throw ArgumentError.value(aliasEpoch, 'aliasEpoch', 'must be at least 1');
    }

    final domain = RegistrableDomain.of(host);
    return SiteMailboxKeys.fromMaterial(
      ShadowKdf.derive(
        inputKeyMaterial: _branchKey,
        salt: domain,
        info: '$mailboxSchemeVersion|$domain|$accountIndex|$aliasEpoch',
        length: SiteMailboxKeys.materialLength,
      ),
    );
  }

  /// Derives the keys for the user's one shareable address.
  ///
  /// Unlike a per-site mailbox this one is meant to be given out, so it is
  /// not keyed on any site. That also means it cannot be unlinkable: it is a
  /// single permanent identifier by construction, which is exactly the trade
  /// a user makes in exchange for an address they can say out loud.
  SiteMailboxKeys handleMailboxKeys({int handleEpoch = 1}) {
    _assertUsable();
    if (handleEpoch < 1) {
      throw ArgumentError.value(
          handleEpoch, 'handleEpoch', 'must be at least 1');
    }
    return SiteMailboxKeys.fromMaterial(
      ShadowKdf.derive(
        inputKeyMaterial: _branchKey,
        salt: _handleSalt,
        info: '$handleSchemeVersion|$handleEpoch',
        length: SiteMailboxKeys.materialLength,
      ),
    );
  }

  /// The key an adapter backup is encrypted to.
  ///
  /// Derived from the phrase rather than from a password the user picks,
  /// because a backup of which sites you have accounts on is exactly as
  /// sensitive as the accounts, and a second password is a second thing to
  /// lose. The phrase already restores everything else; this makes it
  /// restore the rotation state too.
  ///
  /// Its own info string, so the bytes are unrelated to any credential.
  Uint8List backupKey() {
    _assertUsable();
    return ShadowKdf.derive(
      inputKeyMaterial: _branchKey,
      salt: _rootSalt,
      info: _backupInfo,
      length: 32,
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
    _wiped = true;
  }

  /// Refuses to derive anything from a wiped key. See [_wiped].
  void _assertUsable() {
    if (_wiped) {
      throw StateError(
        'This identity has been wiped. Unlock again before deriving.',
      );
    }
  }
}
