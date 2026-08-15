import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/deploy_project.dart';
import '../../providers/deploy_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class DeploySelectProjectScreen extends StatelessWidget {
  const DeploySelectProjectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlindScaffold(
      title: 'Deploy Website',
      subtitle: 'Publish your site to the decentralized web',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _HeroCard(onStart: () {
            _startNew(context);
            context.push('/deploy/config');
          }),
          const SizedBox(height: 24),
          Text('What would you like to deploy?', style: BlindTypography.h3),
          const SizedBox(height: 12),
          ListItemCard(
            title: 'Static Site',
            subtitle: 'HTML, CSS & JS files',
            leadingIcon: Icons.web_rounded,
            leadingColor: BlindColors.tileBlue,
            onTap: () => _choose(context, ProjectFramework.static_),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'React / Next.js',
            subtitle: 'Compiled build output',
            leadingIcon: Icons.code_rounded,
            leadingColor: BlindColors.tileCyan,
            onTap: () => _choose(context, ProjectFramework.next),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'Vue / Nuxt',
            subtitle: 'Compiled build output',
            leadingIcon: Icons.rocket_launch_rounded,
            leadingColor: BlindColors.tileGreen,
            onTap: () => _choose(context, ProjectFramework.nuxt),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'SvelteKit',
            subtitle: 'Compiled build output',
            leadingIcon: Icons.bolt_rounded,
            leadingColor: BlindColors.tileOrange,
            onTap: () => _choose(context, ProjectFramework.svelte),
          ),
        ],
      ),
    );
  }

  void _startNew(BuildContext context) {
    final project = DeployProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '',
      framework: ProjectFramework.static_,
      createdAt: DateTime.now(),
    );
    context.read<DeployProvider>().setProject(project);
  }

  void _choose(BuildContext context, ProjectFramework framework) {
    final project = DeployProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '',
      framework: framework,
      createdAt: DateTime.now(),
    );
    context.read<DeployProvider>().setProject(project);
    context.push('/deploy/config');
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      gradient: BlindColors.navyGradient,
      border: Border.all(color: BlindColors.cardNavyBorder, width: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: BlindColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cloud_upload_rounded,
                color: BlindColors.primary, size: 24),
          ),
          const SizedBox(height: 16),
          Text('Go Web3 in minutes', style: BlindTypography.h2),
          const SizedBox(height: 6),
          Text(
            'Upload your website, we handle storage, pinning, and on-chain registration.',
            style: BlindTypography.body.copyWith(
              color: BlindColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          BlindButton(
            label: 'Start new deployment',
            leading: Icons.add_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}
