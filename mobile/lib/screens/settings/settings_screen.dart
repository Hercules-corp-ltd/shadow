import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<SettingsProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return BlindScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            gradient: BlindColors.navyGradient,
            border: Border.all(color: BlindColors.cardNavyBorder, width: 1),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: BlindColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('S',
                      style: BlindTypography.h2
                          .copyWith(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Blind user', style: BlindTypography.h3),
                      Text(
                        wallet.walletAddress == null
                            ? 'No wallet connected'
                            : _short(wallet.walletAddress!),
                        style: BlindTypography.bodySm,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListItemCard(
            title: 'General',
            subtitle: 'Language, telemetry, auto-update',
            leadingIcon: Icons.tune_rounded,
            leadingColor: BlindColors.tileBlue,
            onTap: () => context.push('/settings/general'),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'Network',
            subtitle: 'RPC, network, proxy',
            leadingIcon: Icons.router_rounded,
            leadingColor: BlindColors.tilePurple,
            onTap: () => context.push('/settings/network'),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'Storage',
            subtitle: 'Cache, history retention',
            leadingIcon: Icons.storage_rounded,
            leadingColor: BlindColors.tileAmber,
            onTap: () => context.push('/settings/storage'),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'Security',
            subtitle: 'Auto-lock, biometrics',
            leadingIcon: Icons.security_rounded,
            leadingColor: BlindColors.tileGreen,
            onTap: () => context.push('/settings/security'),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'Advanced',
            subtitle: 'Developer mode, log level',
            leadingIcon: Icons.code_rounded,
            leadingColor: BlindColors.tileRed,
            onTap: () => context.push('/settings/advanced'),
          ),
          const SizedBox(height: 24),
          BlindButton(
            label: 'Lock wallet',
            variant: BlindButtonVariant.secondary,
            leading: Icons.lock_outline_rounded,
            onPressed: () => context.push('/wallet/lock'),
          ),
          const SizedBox(height: 8),
          BlindButton(
            label: 'Delete wallet',
            variant: BlindButtonVariant.danger,
            leading: Icons.delete_outline_rounded,
            onPressed: () => context.push('/wallet/delete'),
          ),
        ],
      ),
    );
  }

  static String _short(String v) =>
      v.length < 16 ? v : '${v.substring(0, 6)}...${v.substring(v.length - 6)}';
}
