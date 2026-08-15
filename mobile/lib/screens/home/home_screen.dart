import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/activity.dart';
import '../../providers/activity_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_spacing.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/browser_bottom_bar.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/search_field.dart';
import '../../widgets/section_header.dart';
import '../../widgets/blind_top_bar.dart';

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
      backgroundColor: BlindColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlindTopBar(
              actions: [
                BlindTopBarButton(
                  icon: const Icon(Icons.star_rounded),
                  isActive: true,
                  onPressed: () => context.push('/bookmarks'),
                ),
                BlindTopBarButton(
                  icon: const Icon(Icons.extension_rounded),
                  onPressed: () => context.push('/extensions'),
                ),
                BlindTopBarButton(
                  icon: const Icon(Icons.visibility_off_rounded),
                  onPressed: () {},
                ),
                BlindTopBarButton(
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
        BlindSpacing.pagePadding,
        8,
        BlindSpacing.pagePadding,
        24,
      ),
      children: [
        const _BlindLogoHeader(),
        const SizedBox(height: 20),
        BlindSearchField(
          onSubmitted: (q) {
            if (q.trim().isEmpty) return;
            context.push('/resolve?id=${Uri.encodeComponent(q.trim())}');
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
      backgroundColor: BlindColors.surfaceElevated,
      builder: (_) => _HomeMenuSheet(),
    );
  }
}

class _BlindLogoHeader extends StatelessWidget {
  const _BlindLogoHeader();

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
              BorderSide(color: BlindColors.border),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'S',
            style: BlindTypography.displayLg.copyWith(fontSize: 36),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'SHADOW',
          style: BlindTypography.displayLg.copyWith(letterSpacing: 4),
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
        borderRadius: BorderRadius.circular(BlindRadius.xl),
        onTap: () => context.push('/deploy'),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: BlindColors.navyGradient,
            borderRadius: BorderRadius.circular(BlindRadius.xl),
            border: Border.all(color: BlindColors.cardNavyBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Convert Your Existing Website',
                        style: BlindTypography.h3),
                    const SizedBox(height: 8),
                    Text(
                      'Transform any traditional website into a decentralized Web3 site in minutes',
                      style: BlindTypography.bodySm,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(BlindRadius.sm),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Get Started', style: BlindTypography.label),
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
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(BlindRadius.md),
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
      _Feature('Wallet', Icons.account_balance_wallet_rounded,
          BlindColors.tileBlue, '/wallet'),
      _Feature('Domains', Icons.language_rounded, BlindColors.tilePurple,
          '/domains'),
      _Feature('Deploy', Icons.rocket_launch_rounded, BlindColors.tileGreen,
          '/deploy'),
      _Feature('Resolve', Icons.link_rounded, BlindColors.tileOrange,
          '/resolve'),
      _Feature('Tokens', Icons.monetization_on_rounded,
          BlindColors.tileAmber, '/tokens'),
      _Feature(
          'Activity', Icons.pie_chart_rounded, BlindColors.tilePink, '/activity'),
      _Feature('Settings', Icons.settings_rounded, BlindColors.tileGray,
          '/settings'),
      _Feature('History', Icons.history_rounded, BlindColors.tileCyan,
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
        ActivityKind.deploy => BlindColors.primary,
        ActivityKind.purchase => BlindColors.tilePink,
        ActivityKind.domainRegister => BlindColors.tilePurple,
        ActivityKind.transfer => BlindColors.tileBlue,
        ActivityKind.siteVisit => BlindColors.tileCyan,
        ActivityKind.info => BlindColors.tileGray,
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
          color: BlindColors.surfaceElevated,
          borderRadius: BorderRadius.circular(BlindRadius.md),
          border: Border.all(color: BlindColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: BlindColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No recent activity yet — deploy a site or mint a domain to get going.',
                style: BlindTypography.bodySm,
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
            statusColor: BlindColors.success,
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
    return const BrowserBottomBar(
      tabs: [
        BrowserTab(
            title: 'Olympus Home', url: 'olympus://home', icon: Icons.home_rounded),
        BrowserTab(
            title: 'Web3 Portal', url: 'olympus://web3', icon: Icons.bolt_rounded),
      ],
      activeIndex: 0,
      currentUrl: 'olympus://home',
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
                leading: Icon(item.icon, color: BlindColors.primary),
                title: Text(item.label, style: BlindTypography.bodyLg),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: BlindColors.textTertiary),
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
