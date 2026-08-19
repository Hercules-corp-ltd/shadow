import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/deploy_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DeployFilesAddedScreen extends StatelessWidget {
  const DeployFilesAddedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeployProvider>();
    final project = provider.project;
    final files = project?.files ?? const [];
    final total = files.fold<int>(0, (a, b) => a + b.sizeBytes);

    return ShadowScaffold(
      title: 'Review Files',
      subtitle: '${files.length} files · ${_fmtBytes(total)}',
      body: Column(
        children: [
          Expanded(
            child: files.isEmpty
                ? const EmptyState(
                    icon: Icons.folder_open_rounded,
                    title: 'No files yet',
                    message:
                        'Go back and pick the files you want to publish — '
                        'the built output of your site, not its source.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemBuilder: (_, i) {
                      final f = files[i];
                      // The same row every other list in the app is made of,
                      // rather than a hand-rolled copy of it that would drift
                      // the next time ListItemCard changed.
                      return ListItemCard(
                        title: f.path,
                        subtitle: _fmtBytes(f.sizeBytes),
                        leadingIcon: Icons.insert_drive_file_rounded,
                        leadingColor: ShadowColors.textSecondary,
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: ShadowColors.textTertiary),
                          tooltip: 'Remove from this deployment',
                          onPressed: () {
                            final updated = [...files]..removeAt(i);
                            context
                                .read<DeployProvider>()
                                .updateFiles(updated);
                          },
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemCount: files.length,
                  ),
          ),
          const SizedBox(height: 12),
          ShadowButton(
            label: 'Deploy to Shadow',
            size: ShadowButtonSize.lg,
            trailing: Icons.rocket_launch_rounded,
            onPressed: files.isEmpty
                ? null
                : () => context.push('/deploy/progress'),
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Add more files',
            variant: ShadowButtonVariant.ghost,
            leading: Icons.add_rounded,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }

  static String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
