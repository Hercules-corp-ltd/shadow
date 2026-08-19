import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/unbuilt_tile.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_scaffold.dart';

class SettingsSecurityScreen extends StatelessWidget {
  const SettingsSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final s = provider.settings;

    return ShadowScaffold(
      title: 'Security',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SwitchListTile(
                  value: s.requireUnlock,
                  title: Text('Require password each launch',
                      style: ShadowTypography.body),
                  subtitle: Text('Always lock wallet when the app closes',
                      style: ShadowTypography.bodySm),
                  onChanged: (v) =>
                      provider.update(s.copyWith(requireUnlock: v)),
                ),
                const Divider(height: 1, color: ShadowColors.border),
                const UnbuiltTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Unlock with biometrics',
                  reason: 'Shadow has no biometric integration yet — unlocking '
                      'always uses your password.',
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
                Text('Auto-lock after', style: ShadowTypography.h4),
                Text(
                  'No idle timer runs yet, so this value is stored and not '
                  'acted on. The wallet locks when you lock it.',
                  style: ShadowTypography.bodySm,
                ),
                Slider(
                  min: 1,
                  max: 60,
                  divisions: 59,
                  value: s.autoLockMinutes.toDouble().clamp(1, 60),
                  label: '${s.autoLockMinutes} min',
                  // Disabled rather than removed: the preference is worth
                  // keeping once a timer exists, but a slider that appears to
                  // set a security control it does not set is a lie.
                  onChanged: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
