import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/settings_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_scaffold.dart';

class SettingsSecurityScreen extends StatefulWidget {
  const SettingsSecurityScreen({super.key});

  @override
  State<SettingsSecurityScreen> createState() => _SettingsSecurityScreenState();
}

class _SettingsSecurityScreenState extends State<SettingsSecurityScreen> {
  final BiometricService _biometrics = BiometricService();
  bool _biometricBusy = false;

  Future<void> _setBiometricsEnabled(
    SettingsProvider provider,
    ShadowSettings settings,
    bool enabled,
  ) async {
    if (_biometricBusy) return;

    if (!enabled) {
      await _biometrics.clearStoredPassword();
      if (!mounted) return;
      await provider.update(settings.copyWith(biometricsEnabled: false));
      return;
    }

    setState(() => _biometricBusy = true);
    try {
      if (!await _biometrics.isAvailable()) {
        if (!mounted) return;
        _showMessage(
          'This device has no fingerprint or face unlock set up.',
        );
        return;
      }

      final password = await _promptWalletPassword();
      if (password == null) return;

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      // Let the password dialog route finish closing before the system sheet.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      if (!await _biometrics.confirmEnrollment()) return;

      await _biometrics.storePassword(password);
      if (!mounted) return;

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await provider.update(settings.copyWith(biometricsEnabled: true));
    } finally {
      if (mounted) {
        setState(() => _biometricBusy = false);
      }
    }
  }

  Future<String?> _promptWalletPassword() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ConfirmWalletPasswordDialog(),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SettingsProvider>();
    final s = context.select<SettingsProvider, ShadowSettings>(
      (p) => p.settings,
    );
    final walletUnlocked = context.select<WalletProvider, bool>(
      (p) => p.state == WalletLifecycle.unlocked,
    );

    return ShadowScaffold(
      title: 'Security',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SwitchListTile(
                  value: s.requireUnlock,
                  title: Text('Require password each launch',
                      style: ShadowTypography.body),
                  subtitle: Text('Always lock wallet when the app closes',
                      style: ShadowTypography.bodySm),
                  onChanged: (v) =>
                      provider.update(s.copyWith(requireUnlock: v)),
                ),
                const Divider(height: 1, color: ShadowColors.border),
                SwitchListTile(
                  secondary: _biometricBusy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint_rounded, size: 24),
                  value: s.biometricsEnabled,
                  title: Text('Unlock with biometrics',
                      style: ShadowTypography.body),
                  subtitle: Text(
                    walletUnlocked
                        ? 'Use fingerprint or face unlock instead of '
                            'typing your password'
                        : 'Unlock your wallet first to enable biometrics',
                    style: ShadowTypography.bodySm,
                  ),
                  onChanged: walletUnlocked && !_biometricBusy
                      ? (v) => _setBiometricsEnabled(provider, s, v)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Auto-lock after', style: ShadowTypography.h4),
                Text(
                  'No idle timer runs yet, so this value is stored and not '
                  'acted on. The wallet locks when you lock it.',
                  style: ShadowTypography.bodySm,
                ),
                Slider(
                  min: 1,
                  max: 60,
                  divisions: 59,
                  value: s.autoLockMinutes.toDouble().clamp(1, 60),
                  label: '${s.autoLockMinutes} min',
                  onChanged: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Owns its [TextEditingController] so the parent never disposes it while the
/// route is still animating closed — that race caused _dependents.isEmpty.
class _ConfirmWalletPasswordDialog extends StatefulWidget {
  const _ConfirmWalletPasswordDialog();

  @override
  State<_ConfirmWalletPasswordDialog> createState() =>
      _ConfirmWalletPasswordDialogState();
}

class _ConfirmWalletPasswordDialogState
    extends State<_ConfirmWalletPasswordDialog> {
  final _controller = TextEditingController();
  final _wallet = WalletService();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Password cannot be empty');
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      if (await _wallet.loadWallet(password) == null) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _error = 'Incorrect password';
        });
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(password);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Could not verify password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm wallet password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: ShadowTypography.bodySm
                  .copyWith(color: ShadowColors.error),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            enabled: !_checking,
            decoration: const InputDecoration(hintText: 'Password'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _checking ? null : _submit,
          child: _checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }
}
