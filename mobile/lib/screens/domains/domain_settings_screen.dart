import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/domains_provider.dart';
import '../../services/domain_service.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DomainSettingsScreen extends StatefulWidget {
  const DomainSettingsScreen({super.key, required this.domain});
  final String domain;

  @override
  State<DomainSettingsScreen> createState() => _DomainSettingsScreenState();
}

class _DomainSettingsScreenState extends State<DomainSettingsScreen> {
  final _service = DomainService();
  bool _verifying = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DomainsProvider>().active;

    return ShadowScaffold(
      title: 'Settings',
      subtitle: widget.domain,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verification', style: ShadowTypography.h4),
                const SizedBox(height: 6),
                Text(
                  d?.isVerified == true
                      ? 'Your domain is verified — trust score ${d?.trustScore ?? 0}.'
                      : 'Increase trust by verifying content ownership.',
                  style: ShadowTypography.bodySm,
                ),
                const SizedBox(height: 12),
                ShadowButton(
                  label: _verifying ? 'Verifying...' : 'Verify ownership',
                  isLoading: _verifying,
                  onPressed: _verifying ? null : _verify,
                ),
              ],
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: ShadowTypography.bodySm),
          ],
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Metadata', style: ShadowTypography.h4),
                const SizedBox(height: 6),
                Text(
                  d?.metadata.isEmpty == false
                      ? d!.metadata.toString()
                      : 'No metadata set yet.',
                  style: ShadowTypography.bodySm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    try {
      await _service.verify(widget.domain);
      setState(() => _message = 'Verification requested.');
    } catch (e) {
      setState(() => _message = 'Verification failed: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }
}
