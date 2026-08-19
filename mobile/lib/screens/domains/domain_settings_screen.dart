import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/domains_provider.dart';
import '../../services/domain_service.dart';
import '../../theme/shadow_colors.dart';
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
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // This screen never loaded anything: it read whatever domain the provider
    // happened to be holding, and nothing checked that it was the domain the
    // screen is titled for. Arriving here directly — a deep link, or Android
    // restoring the process, both of which the router allows — printed
    // confident sentences about someone else's domain, or about none.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DomainsProvider>().load(widget.domain),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DomainsProvider>();
    final active = provider.active;
    // Only trust the loaded record if it is actually this domain.
    final d = active?.domain == widget.domain ? active : null;

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
                  d == null
                      ? 'This domain has not loaded, so its verification '
                          'state is unknown.'
                      : d.isVerified
                          ? 'Your domain is verified — trust score '
                              '${d.trustScore ?? 0}.'
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
            // Coloured by outcome. Both results used to be painted in the same
            // neutral grey, so the only thing separating "it worked" from "it
            // blew up" was reading to the end of a sentence that began the
            // same way.
            Text(
              _message!,
              style: ShadowTypography.bodySm.copyWith(
                color: _failed ? ShadowColors.error : ShadowColors.success,
              ),
            ),
          ],
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Metadata', style: ShadowTypography.h4),
                const SizedBox(height: 6),
                // Map.toString() was being printed straight to the user:
                // `{key: value, other: {nested: 1}}`, Dart's debug form,
                // braces and all, on the screen whose whole purpose is this
                // data.
                if (d == null)
                  Text('Not loaded.', style: ShadowTypography.bodySm)
                else if (d.metadata.isEmpty)
                  Text('No metadata set yet.', style: ShadowTypography.bodySm)
                else
                  ...d.metadata.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 110,
                            child: Text(e.key,
                                style: ShadowTypography.caption.copyWith(
                                  color: ShadowColors.textTertiary,
                                )),
                          ),
                          Expanded(
                            child: SelectableText(
                              '${e.value}',
                              style: ShadowTypography.mono,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      // Clear the last result, so a stale success cannot sit under a fresh
      // attempt that has not finished.
      _message = null;
      _failed = false;
    });
    try {
      await _service.verify(widget.domain);
      if (!mounted) return;
      setState(() {
        _message = 'Verification requested.';
        _failed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Verification failed: $e';
        _failed = true;
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }
}
