import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_scaffold.dart';

class SettingsGeneralScreen extends StatelessWidget {
  const SettingsGeneralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final s = provider.settings;

    return ShadowScaffold(
      title: 'General',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SwitchListTile(
                  value: s.analyticsEnabled,
                  title: Text('Anonymous analytics',
                      style: ShadowTypography.body),
                  subtitle: Text(
                      'Help improve Shadow by sharing anonymous usage data',
                      style: ShadowTypography.bodySm),
                  onChanged: (v) => provider.update(
                      s.copyWith(analyticsEnabled: v)),
                ),
                const Divider(height: 1, color: ShadowColors.border),
                SwitchListTile(
                  value: s.telemetryEnabled,
                  title: Text('Crash telemetry', style: ShadowTypography.body),
                  subtitle: Text('Send crash reports automatically',
                      style: ShadowTypography.bodySm),
                  onChanged: (v) => provider.update(
                      s.copyWith(telemetryEnabled: v)),
                ),
                const Divider(height: 1, color: ShadowColors.border),
                SwitchListTile(
                  value: s.autoUpdateEnabled,
                  title: Text('Automatic updates', style: ShadowTypography.body),
                  subtitle: Text('Keep Shadow up-to-date in the background',
                      style: ShadowTypography.bodySm),
                  onChanged: (v) => provider.update(
                      s.copyWith(autoUpdateEnabled: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
