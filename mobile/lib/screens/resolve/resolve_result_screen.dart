import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/site.dart';
import '../../providers/bookmarks_provider.dart';
import '../../services/history_service.dart';
import '../../services/resolve_service.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class ResolveResultScreen extends StatefulWidget {
  const ResolveResultScreen({super.key, required this.shadowId});
  final String shadowId;

  @override
  State<ResolveResultScreen> createState() => _ResolveResultScreenState();
}

class _ResolveResultScreenState extends State<ResolveResultScreen> {
  final _service = ResolveService();
  final _historyService = HistoryService();
  Site? _site;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = widget.shadowId;
    Site? site;
    if (id.endsWith('.shadow')) {
      site = await _service.resolveDomain(id);
    } else {
      site = await _service.resolveById(id);
    }
    if (!mounted) return;
    setState(() {
      _site = site;
      _loading = false;
    });
    if (site != null) {
      try {
        await _historyService.record(domain: site.domain, title: site.title);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ShadowScaffold(
        title: 'Resolved',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final site = _site;
    if (site == null) {
      return ShadowScaffold(
        title: 'Not found',
        body: Center(
          child: Text('Site could not be resolved', style: ShadowTypography.body),
        ),
      );
    }

    return ShadowScaffold(
      title: site.title ?? site.domain,
      subtitle: site.domain,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            gradient: ShadowColors.navyGradient,
            border: Border.all(color: ShadowColors.cardNavyBorder, width: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: ShadowColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.public_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(site.title ?? site.domain,
                              style: ShadowTypography.h3),
                          const SizedBox(height: 4),
                          Text(site.domain,
                              style: ShadowTypography.bodySm),
                        ],
                      ),
                    ),
                  ],
                ),
                if (site.description != null) ...[
                  const SizedBox(height: 16),
                  Text(site.description!, style: ShadowTypography.body),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Deploy version', site.deployVersion),
                _row('Last deployed',
                    DateFormat.yMMMd().add_jm().format(site.lastDeployedAt)),
                _row('Visits', site.visitCount.toString()),
                _row('Content CID', site.contentCid, copy: true),
                _row('Program', site.programAddress, copy: true),
                _row('Owner', site.ownerPubkey, copy: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ShadowButton(
            label: 'Open content',
            size: ShadowButtonSize.lg,
            leading: Icons.open_in_new_rounded,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rendering in browser...')),
              );
            },
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Save to bookmarks',
            variant: ShadowButtonVariant.secondary,
            leading: Icons.bookmark_add_outlined,
            onPressed: () async {
              await context.read<BookmarksProvider>().add(
                    domain: site.domain,
                    programAddress: site.programAddress,
                    title: site.title,
                  );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bookmarked')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool copy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: ShadowTypography.bodySm
                  .copyWith(color: ShadowColors.textTertiary),
            ),
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
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              },
            ),
        ],
      ),
    );
  }
}
