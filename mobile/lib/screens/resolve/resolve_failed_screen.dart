import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class ResolveFailedScreen extends StatelessWidget {
  const ResolveFailedScreen({super.key, required this.blindId});
  final String blindId;

  @override
  Widget build(BuildContext context) {
    return BlindScaffold(
      title: 'Resolution failed',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: BlindColors.error.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sentiment_dissatisfied_rounded,
                  size: 56, color: BlindColors.error),
            ),
          ),
          const SizedBox(height: 24),
          Text('We couldn\'t resolve this content',
              style: BlindTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'The identifier "$blindId" is not registered, may be expired, or the content is no longer pinned.',
            style: BlindTypography.bodySm,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Things to try', style: BlindTypography.h4),
                const SizedBox(height: 8),
                Text('- Check for typos in the domain or CID',
                    style: BlindTypography.bodySm),
                Text('- Switch to the correct network (devnet vs mainnet)',
                    style: BlindTypography.bodySm),
                Text('- Ask the owner to re-pin the content',
                    style: BlindTypography.bodySm),
              ],
            ),
          ),
          const SizedBox(height: 24),
          BlindButton(
            label: 'Try again',
            leading: Icons.refresh_rounded,
            onPressed: () => context.go(
              '/resolve/resolving?id=${Uri.encodeComponent(blindId)}',
            ),
          ),
          const SizedBox(height: 8),
          BlindButton(
            label: 'Back',
            variant: BlindButtonVariant.ghost,
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}
