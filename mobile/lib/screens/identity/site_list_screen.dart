import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/site_adapter_record.dart';
import '../../providers/site_adapter_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_scaffold.dart';

/// Every site Shadow holds an identity for.
///
/// Only sites the user has actually chosen a behaviour for. A site merely
/// visited has no record at all — that is what keeps the mail service from
/// hearing about browsing — so an empty list here is the honest state of a
/// browser that has not been used to sign up for anything yet.
class SiteListScreen extends StatelessWidget {
  const SiteListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adapters = context.watch<SiteAdapterProvider>();

    return ShadowScaffold(
      title: 'Your sites',
      body: FutureBuilder<List<SiteAdapterRecord>>(
        // Keyed on the provider's notification count so a burn or a rotation
        // elsewhere refreshes this list rather than leaving it stale.
        key: ValueKey<int>(adapters.revision),
        future: adapters.configured(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data ?? <SiteAdapterRecord>[];
          if (records.isEmpty) {
            return const EmptyState(
              icon: Icons.fingerprint_rounded,
              title: 'No sites yet',
              message:
                  'Sites appear here once you fill an identity into one. '
                  'Somewhere you have only visited is not recorded at all.',
            );
          }

          records.sort((a, b) => a.domain.compareTo(b.domain));

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _SiteRow(record: records[index]),
          );
        },
      ),
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.record});

  final SiteAdapterRecord record;

  @override
  Widget build(BuildContext context) {
    final account = record.account;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        title: Text(record.domain, style: ShadowTypography.body),
        subtitle: Text(
          _describe(record),
          style: ShadowTypography.caption,
        ),
        trailing: account.isBurning
            ? const Icon(Icons.local_fire_department_rounded,
                size: 18, color: ShadowColors.warning)
            : const Icon(Icons.chevron_right_rounded,
                size: 18, color: ShadowColors.textSecondary),
        onTap: () => context.push(
          '/identity/sites/${Uri.encodeComponent(record.domain)}'
          '?account=${record.accountIndex}',
        ),
      ),
    );
  }

  static String _describe(SiteAdapterRecord record) {
    final account = record.account;
    final parts = <String>[
      switch (account.mode) {
        SiteMode.off => 'Normal browsing',
        SiteMode.masked => 'Masked identity',
        SiteMode.public => 'Your handle',
      },
    ];

    // A site set back to normal browsing can still hold a live address from
    // before. Say so, because it is the only place that address is visible
    // and the only route to closing it.
    if (account.mode == SiteMode.off &&
        account.mailbox.state != MailboxState.none) {
      parts.add('still has an address');
    }
    if (account.isBurning) parts.add('replacing the address');
    if (!account.isBurning && account.mailbox.unacknowledged > 0) {
      parts.add('${account.mailbox.unacknowledged} arrived');
    }
    if (account.passwordEpoch > 1) {
      parts.add('password v${account.passwordEpoch}');
    }
    if (account.aliasEpoch > 1) parts.add('address v${account.aliasEpoch}');
    if (record.accountIndex > 0) parts.add('account ${record.accountIndex}');

    return parts.join(' · ');
  }
}
