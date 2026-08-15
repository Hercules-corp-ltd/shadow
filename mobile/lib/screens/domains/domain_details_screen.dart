import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/domain.dart';
import '../../providers/domains_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';
import '../../widgets/status_pill.dart';

class DomainDetailsScreen extends StatefulWidget {
  const DomainDetailsScreen({super.key, required this.domain});
  final String domain;

  @override
  State<DomainDetailsScreen> createState() => _DomainDetailsScreenState();
}

class _DomainDetailsScreenState extends State<DomainDetailsScreen> {
  BlindDomain? _d;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final d = await context.read<DomainsProvider>().load(widget.domain);
      if (mounted) setState(() => _d = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final df = DateFormat.yMMMd();

    return BlindScaffold(
      title: widget.domain,
      subtitle: d == null
          ? 'Loading...'
          : d.isVerified
              ? 'Verified domain'
              : 'Unverified',
      body: d == null
          ? const Center(child: CircularProgressIndicator())
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
                            child: Text(d.domain, style: BlindTypography.h2),
                          ),
                          StatusPill(
                            label: d.isVerified ? 'Verified' : 'Unverified',
                            color: d.isVerified
                                ? BlindColors.success
                                : BlindColors.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Row(label: 'Registered', value: df.format(d.registeredAt)),
                      if (d.expiresAt != null)
                        _Row(
                          label: 'Expires',
                          value: df.format(d.expiresAt!),
                          valueColor:
                              d.isExpired ? BlindColors.error : null,
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
                            label: 'Trust score',
                            value: '${d.trustScore}/100'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListItemCard(
                  title: 'DNS records',
                  subtitle: '${d.dnsRecords.length} records',
                  leadingIcon: Icons.dns_rounded,
                  leadingColor: BlindColors.tileCyan,
                  onTap: () => context.push('/domains/${d.domain}/dns'),
                ),
                const SizedBox(height: 8),
                ListItemCard(
                  title: 'Settings',
                  subtitle: 'Metadata, visibility, verification',
                  leadingIcon: Icons.settings_rounded,
                  leadingColor: BlindColors.tileGray,
                  onTap: () => context.push('/domains/${d.domain}/settings'),
                ),
                const SizedBox(height: 8),
                ListItemCard(
                  title: 'Renew',
                  subtitle: 'Extend your registration',
                  leadingIcon: Icons.refresh_rounded,
                  leadingColor: BlindColors.tileGreen,
                  onTap: () => context.push('/domains/${d.domain}/renew'),
                ),
                const SizedBox(height: 8),
                ListItemCard(
                  title: 'Transfer ownership',
                  subtitle: 'Send this domain to another wallet',
                  leadingIcon: Icons.swap_horiz_rounded,
                  leadingColor: BlindColors.tileAmber,
                  onTap: () => context.push('/domains/${d.domain}/transfer'),
                ),
                const SizedBox(height: 20),
                BlindButton(
                  label: 'Open site',
                  size: BlindButtonSize.lg,
                  leading: Icons.open_in_new_rounded,
                  onPressed: () => context.push(
                    '/resolve?id=${Uri.encodeComponent(d.domain)}',
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
                style: BlindTypography.bodySm
                    .copyWith(color: BlindColors.textTertiary)),
          ),
          Expanded(
            child: Text(
              value,
              style: BlindTypography.body.copyWith(color: valueColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: BlindColors.textSecondary),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}
