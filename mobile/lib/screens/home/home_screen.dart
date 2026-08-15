import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/activity.dart';
import '../../providers/activity_provider.dart';
import '../../providers/browser_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_spacing.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/browser_bottom_bar.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/search_field.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shadow_top_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityProvider>().loadRecent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShadowColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ShadowTopBar(
              actions: [
                ShadowTopBarButton(
                  icon: const Icon(Icons.star_rounded),
                  isActive: true,
                  onPressed: () => context.push('/bookmarks'),
                ),
                ShadowTopBarButton(
                  icon: const Icon(Icons.extension_rounded),
                  onPressed: () => context.push('/extensions'),
                ),
                ShadowTopBarButton(
                  icon: const Icon(Icons.visibility_off_rounded),
                  onPressed: () {},
                ),
                ShadowTopBarButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => _showMenu(context),
                ),
              ],
            ),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
      bottomNavigationBar: const _HomeBrowserBar(),
    );
  }

  Widget _buildContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ShadowSpacing.pagePadding,
        8,
        ShadowSpacing.pagePadding,
        24,
      ),
      children: [
        const _ShadowLogoHeader(),
        const SizedBox(height: 20),
        ShadowSearchField(
          onSubmitted: (q) {
            final query = q.trim();
            if (query.isEmpty) return;
            // Shadow-native identifiers go to the resolver; everything else is
            // ordinary web browsing. Sending a plain search to the resolver
            // was the old behaviour and it dead-ended on an empty text box.
            if (_isShadowIdentifier(query)) {
              context.push('/resolve/resolving?id=${Uri.encodeComponent(query)}');
            } else {
              context.push('/browse?url=${Uri.encodeComponent(query)}');
            }
          },
        ),
        const SizedBox(height: 20),
        const _ConvertCta(),
        const SizedBox(height: 24),
        const _FeatureGrid(),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Recent Activity',
          actionLabel: 'View all',
          onAction: () => context.push('/activity'),
        ),
        const SizedBox(height: 12),
        const _RecentActivityList(),
      ],
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ShadowColors.surfaceElevated,
      builder: (_) => _HomeMenuSheet(),
    );
  }
}

/// True for things only Shadow can resolve: a .shadow domain, an IPFS or
/// Arweave content id, or a bare base58 program address.
bool _isShadowIdentifier(String query) {
  final value = query.toLowerCase();
  if (value.endsWith('.shadow')) return true;
  if (value.startsWith('shadow://')) return true;
  if (RegExp(r'^(qm[1-9a-hj-np-z]{44}|bafy[a-z2-7]{50,})$').hasMatch(value)) {
    return true;
  }
  // A bare base58 address: no dots, no spaces, Solana-pubkey length.
  if (!query.contains('.') &&
      !query.contains(' ') &&
      RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(query)) {
    return true;
  }
  return false;
}

class _ShadowLogoHeader extends StatelessWidget {
  const _ShadowLogoHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFF2A2A2A), Color(0xFF050505)],
            ),
            border: Border.fromBorderSide(
              BorderSide(color: ShadowColors.border),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'S',
            style: ShadowTypography.displayLg.copyWith(fontSize: 36),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'SHADOW',
          style: ShadowTypography.displayLg.copyWith(letterSpacing: 4),
        ),
      ],
    );
  }
}

class _ConvertCta extends StatelessWidget {
  const _ConvertCta();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ShadowRadius.xl),
        onTap: () => context.push('/deploy'),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: ShadowColors.navyGradient,
            borderRadius: BorderRadius.circular(ShadowRadius.xl),
            border: Border.all(color: ShadowColors.cardNavyBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Convert Your Existing Website',
                        style: ShadowTypography.h3),
                    const SizedBox(height: 8),
                    Text(
                      'Transform any traditional website into a decentralized Web3 site in minutes',
                      style: ShadowTypography.bodySm,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(ShadowRadius.sm),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Get Started', style: ShadowTypography.label),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(ShadowRadius.md),
                ),
                child: const Icon(Icons.public_rounded,
                    size: 36, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    final tiles = <_Feature>[
      const _Feature('Identity', Icons.fingerprint_rounded, ShadowColors.tileRed,
          '/identity'),
      const _Feature('Wallet', Icons.account_balance_wallet_rounded,
          ShadowColors.tileBlue, '/wallet'),
      const _Feature('Domains', Icons.language_rounded, ShadowColors.tilePurple,
          '/domains'),
      const _Feature('Deploy', Icons.rocket_launch_rounded, ShadowColors.tileGreen,
          '/deploy'),
      const _Feature('Resolve', Icons.link_rounded, ShadowColors.tileOrange,
          '/resolve'),
      const _Feature('Tokens', Icons.monetization_on_rounded,
          ShadowColors.tileAmber, '/tokens'),
      const _Feature(
          'Activity', Icons.pie_chart_rounded, ShadowColors.tilePink, '/activity'),
      const _Feature('Settings', Icons.settings_rounded, ShadowColors.tileGray,
          '/settings'),
      const _Feature('History', Icons.history_rounded, ShadowColors.tileCyan,
          '/history'),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 4,
      childAspectRatio: 0.82,
      children: [
        for (final t in tiles)
          IconTile(
            label: t.label,
            icon: Icon(t.icon),
            color: t.color,
            onTap: () => context.push(t.route),
          ),
      ],
    );
  }
}

