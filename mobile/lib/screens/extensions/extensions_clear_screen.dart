import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/extensions_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class ExtensionsClearScreen extends StatelessWidget {
  const ExtensionsClearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Uninstall Extensions',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            color: Colors.red.withValues(alpha: 0.08),
            border: Border.all(
                color: ShadowColors.error.withValues(alpha: 0.4), width: 1),
            child: Column(
              children: [
                const Icon(Icons.layers_clear_rounded,
                    size: 48, color: ShadowColors.error),
                const SizedBox(height: 16),
                Text('Remove all extensions?',
                    style: ShadowTypography.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'All installed extensions and their data will be uninstalled. You can reinstall them anytime from the directory.',
                  style: ShadowTypography.bodySm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ShadowButton(
            label: 'Uninstall all',
            variant: ShadowButtonVariant.danger,
            size: ShadowButtonSize.lg,
            onPressed: () async {
              await context.read<ExtensionsProvider>().clearAll();
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
