import 'package:flutter/foundation.dart';

import '../identity/identity.dart';
import '../services/identity_vault.dart';

enum IdentityLifecycle {
  /// Still reading the keystore.
  uninitialized,

  /// No recovery phrase on this device yet.
  empty,

  /// A phrase exists, but the passphrase has not been supplied this session.
  locked,

  /// Ready to derive.
  unlocked,
}

/// Owns the identity engine for the app.
///
/// Holds the unlocked [ShadowIdentity] in memory only. Locking wipes the
/// branch key; nothing derived is ever persisted, because everything derived
/// can be recomputed from the phrase.
class IdentityProvider with ChangeNotifier {
  IdentityProvider() {
    _bootstrap();
  }

  final IdentityVault _vault = IdentityVault();

  ShadowIdentity? _engine;
  String? _aliasDomain;
  IdentityLifecycle _state = IdentityLifecycle.uninitialized;
  String? _error;

  IdentityLifecycle get state => _state;
  String? get aliasDomain => _aliasDomain;
  String? get error => _error;
  bool get isUnlocked => _state == IdentityLifecycle.unlocked;
  bool get isLoading => _state == IdentityLifecycle.uninitialized;

  Future<void> _bootstrap() async {
    _aliasDomain = await _vault.readAliasDomain();
    final hasPhrase = await _vault.hasPhrase();
    _state = hasPhrase ? IdentityLifecycle.locked : IdentityLifecycle.empty;
    notifyListeners();
  }

  /// Creates a brand-new recovery phrase and stores it.
  ///
  /// Returns the phrase so the caller can show it exactly once. The user must
  /// write it down: it is the only way back to every account derived from it,
  /// and Shadow cannot reissue it.
  Future<String> createPhrase({required String aliasDomain}) async {
    final phrase = ShadowIdentity.generateMnemonic();
    await _vault.writePhrase(phrase);
    await _vault.writeAliasDomain(aliasDomain);
    _aliasDomain = aliasDomain.trim().toLowerCase();
    _state = IdentityLifecycle.locked;
    _error = null;
    notifyListeners();
    return phrase;
  }

  /// Adopts a phrase the user already has.
  Future<bool> importPhrase(String phrase, {required String aliasDomain}) async {
    if (!ShadowIdentity.isValidMnemonic(phrase)) {
      _error = 'That recovery phrase is not valid. Check for a mistyped or missing word.';
      notifyListeners();
      return false;
    }
    await _vault.writePhrase(phrase);
    await _vault.writeAliasDomain(aliasDomain);
    _aliasDomain = aliasDomain.trim().toLowerCase();
    _state = IdentityLifecycle.locked;
    _error = null;
    notifyListeners();
    return true;
  }

  /// Builds the engine for this session.
  ///
  /// [passphrase] is never stored. An empty passphrase still works, but it
  /// puts the identity root on the same branch as any wallet key derived from
  /// the same phrase — so a seed exposed while signing a transaction would
  /// also surrender every account.
  Future<bool> unlock({String passphrase = ''}) async {
    final phrase = await _vault.readPhrase();
    if (phrase == null || phrase.isEmpty) {
      _state = IdentityLifecycle.empty;
      _error = 'There is no recovery phrase on this device yet.';
      notifyListeners();
      return false;
    }
    try {
      final engine = ShadowIdentity.fromMnemonic(phrase, passphrase: passphrase);

      // BIP-39 checksums the words, not the passphrase, so a typo here does
      // not fail — it succeeds into a different, empty universe of accounts.
      // Without this check the user finds out weeks later, when a password
      // stops working or a verification code never arrives at an address
      // they can no longer derive.
      final expected = await _vault.readPassphraseVerifier();
      final actual = engine.passphraseVerifier;

      if (expected == null) {
        // First unlock. This passphrase is now the passphrase.
        await _vault.writePassphraseVerifier(actual);
      } else if (expected != actual) {
        engine.wipe();
        _error = 'That passphrase does not match the one this identity was '
            'set up with. Continuing would create a different, empty set of '
            'accounts rather than opening yours.';
        notifyListeners();
        return false;
      }

      _engine = engine;
      _state = IdentityLifecycle.unlocked;
      _error = null;
      notifyListeners();
      return true;
    } on FormatException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// A short label for the unlocked identity. Null while locked.
  ///
  /// Shown so the user can recognise their own identity. Display only —
  /// it is a stable identifier and must not leave the device.
  String? get fingerprint => _engine?.fingerprint;

  void lock() {
    _engine?.wipe();
    _engine = null;
    _state = IdentityLifecycle.locked;
    notifyListeners();
  }

  Future<void> setAliasDomain(String domain) async {
    await _vault.writeAliasDomain(domain);
    _aliasDomain = domain.trim().toLowerCase();
    notifyListeners();
  }

  /// Derives the identity for [host]. Returns null when locked, or when the
  /// host cannot be reduced to a domain.
  SiteIdentity? identityFor(
    String host, {
    int accountIndex = 0,
    int passwordEpoch = 1,
    int aliasEpoch = 1,
    PasswordPolicy policy = PasswordPolicy.standard,
  }) {
    final engine = _engine;
    final alias = _aliasDomain;
    if (engine == null || alias == null || alias.isEmpty) return null;
    try {
      return engine.forSite(
        host,
        aliasDomain: alias,
        accountIndex: accountIndex,
        passwordEpoch: passwordEpoch,
        aliasEpoch: aliasEpoch,
        policy: policy,
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// The mailbox keys for [host]. Null when locked or underivable.
  ///
  /// Separate from [identityFor] because the keys are needed for things the
  /// credentials are not: claiming the address, signing a poll, opening what
  /// comes back. Returning them from the same call would mean deriving key
  /// material every time a preview is rendered.
  SiteMailboxKeys? mailboxKeysFor(
    String host, {
    int accountIndex = 0,
    int aliasEpoch = 1,
  }) {
    final engine = _engine;
    if (engine == null) return null;
    try {
      return engine.mailboxKeysFor(
        host,
        accountIndex: accountIndex,
        aliasEpoch: aliasEpoch,
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on StateError {
      return null;
    }
  }

  /// Removes the phrase from this device entirely.
  Future<void> forget() async {
    _engine?.wipe();
    _engine = null;
    await _vault.wipe();
    _aliasDomain = null;
    _state = IdentityLifecycle.empty;
    notifyListeners();
  }

  @override
  void dispose() {
    _engine?.wipe();
    super.dispose();
  }
}
