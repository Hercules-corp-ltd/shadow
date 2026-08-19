import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/token_balance.dart';
import '../../providers/tokens_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class SiteTokenDetailsScreen extends StatelessWidget {
  const SiteTokenDetailsScreen({super.key, required this.mint});
  final String mint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<TokensProvider>().tokens;
    final TokenBalance? t = tokens
        .cast<TokenBalance?>()
        .firstWhere((e) => e?.mintAddress == mint, orElse: () => null);

    return ShadowScaffold(
      title: t?.symbol ?? 'Token',
      subtitle: t?.name,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard.lit(
            accent: ShadowColors.primary,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BALANCE',
                    style: ShadowTypography.caption.copyWith(
                      letterSpacing: 2,
                      color: ShadowColors.textTertiary,
                    )),
                const SizedBox(height: 4),
                Text(
                  t == null
                      ? '–'
                      : '${t.balance.toStringAsFixed(4)} ${t.symbol}',
                  style: ShadowTypography.h1.copyWith(
                    color: t == null
                        ? ShadowColors.textSecondary
                        : ShadowColors.primaryHover,
                  ),
                ),
                if (t != null && t.usdValue > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '≈ \$${t.usdValue.toStringAsFixed(2)}',
                    style: ShadowTypography.bodySm
                        .copyWith(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Three enabled buttons wired to an empty closure. A control that
          // looks pressable and silently does nothing is worse than a disabled
          // one — there is no way to tell a tap that registered from a feature
          // that failed. The screens behind them exist, so they are routed;
          // and each of those screens already says for itself whether the
          // operation is built.
          Row(
            children: [
              Expanded(
                child: ShadowButton(
                  label: 'Send',
                  leading: Icons.send_rounded,
                  onPressed: () => context.push('/wallet/send'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadowButton(
                  label: 'Receive',
                  variant: ShadowButtonVariant.secondary,
                  leading: Icons.qr_code_rounded,
                  onPressed: () => context.push('/wallet/receive'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadowButton(
                  label: 'Swap',
                  variant: ShadowButtonVariant.secondary,
                  leading: Icons.swap_horiz_rounded,
                  onPressed: () => context.push('/wallet/swap'),
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
                Text('Token info', style: ShadowTypography.h4),
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
                style: ShadowTypography.bodySm
                    .copyWith(color: ShadowColors.textTertiary)),
          ),
          Expanded(
            child: Text(value,
                style: ShadowTypography.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (copy)
            IconButton(
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: ShadowColors.textSecondary),
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
