import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/deploy_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DeployDeployedScreen extends StatelessWidget {
  const DeployDeployedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final project = context.watch<DeployProvider>().project;
    final domain = project?.domain ?? '${project?.id ?? ''}.shadow';
    final cid = project?.contentCid;

    return ShadowScaffold(
      title: 'Deployed!',
      subtitle: 'Your site is live on Shadow',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: ShadowColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ShadowColors.primary.withValues(alpha: 0.4),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 64),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          ),
          const SizedBox(height: 32),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shadow domain', style: ShadowTypography.caption),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        domain,
                        style: ShadowTypography.h3,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded,
                          color: ShadowColors.textSecondary),
                      onPressed: () => _copy(context, domain),
                    ),
                  ],
                ),
                if (cid != null) ...[
                  const Divider(height: 24, color: ShadowColors.border),
                  Text('Content CID', style: ShadowTypography.caption),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(cid,
                            style: ShadowTypography.mono, maxLines: 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            color: ShadowColors.textSecondary),
                        onPressed: () => _copy(context, cid),
                      ),
                    ],
                  ),
                ],
                if (project?.programAddress != null) ...[
                  const Divider(height: 24, color: ShadowColors.border),
                  Text('Registry account', style: ShadowTypography.caption),
                  const SizedBox(height: 4),
                  SelectableText(
                    project!.programAddress!,
                    style: ShadowTypography.mono,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          ShadowButton(
            label: 'Open site',
            size: ShadowButtonSize.lg,
            leading: Icons.open_in_new_rounded,
            onPressed: () => context
                .push('/resolve/resolving?id=${Uri.encodeComponent(domain)}'),
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Back to home',
            variant: ShadowButtonVariant.ghost,
            onPressed: () {
              context.read<DeployProvider>().reset();
              context.go('/home');
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied: $text')),
      );
    }
  }
}
