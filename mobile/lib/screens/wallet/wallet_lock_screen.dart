import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class WalletLockScreen extends StatelessWidget {
  const WalletLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlindScaffold(
      title: 'Lock wallet',
      body: Column(
        children: [
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.lock_rounded,
                    size: 48, color: BlindColors.primary),
                const SizedBox(height: 16),
                Text('Lock your wallet now?',
                    style: BlindTypography.h3,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'You will need to enter your password to unlock it again. This is a good idea if you are leaving your phone unattended.',
                  style: BlindTypography.bodySm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
          BlindButton(
            label: 'Lock now',
            leading: Icons.lock_rounded,
            size: BlindButtonSize.lg,
            onPressed: () {
              context.read<WalletProvider>().lock();
              context.go('/wallet/locked');
            },
          ),
          const SizedBox(height: 12),
          BlindButton(
            label: 'Cancel',
            variant: BlindButtonVariant.ghost,
            onPressed: () => context.pop(),
          ),
          const SizedBox(height: 24),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: BlindColors.error),
            onPressed: () => context.push('/wallet/delete'),
            child: const Text('Delete wallet'),
          ),
        ],
      ),
    );
  }
}
