import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  String _from = 'SOL';
  String _to = 'USDC';
  final _amount = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<TokensProvider>();
    final mints = {'SOL', ...tokens.tokens.map((t) => t.symbol)}.toList();
    if (!mints.contains(_to)) _to = 'USDC';

    return ShadowScaffold(
      title: 'Swap',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _swapCard(
            label: 'From',
            symbol: _from,
            onSymbolChange: (v) => setState(() => _from = v),
            controller: _amount,
            options: mints,
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: ShadowColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                color: Colors.white,
                icon: const Icon(Icons.swap_vert_rounded),
                onPressed: () {
                  setState(() {
                    final tmp = _from;
                    _from = _to;
                    _to = tmp;
                  });
                },
              ),
            ),
          ),
          _swapCard(
            label: 'To',
            symbol: _to,
            onSymbolChange: (v) => setState(() => _to = v),
            readOnly: true,
            hint: '0.00',
            options: mints,
          ),
          const SizedBox(height: 24),
          ShadowButton(
            label: 'Swap',
            size: ShadowButtonSize.lg,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Swap route coming soon')),
              );
              context.pop();
            },
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
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
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
