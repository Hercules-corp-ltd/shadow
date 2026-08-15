import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/tokens_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/tokens_service.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class WalletSendScreen extends StatefulWidget {
  const WalletSendScreen({super.key});

  @override
  State<WalletSendScreen> createState() => _WalletSendScreenState();
}

class _WalletSendScreenState extends State<WalletSendScreen> {
  final _address = TextEditingController();
  final _amount = TextEditingController();
  String _selectedMint = 'SOL';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final to = _address.text.trim();
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (to.isEmpty || amount <= 0) {
      setState(() => _error = 'Enter a valid destination and amount');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final from = context.read<WalletProvider>().walletAddress!;
      await TokensService().createTransfer(
        fromWallet: from,
        toWallet: to,
        mintAddress: _selectedMint,
        amount: amount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction submitted')),
      );
      context.pop();
    } catch (e) {
      setState(() {
        _error = 'Failed: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<TokensProvider>();
    final allMints = ['SOL', ...tokens.tokens.map((t) => t.symbol)];

    return BlindScaffold(
      title: 'Send',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destination', style: BlindTypography.label),
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
                Text('Asset', style: BlindTypography.label),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedMint,
                  items: allMints
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedMint = v ?? 'SOL'),
                  dropdownColor: BlindColors.surfaceElevated,
                ),
                const SizedBox(height: 12),
                Text('Amount', style: BlindTypography.label),
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
                style: BlindTypography.bodySm
                    .copyWith(color: BlindColors.error)),
          ],
          const SizedBox(height: 24),
          BlindButton(
            label: 'Review & Send',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
            size: BlindButtonSize.lg,
          ),
        ],
      ),
    );
  }
}
