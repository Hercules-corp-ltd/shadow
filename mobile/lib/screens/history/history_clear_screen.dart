import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/history_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class HistoryClearScreen extends StatefulWidget {
  const HistoryClearScreen({super.key});

  @override
  State<HistoryClearScreen> createState() => _HistoryClearScreenState();
}

class _HistoryClearScreenState extends State<HistoryClearScreen> {
  String _range = 'all';

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Clear History',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delete_sweep_rounded,
                        color: ShadowColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select a time range to clear',
                        style: ShadowTypography.h3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RadioGroup<String>(
                  groupValue: _range,
                  onChanged: (v) => setState(() => _range = v ?? 'all'),
                  child: Column(
                    children: <Widget>[
                      for (final r in const [
                        ['all', 'All time'],
                        ['today', 'Today'],
                        ['yesterday', 'Yesterday'],
                        ['7d', 'Last 7 days'],
                        ['30d', 'Last 30 days'],
                      ])
                        RadioListTile<String>(
                          value: r[0],
                          title: Text(r[1], style: ShadowTypography.body),
                          activeColor: ShadowColors.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadowButton(
            label: 'Clear History',
            variant: ShadowButtonVariant.danger,
            size: ShadowButtonSize.lg,
            onPressed: () async {
              await context.read<HistoryProvider>().clear(range: _range);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History cleared')),
              );
              context.pop();
            },
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Cancel',
            variant: ShadowButtonVariant.ghost,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
