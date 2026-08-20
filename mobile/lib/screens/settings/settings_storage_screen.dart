import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/unbuilt_tile.dart';
import '../../widgets/shadow_scaffold.dart';

class SettingsStorageScreen extends StatelessWidget {
  const SettingsStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final s = provider.settings;

    return ShadowScaffold(
      title: 'Storage',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Both sliders were live and neither limit is enforced:
                // there is no cache manager and no history trimmer anywhere
                // in the app, so the screen reported "512 MB" and "1000
                // items" as live ceilings that nothing has ever applied. The
                // controls stay visible so the intent is legible, but they do
                // not move, because a slider that moves is a promise.
                Text('Max cache size', style: ShadowTypography.h4),
                Text('${s.maxCacheMb} MB', style: ShadowTypography.bodySm),
                Slider(
                  min: 128,
                  max: 4096,
                  divisions: 31,
                  value: s.maxCacheMb.toDouble().clamp(128, 4096),
                  label: '${s.maxCacheMb} MB',
                  onChanged: null,
                ),
                const SizedBox(height: 12),
                Text('History retention', style: ShadowTypography.h4),
                Text('${s.maxHistoryItems} items',
                    style: ShadowTypography.bodySm),
                Slider(
                  min: 100,
                  max: 10000,
                  divisions: 99,
                  value: s.maxHistoryItems.toDouble().clamp(100, 10000),
                  onChanged: null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Neither limit is applied yet — Shadow has no cache manager '
                  'and does not trim history, so these are stored numbers '
                  'rather than ceilings. Clear history from the History '
                  'screen in the meantime.',
                  style: ShadowTypography.bodySm,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const GlassCard(
            padding: EdgeInsets.all(8),
            child: UnbuiltTile(
              icon: Icons.auto_delete_outlined,
              title: 'Auto-clear cache weekly',
              reason: 'No scheduled job runs in Shadow, so nothing would '
                  'happen on Sunday or any other day.',
            ),
          ),
        ],
      ),
    );
  }
}
