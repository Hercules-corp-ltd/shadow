import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/activity.dart';
import '../../providers/activity_provider.dart';
import '../../theme/blind_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/blind_scaffold.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<ActivityProvider>().loadRecent());
  }

  IconData _iconFor(ActivityKind k) => switch (k) {
        ActivityKind.deploy => Icons.cloud_upload_rounded,
        ActivityKind.purchase => Icons.shopping_bag_rounded,
        ActivityKind.domainRegister => Icons.language_rounded,
        ActivityKind.transfer => Icons.swap_horiz_rounded,
        ActivityKind.siteVisit => Icons.public_rounded,
        ActivityKind.info => Icons.info_outline_rounded,
      };

  Color _colorFor(ActivityKind k) => switch (k) {
        ActivityKind.deploy => BlindColors.tileBlue,
        ActivityKind.purchase => BlindColors.tileAmber,
        ActivityKind.domainRegister => BlindColors.tilePurple,
        ActivityKind.transfer => BlindColors.tileCyan,
        ActivityKind.siteVisit => BlindColors.tileGreen,
        ActivityKind.info => BlindColors.tileGray,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ActivityProvider>();

    return BlindScaffold(
      title: 'Activity',
      subtitle: 'Your recent actions on Blind',
      actions: [
        IconButton(
          icon: const Icon(Icons.article_rounded),
          tooltip: 'Logs',
          onPressed: () => context.push('/activity/logs'),
        ),
      ],
      body: p.isLoading && p.recent.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : p.recent.isEmpty
              ? EmptyState(
                  icon: Icons.timeline_rounded,
                  title: 'No activity yet',
                  message: 'Your deploys, purchases and visits will show here.',
                  actionLabel: 'View logs',
                  onAction: () => context.push('/activity/logs'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemBuilder: (_, i) {
                    final a = p.recent[i];
                    return ListItemCard(
                      title: a.title,
                      subtitle: a.subtitle,
                      leadingIcon: _iconFor(a.kind),
                      leadingColor: _colorFor(a.kind),
                      statusLabel: a.status,
                      timeLabel: DateFormat.Md().add_Hm().format(a.timestamp),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: p.recent.length,
                ),
    );
  }
}
