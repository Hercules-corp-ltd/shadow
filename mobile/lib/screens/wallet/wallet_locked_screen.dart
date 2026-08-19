import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../services/quick_unlock.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/shadow_button.dart';

class WalletLockedScreen extends StatefulWidget {
  const WalletLockedScreen({super.key});

  @override
  State<WalletLockedScreen> createState() => _WalletLockedScreenState();
}

class _WalletLockedScreenState extends State<WalletLockedScreen> {
  final _password = TextEditingController();
  final QuickUnlock _quick = QuickUnlock(slot: QuickUnlockSlot.wallet);

  bool _loading = false;
  String? _error;
  bool _remember = false;
  bool _canRemember = false;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _readQuickState();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _readQuickState() async {
    final available = await _quick.isAvailable();
    final armed = await _quick.isEnabled();
    if (!mounted) return;
    setState(() {
      _canRemember = available;
      _armed = armed;
    });
    // Offered straight away when armed. Making somebody reach for a button to
    // avoid typing a password they asked not to type is most of the friction
    // back again.
    if (armed) await _unlockWithDevice();
  }

  Future<void> _unlockWithDevice() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _quick.unlock();
    if (!mounted) return;

    if (!result.succeeded) {
      setState(() => _loading = false);
      final problem = result.problem;
      if (problem != null && problem != QuickUnlockProblem.notSet) {
        setState(() => _error = QuickUnlock.explain(problem));
      }
      return;
    }

    try {
      await context.read<WalletProvider>().unlockWallet(result.passphrase!);
      if (!mounted) return;
      context.go('/home');
    } catch (_) {
      // The stored password no longer opens this wallet — changed, or the
      // wallet was replaced. Drop it rather than going on offering a
      // fingerprint that cannot work again.
      await _quick.disable();
      if (!mounted) return;
      setState(() {
        _armed = false;
        _loading = false;
        _error = 'The remembered password no longer opens this wallet, so '
            'Shadow has forgotten it. Type it instead.';
      });
    }
  }

  Future<void> _unlock() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().unlockWallet(_password.text);
      if (!mounted) return;
      // Stored only after a password that actually opened the wallet, and
      // before navigating, so the screen is still alive to say so if the
      // device check is refused.
      if (_remember && !_armed) {
        final stored = await _quick.enable(_password.text);
        if (!mounted) return;
        if (!stored) {
          final detail = _quick.lastError;
          setState(() {
            _error = detail == null
                ? 'The phone did not confirm it was you, so the password was '
                    'not remembered.'
                : 'Could not remember the password: $detail';
          });
        }
      }
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() {
        _error = 'Incorrect password';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final addr = wallet.walletAddress ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        child: SafeArea(
          // Scrollable, with a floor of the viewport height so the Spacers
          // still centre things when there is room. Adding the remember
          // checkbox pushed this 21px past the screen with the keyboard up —
          // a real overflow on a short handset, not just on the emulator.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Spacer(),
                        // A socket with the lock lit inside it, not a grey coin. This
                        // is the first thing seen on a cold launch, so it is the one
                        // shape that decides whether the app looks like Shadow before
                        // anything else has loaded.
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: ShadowColors.recessDeep,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  ShadowColors.primary.withValues(alpha: 0.26),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: ShadowColors.primary
                                    .withValues(alpha: 0.16),
                                blurRadius: 34,
                                spreadRadius: -6,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.lock_rounded,
                              color: ShadowColors.primary, size: 40),
                        ),
                        const SizedBox(height: 24),
                        Text('Wallet locked',
                            style: ShadowTypography.displayMd),
                        const SizedBox(height: 8),
                        Text(
                          addr.isEmpty
                              ? 'Enter your password to unlock'
                              : '${addr.substring(0, 6)}…${addr.substring(addr.length - 6)}',
                          style: ShadowTypography.bodySm,
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofocus: true,
                          onSubmitted: (_) => _unlock(),
                          decoration:
                              const InputDecoration(hintText: 'Password'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!,
                              style: ShadowTypography.bodySm
                                  .copyWith(color: ShadowColors.error)),
                        ],
                        // A checkbox rather than a card offered afterwards: this screen
                        // is replaced the instant the wallet opens, so anything shown
                        // after a successful unlock cannot be read. Asked before, it
                        // is also just the familiar "remember me".
                        if (_canRemember && !_armed) ...<Widget>[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => setState(() => _remember = !_remember),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: <Widget>[
                                  Checkbox(
                                    value: _remember,
                                    onChanged: (v) =>
                                        setState(() => _remember = v ?? false),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Remember this password and unlock with my '
                                      'fingerprint',
                                      style: ShadowTypography.bodySm,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_remember)
                            Text(
                              'Stored on this phone. Anything that opens the phone '
                              'then opens the wallet.',
                              style: ShadowTypography.caption
                                  .copyWith(color: ShadowColors.warning),
                            ),
                        ],
                        const SizedBox(height: 16),
                        ShadowButton(
                          label: 'Unlock',
                          isLoading: _loading,
                          onPressed: _loading ? null : _unlock,
                          size: ShadowButtonSize.lg,
                        ),
                        if (_armed) ...<Widget>[
                          const SizedBox(height: 10),
                          ShadowButton(
                            label: 'Use my fingerprint',
                            variant: ShadowButtonVariant.secondary,
                            onPressed: _loading ? null : _unlockWithDevice,
                          ),
                        ],
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete wallet?'),
                                content: Text(
                                  context
                                              .read<WalletProvider>()
                                              .hasRecoveryPhrase ==
                                          true
                                      ? 'This erases the encrypted wallet from this '
                                          'device. You can restore it from your '
                                          'twelve words.'
                                      : 'This wallet has no recovery phrase, so the '
                                          'key on this device is the only copy. '
                                          'Deleting it destroys the wallet and any '
                                          'funds in it, permanently.',
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              await context
                                  .read<WalletProvider>()
                                  .deleteWallet();
                              if (context.mounted) context.go('/welcome');
                            }
                          },
                          child: const Text('Forgot password? Delete wallet'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
