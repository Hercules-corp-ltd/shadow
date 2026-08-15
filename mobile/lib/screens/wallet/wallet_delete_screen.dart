import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

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
    return BlindScaffold(
      title: 'Delete wallet',
      body: Column(
        children: [
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(20),
            color: Colors.red.withOpacity(0.08),
            border:
                Border.all(color: BlindColors.error.withOpacity(0.4), width: 1),
            child: Column(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 48, color: BlindColors.error),
                const SizedBox(height: 16),
                Text('This cannot be undone',
                    style: BlindTypography.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Deleting your wallet removes the encrypted key material from this device. You can restore it using your 12-word seed phrase.',
                  style: BlindTypography.bodySm,
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
              style: BlindTypography.body,
            ),
            activeColor: BlindColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const Spacer(),
          BlindButton(
            label: 'Delete wallet',
            variant: BlindButtonVariant.danger,
            size: BlindButtonSize.lg,
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
          BlindButton(
            label: 'Cancel',
            variant: BlindButtonVariant.ghost,
            onPressed: () => context.pop(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
