import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/biometric_service.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/hermes_threshold.dart';
import '../../widgets/shadow_button.dart';

enum _UnlockPhase {
  /// Waiting for settings / secure storage.
  preparing,
  /// System fingerprint sheet is up or about to open.
  biometrics,
  /// Biometrics succeeded — Hermes gate experience.
  recognized,
  /// Biometrics off, unavailable, or cancelled / failed.
  password,
}

class WalletLockedScreen extends StatefulWidget {
  const WalletLockedScreen({super.key});

  @override
  State<WalletLockedScreen> createState() => _WalletLockedScreenState();
}

class _WalletLockedScreenState extends State<WalletLockedScreen>
    with WidgetsBindingObserver {
  final _password = TextEditingController();
  final BiometricService _biometrics = BiometricService();

  _UnlockPhase _phase = _UnlockPhase.preparing;
  bool _initStarted = false;
  bool _loading = false;
  bool _autoPromptInFlight = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initStarted) {
      _initStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _beginUnlockFlow());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _phase == _UnlockPhase.preparing) {
      _beginUnlockFlow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _password.dispose();
    super.dispose();
  }

  Future<void> _beginUnlockFlow() async {
    final settings = context.read<SettingsProvider>();
    await settings.ensureLoaded();
    if (!mounted) return;

    if (!settings.settings.biometricsEnabled) {
      setState(() => _phase = _UnlockPhase.password);
      return;
    }

    setState(() => _phase = _UnlockPhase.preparing);

    for (var attempt = 0; attempt < 8; attempt++) {
      if (!mounted) return;
      final ready = await _biometrics.isAvailable() &&
          await _biometrics.hasStoredPassword();
      if (ready) {
        _scheduleAutoBiometricPrompt();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    if (mounted) setState(() => _phase = _UnlockPhase.password);
  }

  void _scheduleAutoBiometricPrompt({bool retry = false}) {
    if (_autoPromptInFlight || _loading) return;
    if (!retry && _phase == _UnlockPhase.password) return;

    _autoPromptInFlight = true;
    setState(() => _phase = _UnlockPhase.biometrics);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _phase == _UnlockPhase.password) {
        _autoPromptInFlight = false;
        return;
      }
      await _runBiometricUnlock(silent: true);
      _autoPromptInFlight = false;
    });
  }

  Future<void> _runBiometricUnlock({bool silent = false}) async {
    if (_loading) return;

    try {
      final password = await _biometrics.unlockPassword(
        onAuthenticated: () {
          if (!mounted) return;
          setState(() => _phase = _UnlockPhase.recognized);
        },
      );
      if (!mounted) return;
      if (password == null) {
        setState(() {
          _phase = _UnlockPhase.password;
          if (!silent) _error = 'Biometric unlock failed';
        });
        return;
      }

      // Gate opens the instant biometrics succeed; hold before decrypt.
      if (_phase != _UnlockPhase.recognized) {
        setState(() => _phase = _UnlockPhase.recognized);
      }

      await Future<void>.delayed(kHermesGateHold);
      if (!mounted) return;

      await context.read<WalletProvider>().unlockWallet(password);
      if (!mounted) return;
      context.go('/home');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _UnlockPhase.password;
        _error = silent ? null : 'Biometric unlock failed';
      });
    }
  }

  Future<void> _unlockWithPassword() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().unlockWallet(_password.text);
      if (!mounted) return;
      final settings = context.read<SettingsProvider>();
      await settings.ensureLoaded();
      if (settings.settings.biometricsEnabled) {
        _biometrics.storePassword(_password.text);
      }
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Incorrect password';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Step 3 — the deliberate Hermes gate after biometrics.
    if (_phase == _UnlockPhase.recognized) {
      return const HermesThreshold(key: ValueKey('hermes-gate'));
    }

    final addr = context.read<WalletProvider>().walletAddress ?? '';
    final biometricsEnabled = context.select<SettingsProvider, bool>(
      (p) => p.settings.biometricsEnabled,
    );
    final showPassword = _phase == _UnlockPhase.password;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: ShadowColors.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    biometricsEnabled && !showPassword
                        ? Icons.fingerprint_rounded
                        : Icons.lock_rounded,
                    color: ShadowColors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Wallet locked', style: ShadowTypography.displayMd),
                const SizedBox(height: 8),
                Text(
                  addr.isEmpty
                      ? 'Enter your password to unlock'
                      : '${addr.substring(0, 6)}…${addr.substring(addr.length - 6)}',
                  style: ShadowTypography.bodySm,
                ),
                const SizedBox(height: 32),
                if (_phase == _UnlockPhase.preparing) ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ] else if (_phase == _UnlockPhase.biometrics) ...[
                  Text(
                    'Confirm with biometrics',
                    style: ShadowTypography.bodySm,
                  ),
                ] else if (showPassword) ...[
                  if (biometricsEnabled) ...[
                    TextButton.icon(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() => _error = null);
                              _scheduleAutoBiometricPrompt(retry: true);
                            },
                      icon: const Icon(Icons.fingerprint_rounded, size: 20),
                      label: const Text('Use biometrics'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofocus: true,
                    onSubmitted: (_) => _unlockWithPassword(),
                    decoration: const InputDecoration(hintText: 'Password'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: ShadowTypography.bodySm
                          .copyWith(color: ShadowColors.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ShadowButton(
                    label: 'Unlock',
                    isLoading: _loading,
                    onPressed: _loading ? null : _unlockWithPassword,
                    size: ShadowButtonSize.lg,
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete wallet?'),
                        content: Text(
                          context.read<WalletProvider>().hasRecoveryPhrase ==
                                  true
                              ? 'This erases the encrypted wallet from this '
                                  'device. You can restore it from your '
                                  'twelve words.'
                              : 'This wallet has no recovery phrase, so the '
                                  'key on this device is the only copy. '
                                  'Deleting it destroys the wallet and any '
                                  'funds in it, permanently.',
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await context.read<WalletProvider>().deleteWallet();
                      if (context.mounted) context.go('/welcome');
                    }
                  },
                  child: const Text('Forgot password? Delete wallet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
