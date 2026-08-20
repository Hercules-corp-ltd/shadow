import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/domains_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/load_state_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DomainResultsScreen extends StatelessWidget {
  const DomainResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DomainsProvider>();

    return ShadowScaffold(
      title: 'Search Results',
      // A count is a claim. DomainsProvider.search substitutes an empty list
      // on any failure, so a dead backend used to report "0 matches" — a
      // factual statement about the registry, made by a request that never
      // completed.
      subtitle: p.error != null
          ? 'Search did not complete'
          : p.isLoading
              ? 'Searching…'
              : '${p.searchResults.length} matches',
      body: LoadStateView(
        isLoading: p.isLoading,
        isEmpty: p.searchResults.isEmpty,
        error: p.error,
        // LoadStateView labels this "Try again", so it has to actually try
        // again. It used to pop the screen, which is the one thing a user who
        // asked to retry did not ask for.
        onRetry: () => p.search(p.lastQuery),
        emptyIcon: Icons.search_off_rounded,
        emptyTitle: 'No matching domains',
        // The search only returns registered, verified domains, so an empty
        // result does not imply the name is free. Saying "no matches" is the
        // honest reading; the green "Available" badge below never fires,
        // because every result by definition has an owner.
        emptyMessage:
            'Nothing registered matches that. Shadow cannot yet confirm '
            'whether a name is free to claim.',
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemBuilder: (_, i) {
            final d = p.searchResults[i];
            final available = d.ownerPubkey.isEmpty;
            return GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ShadowColors.recessDeep,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (available
                                ? ShadowColors.success
                                : ShadowColors.textTertiary)
                            .withValues(alpha: 0.32),
                      ),
                    ),
                    child: Icon(
                      available ? Icons.check_rounded : Icons.block_rounded,
                      color: available
                          ? ShadowColors.success
                          : ShadowColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.domain, style: ShadowTypography.h4),
                        Text(
                          available ? 'Available' : 'Taken',
                          style: ShadowTypography.bodySm.copyWith(
                            color: available
                                ? ShadowColors.success
                                : ShadowColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (available)
                    ShadowButton(
                      label: 'Register',
                      size: ShadowButtonSize.sm,
                      expand: false,
                      onPressed: () => context.push(
                        '/domains/register?q=${Uri.encodeComponent(d.domain)}',
                      ),
                    )
                  else
                    TextButton(
                      onPressed: () => context.push('/domains/${d.domain}'),
                      child: const Text('View'),
                    ),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: p.searchResults.length,
        ),
      ),
    );
  }
}
