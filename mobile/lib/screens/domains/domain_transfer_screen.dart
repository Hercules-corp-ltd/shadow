import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/domains_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DomainTransferScreen extends StatefulWidget {
  const DomainTransferScreen({super.key, required this.domain});
  final String domain;

  @override
  State<DomainTransferScreen> createState() => _DomainTransferScreenState();
}

class _DomainTransferScreenState extends State<DomainTransferScreen> {
  final _addressCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Transfer ownership',
      subtitle: widget.domain,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            color: Colors.red.withValues(alpha: 0.06),
            border: Border.all(
                color: ShadowColors.error.withValues(alpha: 0.4), width: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: ShadowColors.warning),
                    const SizedBox(width: 8),
                    Text('This action is irreversible',
                        style: ShadowTypography.h4),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Once transferred, only the new wallet can manage this domain. Make sure you\'ve double-checked the address.',
                  style: ShadowTypography.bodySm,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New owner (Solana address)',
                    style: ShadowTypography.h4),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Public key (base58)',
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: ShadowTypography.bodySm
                    .copyWith(color: ShadowColors.error)),
          ],
          const SizedBox(height: 20),
          ShadowButton(
            label: _submitting ? 'Transferring...' : 'Transfer ownership',
            size: ShadowButtonSize.lg,
            variant: ShadowButtonVariant.danger,
            isLoading: _submitting,
            onPressed: _submitting || _addressCtrl.text.trim().isEmpty
                ? null
                : _transfer,
          ),
        ],
      ),
    );
  }

  Future<void> _transfer() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context
          .read<DomainsProvider>()
          .transfer(widget.domain, _addressCtrl.text.trim());
      if (!mounted) return;
      context.go('/domains');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
