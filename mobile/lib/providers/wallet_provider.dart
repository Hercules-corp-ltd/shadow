import 'package:flutter/foundation.dart';
import 'package:solana/solana.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/quick_unlock.dart';
import '../services/wallet_service.dart';

enum WalletLifecycle { uninitialized, noWallet, locked, unlocked }

class WalletProvider with ChangeNotifier {
  final WalletService _walletService = WalletService();
  final AuthService _authService = AuthService();

  /// The wallet's remembered password, if the user armed one.
  ///
  /// Held here so that deleting the wallet can destroy it. Injectable only so a
  /// test can hand in an in-memory store; nothing in the app passes it.
  final QuickUnlock _walletQuick;

  /// Bumped whenever the wallet this provider represents stops being the one it
  /// represented — locked, deleted, replaced. Read by the background sign-in
  /// below to notice that it finished for a wallet that no longer exists.
  int _walletGeneration = 0;

  bool _gateOpen = false;

  Ed25519HDKeyPair? _wallet;
  String? _walletAddress;
  bool _isLoading = true;
  bool _onboardingComplete = false;
  WalletLifecycle _state = WalletLifecycle.uninitialized;


  Ed25519HDKeyPair? get wallet => _wallet;
  String? get walletAddress => _walletAddress;
  bool get isLoading => _isLoading;
  bool get isConnected => _state == WalletLifecycle.unlocked;
  WalletLifecycle get state => _state;

  /// True while the unlock gate is playing on the lock screen.
  ///
  /// The router's redirect moves an unlocked user off `/wallet/locked` the
  /// instant the state changes, which is correct every other time and fatal
  /// here: unlocking is what starts the animation, so without this the gate
  /// would be torn down on the very frame it began. This says "the screen you
  /// are about to redirect away from is mid-sentence".
  ///
  /// Deliberately on the provider rather than local to the screen, because the
  /// thing that has to see it is the router, and the router already listens to
  /// this object.
  bool get gateOpen => _gateOpen;

  void openGate() {
    if (_gateOpen) return;
    _gateOpen = true;
    notifyListeners();
  }

  /// Idempotent, and safe to call from dispose() — hence no notifyListeners()
  /// when nothing changed. A gate left open would pin an unlocked user to the
  /// lock screen, so every exit from the animation calls this, including the
  /// ones that are on fire.
  void closeGate() {
    if (!_gateOpen) return;
    _gateOpen = false;
    notifyListeners();
  }


  /// Whether the tour has been seen or explicitly skipped.
  ///
  /// Synchronous, and settled before [isLoading] clears, because the router's
  /// redirect runs on every navigation and cannot await. The flag itself had
  /// been written by both onboarding screens and read by nobody.
  bool get onboardingComplete => _onboardingComplete;

  /// Called when the flag is written, so the router sees it without a reload.
  void setOnboardingComplete() {
    if (_onboardingComplete) return;
    _onboardingComplete = true;
    notifyListeners();
  }

