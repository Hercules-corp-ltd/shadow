import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_scaffold.dart';

class SettingsAdvancedScreen extends StatelessWidget {
  const SettingsAdvancedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final s = provider.settings;

    return ShadowScaffold(
      title: 'Advanced',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SwitchListTile(
                  value: s.developerMode,
                  title: Text('Developer mode', style: ShadowTypography.body),
                  subtitle: Text('Show internal dev tools',
                      style: ShadowTypography.bodySm),
                  onChanged: (v) =>
                      provider.update(s.copyWith(developerMode: v)),
                ),
                const Divider(height: 1, color: ShadowColors.border),
                SwitchListTile(
                  value: s.experimentalFeatures,
                  title: Text('Experimental features',
                      style: ShadowTypography.body),
                  subtitle: Text('Enable unstable features in progress',
                      style: ShadowTypography.bodySm),
                  onChanged: (v) =>
                      provider.update(s.copyWith(experimentalFeatures: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Log level', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final l in const ['debug', 'info', 'warn', 'error'])
                      ChoiceChip(
                        label: Text(l.toUpperCase()),
                        selected: s.logLevel == l,
                        onSelected: (_) =>
                            provider.update(s.copyWith(logLevel: l)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
