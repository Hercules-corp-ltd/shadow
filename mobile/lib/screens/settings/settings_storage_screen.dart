import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_scaffold.dart';

class SettingsStorageScreen extends StatelessWidget {
  const SettingsStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final s = provider.settings;

    return BlindScaffold(
      title: 'Storage',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Max cache size', style: BlindTypography.h4),
                Text('${s.maxCacheMb} MB', style: BlindTypography.bodySm),
                Slider(
                  min: 128,
                  max: 4096,
                  divisions: 31,
                  value: s.maxCacheMb.toDouble().clamp(128, 4096),
                  label: '${s.maxCacheMb} MB',
                  onChanged: (v) =>
                      provider.update(s.copyWith(maxCacheMb: v.toInt())),
                ),
                const SizedBox(height: 12),
                Text('History retention', style: BlindTypography.h4),
                Text('${s.maxHistoryItems} items',
                    style: BlindTypography.bodySm),
                Slider(
                  min: 100,
                  max: 10000,
                  divisions: 99,
                  value: s.maxHistoryItems.toDouble().clamp(100, 10000),
                  onChanged: (v) => provider
                      .update(s.copyWith(maxHistoryItems: v.toInt())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: SwitchListTile(
              value: s.autoClearCache,
              title: Text('Auto-clear cache weekly',
                  style: BlindTypography.body),
              subtitle: Text('Remove non-pinned content every Sunday',
                  style: BlindTypography.bodySm),
              onChanged: (v) => provider.update(s.copyWith(autoClearCache: v)),
            ),
          ),
        ],
      ),
    );
  }
}