class _Feature {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _Feature(this.label, this.icon, this.color, this.route);
}

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList();

  IconData _iconFor(ActivityKind k) => switch (k) {
        ActivityKind.deploy => Icons.rocket_launch_rounded,
        ActivityKind.purchase => Icons.shopping_cart_rounded,
        ActivityKind.domainRegister => Icons.language_rounded,
        ActivityKind.transfer => Icons.send_rounded,
        ActivityKind.siteVisit => Icons.public_rounded,
        ActivityKind.info => Icons.info_rounded,
      };

  Color _colorFor(ActivityKind k) => switch (k) {
        ActivityKind.deploy => ShadowColors.primary,
        ActivityKind.purchase => ShadowColors.tilePink,
        ActivityKind.domainRegister => ShadowColors.tilePurple,
        ActivityKind.transfer => ShadowColors.tileBlue,
        ActivityKind.siteVisit => ShadowColors.tileCyan,
        ActivityKind.info => ShadowColors.tileGray,
      };

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ActivityProvider>();
    final recent = p.recent;

    if (p.isLoading && recent.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ShadowColors.surfaceElevated,
          borderRadius: BorderRadius.circular(ShadowRadius.md),
          border: Border.all(color: ShadowColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: ShadowColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No recent activity yet — deploy a site or mint a domain to get going.',
                style: ShadowTypography.bodySm,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final entry in recent.take(4)) ...[
          ListItemCard(
            title: entry.title,
            subtitle: entry.subtitle,
            timeLabel: _timeAgo(entry.timestamp),
            statusLabel: entry.status ?? 'Success',
            statusColor: ShadowColors.success,
            leadingIcon: _iconFor(entry.kind),
            leadingColor: _colorFor(entry.kind),
            onTap: () {
              if (entry.relatedDomain != null) {
                context.push('/domains/${entry.relatedDomain}');
              }
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HomeBrowserBar extends StatelessWidget {
  const _HomeBrowserBar();

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final tab = browser.activeTab;

    return BrowserBottomBar(
      tabs: browser.hasTabs
          ? [
              for (final t in browser.tabs)
                BrowserTab(title: t.title, url: t.displayUrl),
            ]
          : const [
              BrowserTab(
                title: 'New tab',
                url: 'Tap to browse',
                icon: Icons.home_rounded,
              ),
            ],
      activeIndex: browser.hasTabs ? browser.activeIndex : 0,
      currentUrl: tab?.displayUrl ?? 'Tap to browse',
      isSecure: tab?.isSecure ?? false,
      onTapUrl: () => context.push('/browse'),
      onAddTab: () => context.push('/browse'),
      onSelectTab: (index) {
        browser.selectTab(index);
        context.push('/browse');
      },
      onCloseTab: browser.hasTabs ? browser.closeTab : null,
      onRefresh: browser.hasTabs ? browser.reload : null,
    );
  }
}

class _HomeMenuSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      const _MenuItem('History', Icons.history_rounded, '/history'),
      const _MenuItem('Bookmarks', Icons.bookmark_rounded, '/bookmarks'),
      const _MenuItem('Downloads', Icons.download_rounded, '/downloads'),
      const _MenuItem('Extensions', Icons.extension_rounded, '/extensions'),
      const _MenuItem('Deploy Website', Icons.rocket_launch_rounded, '/deploy'),
      const _MenuItem('Activity & Logs', Icons.pie_chart_rounded, '/activity'),
      const _MenuItem('Settings', Icons.settings_rounded, '/settings'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              ListTile(
                leading: Icon(item.icon, color: ShadowColors.primary),
                title: Text(item.label, style: ShadowTypography.bodyLg),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: ShadowColors.textTertiary),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(item.route);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  final String route;
  const _MenuItem(this.label, this.icon, this.route);
}
