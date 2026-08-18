import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint / Face ID gate for the wallet password.
///
/// The wallet stays encrypted on disk under the user's password. Biometrics
/// only unlock access to that password in the platform keystore — they do
/// not replace the password or store the key in the clear.
class BiometricService {
  static const String _passwordKey = 'shadow_wallet_biometric_password';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    if (!await _auth.isDeviceSupported()) return false;
    return await _auth.canCheckBiometrics;
  }

  Future<bool> hasStoredPassword() async {
    final value = await _storage.read(key: _passwordKey);
    return value != null && value.isNotEmpty;
  }

  Future<void> storePassword(String password) async {
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<void> clearStoredPassword() async {
    await _storage.delete(key: _passwordKey);
  }

  /// Prompts for biometrics, then returns the stored wallet password.
  ///
  /// [onAuthenticated] runs as soon as the platform confirms biometrics,
  /// before reading secure storage — so the UI can hide the lock screen
  /// while the sheet dismisses and the wallet decrypts.
  Future<String?> unlockPassword({
    String reason = 'Unlock your Shadow wallet',
    void Function()? onAuthenticated,
  }) async {
    if (!await hasStoredPassword()) return null;
    final ok = await _auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
    if (!ok) return null;
    onAuthenticated?.call();
    return _storage.read(key: _passwordKey);
  }

  /// Confirms the device can authenticate before enabling the setting.
  Future<bool> confirmEnrollment() => _auth.authenticate(
        localizedReason: 'Confirm biometrics to enable wallet unlock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
}
