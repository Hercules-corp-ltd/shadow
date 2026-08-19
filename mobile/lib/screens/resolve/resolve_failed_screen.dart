import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

/// Why a resolution did not produce content.
///
/// The distinction is the whole point of this screen. Previously every
/// failure — a dead server, a 401, a timeout — was reported as "this
/// identifier is not registered", which sends the user off to check their
/// spelling when the actual problem is that nothing was reachable.
enum ResolveFailure {
  /// The server answered: no such site.
  notFound,

  /// The site is registered, but no content is pinned behind it.
  unpinned,

  /// Nothing could be established either way.
  unreachable;

  static ResolveFailure parse(String? raw) => switch (raw) {
        'notfound' => ResolveFailure.notFound,
        'unpinned' => ResolveFailure.unpinned,
        _ => ResolveFailure.unreachable,
      };
}

class ResolveFailedScreen extends StatelessWidget {
  const ResolveFailedScreen({
    super.key,
    required this.shadowId,
    this.reason = ResolveFailure.unreachable,
    this.detail,
  });

  final String shadowId;
  final ResolveFailure reason;

  /// Extra context for [ResolveFailure.unreachable] — the network-level cause.
  final String? detail;

  String get _headline => switch (reason) {
        ResolveFailure.notFound => 'Nothing is registered here',
        ResolveFailure.unpinned => 'Registered, but nothing is pinned',
        ResolveFailure.unreachable => 'Could not check this identifier',
      };

  String get _explanation => switch (reason) {
        ResolveFailure.notFound =>
          'The network answered, and there is no site registered as '
              '"$shadowId".',
        ResolveFailure.unpinned =>
          '"$shadowId" is registered, but its content is not currently '
              'available. The owner may need to re-pin it.',
        ResolveFailure.unreachable =>
          'Shadow could not reach the network, so it does not know whether '
              '"$shadowId" exists. This is not the same as the name being '
              'unregistered.',
      };

  List<String> get _suggestions => switch (reason) {
        ResolveFailure.notFound => const [
            'Check for typos in the domain or CID',
            'Confirm you are on the right network — a name registered on '
                'devnet will not resolve on mainnet',
          ],
        ResolveFailure.unpinned => const [
            'Ask the owner to re-pin the content',
            'The content may still be propagating — try again shortly',
          ],
        ResolveFailure.unreachable => const [
            'Check your internet connection',
            'Confirm the API address in Settings points somewhere reachable',
            'The Shadow backend may not be running',
          ],
      };

  @override
  Widget build(BuildContext context) {
    final isUnreachable = reason == ResolveFailure.unreachable;
    final tone = isUnreachable ? ShadowColors.warning : ShadowColors.error;

    return ShadowScaffold(
      title: 'Resolution failed',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUnreachable
                    ? Icons.cloud_off_rounded
                    : Icons.search_off_rounded,
                size: 56,
                color: tone,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(_headline,
              style: ShadowTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            _explanation,
            style: ShadowTypography.bodySm,
            textAlign: TextAlign.center,
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              detail!,
              style: ShadowTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Things to try', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                for (final suggestion in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child:
                        Text('- $suggestion', style: ShadowTypography.bodySm),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ShadowButton(
            label: 'Try again',
            leading: Icons.refresh_rounded,
            onPressed: () => context.go(
              '/resolve/resolving?id=${Uri.encodeComponent(shadowId)}',
            ),
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Back',
            variant: ShadowButtonVariant.ghost,
            onPressed: () => context.go('/resolve'),
          ),
        ],
      ),
    );
  }
}
