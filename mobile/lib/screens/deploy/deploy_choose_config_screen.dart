import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/shadow_colors.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';
import '../../widgets/unbuilt_tile.dart';

class DeployChooseConfigScreen extends StatelessWidget {
  const DeployChooseConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Upload Method',
      subtitle: 'How would you like to add your site?',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListItemCard(
            title: 'Upload files from this device',
            subtitle: 'Pick HTML / build files from local storage',
            leadingIcon: Icons.file_upload_rounded,
            leadingColor: ShadowColors.tileBlue,
            onTap: () => context.push('/deploy/upload'),
          ),
          const SizedBox(height: 8),
          // Not built, and it has to look it. With onTap: null this row was
          // inert but rendered identically to the two live ones either side —
          // same fill, same coloured glyph, and still a chevron promising it
          // went somewhere. UnbuiltTile is the house answer for this.
          const UnbuiltTile(
            title: 'Import from a public repository',
            reason: 'Cloning a repository needs a build step Shadow does not '
                'run yet. Build your site locally and upload the output.',
            icon: Icons.source_rounded,
          ),
          const SizedBox(height: 8),
          // Was "Download a starter config" / "shadow.config.json template +
          // docs". Neither is true at the destination: the screen offers a
          // copy button and no download, and there are no docs. Nothing in
          // the repo reads shadow.config.json either, so it is a shape to
          // copy, not a file the deployer consumes — and the row now says so.
          ListItemCard(
            title: 'Copy a starter config',
            subtitle: 'A shadow.config.json shape to keep in your project',
            leadingIcon: Icons.description_rounded,
            leadingColor: ShadowColors.tileAmber,
            onTap: () => context.push('/deploy/download'),
          ),
          const SizedBox(height: 24),
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
