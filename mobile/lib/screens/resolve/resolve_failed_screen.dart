import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class ResolveFailedScreen extends StatelessWidget {
  const ResolveFailedScreen({super.key, required this.shadowId});
  final String shadowId;

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
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
                color: ShadowColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sentiment_dissatisfied_rounded,
                  size: 56, color: ShadowColors.error),
            ),
          ),
          const SizedBox(height: 24),
          Text('We couldn\'t resolve this content',
              style: ShadowTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'The identifier "$shadowId" is not registered, may be expired, or the content is no longer pinned.',
            style: ShadowTypography.bodySm,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Things to try', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                Text('- Check for typos in the domain or CID',
                    style: ShadowTypography.bodySm),
                Text('- Switch to the correct network (devnet vs mainnet)',
                    style: ShadowTypography.bodySm),
                Text('- Ask the owner to re-pin the content',
                    style: ShadowTypography.bodySm),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ShadowButton(
            label: 'Try again',
            leading: Icons.refresh_rounded,
            onPressed: () => context.go(
              '/resolve/resolving?id=${Uri.encodeComponent(shadowId)}',
            ),
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Back',
            variant: ShadowButtonVariant.ghost,
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}
