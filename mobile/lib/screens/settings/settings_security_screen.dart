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
          const GlassCard(
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                // `requireUnlock` is written here and read nowhere. There is
                // no lifecycle observer in the app, and WalletProvider's
                // bootstrap sets WalletLifecycle.locked unconditionally
                // whenever a stored address exists — so the wallet always
                // locks at launch, and this switch could only ever disagree
                // with the behaviour it named. A switch that moves is a
                // promise.
                UnbuiltTile(
                  icon: Icons.lock_clock_rounded,
                  title: 'Require password each launch',
                  reason: 'Shadow already locks the wallet on every launch, '
                      'and there is no way to turn that off yet — so this '
                      'would only ever have been a switch that agreed with '
                      'itself.',
                ),
                Divider(height: 1, color: ShadowColors.border),
                UnbuiltTile(
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
