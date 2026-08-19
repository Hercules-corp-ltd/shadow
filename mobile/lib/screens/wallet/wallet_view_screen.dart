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
    // A slab of solid brand orange with white text on it is what every
    // wallet app does with this card, and it was the loudest object in
    // Shadow by a distance — a bright rectangle sitting on a black page,
    // with the least interesting thing on the screen (the word "balance")
    // rendered at the highest contrast available.
    //
    // The orange stays, as light rather than as paint: a warm pool behind
    // the figure, a warm edge, and the number itself carrying the colour.
    // Same information, and the balance is now the brightest thing on the
    // card instead of the third brightest.
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            ShadowColors.primary.withValues(alpha: 0.18),
            ShadowColors.primary.withValues(alpha: 0.045),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ShadowColors.primary.withValues(alpha: 0.30),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ShadowColors.primary.withValues(alpha: 0.10),
            blurRadius: 40,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SOL, not dollars. Nothing here knows a price, and the figure this
          // replaced was computed from a hardcoded one.
          Text('SOL BALANCE',
              style: ShadowTypography.label.copyWith(
                letterSpacing: 2,
                color: ShadowColors.textTertiary,
              )),
          const SizedBox(height: 8),
          Text(
            portfolio == null ? '—' : portfolio.solBalance.toStringAsFixed(4),
            style: ShadowTypography.displayMd.copyWith(
              color: portfolio == null
                  ? ShadowColors.textSecondary
                  : ShadowColors.primaryHover,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            portfolio == null
                ? 'Loading…'
                : '${portfolio.tokenCount} SPL token'
                    '${portfolio.tokenCount == 1 ? '' : 's'}',
            style: ShadowTypography.bodySm,
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
                icon: const Icon(Icons.copy_rounded,
                    color: ShadowColors.textSecondary),
              ),
              IconButton(
                onPressed: () => context.push('/wallet/receive'),
                icon: const Icon(Icons.qr_code_rounded,
                    color: ShadowColors.textSecondary),
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
        // Sits beside three working actions at the same weight and does
        // nothing but say "coming soon" after the tap. Disabled, so the
        // difference is visible before the tap rather than after it —
        // IconTile fades an onTap-less tile the way ShadowButton does.
        const IconTile(
          label: 'Buy',
          icon: Icon(Icons.add_rounded),
          color: ShadowColors.tileAmber,
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
                Text(t.balance.toStringAsFixed(4), style: ShadowTypography.h4),
                // Only when a price is actually known. TokensService never
                // sets usdValue — its own doc says there is no honest way to
                // derive one from RPC balances — so this printed a confident
                // "\$0.00" under every token the wallet held.
                if (t.usdValue > 0)
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
      // "No NFTs in this wallet yet" was a claim about the user's wallet.
      // TokensService.nfts() is `async => const []` — it does not read
      // anything — so the app was telling every holder they own none. Its own
      // doc calls this out: "not implemented" and "you have none" are
      // different statements.
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Shadow does not read NFTs yet, so this stays empty whatever you '
          'hold. Metaplex metadata is not fetched.',
          style: ShadowTypography.bodySm,
        ),
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
                      ? const Icon(Icons.image_rounded,
                          size: 48, color: ShadowColors.textTertiary)
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
