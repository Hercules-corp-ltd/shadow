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

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Delete wallet',
      body: Column(
        children: [
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(20),
            color: Colors.red.withOpacity(0.08),
            border:
                Border.all(color: ShadowColors.error.withOpacity(0.4), width: 1),
            child: Column(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 48, color: ShadowColors.error),
                const SizedBox(height: 16),
                Text('This cannot be undone',
                    style: ShadowTypography.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Deleting your wallet removes the encrypted key material from this device. You can restore it using your 12-word seed phrase.',
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
              'I have backed up my seed phrase',
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
            onPressed: !_acknowledged || _loading
                ? null
                : () async {
                    setState(() => _loading = true);
                    await context.read<WalletProvider>().deleteWallet();
                    if (!mounted) return;
                    context.go('/welcome');
                  },
          ),
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
