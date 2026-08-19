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
          // The last of the old Figma palette: a navy gradient card, a solid
          // orange disc with an "S" in it, and the words "Shadow user" over an
          // address. Two of those three were invented — there is no account
          // and no display name in this app, so the avatar was a placeholder
          // for a person who does not exist and the heading named nobody.
          //
          // What is actually true here is the address, so the address is the
          // heading, in the same mono the home screen uses for it.
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Image.asset(
                  'assets/brand/shadow-mark.png',
                  width: 44,
                  height: 44,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THIS DEVICE',
                        style: ShadowTypography.caption.copyWith(
                          letterSpacing: 2,
                          color: ShadowColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wallet.walletAddress == null
                            ? 'No wallet connected'
                            : _short(wallet.walletAddress!),
                        style: TextStyle(
                          fontFamily: ShadowTypography.monoFamily,
                          fontSize: 14,
                          color: wallet.walletAddress == null
                              ? ShadowColors.textSecondary
                              : ShadowColors.textPrimary,
                        ),
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
