import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/domain.dart';
import '../../providers/domains_provider.dart';
import '../../services/fetch_outcome.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';
import '../../widgets/status_pill.dart';

class DomainDetailsScreen extends StatefulWidget {
  const DomainDetailsScreen({super.key, required this.domain});
  final String domain;

  @override
  State<DomainDetailsScreen> createState() => _DomainDetailsScreenState();
}

class _DomainDetailsScreenState extends State<DomainDetailsScreen> {
  ShadowDomain? _d;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final outcome = await context.read<DomainsProvider>().load(widget.domain);
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (outcome) {
        case FetchSuccess(value: final d):
          _d = d;
        case FetchNotFound():
          _error = 'No domain registered as "${widget.domain}"';
        case FetchUnreachable(reason: final reason):
          _error = reason;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final df = DateFormat.yMMMd();

    return ShadowScaffold(
      title: widget.domain,
      subtitle: switch ((d, _loading)) {
        (final ShadowDomain domain, _) =>
          domain.isVerified ? 'Verified domain' : 'Unverified',
        (_, true) => 'Loading...',
        _ => 'Unavailable',
      },
      body: d == null
          ? (_loading
              ? const Center(child: CircularProgressIndicator())
              : EmptyState(
                  icon: Icons.cloud_off_rounded,
                  tone: EmptyStateTone.error,
                  title: 'Could not load this domain',
                  message: _error ?? 'Something went wrong.',
                  actionLabel: 'Try again',
                  onAction: _load,
                ))
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(d.domain, style: ShadowTypography.h2),
                          ),
                          StatusPill(
                            label: d.isVerified ? 'Verified' : 'Unverified',
                            color: d.isVerified
                                ? ShadowColors.success
                                : ShadowColors.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Row(
                          label: 'Registered',
                          value: d.registeredAt == null
                              ? 'Not reported'
                              : df.format(d.registeredAt!)),
                      if (d.expiresAt != null)
                        _Row(
                          label: 'Expires',
                          value: df.format(d.expiresAt!),
                          valueColor: d.isExpired ? ShadowColors.error : null,
                        ),
                      _Row(
                        label: 'Owner',
                        value: _short(d.ownerPubkey),
                        onCopy: () => _copy(context, d.ownerPubkey),
                      ),
                      _Row(
                        label: 'Program',
                        value: _short(d.programAddress),
                        onCopy: () => _copy(context, d.programAddress),
                      ),
                      if (d.trustScore != null)
                        _Row(
                            label: 'Trust score', value: '${d.trustScore}/100'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListItemCard(
                  title: 'DNS records',
                  subtitle: '${d.dnsRecords.length} records',
                  leadingIcon: Icons.dns_rounded,
                  leadingColor: ShadowColors.tileCyan,
                  onTap: () => context.push('/domains/${d.domain}/dns'),
                ),
                const SizedBox(height: 8),
                ListItemCard(
                  title: 'Settings',
                  subtitle: 'Metadata, visibility, verification',
                  leadingIcon: Icons.settings_rounded,
                  leadingColor: ShadowColors.tileGray,
                  onTap: () => context.push('/domains/${d.domain}/settings'),
                ),
                const SizedBox(height: 8),
                ListItemCard(
                  title: 'Renew',
                  subtitle: 'Extend your registration',
                  leadingIcon: Icons.refresh_rounded,
                  leadingColor: ShadowColors.tileGreen,
                  onTap: () => context.push('/domains/${d.domain}/renew'),
                ),
                const SizedBox(height: 8),
                ListItemCard(
                  title: 'Transfer ownership',
                  subtitle: 'Send this domain to another wallet',
                  leadingIcon: Icons.swap_horiz_rounded,
                  leadingColor: ShadowColors.tileAmber,
                  onTap: () => context.push('/domains/${d.domain}/transfer'),
                ),
                const SizedBox(height: 20),
                ShadowButton(
                  label: 'Open site',
                  size: ShadowButtonSize.lg,
                  leading: Icons.open_in_new_rounded,
                  onPressed: () => context.push(
                    '/resolve/resolving?id=${Uri.encodeComponent(d.domain)}',
                  ),
                ),
              ],
            ),
    );
  }

  static String _short(String v) =>
      v.length < 16 ? v : '${v.substring(0, 6)}...${v.substring(v.length - 6)}';

  static Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied')),
      );
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.onCopy,
    this.valueColor,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: ShadowTypography.bodySm
                    .copyWith(color: ShadowColors.textTertiary)),
          ),
          Expanded(
            child: Text(
              value,
              style: ShadowTypography.body.copyWith(color: valueColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: ShadowColors.textSecondary),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}
