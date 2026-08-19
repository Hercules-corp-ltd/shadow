// Wallet Service - Handles Solana wallet generation, encryption, and storage
// Named after Hermes (Messenger God) for wallet operations

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart';

import '../identity/shadow_identity.dart';

class WalletService {
  static const String _walletStorageKey = 'shadow_wallet_encrypted';
  static const String _walletAddressKey = 'shadow_wallet_address';
  static const String _walletSaltKey = 'shadow_wallet_salt';
  static const String _walletIvKey = 'shadow_wallet_iv';

  // The recovery phrase, encrypted under the same password as the key.
  static const String _mnemonicStorageKey = 'shadow_wallet_mnemonic';
  static const String _mnemonicSaltKey = 'shadow_wallet_mnemonic_salt';
  static const String _mnemonicIvKey = 'shadow_wallet_mnemonic_iv';

  static const int _pbkdf2Iterations = 100000;

  /// Generates a fresh recovery phrase.
  ///
  /// Wallets used to be created with `Ed25519HDKeyPair.random()`, which has
  /// no phrase behind it at all. That made a wallet created inside Shadow
  /// unrecoverable by design: the encrypted key on the device was the only
  /// copy in existence, so a forgotten password, a wiped phone or a tapped
  /// "delete wallet" was permanent loss — while the delete screen assured
  /// the user they could restore from a seed phrase they had never been
  /// shown.
  String createMnemonic() => ShadowIdentity.generateMnemonic();

  /// Derives the Solana keypair for [mnemonic].
  ///
  /// Same call as the import path, so a phrase created here restores
  /// identically anywhere else that speaks BIP-44 for Solana.
  Future<Ed25519HDKeyPair> walletFromMnemonic(String mnemonic) =>
      Ed25519HDKeyPair.fromMnemonic(mnemonic);

  /// Derive encryption key from password using PBKDF2
  Uint8List _deriveKey(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, 32));

    return pbkdf2.process(passwordBytes);
  }

  /// Generate random salt
  Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
  }

  /// Generate random IV
  Uint8List _generateIv() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(12, (_) => random.nextInt(256)));
  }

  /// Encrypt data using AES-GCM
  Future<Map<String, String>> _encrypt(
    Uint8List data,
    String password,
    Uint8List? salt,
    Uint8List? iv,
  ) async {
    final encryptionSalt = salt ?? _generateSalt();
    final encryptionIv = iv ?? _generateIv();

    // Derive key
    final key = _deriveKey(password, encryptionSalt);

    // Create AES-GCM cipher
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          128, // tag length
          encryptionIv,
          Uint8List(0), // additional authenticated data
        ),
      );

    // Encrypt
    final encrypted = cipher.process(data);

    return {
      'encrypted': base64Encode(encrypted),
      'salt': base64Encode(encryptionSalt),
      'iv': base64Encode(encryptionIv),
    };
  }

  /// Decrypt data using AES-GCM
  Future<Uint8List> _decrypt(
    String encryptedBase64,
    String password,
    String saltBase64,
    String ivBase64,
  ) async {
    try {
      final encrypted = base64Decode(encryptedBase64);
      final salt = base64Decode(saltBase64);
      final iv = base64Decode(ivBase64);

      // Derive key
      final key = _deriveKey(password, salt);

      // Create AES-GCM cipher
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(key),
            128, // tag length
            iv,
            Uint8List(0), // additional authenticated data
          ),
        );

      // Decrypt
      return cipher.process(encrypted);
    } catch (e) {
      throw Exception('Failed to decrypt wallet. Wrong password?');
    }
  }

  /// Store wallet securely with encryption
  ///
  /// [mnemonic] is stored under the same password rather than in the
  /// keystore in the clear. It is the seed to real funds, so the bar it has
  /// to clear is the one the private key already clears — device access
  /// alone must not be enough.
  Future<void> storeWallet(
    Ed25519HDKeyPair keypair,
    String password, {
    String? mnemonic,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = await keypair.extract();
      final secretKey = Uint8List.fromList(data.bytes);
      final address = keypair.address;

      final encrypted = await _encrypt(secretKey, password, null, null);

      // Store in SharedPreferences
      await prefs.setString(_walletStorageKey, encrypted['encrypted']!);
      await prefs.setString(_walletAddressKey, address);
      await prefs.setString(_walletSaltKey, encrypted['salt']!);
      await prefs.setString(_walletIvKey, encrypted['iv']!);

      if (mnemonic != null && mnemonic.trim().isNotEmpty) {
        final sealed = await _encrypt(
          Uint8List.fromList(utf8.encode(mnemonic.trim())),
          password,
          null,
          null,
        );
        await prefs.setString(_mnemonicStorageKey, sealed['encrypted']!);
        await prefs.setString(_mnemonicSaltKey, sealed['salt']!);
        await prefs.setString(_mnemonicIvKey, sealed['iv']!);
      }
    } catch (e) {
      throw Exception('Failed to store wallet: $e');
    }
  }

  /// Returns the stored recovery phrase, or null when there is none.
  ///
  /// Null is not an error state — wallets created before this existed are
  /// genuinely phraseless, and [hasRecoveryPhrase] is how the UI finds out
  /// so it can stop claiming otherwise.
  Future<String?> revealMnemonic(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString(_mnemonicStorageKey);
    final salt = prefs.getString(_mnemonicSaltKey);
    final iv = prefs.getString(_mnemonicIvKey);
    if (encrypted == null || salt == null || iv == null) return null;

    final plain = await _decrypt(encrypted, password, salt, iv);
    return utf8.decode(plain);
  }

  /// Whether this wallet can be restored from words.
  ///
  /// False for any wallet created before wallets had phrases. Those keys
  /// exist only as the ciphertext on this device.
  Future<bool> hasRecoveryPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_mnemonicStorageKey);
  }

  /// Load wallet from storage with password decryption
  Future<Ed25519HDKeyPair?> loadWallet(String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString(_walletStorageKey);
      final salt = prefs.getString(_walletSaltKey);
      final iv = prefs.getString(_walletIvKey);

      if (encrypted == null || salt == null || iv == null) {
        return null;
      }

      // Decrypt wallet
      final secretKey = await _decrypt(encrypted, password, salt, iv);

      return await Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: secretKey,
      );
    } catch (e) {
      throw Exception('Failed to load wallet: $e');
    }
  }

  /// Get wallet address from storage
  Future<String?> getStoredWalletAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_walletAddressKey);
  }

  /// Check if wallet exists in storage
  Future<bool> hasStoredWallet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_walletStorageKey);
  }

  /// Delete wallet from storage
  Future<void> deleteWallet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_walletStorageKey);
    await prefs.remove(_walletAddressKey);
    await prefs.remove(_walletSaltKey);
    await prefs.remove(_walletIvKey);
    await prefs.remove(_mnemonicStorageKey);
    await prefs.remove(_mnemonicSaltKey);
    await prefs.remove(_mnemonicIvKey);
  }

  /// Verify password is correct for stored wallet
  Future<bool> verifyPassword(String password) async {
    try {
      await loadWallet(password);
      return true;
    } catch (e) {
      return false;
    }
  }
}
