import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class DeployDownloadConfigScreen extends StatelessWidget {
  const DeployDownloadConfigScreen({super.key});

  static const _template = '''{
  "name": "my-blind-site",
  "framework": "static",
  "build": {
    "command": null,
    "outputDir": "./"
  },
  "domain": "myname.blind",
  "meta": {
    "title": "My Blind site",
    "description": "Deployed on the Blind decentralized web."
  }
}
''';

  @override
  Widget build(BuildContext context) {
    return BlindScaffold(
      title: 'blind.config.json',
      subtitle: 'Starter template for your project',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: SelectableText(_template, style: BlindTypography.mono),
          ),
          const SizedBox(height: 20),
          BlindButton(
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
          BlindButton(
            label: 'Back',
            variant: BlindButtonVariant.ghost,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
