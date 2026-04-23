import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class WalletReceiveScreen extends StatelessWidget {
  const WalletReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final address = context.watch<WalletProvider>().walletAddress ?? '';

    return ShadowScaffold(
      title: 'Receive',
      subtitle: 'Share this address to receive SOL or SPL tokens',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: address,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wallet address', style: ShadowTypography.label),
                const SizedBox(height: 6),
                SelectableText(address, style: ShadowTypography.mono),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadowButton(
            label: 'Copy address',
            leading: Icons.copy_rounded,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}
