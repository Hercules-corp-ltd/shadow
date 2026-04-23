import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../../models/download.dart';
import '../../providers/downloads_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_scaffold.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<DownloadsProvider>().load());
  }

  IconData _iconFor(DownloadType t) => switch (t) {
        DownloadType.image => Icons.image_rounded,
        DownloadType.video => Icons.play_circle_rounded,
        DownloadType.audio => Icons.music_note_rounded,
        DownloadType.code => Icons.code_rounded,
        DownloadType.archive => Icons.folder_zip_rounded,
        DownloadType.document => Icons.description_rounded,
        DownloadType.other => Icons.insert_drive_file_rounded,
      };

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DownloadsProvider>();

    return ShadowScaffold(
      title: 'Downloads',
      subtitle: '${p.items.length} items',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: ShadowColors.error),
          onPressed: p.items.isEmpty
              ? null
              : () => context.push('/downloads/clear'),
        ),
      ],
      body: p.isLoading && p.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : p.items.isEmpty
              ? EmptyState(
                  icon: Icons.download_rounded,
                  title: 'No downloads yet',
                  message:
                      'Files you download from Shadow sites will appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemBuilder: (_, i) {
                    final d = p.items[i];
                    return GlassCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () {},
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  ShadowColors.primary.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_iconFor(d.type),
                                color: ShadowColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.fileName,
                                    style: ShadowTypography.h4,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(
                                  '${_fmtSize(d.sizeBytes)} · ${d.sourceDomain} · ${DateFormat.Md().format(d.startedAt)}',
                                  style: ShadowTypography.bodySm,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (d.status == DownloadStatus.downloading) ...[
                                  const SizedBox(height: 8),
                                  LinearPercentIndicator(
                                    percent: d.progress.clamp(0, 1),
                                    backgroundColor: ShadowColors.border,
                                    progressColor: ShadowColors.primary,
                                    animation: true,
                                    lineHeight: 4,
                                    padding: EdgeInsets.zero,
                                    barRadius: const Radius.circular(4),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              d.status == DownloadStatus.downloading
                                  ? Icons.pause_circle_rounded
                                  : d.status == DownloadStatus.paused
                                      ? Icons.play_circle_rounded
                                      : Icons.more_vert_rounded,
                              color: ShadowColors.textSecondary,
                            ),
                            onPressed: () {
                              final provider =
                                  context.read<DownloadsProvider>();
                              if (d.status == DownloadStatus.downloading) {
                                provider.pause(d.id);
                              } else if (d.status == DownloadStatus.paused) {
                                provider.resume(d.id);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: p.items.length,
                ),
    );
  }
}
