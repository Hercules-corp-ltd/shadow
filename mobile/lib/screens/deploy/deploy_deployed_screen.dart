import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/deploy_project.dart';
import '../../providers/deploy_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DeployDeployedScreen extends StatelessWidget {
  const DeployDeployedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeployProvider>();
    final project = provider.project;

    // Nothing here used to check that a deployment had happened. With a null
    // project the screen still announced "Deployed! Your site is live on
    // Shadow", and showBack: false removed the way out. That is reachable
    // today: "Back to home" below calls reset() — which nulls the project and
    // notifies — before the route changes, and this is a watch, so the success
    // page rebuilds empty while it is still painting its exit.
    if (project == null || project.status != DeployStatus.deployed) {
      return ShadowScaffold(
        title: 'Deployment',
        body: EmptyState(
          icon: Icons.cloud_off_rounded,
          tone: EmptyStateTone.error,
          title: 'Nothing to show here',
          message: 'This screen reports the result of a deployment, and there '
              'is no finished deployment in this session.',
          actionLabel: 'Back to home',
          onAction: () => context.go('/home'),
        ),
      );
    }

    // The domain used to fall back to "${project.id}.shadow". project.id is a
    // millisecond timestamp handed out by the *previous* screen, and nothing
    // client- or server-side ever allocates that name — the config screen even
    // invites a blank domain. So the success page printed an address that does
    // not exist, under the heading "Shadow domain", with a copy button and an
    // "Open site" link pointed at it. A user would copy it and hand it out.
    final domain = project.domain;
    final cid = project.contentCid;

    return ShadowScaffold(
      title: 'Deployed!',
      subtitle: domain == null
          ? 'Published, and not yet named'
          : 'Your site is live on Shadow',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Center(
            // The elastic overshoot here is exactly the motion class the
            // reduce-motion switch exists to stop, and it could not be turned
            // off. It is skipped, not shortened: a success mark does not need
            // to bounce to be understood.
            child: _mark(
                context,
                Container(
                  width: 120,
                  height: 120,
                  // Success, and it is allowed to be bright - but as a light in
                  // a socket, like every other disc in the app, not a filled
                  // orange coin.
                  decoration: BoxDecoration(
                    color: ShadowColors.recessDeep,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ShadowColors.primary.withValues(alpha: 0.40),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ShadowColors.primary.withValues(alpha: 0.28),
                        blurRadius: 48,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: ShadowColors.primary, size: 64),
                )),
          ),
          const SizedBox(height: 32),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (domain != null) ...[
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
                        tooltip: 'Copy domain',
                        onPressed: () => _copy(context, domain),
                      ),
                    ],
                  ),
                ] else ...[
                  Text('No domain yet', style: ShadowTypography.caption),
                  const SizedBox(height: 4),
                  Text(
                    'This deployment went out without a name. The content '
                    'address below is how to reach it until you register one.',
                    style: ShadowTypography.bodySm,
                  ),
                ],
                if (cid != null) ...[
                  const Divider(height: 24, color: ShadowColors.edge),
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
                if (project.programAddress != null) ...[
                  const Divider(height: 24, color: ShadowColors.edge),
                  Text('Registry account', style: ShadowTypography.caption),
                  const SizedBox(height: 4),
                  SelectableText(
                    project.programAddress!,
                    style: ShadowTypography.mono,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Only offered when there is something to open. It used to resolve
          // the invented name, so the primary action on the success screen was
          // guaranteed to fail.
          ShadowButton(
            label: 'Open site',
            size: ShadowButtonSize.lg,
            leading: Icons.open_in_new_rounded,
            onPressed: domain == null
                ? null
                : () => context.push(
                      '/resolve/resolving?id=${Uri.encodeComponent(domain)}',
                    ),
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

  /// Skipped outright under reduce-motion rather than shortened: a success
  /// mark does not need to bounce to be understood, and an elastic overshoot
  /// is exactly the motion class that switch exists to stop.
  static Widget _mark(BuildContext context, Widget child) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) return child;
    return child.animate().scale(
          duration: 400.ms,
          curve: Curves.elasticOut,
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
