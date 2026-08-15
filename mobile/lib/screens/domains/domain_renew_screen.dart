import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/domains_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DomainRenewScreen extends StatefulWidget {
  const DomainRenewScreen({super.key, required this.domain});
  final String domain;

  @override
  State<DomainRenewScreen> createState() => _DomainRenewScreenState();
}

class _DomainRenewScreenState extends State<DomainRenewScreen> {
  int _years = 1;
  bool _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Renew Domain',
      subtitle: widget.domain,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Extend by', style: ShadowTypography.h4),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final y in const [1, 2, 3, 5, 10])
                      ChoiceChip(
                        label: Text('$y ${y == 1 ? 'year' : 'years'}'),
                        selected: _years == y,
                        onSelected: (_) => setState(() => _years = y),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: ShadowTypography.bodySm
                  .copyWith(color: ShadowColors.error),
            ),
          ],
          const SizedBox(height: 16),
          ShadowButton(
            label: _submitting ? 'Renewing...' : 'Renew for $_years year(s)',
            size: ShadowButtonSize.lg,
            isLoading: _submitting,
            onPressed: _submitting ? null : _renew,
          ),
        ],
      ),
    );
  }

  Future<void> _renew() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context
          .read<DomainsProvider>()
          .renew(widget.domain, years: _years);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renewed ${widget.domain} for $_years year(s)')),
      );
      context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
