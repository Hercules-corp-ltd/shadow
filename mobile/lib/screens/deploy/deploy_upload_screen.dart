import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/deploy_project.dart';
import '../../providers/deploy_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DeployUploadScreen extends StatefulWidget {
  const DeployUploadScreen({super.key});

  @override
  State<DeployUploadScreen> createState() => _DeployUploadScreenState();
}

class _DeployUploadScreenState extends State<DeployUploadScreen> {
  bool _picking = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final picked = result.files
          .map((f) => DeployFile(
                path: f.name,
                sizeBytes: f.size,
                localPath: f.path,
              ))
          .toList();
      // Append, because the review screen's "Add more files" button pops back
      // here and DeployProvider.updateFiles is a full replace. Every file
      // already staged was being discarded the moment a second pick returned —
      // silent, with no warning and nothing to undo it with.
      //
      // Re-picking the same file replaces its entry rather than duplicating
      // it, so arriving here twice with the same selection is a no-op instead
      // of doubling the upload.
      final provider = context.read<DeployProvider>();
      final existing = provider.project?.files ?? const <DeployFile>[];
      final merged = <String, DeployFile>{
        for (final f in existing) f.path: f,
        for (final f in picked) f.path: f,
      };
      provider.updateFiles(merged.values.toList());
      if (!mounted) return;
      context.push('/deploy/files');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Upload files',
      subtitle: 'Select your site files to deploy',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(32),
            onTap: _picking ? null : _pick,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: ShadowColors.recessDeep,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ShadowColors.primary.withValues(alpha: 0.28),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: ShadowColors.primary.withValues(alpha: 0.14),
                        blurRadius: 28,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.file_upload_rounded,
                    size: 32,
                    color: ShadowColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tap to select files', style: ShadowTypography.h3),
                const SizedBox(height: 8),
                Text(
                  'HTML, CSS, JS, images, fonts, and any static assets',
                  style: ShadowTypography.bodySm,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: ShadowTypography.bodySm
                    .copyWith(color: ShadowColors.error)),
          ],
          const SizedBox(height: 20),
          ShadowButton(
            label: _picking ? 'Picking...' : 'Browse files',
            size: ShadowButtonSize.lg,
            leading: Icons.folder_open_rounded,
            isLoading: _picking,
            onPressed: _picking ? null : _pick,
          ),
        ],
      ),
    );
  }
}
