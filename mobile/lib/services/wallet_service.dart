// Wallet Service - Handles Solana wallet generation, encryption, and storage
// Named after Hermes (Messenger God) for wallet operations

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart';

class WalletService {
  static const String _walletStorageKey = 'shadow_wallet_encrypted';
  static const String _walletAddressKey = 'shadow_wallet_address';
  static const String _walletSaltKey = 'shadow_wallet_salt';
  static const String _walletIvKey = 'shadow_wallet_iv';
  static const int _pbkdf2Iterations = 100000;

  /// Generate a new Solana keypair
  Future<Ed25519HDKeyPair> generateWallet() async {
    return Ed25519HDKeyPair.random();
  }

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
  Future<void> storeWallet(Ed25519HDKeyPair keypair, String password) async {
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
    } catch (e) {
      throw Exception('Failed to store wallet: $e');
    }
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

