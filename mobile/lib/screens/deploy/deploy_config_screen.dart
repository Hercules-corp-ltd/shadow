import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/deploy_project.dart';
import '../../providers/deploy_provider.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DeployConfigScreen extends StatefulWidget {
  const DeployConfigScreen({super.key});

  @override
  State<DeployConfigScreen> createState() => _DeployConfigScreenState();
}

class _DeployConfigScreenState extends State<DeployConfigScreen> {
  final _nameCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();
  ProjectFramework _framework = ProjectFramework.static_;

  @override
  void initState() {
    super.initState();
    final p = context.read<DeployProvider>().project;
    if (p != null) {
      _nameCtrl.text = p.name;
      _domainCtrl.text = p.domain ?? '';
      _framework = p.framework;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _domainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Configure Project',
      subtitle: 'Set basic details before upload',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Project name', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'My awesome site',
                  ),
                ),
                const SizedBox(height: 20),
                Text('Shadow domain (optional)', style: ShadowTypography.h4),
                const SizedBox(height: 6),
                Text(
                  'Leave blank to deploy with a generated ID first.',
                  style: ShadowTypography.caption,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _domainCtrl,
                  decoration: const InputDecoration(
                    hintText: 'myname.shadow',
                  ),
                ),
                const SizedBox(height: 20),
                Text('Framework', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in ProjectFramework.values)
                      ChoiceChip(
                        label: Text(_label(f)),
                        selected: _framework == f,
                        onSelected: (_) => setState(() => _framework = f),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ShadowButton(
            label: 'Continue',
            size: ShadowButtonSize.lg,
            trailing: Icons.arrow_forward_rounded,
            onPressed: _nameCtrl.text.trim().isEmpty
                ? null
                : () {
                    final p = context.read<DeployProvider>();
                    p.setProject(p.project!.copyWith(
                      name: _nameCtrl.text.trim(),
                      domain: _domainCtrl.text.trim().isEmpty
                          ? null
                          : _domainCtrl.text.trim(),
                      framework: _framework,
                    ));
                    context.push('/deploy/choose');
                  },
          ),
        ],
      ),
    );
  }

  static String _label(ProjectFramework f) => switch (f) {
        ProjectFramework.static_ => 'Static',
        ProjectFramework.react => 'React',
        ProjectFramework.vue => 'Vue',
        ProjectFramework.angular => 'Angular',
        ProjectFramework.next => 'Next.js',
        ProjectFramework.nuxt => 'Nuxt',
        ProjectFramework.svelte => 'Svelte',
      };
}
