import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/bookmarks_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class BookmarksClearScreen extends StatelessWidget {
  const BookmarksClearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Clear Bookmarks',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            color: Colors.red.withOpacity(0.08),
            border:
                Border.all(color: ShadowColors.error.withOpacity(0.4), width: 1),
            child: Column(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 48, color: ShadowColors.error),
                const SizedBox(height: 16),
                Text('Remove all bookmarks?',
                    style: ShadowTypography.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'This will permanently remove every saved bookmark across all folders. This action cannot be undone.',
                  style: ShadowTypography.bodySm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ShadowButton(
            label: 'Remove all bookmarks',
            variant: ShadowButtonVariant.danger,
            size: ShadowButtonSize.lg,
            onPressed: () async {
              await context.read<BookmarksProvider>().clearAll();
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
