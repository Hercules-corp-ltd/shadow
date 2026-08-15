import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/tokens_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/search_field.dart';
import '../../widgets/shadow_scaffold.dart';

class SiteTokenScreen extends StatefulWidget {
  const SiteTokenScreen({super.key});

  @override
  State<SiteTokenScreen> createState() => _SiteTokenScreenState();
}

class _SiteTokenScreenState extends State<SiteTokenScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = context.read<WalletProvider>().walletAddress;
      if (wallet != null) context.read<TokensProvider>().load(wallet);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TokensProvider>();
    final tokens = p.tokens
        .where((t) =>
            _query.isEmpty ||
            t.symbol.toLowerCase().contains(_query.toLowerCase()) ||
            t.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return ShadowScaffold(
      title: 'Site Tokens',
      subtitle: 'Tokens issued by Shadow sites you follow',
      body: Column(
        children: [
          ShadowSearchField(
            hint: 'Search tokens...',
            onChanged: (q) => setState(() => _query = q),
          ),
          const SizedBox(height: 16),
          if (p.portfolio != null)
            GlassCard(
              padding: const EdgeInsets.all(16),
              gradient: ShadowColors.primaryGradient,
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Portfolio value',
                            style: ShadowTypography.caption
                                .copyWith(color: Colors.white70)),
                        Text(
                          '\$${p.portfolio!.totalUsd.toStringAsFixed(2)}',
                          style: ShadowTypography.h2
                              .copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: p.isLoading && tokens.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : tokens.isEmpty
                    ? const EmptyState(
                        icon: Icons.token_rounded,
                        title: 'No tokens yet',
                        message:
                            'Site tokens you hold or follow will appear here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemBuilder: (_, i) {
                          final t = tokens[i];
                          return GlassCard(
                            padding: const EdgeInsets.all(14),
                            onTap: () => context.push('/tokens/${t.mintAddress}'),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    gradient: ShadowColors.goldGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    t.symbol.isEmpty
                                        ? '?'
                                        : t.symbol[0].toUpperCase(),
                                    style: ShadowTypography.h4
                                        .copyWith(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(t.symbol,
                                          style: ShadowTypography.h4),
                                      Text(t.name,
                                          style: ShadowTypography.bodySm,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      t.balance.toStringAsFixed(4),
                                      style: ShadowTypography.body,
                                    ),
                                    if (t.usdValue > 0)
                                      Text(
                                        '\$${t.usdValue.toStringAsFixed(2)}',
                                        style: ShadowTypography.caption,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: tokens.length,
                      ),
          ),
        ],
      ),
    );
  }
}
