import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/downloads_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DownloadsClearScreen extends StatelessWidget {
  const DownloadsClearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Clear Downloads',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            color: Colors.red.withValues(alpha: 0.08),
            border:
                Border.all(color: ShadowColors.error.withValues(alpha: 0.4), width: 1),
            child: Column(
              children: [
                const Icon(Icons.delete_sweep_rounded,
                    size: 48, color: ShadowColors.error),
                const SizedBox(height: 16),
                Text('Remove all download records?',
                    style: ShadowTypography.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Clears the list of downloaded files. Files already saved to your device are NOT deleted.',
                  style: ShadowTypography.bodySm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ShadowButton(
            label: 'Clear download history',
            variant: ShadowButtonVariant.danger,
            size: ShadowButtonSize.lg,
            onPressed: () async {
              await context.read<DownloadsProvider>().clearAll();
              if (!context.mounted) return;
              context.pop();
            },
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Cancel',
            variant: ShadowButtonVariant.ghost,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
