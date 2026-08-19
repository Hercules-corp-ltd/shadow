import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Which secret a [QuickUnlock] is holding.
enum QuickUnlockSlot {
  /// The passphrase that opens the identity and derives every account.
  identity,

  /// The password that opens the wallet keypair.
  wallet,
}

/// Why a quick unlock could not happen.
enum QuickUnlockProblem {
  /// The device has no biometric and no screen lock set up.
  unavailable,

  /// The user cancelled, or the check failed.
  refused,

  /// Nothing is stored for this device.
  notSet,
}

class QuickUnlockResult {
  const QuickUnlockResult._({this.passphrase, this.problem});

  const QuickUnlockResult.ok(String value) : this._(passphrase: value);
  const QuickUnlockResult.failed(QuickUnlockProblem reason)
      : this._(problem: reason);

  final String? passphrase;
  final QuickUnlockProblem? problem;

  bool get succeeded => passphrase != null;
}

/// Unlocking the identity with a fingerprint instead of the passphrase.
///
/// ## What this actually changes, stated plainly
///
/// Before this, the passphrase existed only in the user's head. Nothing on the
/// device held it, which is why an attacker with the unlocked phone still
/// could not derive a single account — they would have the recovery phrase in
/// the keystore and no way to turn it into credentials.
///
/// Turning this on ends that. The passphrase goes into the same app-private
/// encrypted store the phrase already lives in, and from then on anyone who
/// can satisfy the device's own lock can open the identity. The security of
/// every account moves from "something only they know" down to "whatever
/// unlocks this handset".
///
/// That is a legitimate trade — it is the one every password manager offers,
/// and typing a passphrase at every launch is the reason people pick weak ones
/// or write them on the case. But it is the user's trade to make knowingly,
/// so it is off by default and the screen that offers it says this out loud
/// rather than describing it as "convenience".
///
/// ## The honest limit of the gate
///
/// `local_auth` is an *app-level* prompt, not a hardware-bound key. The stored
/// passphrase is protected by Android's EncryptedSharedPreferences and the iOS
/// keychain; the biometric check gates this code path, not the bytes. Somebody
/// with a rooted phone and the app's data directory is past it. Binding the
/// value to a Keystore key that requires authentication would close that, and
/// it is the obvious next step — but claiming hardware protection this does
/// not have would be worse than not having it.
class QuickUnlock {
  QuickUnlock({
    this.slot = QuickUnlockSlot.identity,
    FlutterSecureStorage? storage,
    LocalAuthentication? auth,
  })  : _storage = storage ?? _defaultStorage,
        _auth = auth ?? LocalAuthentication();

  /// Which secret this instance holds. Two separate slots rather than one
  /// combined blob, because they protect different things and a user may
  /// reasonably want the phone to remember the wallet password while still
  /// typing the passphrase that guards every derived account.
  final QuickUnlockSlot slot;

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      // Never syncs. A passphrase on somebody else's server is not a
      // passphrase, and the written recovery phrase is the real backup.
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String get _key => switch (slot) {
        QuickUnlockSlot.identity => 'shadow_identity_quick_passphrase',
        QuickUnlockSlot.wallet => 'shadow_wallet_quick_password',
      };

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  /// Whether this device can check a fingerprint, face, PIN or pattern.
  ///
  /// Deliberately accepts a device credential as well as a biometric: a phone
  /// with no fingerprint reader still has a lock screen, and refusing those
  /// users the feature buys nothing.
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final stored = await _storage.read(key: _key);
    return stored != null;
  }

  /// Stores [passphrase] after the user proves who they are.
  ///
  /// The check comes first on purpose. Enrolling without one would let anybody
  /// holding the unlocked phone arm the shortcut, and then unlock with it.
  Future<bool> enable(String passphrase) async {
    if (!await _authenticate(
        'Confirm it is you before Shadow remembers this')) {
      return false;
    }
    await _storage.write(key: _key, value: passphrase);
    return true;
  }

  Future<void> disable() => _storage.delete(key: _key);

  /// Asks for a fingerprint and hands back the passphrase.
  Future<QuickUnlockResult> unlock() async {
    final stored = await _storage.read(key: _key);
    if (stored == null) {
      return const QuickUnlockResult.failed(QuickUnlockProblem.notSet);
    }
    if (!await isAvailable()) {
      // Biometrics were removed or the screen lock was turned off after the
      // shortcut was armed. Say so rather than reporting a refusal.
      return const QuickUnlockResult.failed(QuickUnlockProblem.unavailable);
    }
    if (!await _authenticate('Unlock your Shadow identity')) {
      return const QuickUnlockResult.failed(QuickUnlockProblem.refused);
    }
    return QuickUnlockResult.ok(stored);
  }

  /// Why the last check failed, when the platform said something useful.
  ///
  /// Kept because swallowing it made a real failure indistinguishable from a
  /// user tapping cancel: the switch slid back either way and the screen had
  /// nothing to say. A `PlatformException` here is usually a setup problem —
  /// no enrolled biometric, no fragment activity — and those need different
  /// words than "that did not check out".
  String? lastError;

  Future<bool> _authenticate(String reason) async {
    lastError = null;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      lastError = '${e.code}: ${e.message ?? ''}'.trim();
      return false;
    } on Exception catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  /// Plain-language reason, for the one place a failure is worth showing.
  static String explain(QuickUnlockProblem problem) {
    switch (problem) {
      case QuickUnlockProblem.unavailable:
        return 'This phone has no fingerprint or screen lock set up any more, '
            'so Shadow cannot check it is you. Type your passphrase instead.';
      case QuickUnlockProblem.refused:
        return 'That did not check out. Type your passphrase instead.';
      case QuickUnlockProblem.notSet:
        return 'Shadow is not remembering a passphrase on this device.';
    }
  }
}
