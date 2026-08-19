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
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadMine());
  }

  /// Extracted so the failure state below has something to retry with.
  void _reloadMine() {
    final wallet = context.read<WalletProvider>().walletAddress;
    if (wallet != null) {
      context.read<DomainsProvider>().loadMine(wallet);
    }
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
                // Disabled while the field is empty. _search returns silently
                // on a blank query, so the brightest control on the screen
                // used to absorb a press and do nothing at all.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _queryCtrl,
                  builder: (context, value, _) => ShadowButton(
                    label: 'Search availability',
                    leading: Icons.search_rounded,
                    onPressed: value.text.trim().isEmpty
                        ? null
                        : () => _search(_queryCtrl.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Your domains', style: ShadowTypography.h3),
          const SizedBox(height: 12),
          // DomainsProvider.loadMine swallows the exception, records it on
          // `error` and substitutes an empty list — so a dead backend, a
          // timeout, or the 401 this backend returns for every authenticated
          // route all used to render as "No domains yet", inviting the user to
          // register a first domain they may already own.
          if (p.error != null)
            EmptyState(
              icon: Icons.cloud_off_rounded,
              tone: EmptyStateTone.error,
              title: 'Could not load your domains',
              message: p.error!,
              actionLabel: 'Try again',
              onAction: _reloadMine,
            )
          else if (p.isLoading && p.myDomains.isEmpty)
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
                  // `?? 0` turned "the server did not send a score" into the
                  // worst score there is, printed as fact.
                  subtitle: d.isVerified
                      ? (d.trustScore == null
                          ? 'Verified'
                          : 'Verified · trust ${d.trustScore}')
                      : 'Unverified',
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
