import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/blind_colors.dart';
import '../../theme/blind_spacing.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/blind_button.dart';

class WalletChooseScreen extends StatelessWidget {
  const WalletChooseScreen({super.key});

  Future<void> _createNewWallet(BuildContext context) async {
    final password = await _askPassword(context, mode: _PasswordMode.create);
    if (password == null) return;
    try {
      await context.read<WalletProvider>().createNewWallet(password);
      if (context.mounted) context.go('/home');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create wallet: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlindColors.background,
      body: GridBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(BlindSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Text(
                  'Choose your\nwallet',
                  style: BlindTypography.displayMd,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a brand new Solana wallet or import an existing one using your 12-word recovery phrase.',
                  style: BlindTypography.bodySm,
                ),
                const SizedBox(height: 32),
                _WalletOption(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Create a new wallet',
                  subtitle: 'Generate a fresh keypair encrypted on this device',
                  color: BlindColors.primary,
                  onTap: () => _createNewWallet(context),
                ),
                const SizedBox(height: 12),
                _WalletOption(
                  icon: Icons.download_rounded,
                  title: 'Import existing wallet',
                  subtitle: 'Restore using your 12 or 24-word seed phrase',
                  color: BlindColors.tileBlue,
                  onTap: () => context.push('/wallet/import'),
                ),
                const Spacer(),
                BlindButton(
                  label: 'Cancel',
                  variant: BlindButtonVariant.ghost,
                  onPressed: () => context.go('/welcome'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletOption extends StatelessWidget {
  const _WalletOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(BlindRadius.sm),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: BlindTypography.h4),
                const SizedBox(height: 4),
                Text(subtitle, style: BlindTypography.bodySm),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: BlindColors.textTertiary),
        ],
      ),
    );
  }
}

enum _PasswordMode {
  create,
  // ignore: unused_field
  unlock,
}

Future<String?> _askPassword(
  BuildContext context, {
  required _PasswordMode mode,
}) async {
  final controller = TextEditingController();
  final confirm = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BlindColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    mode == _PasswordMode.create
                        ? 'Set a wallet password'
                        : 'Unlock your wallet',
                    style: BlindTypography.h3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mode == _PasswordMode.create
                        ? 'Used to encrypt your private key on this device. It never leaves your phone.'
                        : 'Enter the password you set when the wallet was created.',
                    style: BlindTypography.bodySm,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: controller,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) =>
                        (v ?? '').length < 6 ? 'Min 6 characters' : null,
                  ),
                  if (mode == _PasswordMode.create) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirm,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Confirm password'),
                      validator: (v) =>
                          v != controller.text ? 'Passwords do not match' : null,
                    ),
                  ],
                  const SizedBox(height: 20),
                  BlindButton(
                    label: mode == _PasswordMode.create ? 'Create' : 'Unlock',
                    onPressed: () {
                      if (formKey.currentState?.validate() != true) return;
                      Navigator.of(ctx).pop(controller.text);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
