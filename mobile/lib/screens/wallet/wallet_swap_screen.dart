import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/tokens_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class WalletSwapScreen extends StatefulWidget {
  const WalletSwapScreen({super.key});

  @override
  State<WalletSwapScreen> createState() => _WalletSwapScreenState();
}

class _WalletSwapScreenState extends State<WalletSwapScreen> {
  /// Swapping is not implemented, and the screen says so up front — the same
  /// position the send screen already takes, for the same reason. This used
  /// to be a full-strength primary button labelled "Swap" that showed a
  /// "coming soon" toast and popped: a user picked a pair, typed an amount,
  /// pressed the biggest control on the page, and only then learned the
  /// feature does not exist.
  static const bool _swapImplemented = false;

  /// Nullable, and filled from whatever the wallet actually holds.
  ///
  /// These were hardcoded to 'SOL' and 'USDC'. No balance ever carries a
  /// ticker — TokensService sets `symbol` to an abbreviated mint like
  /// '4k3D…zWx7' — so 'USDC' could never be a member of the option list, and
  /// the guard that was meant to catch that (`if (!mints.contains(_to)) _to =
  /// 'USDC';`) re-assigned the same impossible value every build. The screen
  /// opened on an invented pair every time.
  String? _from;
  String? _to;
  final _amount = TextEditingController();

  @override
  void dispose() {
    // There was no dispose() at all, so this controller and its listeners
    // outlived every visit to the screen.
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<TokensProvider>();
    final mints = {'SOL', ...tokens.tokens.map((t) => t.symbol)}.toList();
    final from = _from != null && mints.contains(_from) ? _from! : mints.first;
    final to = _to != null && mints.contains(_to)
        ? _to!
        : mints.firstWhere((m) => m != from, orElse: () => from);

    return ShadowScaffold(
      title: 'Swap',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Same provider contract as the send screen: an unreachable RPC
          // silently reduced both dropdowns to ['SOL'], which is
          // indistinguishable from a wallet that really holds only SOL.
          if (tokens.error != null) ...[
            GlassCard.lit(
              accent: ShadowColors.error,
              padding: const EdgeInsets.all(16),
              child: Text(
                'Balances could not be loaded (${tokens.error}), so the assets '
                'below may be incomplete.',
                style: ShadowTypography.bodySm,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!_swapImplemented) ...[
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
                      'Swapping is not built yet. Shadow can show what you '
                      'hold, but cannot trade it — use a wallet app or an '
                      'exchange until this ships.',
                      style: ShadowTypography.bodySm,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (mints.length < 2) ...[
            Text(
              'This wallet holds one asset, so there is nothing to swap it '
              'for from here.',
              style: ShadowTypography.bodySm,
            ),
            const SizedBox(height: 12),
          ],
          _swapCard(
            label: 'From',
            symbol: from,
            onSymbolChange: (v) => setState(() => _from = v),
            controller: _amount,
            options: mints,
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: ShadowColors.recessDeep,
                shape: BoxShape.circle,
                border: Border.all(
                  color: ShadowColors.primary.withValues(alpha: 0.34),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: ShadowColors.primary.withValues(alpha: 0.13),
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: IconButton(
                color: ShadowColors.primary,
                tooltip: 'Swap the two assets around',
                icon: const Icon(Icons.swap_vert_rounded),
                onPressed: () {
                  setState(() {
                    _from = to;
                    _to = from;
                  });
                },
              ),
            ),
          ),
          _swapCard(
            label: 'To',
            symbol: to,
            onSymbolChange: (v) => setState(() => _to = v),
            readOnly: true,
            hint: '0.00',
            options: mints,
          ),
          const SizedBox(height: 24),
          const ShadowButton(
            label: 'Swapping unavailable',
            size: ShadowButtonSize.lg,
            onPressed: null,
          ),
        ],
      ),
    );
  }

  Widget _swapCard({
    required String label,
    required String symbol,
    required ValueChanged<String> onSymbolChange,
    TextEditingController? controller,
    bool readOnly = false,
    String hint = '',
    required List<String> options,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ShadowTypography.label),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: ShadowTypography.h2,
                  decoration: InputDecoration(
                    hintText: hint.isEmpty ? '0.00' : hint,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              DropdownButton<String>(
                value: options.contains(symbol) ? symbol : options.first,
                dropdownColor: ShadowColors.surfaceElevated,
                items: options
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => onSymbolChange(v ?? symbol),
                underline: const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
