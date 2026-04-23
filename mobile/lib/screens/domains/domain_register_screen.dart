import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/domains_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DomainRegisterScreen extends StatefulWidget {
  const DomainRegisterScreen({super.key});

  @override
  State<DomainRegisterScreen> createState() => _DomainRegisterScreenState();
}

class _DomainRegisterScreenState extends State<DomainRegisterScreen> {
  final _domainCtrl = TextEditingController();
  final _programCtrl = TextEditingController();
  int _years = 1;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = GoRouterState.of(context).uri.queryParameters['q'];
    if (q != null) _domainCtrl.text = q;
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _programCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>().walletAddress ?? '';

    return ShadowScaffold(
      title: 'Register Domain',
      subtitle: 'Claim your .shadow name on-chain',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Domain', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                TextField(
                  controller: _domainCtrl,
                  decoration: const InputDecoration(
                    hintText: 'yourname.shadow',
                  ),
                ),
                const SizedBox(height: 20),
                Text('Site registry address', style: ShadowTypography.h4),
                const SizedBox(height: 6),
                Text(
                  'The PDA of your registered site. Leave blank to register the domain only.',
                  style: ShadowTypography.caption,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _programCtrl,
                  decoration: const InputDecoration(
                    hintText: 'PDA pubkey',
                  ),
                ),
                const SizedBox(height: 20),
                Text('Duration', style: ShadowTypography.h4),
                const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            Text(
              _error!,
              style: ShadowTypography.bodySm
                  .copyWith(color: ShadowColors.error),
            ),
          ],
          const SizedBox(height: 20),
          ShadowButton(
            label: _submitting ? 'Registering...' : 'Register on-chain',
            size: ShadowButtonSize.lg,
            trailing: Icons.rocket_launch_rounded,
            isLoading: _submitting,
            onPressed: _submitting || wallet.isEmpty ? null : () => _submit(wallet),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(String wallet) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final d = await context.read<DomainsProvider>().register(
            domain: _domainCtrl.text.trim(),
            programAddress: _programCtrl.text.trim(),
            ownerPubkey: wallet,
            years: _years,
          );
      if (!mounted) return;
      context.go('/domains/${d.domain}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
