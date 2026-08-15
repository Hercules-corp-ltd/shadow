import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/bookmarks_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class BookmarksClearScreen extends StatelessWidget {
  const BookmarksClearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlindScaffold(
      title: 'Clear Bookmarks',
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
                const Icon(Icons.warning_amber_rounded,
                    size: 48, color: BlindColors.error),
                const SizedBox(height: 16),
                Text('Remove all bookmarks?',
                    style: BlindTypography.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'This will permanently remove every saved bookmark across all folders. This action cannot be undone.',
                  style: BlindTypography.bodySm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BlindButton(
            label: 'Remove all bookmarks',
            variant: BlindButtonVariant.danger,
            size: BlindButtonSize.lg,
            onPressed: () async {
              await context.read<BookmarksProvider>().clearAll();
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
