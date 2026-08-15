import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/deploy_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
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
                ? Center(
                    child: Text(
                      'No files added yet',
                      style: ShadowTypography.bodySm,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemBuilder: (_, i) {
                      final f = files[i];
                      return GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file_rounded,
                                color: ShadowColors.textSecondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.path,
                                      style: ShadowTypography.body,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(_fmtBytes(f.sizeBytes),
                                      style: ShadowTypography.caption),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: ShadowColors.textTertiary),
                              onPressed: () {
                                final updated = [...files]..removeAt(i);
                                context
                                    .read<DeployProvider>()
                                    .updateFiles(updated);
                              },
                            ),
                          ],
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
