import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_scaffold.dart';

class SettingsGeneralScreen extends StatelessWidget {
  const SettingsGeneralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final s = provider.settings;

    return BlindScaffold(
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
                      style: BlindTypography.body),
                  subtitle: Text(
                      'Help improve Blind by sharing anonymous usage data',
                      style: BlindTypography.bodySm),
                  onChanged: (v) => provider.update(
                      s.copyWith(analyticsEnabled: v)),
                ),
                const Divider(height: 1, color: BlindColors.border),
                SwitchListTile(
                  value: s.telemetryEnabled,
                  title: Text('Crash telemetry', style: BlindTypography.body),
                  subtitle: Text('Send crash reports automatically',
                      style: BlindTypography.bodySm),
                  onChanged: (v) => provider.update(
                      s.copyWith(telemetryEnabled: v)),
                ),
                const Divider(height: 1, color: BlindColors.border),
                SwitchListTile(
                  value: s.autoUpdateEnabled,
                  title: Text('Automatic updates', style: BlindTypography.body),
                  subtitle: Text('Keep Blind up-to-date in the background',
                      style: BlindTypography.bodySm),
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
