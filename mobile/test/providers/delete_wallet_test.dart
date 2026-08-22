import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/providers/wallet_provider.dart';
import 'package:shadow_mobile/services/quick_unlock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage, in memory. Same shape as the one in quick_unlock_test —
/// duplicated rather than shared because a test helper that two suites depend
/// on is a third thing to keep true.
class FakeStore extends FlutterSecureStorage {
  const FakeStore(this._values);
  final Map<String, String> _values;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}

/// A store whose delete always fails, the way a corrupted Android keystore does.
class BrokenStore extends FakeStore {
  const BrokenStore(super.values);

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('keystore unavailable');
  }
}

/// Deleting the wallet has to take the shortcut to it as well.
///
/// The quick-unlock secret lives in secure storage under
/// `shadow_wallet_quick_password`; the wallet itself is seven SharedPreferences
/// keys. Nothing connected the two, so "Forgot password? Delete wallet" — the
/// gesture offered to somebody locked out of their own wallet — destroyed the
/// wallet and left the password that opened it on the device.
///
/// It did self-heal, eventually and by accident: the stored password will not
/// open the NEXT wallet, and the lock screen disarms when it notices. These
/// tests exist because "the secret is gone" and "the secret will stop working
/// after a future failure" are not the same promise, and only one of them is
/// what the button says.
const _walletKey = 'shadow_wallet_quick_password';
const _identityKey = 'shadow_identity_quick_passphrase';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  WalletProvider providerWith(Map<String, String> values,
          {bool broken = false}) =>
      WalletProvider(
        walletQuickUnlock: QuickUnlock(
          slot: QuickUnlockSlot.wallet,
          storage: broken ? BrokenStore(values) : FakeStore(values),
        ),
      );

  test('deleting the wallet destroys the remembered wallet password', () async {
    final values = <String, String>{_walletKey: 'the-old-password'};
    await providerWith(values).deleteWallet();
    expect(
      values.containsKey(_walletKey),
      isFalse,
      reason: 'the password that opened the deleted wallet is still on disk',
    );
  });

  test('it leaves the identity passphrase alone', () async {
    // Two secrets, two lifecycles. Nothing in deleteWallet() deletes the
    // identity, so nothing in it may delete the shortcut to the identity —
    // that would silently disarm a fingerprint the user never touched.
    final values = <String, String>{
      _walletKey: 'the-old-password',
      _identityKey: 'the-passphrase',
    };
    await providerWith(values).deleteWallet();
    expect(values[_identityKey], 'the-passphrase');
    expect(values.containsKey(_walletKey), isFalse);
  });

  test('a wallet with no shortcut armed deletes without complaint', () async {
    final values = <String, String>{};
    await providerWith(values).deleteWallet();
    expect(values, isEmpty);
  });

  test('a failing keystore does not block the delete', () async {
    // The overwhelmingly likely reason a user reaches "Forgot password? Delete
    // wallet" is that something is already wrong. Refusing to delete because
    // the keystore cannot be written to would strand them on the one screen
    // they are trying to escape. The wallet goes; the orphaned secret opens
    // nothing.
    final values = <String, String>{_walletKey: 'the-old-password'};
    final p = providerWith(values, broken: true);
    await expectLater(p.deleteWallet(), completes);
    expect(p.state, WalletLifecycle.noWallet);
  });

  test('the wallet is gone from the provider either way', () async {
    final p = providerWith(<String, String>{_walletKey: 'x'});
    await p.deleteWallet();
    expect(p.wallet, isNull);
    expect(p.walletAddress, isNull);
    expect(p.state, WalletLifecycle.noWallet);
  });
}
