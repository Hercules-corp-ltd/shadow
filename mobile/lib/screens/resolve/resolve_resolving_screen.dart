import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../models/site.dart';
import '../../services/resolve_service.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_scaffold.dart';

class ResolveResolvingScreen extends StatefulWidget {
  const ResolveResolvingScreen({super.key, required this.blindId});
  final String blindId;

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
    Site? site;
    final id = widget.blindId;
    if (id.endsWith('.blind')) {
      site = await _service.resolveDomain(id);
    } else {
      site = await _service.resolveById(id);
    }
    if (!mounted) return;
    if (site == null || site.contentCid.isEmpty) {
      context.go('/resolve/failed?id=${Uri.encodeComponent(id)}');
    } else {
      context.go('/resolve/result?id=${Uri.encodeComponent(id)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlindScaffold(
      title: 'Resolving...',
      subtitle: widget.blindId,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: BlindColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(BlindColors.primary),
                ),
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(
                  duration: 1500.ms,
                  color: BlindColors.primary.withOpacity(0.25),
                ),
          ),
          const SizedBox(height: 32),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Looking up registry...', style: BlindTypography.body),
                const SizedBox(height: 8),
                Text('Fetching content pointer from Solana',
                    style: BlindTypography.caption),
                const SizedBox(height: 8),
                Text('Loading from decentralized storage',
                    style: BlindTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
