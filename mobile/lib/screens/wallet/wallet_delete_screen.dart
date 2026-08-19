import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class WalletDeleteScreen extends StatefulWidget {
  const WalletDeleteScreen({super.key});

  @override
  State<WalletDeleteScreen> createState() => _WalletDeleteScreenState();
}

class _WalletDeleteScreenState extends State<WalletDeleteScreen> {
  bool _acknowledged = false;
  bool _loading = false;
  String? _error;

  /// There was no try/catch anywhere on this screen. deleteWallet awaits
  /// SharedPreferences and then a sign-out; if either threw, _loading was
  /// never cleared, so the button stayed a spinner for good, both buttons
  /// stayed disabled, and nothing was said — on the one screen in the app
  /// where "did my wallet actually go?" is the only question that matters.
  Future<void> _delete() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().deleteWallet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not delete the wallet: $e. It is still on this device.';
      });
      return;
    }
    if (!mounted) return;
    context.go('/welcome');
  }

  @override
  void initState() {
    super.initState();
    // The whole screen turns on whether a phrase exists, so ask before
    // drawing anything that makes a promise about one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().refreshRecoverability();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Null means "not checked yet". Treat it as the dangerous case rather
    // than the reassuring one — a screen about irreversible deletion must
    // never default to claiming the data is recoverable.
    final recoverable = context.watch<WalletProvider>().hasRecoveryPhrase;
    final restorable = recoverable == true;

    return ShadowScaffold(
      title: 'Delete wallet',
      body: Column(
        children: [
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(20),
            color: Colors.red.withValues(alpha: 0.08),
            border:
                Border.all(color: ShadowColors.error.withValues(alpha: 0.4), width: 1),
            child: Column(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 48, color: ShadowColors.error),
                const SizedBox(height: 16),
                Text('This cannot be undone',
                    style: ShadowTypography.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  restorable
                      ? 'Deleting removes the encrypted key from this device. '
                          'You can restore this wallet, and everything in it, '
                          'from your twelve words.'
                      : 'This wallet was created before Shadow generated '
                          'recovery phrases, so there are no words for it. '
                          'The encrypted key on this device is the only copy '
                          'that exists. Deleting it destroys the wallet and '
                          'any funds in it permanently — nobody can bring it '
                          'back, including us.',
                  style: ShadowTypography.bodySm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _acknowledged,
            onChanged: (v) => setState(() => _acknowledged = v ?? false),
            title: Text(
              restorable
                  ? 'I have backed up my seed phrase'
                  : 'I understand this wallet cannot be recovered',
              style: ShadowTypography.body,
            ),
            activeColor: ShadowColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const Spacer(),
          ShadowButton(
            label: 'Delete wallet',
            variant: ShadowButtonVariant.danger,
            size: ShadowButtonSize.lg,
            isLoading: _loading,
            onPressed: !_acknowledged || _loading ? null : _delete,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style:
                  ShadowTypography.bodySm.copyWith(color: ShadowColors.error),
            ),
          ],
          const SizedBox(height: 12),
          ShadowButton(
            label: 'Cancel',
            variant: ShadowButtonVariant.ghost,
            onPressed: () => context.pop(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
