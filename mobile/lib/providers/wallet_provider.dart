import 'package:flutter/foundation.dart';
import 'package:solana/solana.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/wallet_service.dart';

enum WalletLifecycle { uninitialized, noWallet, locked, unlocked }

class WalletProvider with ChangeNotifier {
  final WalletService _walletService = WalletService();
  final AuthService _authService = AuthService();

  Ed25519HDKeyPair? _wallet;
  String? _walletAddress;
  bool _isLoading = true;
  WalletLifecycle _state = WalletLifecycle.uninitialized;

  Ed25519HDKeyPair? get wallet => _wallet;
  String? get walletAddress => _walletAddress;
  bool get isLoading => _isLoading;
  bool get isConnected => _state == WalletLifecycle.unlocked;
  WalletLifecycle get state => _state;

  WalletProvider() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _isLoading = true;
    notifyListeners();
    final address = await _walletService.getStoredWalletAddress();
    if (address == null) {
      _state = WalletLifecycle.noWallet;
    } else {
      _walletAddress = address;
      _state = WalletLifecycle.locked;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Creates a new wallet, stores it encrypted, and signs the user in with
  /// the backend via Sign-In-With-Solana.
  Future<void> createNewWallet(String password) async {
    final keypair = await _walletService.generateWallet();
    await _walletService.storeWallet(keypair, password);
    _wallet = keypair;
    _walletAddress = keypair.publicKey.toBase58();
    _state = WalletLifecycle.unlocked;
    notifyListeners();
    try {
      await _authService.signInWithSolana(wallet: keypair);
    } catch (_) {
      // Auth failure is non-fatal for local wallet creation.
    }
  }

  Future<void> importFromSeedPhrase(
    List<String> words,
    String password,
  ) async {
    final mnemonic = words.join(' ');
    final keypair = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
    await _walletService.storeWallet(keypair, password);
    _wallet = keypair;
    _walletAddress = keypair.publicKey.toBase58();
    _state = WalletLifecycle.unlocked;
    notifyListeners();
  }

  Future<void> unlockWallet(String password) async {
    final keypair = await _walletService.loadWallet(password);
    if (keypair == null) {
      throw StateError('No wallet found');
    }
    _wallet = keypair;
    _walletAddress = keypair.publicKey.toBase58();
    _state = WalletLifecycle.unlocked;
    notifyListeners();
    try {
      await _authService.signInWithSolana(wallet: keypair);
    } catch (_) {}
  }

  void lock() {
    _wallet = null;
    _state = WalletLifecycle.locked;
    notifyListeners();
  }

  Future<void> deleteWallet() async {
    await _walletService.deleteWallet();
    await _authService.signOut();
    _wallet = null;
    _walletAddress = null;
    _state = WalletLifecycle.noWallet;
    notifyListeners();
  }

  Future<void> logout() async {
    await deleteWallet();
  }

  Future<bool> hasStoredWallet() => _walletService.hasStoredWallet();
}

extension WalletOnboardingFlag on WalletProvider {
  static const _onboardingKey = 'blind_onboarding_complete_v1';

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }
}