  WalletProvider({QuickUnlock? walletQuickUnlock})
      : _walletQuick =
            walletQuickUnlock ?? QuickUnlock(slot: QuickUnlockSlot.wallet) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _isLoading = true;
    notifyListeners();
    _onboardingComplete = await isOnboardingComplete();
    final address = await _walletService.getStoredWalletAddress();
    if (address == null) {
      _state = WalletLifecycle.noWallet;
    } else {
      _walletAddress = address;
      _hasRecoveryPhrase = await _walletService.hasRecoveryPhrase();
      _state = WalletLifecycle.locked;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Whether the stored wallet can be restored from words.
  ///
  /// Null until [refreshRecoverability] has run. False means the wallet
  /// predates recovery phrases and the ciphertext on this device is the only
  /// copy of the key in existence — which the delete and lock screens have
  /// to say plainly instead of promising a phrase that does not exist.
  bool? get hasRecoveryPhrase => _hasRecoveryPhrase;
  bool? _hasRecoveryPhrase;

  Future<void> refreshRecoverability() async {
    _hasRecoveryPhrase = await _walletService.hasRecoveryPhrase();
    notifyListeners();
  }

  /// Creates a new wallet from a fresh recovery phrase and returns it.
  ///
  /// The phrase is the caller's to display exactly once, and the caller must
  /// not continue until the user has confirmed they wrote it down. Returning
  /// it rather than storing it silently is deliberate: this used to be
  /// `Ed25519HDKeyPair.random()`, with no phrase anywhere, which is how the
  /// app ended up telling people to back up words it had never generated.
  Future<String> createNewWallet(String password) async {
    final mnemonic = _walletService.createMnemonic();
    final keypair = await _walletService.walletFromMnemonic(mnemonic);
    await _walletService.storeWallet(keypair, password, mnemonic: mnemonic);
    _wallet = keypair;
    _walletAddress = keypair.publicKey.toBase58();
    _hasRecoveryPhrase = true;
    _state = WalletLifecycle.unlocked;
    notifyListeners();
    try {
      await _authService.signInWithSolana(wallet: keypair);
    } catch (_) {
      // Auth failure is non-fatal for local wallet creation.
    }
    return mnemonic;
  }

  Future<void> importFromSeedPhrase(
    List<String> words,
    String password,
  ) async {
    final mnemonic = words.join(' ');
    final keypair = await _walletService.walletFromMnemonic(mnemonic);
    await _walletService.storeWallet(keypair, password, mnemonic: mnemonic);
    _wallet = keypair;
    _walletAddress = keypair.publicKey.toBase58();
    _hasRecoveryPhrase = true;
    _state = WalletLifecycle.unlocked;
    notifyListeners();
  }

  /// Re-reads the stored phrase. Requires the wallet password.
  Future<String?> revealRecoveryPhrase(String password) =>
      _walletService.revealMnemonic(password);

  Future<void> unlockWallet(String password) async {
    final keypair = await _walletService.loadWallet(password);
    if (keypair == null) {
      throw StateError('No wallet found');
    }
    _wallet = keypair;
    _walletAddress = keypair.publicKey.toBase58();
    _state = WalletLifecycle.unlocked;
    notifyListeners();
    // Session sign-in hits the network — must not block unlock navigation.
    _signInInBackground(keypair);
  }

  /// Signs the session in without holding up the unlock.
  ///
  /// Taking this off the unlock path is right — nothing on the home screen
  /// needs the session, it is all local derivation, and a slow network should
  /// not stand between a correct password and the wallet.
  ///
  /// But an unawaited network call outlives the thing that started it. Delete
  /// the wallet while this is in flight and the order becomes: signOut() clears
  /// the token, then this resolves and AuthService writes a fresh one to
  /// SharedPreferences — a live session belonging to a wallet the user just
  /// destroyed, sitting on disk until something happens to overwrite it.
  ///
  /// So it checks whether it still speaks for the current wallet before letting
  /// the token stand, and signs out again if it does not. The generation counter
  /// rather than comparing keypairs: re-importing the same seed phrase is a new
  /// session even though the key is identical.
  void _signInInBackground(Ed25519HDKeyPair keypair) {
    final generation = _walletGeneration;
    Future<void>(() async {
      try {
        await _authService.signInWithSolana(wallet: keypair);
      } catch (_) {
        return;
      }
      if (generation != _walletGeneration || _wallet == null) {
        try {
          await _authService.signOut();
        } catch (_) {}
      }
    });
  }

  void lock() {
    _wallet = null;
    _state = WalletLifecycle.locked;
    _walletGeneration++;
    _gateOpen = false;
    notifyListeners();
  }

  Future<void> deleteWallet() async {
    _walletGeneration++;
    _gateOpen = false;
    // Destroy the remembered password BEFORE the thing it opens.
    //
    // WalletService.deleteWallet() removes seven SharedPreferences keys and the
    // quick-unlock secret is not one of them — it lives in secure storage under
    // `shadow_wallet_quick_password`. So "Forgot password? Delete wallet", the
    // gesture offered to somebody locked out of their own wallet, left the
    // password that opened it sitting on the device.
    //
    // It self-healed eventually: the stored password will not open the NEXT
    // wallet, and wallet_locked_screen catches that and disarms. But "delete"
    // has to mean the secret is gone at the moment it is asked for, not after a
    // future failure happens to notice.
    //
    // Only the wallet slot. The identity passphrase is a separate secret with a
    // separate lifecycle — nothing here deletes the identity, so nothing here
    // may delete the shortcut to it.
    //
    // Guarded, and the order matters: a corrupted Android keystore throws
    // PlatformException from a secure-storage delete, and a user who asked to
    // destroy their wallet must not be refused because the keystore is unwell.
    // The wallet still goes; the worst case is a secret that opens nothing.
    try {
      await _walletQuick.disable();
    } catch (_) {}
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
  static const _onboardingKey = 'shadow_onboarding_complete_v1';

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    setOnboardingComplete();
  }
}
