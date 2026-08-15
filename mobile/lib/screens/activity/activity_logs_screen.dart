import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/activity_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_scaffold.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  String? _level;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ActivityProvider>().loadLogs(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ActivityProvider>();

    return ShadowScaffold(
      title: 'Logs',
      subtitle: 'Diagnostic logs from your browser',
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final l in const [null, 'debug', 'info', 'warn', 'error'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(l == null ? 'All' : l.toUpperCase()),
                      selected: _level == l,
                      onSelected: (_) {
                        setState(() => _level = l);
                        context.read<ActivityProvider>().loadLogs(level: l);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: p.isLoading && p.logs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : p.logs.isEmpty
                    ? EmptyState(
                        icon: Icons.article_rounded,
                        title: 'No logs',
                        message: 'Logs matching this filter will appear here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemBuilder: (_, i) {
                          final l = p.logs[i];
                          final lvl = (l.status ?? 'info').toLowerCase();
                          final color = switch (lvl) {
                            'error' => ShadowColors.error,
                            'warn' => ShadowColors.warning,
                            'debug' => ShadowColors.textTertiary,
                            _ => ShadowColors.info,
                          };
                          return GlassCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    lvl.toUpperCase(),
                                    style: ShadowTypography.caption.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(l.title,
                                          style: ShadowTypography.body),
                                      if (l.subtitle != null)
                                        Text(l.subtitle!,
                                            style: ShadowTypography.caption),
                                      Text(
                                        DateFormat('HH:mm:ss').format(l.timestamp),
                                        style: ShadowTypography.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemCount: p.logs.length,
                      ),
          ),
        ],
      ),
    );
  }
}
