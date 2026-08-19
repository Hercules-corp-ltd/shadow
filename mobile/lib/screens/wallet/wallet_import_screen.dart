import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class WalletImportScreen extends StatefulWidget {
  const WalletImportScreen({super.key});

  @override
  State<WalletImportScreen> createState() => _WalletImportScreenState();
}

class _WalletImportScreenState extends State<WalletImportScreen> {
  final List<TextEditingController> _controllers =
      List.generate(12, (_) => TextEditingController());
  final TextEditingController _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final words = _controllers.map((c) => c.text.trim()).toList();
    if (words.any((w) => w.isEmpty)) {
      setState(() => _error = 'Please fill in all 12 words');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await context.read<WalletProvider>().importFromSeedPhrase(
            words,
            _password.text,
          );
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() {
        _error = 'Failed to import: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Import existing\nwallet',
      subtitle: 'Enter your 12-word recovery phrase',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              // Twelve fields that between them are a wallet.
              //
              // These were left on the framework defaults, which means
              // autocorrect and predictive suggestions were ON: every word of
              // a BIP-39 seed typed here went into the system keyboard's
              // personal dictionary, and on both platforms that store syncs
              // to the vendor's cloud by default. The phrase reconstructs the
              // wallet, so the whole point of it never leaving the device was
              // being lost to the software keyboard.
              //
              // enableSuggestions and autocorrect off, and the field is not
              // obscured — a user restoring a wallet needs to see what they
              // typed — but it is marked as not eligible for autofill save.
              itemBuilder: (_, i) => TextField(
                controller: _controllers[i],
                textInputAction:
                    i == 11 ? TextInputAction.done : TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                autofillHints: const <String>[],
                keyboardType: TextInputType.visiblePassword,
                style: ShadowTypography.body,
                decoration: InputDecoration(
                  hintText: '${i + 1}.',
                  hintStyle: ShadowTypography.body
                      .copyWith(color: ShadowColors.textTertiary),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Password', style: ShadowTypography.label),
          const SizedBox(height: 8),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Password to encrypt this wallet',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: ShadowTypography.bodySm
                    .copyWith(color: ShadowColors.error)),
          ],
          const SizedBox(height: 24),
          ShadowButton(
            label: 'Import Wallet',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
            size: ShadowButtonSize.lg,
          ),
        ],
      ),
    );
  }
}
