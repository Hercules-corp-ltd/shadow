import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../services/fetch_outcome.dart';
import '../../services/resolve_service.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_scaffold.dart';

class ResolveResolvingScreen extends StatefulWidget {
  const ResolveResolvingScreen({super.key, required this.shadowId});
  final String shadowId;

  @override
  State<ResolveResolvingScreen> createState() => _ResolveResolvingScreenState();
}

class _ResolveResolvingScreenState extends State<ResolveResolvingScreen> {
  final _service = ResolveService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final id = widget.shadowId;
    final outcome = id.endsWith('.shadow')
        ? await _service.resolveDomain(id)
        : await _service.resolveById(id);
    if (!mounted) return;

    final encoded = Uri.encodeComponent(id);
    switch (outcome) {
      case FetchSuccess(value: final site) when site.contentCid.isNotEmpty:
        context.go('/resolve/result?id=$encoded');
      case FetchSuccess():
        // Registered, but nothing is pinned behind it. That is a genuine
        // "no content" answer rather than a lookup failure.
        context.go('/resolve/failed?id=$encoded&reason=unpinned');
      case FetchNotFound():
        context.go('/resolve/failed?id=$encoded&reason=notfound');
      case FetchUnreachable(reason: final reason):
        context.go(
          '/resolve/failed?id=$encoded&reason=unreachable'
          '&detail=${Uri.encodeComponent(reason)}',
        );
    }
  }

  /// The shimmer is skipped under reduce-motion. It repeats forever, and the
  /// progress indicator inside it already says "working", so nothing is lost
  /// by dropping it.
  Widget _spinner(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final disc = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: ShadowColors.recessDeep,
        shape: BoxShape.circle,
        border: Border.all(
          color: ShadowColors.primary.withValues(alpha: 0.26),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ShadowColors.primary.withValues(alpha: 0.14),
            blurRadius: 34,
            spreadRadius: -6,
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(ShadowColors.primary),
        ),
      ),
    );

    if (still) return disc;
    return disc.animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1500.ms,
          color: ShadowColors.primary.withValues(alpha: 0.25),
        );
  }

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Resolving...',
      subtitle: widget.shadowId,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 32),
          Center(child: _spinner(context)),
          const SizedBox(height: 32),
          GlassCard(
            padding: const EdgeInsets.all(20),
            // There were three lines here, the first styled active and the
            // next two dimmed — an unmistakable three-step progress list.
            // Nothing ever changed them; this screen holds no stage state at
            // all. It was also wrong about the steps: _resolve() makes one
            // HTTP GET to the Shadow API and never speaks to Solana or to any
            // storage network. One line, and it is true.
            child: Text(
              'Asking the Shadow API where this name points…',
              style: ShadowTypography.body,
            ),
          ),
        ],
      ),
    );
  }
}
