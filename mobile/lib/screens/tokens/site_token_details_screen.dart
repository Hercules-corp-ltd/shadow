import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/token_balance.dart';
import '../../providers/tokens_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class SiteTokenDetailsScreen extends StatelessWidget {
  const SiteTokenDetailsScreen({super.key, required this.mint});
  final String mint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<TokensProvider>().tokens;
    final TokenBalance? t = tokens
        .cast<TokenBalance?>()
        .firstWhere((e) => e?.mintAddress == mint, orElse: () => null);

    return BlindScaffold(
      title: t?.symbol ?? 'Token',
      subtitle: t?.name,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            gradient: BlindColors.primaryGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Balance',
                    style: BlindTypography.caption
                        .copyWith(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  t == null
                      ? '–'
                      : '${t.balance.toStringAsFixed(4)} ${t.symbol}',
                  style: BlindTypography.h1.copyWith(color: Colors.white),
                ),
                if (t != null && t.usdValue > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '≈ \$${t.usdValue.toStringAsFixed(2)}',
                    style: BlindTypography.bodySm
                        .copyWith(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: BlindButton(
                  label: 'Send',
                  leading: Icons.send_rounded,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BlindButton(
                  label: 'Receive',
                  variant: BlindButtonVariant.secondary,
                  leading: Icons.qr_code_rounded,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BlindButton(
                  label: 'Swap',
                  variant: BlindButtonVariant.secondary,
                  leading: Icons.swap_horiz_rounded,
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Token info', style: BlindTypography.h4),
                const SizedBox(height: 12),
                _row(context, 'Mint', mint, copy: true),
                if (t != null) ...[
                  _row(context, 'Symbol', t.symbol),
                  _row(context, 'Name', t.name),
                  _row(context, 'Decimals', '${t.decimals}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool copy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: BlindTypography.bodySm
                    .copyWith(color: BlindColors.textTertiary)),
          ),
          Expanded(
            child: Text(value,
                style: BlindTypography.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (copy)
            IconButton(
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: BlindColors.textSecondary),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
