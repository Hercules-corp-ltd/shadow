import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/activity.dart';
import '../../providers/activity_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../widgets/load_state_view.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/shadow_scaffold.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<ActivityProvider>().loadRecent());
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
        ActivityKind.deploy => ShadowColors.tileBlue,
        ActivityKind.purchase => ShadowColors.tileAmber,
        ActivityKind.domainRegister => ShadowColors.tilePurple,
        ActivityKind.transfer => ShadowColors.tileCyan,
        ActivityKind.siteVisit => ShadowColors.tileGreen,
        ActivityKind.info => ShadowColors.tileGray,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ActivityProvider>();

    return ShadowScaffold(
      title: 'Activity',
      subtitle: 'Your recent actions on Shadow',
      actions: [
        IconButton(
          icon: const Icon(Icons.article_rounded),
          tooltip: 'Logs',
          onPressed: () => context.push('/activity/logs'),
        ),
      ],
      // "Your deploys, purchases and visits will show here" described a
      // capability that does not exist: ActivityService.record() has no
      // callers anywhere in the app — the browser records visits through
      // HistoryService instead — so nothing can ever put a row in this list.
      body: LoadStateView(
        isLoading: p.isLoading,
        isEmpty: p.recent.isEmpty,
        error: p.error,
        onRetry: p.loadRecent,
        emptyIcon: Icons.timeline_rounded,
        emptyTitle: 'Nothing is recorded here yet',
        emptyMessage: 'Shadow does not write to an activity log yet, so this '
            'stays empty whatever you do. Browsing history is kept '
            'separately, under History.',
        child: ListView.separated(
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
      ),
    );
  }
}
