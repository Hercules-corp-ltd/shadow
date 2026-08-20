import 'package:flutter/material.dart';

import '../../theme/shadow_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/unbuilt_tile.dart';
import '../../widgets/shadow_scaffold.dart';

class SettingsGeneralScreen extends StatelessWidget {
  const SettingsGeneralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'General',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: const [
          GlassCard(
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                // Every control on this screen wrote a field that nothing
                // read. There is no analytics client, no crash reporter and no
                // updater anywhere in the app, so all three subtitles
                // described capabilities that do not exist — and "help improve
                // Shadow by sharing anonymous usage data" invited a user to
                // opt into something that could not happen either way.
                UnbuiltTile(
                  icon: Icons.insights_rounded,
                  title: 'Anonymous analytics',
                  reason: 'Shadow has no analytics client and sends nothing, '
                      'so there is nothing here to turn on or off.',
                ),
                Divider(height: 1, color: ShadowColors.edge),
                UnbuiltTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Crash telemetry',
                  reason: 'No crash reporter ships with Shadow, so no report '
                      'has ever left this device.',
                ),
                Divider(height: 1, color: ShadowColors.edge),
                UnbuiltTile(
                  icon: Icons.system_update_alt_rounded,
                  title: 'Automatic updates',
                  reason: 'Shadow has no updater — new versions arrive the '
                      'same way this one was installed.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
