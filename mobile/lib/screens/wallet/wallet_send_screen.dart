import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/tokens_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class WalletSendScreen extends StatefulWidget {
  const WalletSendScreen({super.key});

  @override
  State<WalletSendScreen> createState() => _WalletSendScreenState();
}

class _WalletSendScreenState extends State<WalletSendScreen> {
  final _address = TextEditingController();
  final _amount = TextEditingController();
  String _selectedMint = 'SOL';
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Sending is not implemented, and the screen says so up front.
  ///
  /// This used to POST /tokens/transfer — a route that never existed — and
  /// then report "Transaction submitted" for a request that had failed.
  /// Building it properly means constructing, signing and submitting a real
  /// Solana transaction with the user's key. That moves actual money and has
  /// never run on a device, so it is not something to ship quietly behind a
  /// button that already looks finished. The controls stay visible so the
  /// shape of the feature is clear; the action is disabled.
  static const bool _sendingImplemented = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<TokensProvider>();
    // A Set, because DropdownButtonFormField asserts that exactly one item
    // matches the current value. Two balances abbreviating to the same symbol
    // — or any token whose symbol is literally 'SOL' — used to produce a
    // duplicate here and take the screen down with 'There should be exactly
    // one item with [DropdownButton]'s value'.
    final allMints =
        <String>{'SOL', ...tokens.tokens.map((t) => t.symbol)}.toList();

    return ShadowScaffold(
      title: 'Send',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (!_sendingImplemented) ...[
            GlassCard(
              padding: const EdgeInsets.all(16),
              border: Border.all(
                  color: ShadowColors.warning.withValues(alpha: 0.4)),
              child: Row(
                children: [
                  const Icon(Icons.construction_rounded,
                      color: ShadowColors.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sending is not built yet. Shadow can show what you '
                      'hold, but cannot move it — use a wallet app for '
                      'transfers until this ships.',
                      style: ShadowTypography.bodySm,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destination', style: ShadowTypography.label),
                const SizedBox(height: 8),
                TextField(
                  controller: _address,
                  decoration: const InputDecoration(
                    hintText: 'Enter a Solana address',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asset', style: ShadowTypography.label),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedMint,
                  items: allMints
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedMint = v ?? 'SOL'),
                  dropdownColor: ShadowColors.surfaceElevated,
                ),
                const SizedBox(height: 12),
                Text('Amount', style: ShadowTypography.label),
                const SizedBox(height: 8),
                TextField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '0.00'),
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
          const SizedBox(height: 24),
          const ShadowButton(
            label:
                _sendingImplemented ? 'Review & Send' : 'Sending unavailable',
            onPressed: null,
            size: ShadowButtonSize.lg,
          ),
        ],
      ),
    );
  }
}
