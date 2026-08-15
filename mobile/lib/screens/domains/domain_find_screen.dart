import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/domains_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/search_field.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DomainFindScreen extends StatefulWidget {
  const DomainFindScreen({super.key});

  @override
  State<DomainFindScreen> createState() => _DomainFindScreenState();
}

class _DomainFindScreenState extends State<DomainFindScreen> {
  final _queryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = context.read<WalletProvider>().walletAddress;
      if (wallet != null) {
        context.read<DomainsProvider>().loadMine(wallet);
      }
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DomainsProvider>();

    return ShadowScaffold(
      title: 'Shadow Domains',
      subtitle: 'Find, register, and manage your Shadow domains',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            gradient: ShadowColors.navyGradient,
            border: Border.all(color: ShadowColors.cardNavyBorder, width: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Find your Shadow name', style: ShadowTypography.h3),
                const SizedBox(height: 12),
                ShadowSearchField(
                  hint: 'yourname.shadow',
                  controller: _queryCtrl,
                  onSubmitted: (q) => _search(q),
                ),
                const SizedBox(height: 12),
                ShadowButton(
                  label: 'Search availability',
                  leading: Icons.search_rounded,
                  onPressed: () => _search(_queryCtrl.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Your domains', style: ShadowTypography.h3),
          const SizedBox(height: 12),
          if (p.isLoading && p.myDomains.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (p.myDomains.isEmpty)
            const EmptyState(
              icon: Icons.language_rounded,
              title: 'No domains yet',
              message:
                  'Register your first .shadow domain to claim your identity on the decentralized web.',
            )
          else
            ...p.myDomains.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListItemCard(
                  title: d.domain,
                  subtitle: d.isVerified ? 'Verified · trust ${d.trustScore ?? 0}' : 'Unverified',
                  leadingIcon: Icons.language_rounded,
                  leadingColor: d.isVerified
                      ? ShadowColors.success
                      : ShadowColors.tileGray,
                  onTap: () => context.push('/domains/${d.domain}'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _search(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    context.read<DomainsProvider>().search(query);
    context.push('/domains/results');
  }
}
