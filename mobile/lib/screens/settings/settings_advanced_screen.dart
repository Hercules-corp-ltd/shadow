import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/unbuilt_tile.dart';
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
          const GlassCard(
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                // Neither of these is read anywhere. No screen changes when
                // developer mode is on — there are no internal dev tools to
                // show — and nothing in the app is gated on the experimental
                // flag, so both switches only ever moved themselves.
                UnbuiltTile(
                  icon: Icons.terminal_rounded,
                  title: 'Developer mode',
                  reason: 'Nothing on any screen is gated on this yet, so '
                      'turning it on shows no extra tools.',
                ),
                Divider(height: 1, color: ShadowColors.edge),
                UnbuiltTile(
                  icon: Icons.science_outlined,
                  title: 'Experimental features',
                  reason: 'No feature is behind this flag yet.',
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
                Text('Shadow API address', style: ShadowTypography.h4),
                const SizedBox(height: 4),
                Text(
                  'Where the Shadow backend lives. Leave empty for the '
                  'built-in default. On an Android emulator, the machine '
                  'running the server is 10.0.2.2, not localhost.',
                  style: ShadowTypography.bodySm,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: s.apiBaseUrl,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  style: ShadowTypography.mono,
                  decoration: const InputDecoration(
                    hintText: 'http://10.0.2.2:8080/api',
                  ),
                  onFieldSubmitted: (v) =>
                      provider.update(s.copyWith(apiBaseUrl: v.trim())),
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
                // The four chips selected a string that never reached a log
                // call — no logger in the app consults logLevel. Kept visible
                // and inert rather than pretending to filter something.
                Text('Log level', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final l in const ['debug', 'info', 'warn', 'error'])
                      ChoiceChip(
                        label: Text(l.toUpperCase()),
                        selected: s.logLevel == l,
                        onSelected: null,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Shadow has no logger reading this yet, so the choice is '
                  'stored and nothing filters on it.',
                  style: ShadowTypography.bodySm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
