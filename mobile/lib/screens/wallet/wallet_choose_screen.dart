import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_spacing.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/shadow_button.dart';

class WalletChooseScreen extends StatelessWidget {
  const WalletChooseScreen({super.key});

  Future<void> _createNewWallet(BuildContext context) async {
    final password = await _askPassword(context, mode: _PasswordMode.create);
    if (password == null || !context.mounted) return;
    try {
      final phrase = await context.read<WalletProvider>().createNewWallet(
            password,
          );
      // Straight to the phrase, never to /home. These words exist in exactly
      // one place until the user writes them down, and this is the only
      // moment Shadow can show them.
      if (context.mounted) context.go('/wallet/phrase', extra: phrase);
    } catch (e) {
      // storeWallet re-throws as Exception('Failed to store wallet: $e'), so
      // interpolating it showed a user a nested raw toString that said
      // nothing about whether a wallet now exists. It does not: createNewWallet
      // stores before it touches provider state, so a throw means nothing was
      // saved, and that is the useful sentence.
      assert(() {
        debugPrint('createNewWallet failed: $e');
        return true;
      }());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not create the wallet. Nothing was saved on this device.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(ShadowSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Text(
                  'Choose your\nwallet',
                  style: ShadowTypography.displayMd,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a brand new Solana wallet or import an existing one using your 12-word recovery phrase.',
                  style: ShadowTypography.bodySm,
                ),
                const SizedBox(height: 32),
                _WalletOption(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Create a new wallet',
                  subtitle:
                      'Twelve words, shown once, that restore it anywhere',
                  color: ShadowColors.primary,
                  onTap: () => _createNewWallet(context),
                ),
                const SizedBox(height: 12),
                _WalletOption(
                  icon: Icons.download_rounded,
                  title: 'Import existing wallet',
                  // The import screen has exactly twelve slots, validates
                  // "all 12 words", and is titled for twelve. This was the
                  // only mention of 24 anywhere in the app, and it sent a user
                  // holding a 24-word phrase into a screen that cannot take
                  // it.
                  subtitle: 'Restore using your 12-word recovery phrase',
                  color: ShadowColors.tileBlue,
                  onTap: () => context.push('/wallet/import'),
                ),
                const Spacer(),
                ShadowButton(
                  label: 'Cancel',
                  variant: ShadowButtonVariant.ghost,
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
              color: ShadowColors.recessDeep,
              borderRadius: BorderRadius.circular(ShadowRadius.sm),
              border: Border.all(color: color.withValues(alpha: 0.32)),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ShadowTypography.h4),
                const SizedBox(height: 4),
                Text(subtitle, style: ShadowTypography.bodySm),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: ShadowColors.textTertiary),
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

  // Disposed when the sheet closes. This is a plain function, so nothing owned
  // these — every open of the password sheet, cancelled ones included, leaked
  // two ChangeNotifiers for the life of the process.
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ShadowColors.surface,
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
                    style: ShadowTypography.h3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mode == _PasswordMode.create
                        ? 'Used to encrypt your private key on this device. It never leaves your phone.'
                        : 'Enter the password you set when the wallet was created.',
                    style: ShadowTypography.bodySm,
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
                      validator: (v) => v != controller.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 20),
                  ShadowButton(
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

  controller.dispose();
  confirm.dispose();
  return result;
}
