import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/blind_colors.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class DeployChooseConfigScreen extends StatelessWidget {
  const DeployChooseConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlindScaffold(
      title: 'Upload Method',
      subtitle: 'How would you like to add your site?',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListItemCard(
            title: 'Upload files from this device',
            subtitle: 'Pick HTML / build files from local storage',
            leadingIcon: Icons.file_upload_rounded,
            leadingColor: BlindColors.tileBlue,
            onTap: () => context.push('/deploy/upload'),
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'Import from a public repository',
            subtitle: 'Clone a GitHub / GitLab repository (coming soon)',
            leadingIcon: Icons.source_rounded,
            leadingColor: BlindColors.tilePurple,
            onTap: null,
          ),
          const SizedBox(height: 8),
          ListItemCard(
            title: 'Download a starter config',
            subtitle: 'blind.config.json template + docs',
            leadingIcon: Icons.description_rounded,
            leadingColor: BlindColors.tileAmber,
            onTap: () => context.push('/deploy/download'),
          ),
          const SizedBox(height: 24),
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
