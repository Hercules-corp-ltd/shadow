import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/domains_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../services/fetch_outcome.dart';
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
          GlassCard.lit(
            accent: ShadowColors.error,
            padding: const EdgeInsets.all(20),
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
                Text('New owner (Solana address)', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressCtrl,
                  autocorrect: false,
                  // The Transfer button is gated on this being non-empty, and
                  // this screen has no other setState outside _transfer
                  // itself — so without this the button could never enable
                  // and the screen was entirely inert.
                  onChanged: (_) => setState(() {}),
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
      // DioException.toString() is a multi-line debug dump that carries
      // the backend URI in it, rendered straight into the page.
      // describeDioFailure is the house translation and already exists.
      setState(() => _error = e is DioException
          ? describeDioFailure(e)
          : 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
