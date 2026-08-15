import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

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

    return ShadowScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            gradient: ShadowColors.navyGradient,
            border: Border.all(color: ShadowColors.cardNavyBorder, width: 1),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    gradient: ShadowColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('S',
                      style: ShadowTypography.h2
                          .copyWith(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shadow user', style: ShadowTypography.h3),
                      Text(
                        wallet.walletAddress == null
                            ? 'No wallet connected'
                            : _short(wallet.walletAddress!),
                        style: ShadowTypography.bodySm,
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
            leadingColor: ShadowColors.tileBlue,
            onTap: () => context.push('/settings/general'),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'Network',
            subtitle: 'RPC, network, proxy',
            leadingIcon: Icons.router_rounded,
            leadingColor: ShadowColors.tilePurple,
            onTap: () => context.push('/settings/network'),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'Storage',
            subtitle: 'Cache, history retention',
            leadingIcon: Icons.storage_rounded,
            leadingColor: ShadowColors.tileAmber,
            onTap: () => context.push('/settings/storage'),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'Security',
            subtitle: 'Auto-lock, biometrics',
            leadingIcon: Icons.security_rounded,
            leadingColor: ShadowColors.tileGreen,
            onTap: () => context.push('/settings/security'),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'Advanced',
            subtitle: 'Developer mode, log level',
            leadingIcon: Icons.code_rounded,
            leadingColor: ShadowColors.tileRed,
            onTap: () => context.push('/settings/advanced'),
          ),
          const SizedBox(height: 24),
          ShadowButton(
            label: 'Lock wallet',
            variant: ShadowButtonVariant.secondary,
            leading: Icons.lock_outline_rounded,
            onPressed: () => context.push('/wallet/lock'),
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Delete wallet',
            variant: ShadowButtonVariant.danger,
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
