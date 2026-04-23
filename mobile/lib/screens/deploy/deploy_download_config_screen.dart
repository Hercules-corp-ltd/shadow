import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DeployDownloadConfigScreen extends StatelessWidget {
  const DeployDownloadConfigScreen({super.key});

  static const _template = '''{
  "name": "my-shadow-site",
  "framework": "static",
  "build": {
    "command": null,
    "outputDir": "./"
  },
  "domain": "myname.shadow",
  "meta": {
    "title": "My Shadow site",
    "description": "Deployed on the Shadow decentralized web."
  }
}
''';

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'shadow.config.json',
      subtitle: 'Starter template for your project',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: SelectableText(_template, style: ShadowTypography.mono),
          ),
          const SizedBox(height: 20),
          ShadowButton(
            label: 'Copy to clipboard',
            leading: Icons.copy_rounded,
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: _template));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied starter config')),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Back',
            variant: ShadowButtonVariant.ghost,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
