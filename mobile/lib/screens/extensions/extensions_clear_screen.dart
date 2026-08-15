import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/extensions_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class ExtensionsClearScreen extends StatelessWidget {
  const ExtensionsClearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlindScaffold(
      title: 'Uninstall Extensions',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            color: Colors.red.withOpacity(0.08),
            border:
                Border.all(color: BlindColors.error.withOpacity(0.4), width: 1),
            child: Column(
              children: [
                const Icon(Icons.layers_clear_rounded,
                    size: 48, color: BlindColors.error),
                const SizedBox(height: 16),
                Text('Remove all extensions?',
                    style: BlindTypography.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'All installed extensions and their data will be uninstalled. You can reinstall them anytime from the directory.',
                  style: BlindTypography.bodySm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BlindButton(
            label: 'Uninstall all',
            variant: BlindButtonVariant.danger,
            size: BlindButtonSize.lg,
            onPressed: () async {
              await context.read<ExtensionsProvider>().clearAll();
              if (!context.mounted) return;
              context.pop();
            },
          ),
          const SizedBox(height: 8),
          BlindButton(
            label: 'Cancel',
            variant: BlindButtonVariant.ghost,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
