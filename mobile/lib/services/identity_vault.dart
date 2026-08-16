// Identity Vault — custody of the recovery phrase that every Shadow identity
// descends from. Named for Hestia, who keeps the hearth.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the recovery phrase in the platform keystore, and nothing else.
///
/// Two deliberate choices worth knowing before changing anything here:
///
/// **The phrase lives in the Keychain / Keystore, not in SharedPreferences.**
/// SharedPreferences is an unencrypted plist on iOS and an unencrypted XML
/// file on Android, both of which come out of a device backup in plain text.
///
/// **The BIP-39 passphrase is never stored, anywhere, by design.** It is what
/// separates the identity branch from any trading key sharing the same
/// phrase, so persisting it beside the phrase would dissolve the separation
/// it exists to create. The user enters it on unlock and it is held in memory
/// for the session only.
class IdentityVault {
  static const String _phraseKey = 'shadow_identity_phrase';
  static const String _aliasDomainKey = 'shadow_identity_alias_domain';
  static const String _verifierKey = 'shadow_identity_passphrase_verifier';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      // first_unlock_this_device keeps the phrase off iCloud Keychain. A
      // recovery phrase that silently syncs to Apple is not the user's
      // secret any more; their written backup is the recovery path.
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<bool> hasPhrase() async {
    final phrase = await _storage.read(key: _phraseKey);
    return phrase != null && phrase.isNotEmpty;
  }

  Future<String?> readPhrase() => _storage.read(key: _phraseKey);

  Future<void> writePhrase(String phrase) =>
      _storage.write(key: _phraseKey, value: phrase.trim());

  /// The domain the user's aliases are minted under. Not a secret, but it
  /// belongs with the phrase: without it the derived addresses are unusable.
  Future<String?> readAliasDomain() => _storage.read(key: _aliasDomainKey);

  Future<void> writeAliasDomain(String domain) =>
      _storage.write(key: _aliasDomainKey, value: domain.trim().toLowerCase());

  /// Proof that a later unlock used the same passphrase as the first one.
  ///
  /// Written on first unlock and compared thereafter. See
  /// `ShadowIdentity.passphraseVerifier` for what this does and does not
  /// give away.
  Future<String?> readPassphraseVerifier() => _storage.read(key: _verifierKey);

  Future<void> writePassphraseVerifier(String verifier) =>
      _storage.write(key: _verifierKey, value: verifier);

  /// Erases everything. Irreversible without the written-down phrase.
  Future<void> wipe() async {
    await _storage.delete(key: _phraseKey);
    await _storage.delete(key: _aliasDomainKey);
    await _storage.delete(key: _verifierKey);
  }
}
