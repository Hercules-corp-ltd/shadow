import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class WalletLockScreen extends StatelessWidget {
  const WalletLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Lock wallet',
      body: Column(
        children: [
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.lock_rounded,
                    size: 48, color: ShadowColors.primary),
                const SizedBox(height: 16),
                Text('Lock your wallet now?',
                    style: ShadowTypography.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'You will need to enter your password to unlock it again. This is a good idea if you are leaving your phone unattended.',
                  style: ShadowTypography.bodySm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
          ShadowButton(
            label: 'Lock now',
            leading: Icons.lock_rounded,
            size: ShadowButtonSize.lg,
            onPressed: () {
              context.read<WalletProvider>().lock();
              context.go('/wallet/locked');
            },
          ),
          const SizedBox(height: 12),
          ShadowButton(
            label: 'Cancel',
            variant: ShadowButtonVariant.ghost,
            onPressed: () => context.pop(),
          ),
          const SizedBox(height: 24),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ShadowColors.error),
            onPressed: () => context.push('/wallet/delete'),
            child: const Text('Delete wallet'),
          ),
        ],
      ),
    );
  }
}
