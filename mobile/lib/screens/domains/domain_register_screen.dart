import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/domains_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../services/fetch_outcome.dart';
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

  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // GoRouterState.of does an inherited-widget lookup, which is illegal from
    // initState and trips an assertion in debug builds. This is the earliest
    // point it is safe; the flag keeps it to one prefill so the field is not
    // reset out from under someone typing.
    if (_prefilled) return;
    _prefilled = true;
    final q = GoRouterState.of(context).uri.queryParameters['q'];
    if (q != null && q.isNotEmpty) _domainCtrl.text = q;
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
                  autocorrect: false,
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
              style:
                  ShadowTypography.bodySm.copyWith(color: ShadowColors.error),
            ),
          ],
          const SizedBox(height: 20),
          // Say why it is disabled. The button greyed out with no wallet and
          // nothing on the screen explained it, so the whole form was fillable
          // and the only action was dead for a reason the user could not see.
          if (wallet.isEmpty) ...[
            Text(
              'Registering writes an owner on-chain, so it needs a wallet. '
              'Create or import one first.',
              style: ShadowTypography.bodySm,
            ),
            const SizedBox(height: 12),
          ],
          // Enabled only when there is something to register. Nothing used to
          // stop this firing with an empty field — the enabled state ignored
          // the text entirely and the field had no onChanged — which POSTed a
          // registration for the empty string.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _domainCtrl,
            builder: (context, value, _) => ShadowButton(
              label: _submitting ? 'Registering...' : 'Register on-chain',
              size: ShadowButtonSize.lg,
              trailing: Icons.rocket_launch_rounded,
              isLoading: _submitting,
              onPressed:
                  _submitting || wallet.isEmpty || value.text.trim().isEmpty
                      ? null
                      : () => _submit(wallet),
            ),
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
