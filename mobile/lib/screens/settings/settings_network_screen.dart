import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/settings_service.dart';
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
  String? _rpcError;

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

  /// The endpoint each chip actually selects.
  static const Map<String, String> _clusters = <String, String>{
    'mainnet': 'https://api.mainnet-beta.solana.com',
    'devnet': 'https://api.devnet.solana.com',
    'testnet': 'https://api.testnet.solana.com',
  };

  void _switchCluster(SettingsProvider provider, ShadowSettings s, String n) {
    // Tapping the chip that is already selected does nothing, so a custom
    // endpoint for the current cluster — a Helius or QuickNode mainnet URL —
    // survives a stray tap. Choosing a *different* cluster does replace it,
    // which is the whole point of the control.
    if (s.network == n) return;
    final url = _clusters[n]!;
    provider.update(s.copyWith(network: n, rpcUrl: url));
    _rpcCtrl.text = url;
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
                // These chips used to write `network` and nothing else, and
                // nothing anywhere reads `network` — every RPC consumer takes
                // `rpcUrl`, and the home screen's badge deliberately derives
                // the cluster from the RPC host "because that is where the
                // bytes actually go". So tapping DEVNET lit the chip, saved a
                // label, and left the app pointed at mainnet. Somebody
                // switching to devnet to rehearse a transfer would have been
                // on mainnet with real funds, with the UI confirming they
                // were not. The chip moves the endpoint now.
                Wrap(
                  spacing: 8,
                  children: [
                    for (final n in _clusters.keys)
                      ChoiceChip(
                        label: Text(n.toUpperCase()),
                        selected: s.network == n,
                        onSelected: (_) => _switchCluster(provider, s, n),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('RPC URL', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                TextField(
                  controller: _rpcCtrl,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  // Committed only if it parses. An empty or malformed value
                  // used to persist straight through to TokensProvider, after
                  // which every balance read failed against the empty string
                  // — with nothing on this screen reporting it and no way back
                  // but retyping a URL from memory.
                  onSubmitted: (v) {
                    final t = v.trim();
                    final uri = Uri.tryParse(t);
                    if (t.isEmpty ||
                        uri == null ||
                        !uri.hasScheme ||
                        !uri.hasAuthority) {
                      setState(() => _rpcError =
                          'That is not a URL Shadow can call. It needs a '
                              'scheme and a host, like https://example.com');
                      return;
                    }
                    setState(() => _rpcError = null);
                    provider.update(s.copyWith(rpcUrl: t));
                  },
                  decoration: InputDecoration(
                    hintText: 'https://api.mainnet-beta.solana.com',
                    errorText: _rpcError,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is the address the app actually talks to. The chips '
                  'above set it; you can point it anywhere.',
                  style: ShadowTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const GlassCard(
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                UnbuiltTile(
                  icon: Icons.shield_outlined,
                  title: 'Route traffic through Tor',
                  reason: 'No Tor client ships with Shadow yet, so this switch '
                      'would change nothing. Your IP is visible to sites you '
                      'visit.',
                ),
                Divider(height: 1, color: ShadowColors.edge),
                // Both of these defaulted to ON and were read by
                // nothing, so this screen sat directly beneath an honest
                // UnbuiltTile and asserted that Shadow was already fetching
                // from IPFS pins and the permaweb. It is not — and turning
                // them off changed nothing either.
                UnbuiltTile(
                  icon: Icons.hub_outlined,
                  title: 'IPFS gateway',
                  reason: 'No IPFS client or gateway is wired into the '
                      'browser yet, so ipfs:// addresses do not resolve.',
                ),
                Divider(height: 1, color: ShadowColors.edge),
                UnbuiltTile(
                  icon: Icons.public_rounded,
                  title: 'Arweave permaweb',
                  reason: 'Nothing in the browser reads from Arweave yet.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
