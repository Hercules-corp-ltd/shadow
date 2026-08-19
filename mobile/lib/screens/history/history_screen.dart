import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/history_entry.dart';
import '../../providers/history_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/load_state_view.dart';
import '../../widgets/search_field.dart';
import '../../widgets/shadow_scaffold.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<HistoryProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<HistoryProvider>();

    return ShadowScaffold(
      title: 'Browsing History',
      subtitle: 'View and manage your browsing activity',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: ShadowColors.error),
          onPressed: p.entries.isEmpty
              ? null
              : () => context.push('/history/clear'),
        ),
      ],
      body: Column(
        children: [
          ShadowSearchField(
            hint: 'Search history...',
            controller: _searchCtrl,
            onChanged: (q) => p.setQuery(q),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in const ['all', 'today', 'yesterday', '7d', '30d'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_label(r)),
                      selected: p.range == r,
                      onSelected: (_) => p.load(range: r),
                      labelStyle: ShadowTypography.label,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildList(p)),
        ],
      ),
    );
  }

  static String _label(String r) => switch (r) {
        'all' => 'All time',
        'today' => 'Today',
        'yesterday' => 'Yesterday',
        '7d' => 'Last 7 days',
        '30d' => 'Last 30 days',
        _ => r,
      };

  Widget _buildList(HistoryProvider p) {
    // Through LoadStateView, so a load that failed cannot be reported as an
    // account with no history. HistoryProvider has carried `error` the whole
    // time and this screen never read it.
    return LoadStateView(
      isLoading: p.isLoading,
      isEmpty: p.entries.isEmpty,
      error: p.error,
      onRetry: () => p.load(range: p.range),
      emptyIcon: Icons.history_rounded,
      emptyTitle: 'No history yet',
      emptyMessage: 'Sites you visit on Shadow will appear here.',
      child: _list(p.entries),
    );
  }

  Widget _list(List<HistoryEntry> entries) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemBuilder: (_, i) {
        final e = entries[i];
        return ListItemCard(
          title: e.title ?? e.domain,
          subtitle: e.domain,
          leadingIcon: Icons.public_rounded,
          leadingColor: ShadowColors.tileCyan,
          timeLabel: DateFormat('HH:mm').format(e.visitedAt),
          onTap: () => context.push('/resolve/resolving?id=${Uri.encodeComponent(e.domain)}'),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: entries.length,
    );
  }
}
