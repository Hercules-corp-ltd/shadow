import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/unbuilt_tile.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_scaffold.dart';

class SettingsNetworkScreen extends StatefulWidget {
  const SettingsNetworkScreen({super.key});

  @override
  State<SettingsNetworkScreen> createState() => _SettingsNetworkScreenState();
}

class _SettingsNetworkScreenState extends State<SettingsNetworkScreen> {
  late TextEditingController _rpcCtrl;

  @override
  void initState() {
    super.initState();
    _rpcCtrl = TextEditingController(
      text: context.read<SettingsProvider>().settings.rpcUrl,
    );
  }

  @override
  void dispose() {
    _rpcCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final s = provider.settings;

    return ShadowScaffold(
      title: 'Network',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Solana cluster', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final n in const ['mainnet', 'devnet', 'testnet'])
                      ChoiceChip(
                        label: Text(n.toUpperCase()),
                        selected: s.network == n,
                        onSelected: (_) =>
                            provider.update(s.copyWith(network: n)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('RPC URL', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                TextField(
                  controller: _rpcCtrl,
                  onSubmitted: (v) => provider.update(s.copyWith(rpcUrl: v)),
                  decoration: const InputDecoration(
                    hintText: 'https://api.mainnet-beta.solana.com',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                const UnbuiltTile(
                  icon: Icons.shield_outlined,
                  title: 'Route traffic through Tor',
                  reason:
                      'No Tor client ships with Shadow yet, so this switch '
                      'would change nothing. Your IP is visible to sites you '
                      'visit.',
                ),
                const Divider(height: 1, color: ShadowColors.border),
                SwitchListTile(
                  value: s.ipfsEnabled,
                  title: Text('IPFS gateway', style: ShadowTypography.body),
                  subtitle: Text('Fetch content from IPFS pins',
                      style: ShadowTypography.bodySm),
                  onChanged: (v) =>
                      provider.update(s.copyWith(ipfsEnabled: v)),
                ),
                const Divider(height: 1, color: ShadowColors.border),
                SwitchListTile(
                  value: s.arweaveEnabled,
                  title: Text('Arweave permaweb',
                      style: ShadowTypography.body),
                  subtitle: Text('Fetch content from Arweave',
                      style: ShadowTypography.bodySm),
                  onChanged: (v) =>
                      provider.update(s.copyWith(arweaveEnabled: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
