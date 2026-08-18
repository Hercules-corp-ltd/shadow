import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/shadow_button.dart';

class WalletLockedScreen extends StatefulWidget {
  const WalletLockedScreen({super.key});

  @override
  State<WalletLockedScreen> createState() => _WalletLockedScreenState();
}

class _WalletLockedScreenState extends State<WalletLockedScreen> {
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().unlockWallet(_password.text);
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() {
        _error = 'Incorrect password';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final addr = wallet.walletAddress ?? '';

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
                  child: const Icon(Icons.lock_rounded,
                      color: ShadowColors.primary, size: 40),
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
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofocus: true,
                  onSubmitted: (_) => _unlock(),
                  decoration:
                      const InputDecoration(hintText: 'Password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: ShadowTypography.bodySm
                          .copyWith(color: ShadowColors.error)),
                ],
                const SizedBox(height: 16),
                ShadowButton(
                  label: 'Unlock',
                  isLoading: _loading,
                  onPressed: _loading ? null : _unlock,
                  size: ShadowButtonSize.lg,
                ),
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
