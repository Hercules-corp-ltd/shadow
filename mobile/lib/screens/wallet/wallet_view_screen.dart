import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/nft.dart';
import '../../models/token_balance.dart';
import '../../providers/tokens_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shadow_scaffold.dart';

class WalletViewScreen extends StatefulWidget {
  const WalletViewScreen({super.key});

  @override
  State<WalletViewScreen> createState() => _WalletViewScreenState();
}

class _WalletViewScreenState extends State<WalletViewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final addr = context.read<WalletProvider>().walletAddress;
      if (addr != null) context.read<TokensProvider>().load(addr);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final tokens = context.watch<TokensProvider>();
    final addr = wallet.walletAddress ?? '';
    final shortAddr = addr.length > 12
        ? '${addr.substring(0, 6)}…${addr.substring(addr.length - 6)}'
        : addr;

    return ShadowScaffold(
      title: 'Wallet',
      subtitle: shortAddr,
      actions: [
        IconButton(
          icon: const Icon(Icons.lock_rounded),
          onPressed: () => context.push('/wallet/lock'),
        ),
      ],
      body: RefreshIndicator(
        color: ShadowColors.primary,
        onRefresh: () async {
          await context.read<TokensProvider>().load(addr);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildBalanceCard(context, tokens),
            const SizedBox(height: 16),
            _buildActions(context),
            const SizedBox(height: 24),
            SectionHeader(title: 'Tokens (${tokens.tokens.length})'),
            const SizedBox(height: 12),
            ..._buildTokenList(tokens.tokens),
            const SizedBox(height: 24),
            SectionHeader(title: 'NFTs (${tokens.nfts.length})'),
            const SizedBox(height: 12),
            _buildNftGrid(tokens.nfts),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, TokensProvider tokens) {
    final portfolio = tokens.portfolio;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ShadowColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SOL, not dollars. Nothing here knows a price, and the figure this
          // replaced was computed from a hardcoded one.
          Text('SOL balance',
              style: ShadowTypography.label
                  .copyWith(color: Colors.white.withValues(alpha: 0.9))),
          const SizedBox(height: 8),
          Text(
            portfolio == null
                ? '—'
                : portfolio.solBalance.toStringAsFixed(4),
            style: ShadowTypography.displayMd.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            portfolio == null
                ? 'Loading…'
                : '${portfolio.tokenCount} SPL token'
                    '${portfolio.tokenCount == 1 ? '' : 's'}',
            style: ShadowTypography.bodySm.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  final addr = context.read<WalletProvider>().walletAddress;
                  if (addr != null) {
                    Clipboard.setData(ClipboardData(text: addr));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: () => context.push('/wallet/receive'),
                icon: const Icon(Icons.qr_code_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconTile(
          label: 'Send',
          icon: const Icon(Icons.arrow_upward_rounded),
          color: ShadowColors.tileBlue,
          onTap: () => context.push('/wallet/send'),
        ),
        IconTile(
          label: 'Receive',
          icon: const Icon(Icons.arrow_downward_rounded),
          color: ShadowColors.tileGreen,
          onTap: () => context.push('/wallet/receive'),
        ),
        IconTile(
          label: 'Swap',
          icon: const Icon(Icons.swap_horiz_rounded),
          color: ShadowColors.tilePurple,
          onTap: () => context.push('/wallet/swap'),
        ),
        IconTile(
          label: 'Buy',
          icon: const Icon(Icons.add_rounded),
          color: ShadowColors.tileAmber,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('On-ramp coming soon')),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTokenList(List<TokenBalance> items) {
    if (items.isEmpty) {
      return [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No tokens yet. Swap SOL to any SPL token to see it here.',
            style: ShadowTypography.bodySm,
          ),
        ),
      ];
    }
    return [
      for (final t in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListItemCard(
            title: t.symbol,
            subtitle: t.name,
            leadingIcon: Icons.monetization_on_rounded,
            leadingColor: ShadowColors.tileAmber,
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.balance.toStringAsFixed(4),
                    style: ShadowTypography.h4),
                Text('\$${t.usdValue.toStringAsFixed(2)}',
                    style: ShadowTypography.bodySm),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _buildNftGrid(List<Nft> nfts) {
    if (nfts.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Text('No NFTs in this wallet yet.', style: ShadowTypography.bodySm),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: nfts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (_, i) {
        final nft = nfts[i];
        return Container(
          decoration: BoxDecoration(
            color: ShadowColors.surfaceGlass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ShadowColors.edge),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: ShadowColors.surface,
                  child: nft.imageUrl == null
                      ? const Icon(Icons.image_rounded, size: 48, color: ShadowColors.textTertiary)
                      : Image.network(nft.imageUrl!, fit: BoxFit.cover),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nft.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShadowTypography.h4),
                    if (nft.collectionName != null)
                      Text(nft.collectionName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ShadowTypography.bodySm),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
