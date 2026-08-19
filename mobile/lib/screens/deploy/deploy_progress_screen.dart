import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../../models/deploy_project.dart';
import '../../providers/deploy_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DeployProgressScreen extends StatefulWidget {
  const DeployProgressScreen({super.key});

  @override
  State<DeployProgressScreen> createState() => _DeployProgressScreenState();
}

class _DeployProgressScreenState extends State<DeployProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final provider = context.read<DeployProvider>();
    await provider.upload((f) async {
      if (f.localPath == null) {
        throw StateError('File "${f.path}" has no local path.');
      }
      return Uint8List.fromList(await File(f.localPath!).readAsBytes());
    });
    if (!mounted) return;
    if (provider.project?.status == DeployStatus.uploaded) {
      await provider.deploy();
    }
    if (!mounted) return;
    if (provider.project?.status == DeployStatus.deployed) {
      context.go('/deploy/deployed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeployProvider>();
    final project = provider.project;
    final status = project?.status ?? DeployStatus.idle;

    final steps = <_StepData>[
      _StepData(
        label: 'Uploading to decentralized storage',
        done: status == DeployStatus.uploaded ||
            status == DeployStatus.deploying ||
            status == DeployStatus.deployed,
        active: status == DeployStatus.uploading,
        progress: provider.uploadProgress,
      ),
      _StepData(
        label: 'Registering on Solana',
        done: status == DeployStatus.deployed,
        active: status == DeployStatus.deploying,
      ),
      // There used to be a third step here, "Publishing to Shadow network".
      // Nothing ran it: it could never be `active`, and it ticked itself off
      // the moment the on-chain registration finished. It was a progress bar
      // for work that does not exist, which is the one thing a progress list
      // must never contain — a user watching it would believe a step
      // completed that was never attempted.
    ];

    // The title was the constant 'Deploying...', so after a failure the
    // header asserted work was ongoing above a body that said it had stopped.
    // And with no project at all — a deep link here, or a restart after the
    // provider reset — upload() returns immediately without touching status,
    // so the screen sat on 'Deploying...' for ever with nothing running.
    final title = switch (status) {
      DeployStatus.failed => 'Deployment failed',
      DeployStatus.deployed => 'Deployed',
      _ when project == null => 'Nothing to deploy',
      _ => 'Deploying…',
    };

    if (project == null) {
      return ShadowScaffold(
        title: title,
        body: EmptyState(
          icon: Icons.cloud_off_rounded,
          tone: EmptyStateTone.error,
          title: 'No deployment in progress',
          message: 'This screen runs a deployment that was set up on the '
              'screens before it, and there is none in this session.',
          actionLabel: 'Start one',
          onAction: () => context.go('/deploy'),
        ),
      );
    }

    return ShadowScaffold(
      title: title,
      subtitle: project.name,
      showBack: status == DeployStatus.failed,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in steps) ...[
                  Row(
                    children: [
                      _StepIcon(step: s),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.label, style: ShadowTypography.body),
                      ),
                    ],
                  ),
                  if (s.active && s.progress != null) ...[
                    const SizedBox(height: 8),
                    LinearPercentIndicator(
                      percent: s.progress!.clamp(0, 1),
                      backgroundColor: ShadowColors.recess,
                      progressColor: ShadowColors.primary,
                      animation: true,
                      lineHeight: 4,
                      padding: EdgeInsets.zero,
                      barRadius: const Radius.circular(4),
                    ),
                  ],
                  if (s != steps.last) const SizedBox(height: 20),
                ],
              ],
            ),
          ),
          if (status == DeployStatus.failed && provider.error != null) ...[
            const SizedBox(height: 20),
            GlassCard.lit(
              accent: ShadowColors.error,
              padding: const EdgeInsets.all(16),
              child: Text(
                provider.error!,
                style:
                    ShadowTypography.body.copyWith(color: ShadowColors.error),
              ),
            ),
            const SizedBox(height: 16),
            ShadowButton(
              label: 'Retry',
              onPressed: _run,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepData {
  _StepData({
    required this.label,
    required this.done,
    required this.active,
    this.progress,
  });

  final String label;
  final bool done;
  final bool active;
  final double? progress;
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.step});
  final _StepData step;

  @override
  Widget build(BuildContext context) {
    if (step.done) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: ShadowColors.recessDeep,
          shape: BoxShape.circle,
          border: Border.all(
            color: ShadowColors.success.withValues(alpha: 0.55),
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.check_rounded,
            size: 14, color: ShadowColors.success),
      );
    }
    if (step.active) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(ShadowColors.primary),
        ),
      );
    }
    // Not yet started: an empty socket, so the three states read as one
    // control filling with light rather than three unrelated shapes.
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: ShadowColors.recessDeep,
        shape: BoxShape.circle,
        border: Border.all(color: ShadowColors.edgeFaint),
      ),
    );
  }
}
