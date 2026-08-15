import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/history_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class HistoryClearScreen extends StatefulWidget {
  const HistoryClearScreen({super.key});

  @override
  State<HistoryClearScreen> createState() => _HistoryClearScreenState();
}

class _HistoryClearScreenState extends State<HistoryClearScreen> {
  String _range = 'all';

  @override
  Widget build(BuildContext context) {
    return BlindScaffold(
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
                        color: BlindColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select a time range to clear',
                        style: BlindTypography.h3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final r in const [
                  ['all', 'All time'],
                  ['today', 'Today'],
                  ['yesterday', 'Yesterday'],
                  ['7d', 'Last 7 days'],
                  ['30d', 'Last 30 days'],
                ])
                  RadioListTile<String>(
                    value: r[0],
                    groupValue: _range,
                    onChanged: (v) => setState(() => _range = v ?? 'all'),
                    title: Text(r[1], style: BlindTypography.body),
                    activeColor: BlindColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BlindButton(
            label: 'Clear History',
            variant: BlindButtonVariant.danger,
            size: BlindButtonSize.lg,
            onPressed: () async {
              await context.read<HistoryProvider>().clear();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History cleared')),
              );
              context.pop();
            },
          ),
          const SizedBox(height: 8),
          BlindButton(
            label: 'Cancel',
            variant: BlindButtonVariant.ghost,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
